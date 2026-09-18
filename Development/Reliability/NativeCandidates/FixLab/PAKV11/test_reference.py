"""Tests of the independent reader and build-output guards. Synthetic inputs only."""
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import verify_reference as ref

HERE = Path(__file__).resolve().parent


class ReferenceTests(unittest.TestCase):
    def setUp(self):
        self.vector = json.loads((HERE/'testdata/golden.json').read_text())
        self.raw = bytes.fromhex(self.vector['archiveHex'])
        self.expected = {p: bytes.fromhex(v) for p, v in self.vector['expected'].items()}

    def test_independent_golden_readback(self):
        r = ref.verify(self.raw, self.expected)
        self.assertTrue(r['byteExact'])
        self.assertEqual(r['archiveSha256'], self.vector['sha256'])

    def test_golden_recipe_reproduces_frozen_fixture(self):
        p = subprocess.run([sys.executable, '-B', str(HERE/'testdata/make_golden.py')],
                           check=True, capture_output=True, text=True, timeout=10)
        self.assertEqual(json.loads(p.stdout), self.vector)

    def test_all_truncations(self):
        for n in range(len(self.raw)):
            with self.subTest(n=n), self.assertRaises(ref.Invalid):
                ref.parse(self.raw[:n])

    def test_expected_bytes_are_independent_requirement(self):
        b = bytearray(self.raw)
        b[53] = ord('X')
        b[28:48] = hashlib.sha1(b[53:56]).digest()
        self.assertFalse(ref.verify(b)['byteExact'])
        with self.assertRaises(ref.Invalid):
            ref.verify(b, self.expected)

    def test_name_or_file_set_mismatch(self):
        for expected in ({}, {'other': b'abc'}):
            with self.assertRaises(ref.Invalid):
                ref.verify(self.raw, expected)

    def test_footer_flags_and_ranges(self):
        for off in (0, 16, 17, 21, 25, 33, 41, 61):
            b = bytearray(self.raw)
            b[len(b)-221+off] ^= 1
            with self.subTest(off=off), self.assertRaises(ref.Invalid):
                ref.parse(b)

    def test_logical_faults_with_recomputed_index_hashes(self):
        for off, value in ((165+14, 0xffffffff), (165+110, 0xe0400000), (315+12, 0x80000000),
                           (359, 0), (359+14, 0xffffffff), (359+24, 1)):
            b = bytearray(self.raw)
            struct.pack_into('<I', b, off, value)
            b[165+46:165+66] = hashlib.sha1(b[315:359]).digest()
            b[165+86:165+106] = hashlib.sha1(b[359:428]).digest()
            b[428+41:428+61] = hashlib.sha1(b[165:315]).digest()
            with self.subTest(off=off), self.assertRaises(ref.Invalid):
                ref.parse(b)

    def test_path_safety(self):
        for p in ('/a', '../a', 'a/../b', 'a\\b', 'a:b', 'nul.txt', 'CON .txt', 'x/COM1',
                  'bad.', 'bad ', 'caf\u00e9', 'x\x00y', 'a'*256, 'a/'*32+'b'):
            with self.subTest(p=p), self.assertRaises(ref.Invalid):
                ref.safe_path(p)

    def test_hash_vectors_and_case(self):
        for p, h in self.vector['pathHashes'].items():
            self.assertEqual(f'{ref.path_hash(p, 0):016x}', h)
            self.assertEqual(ref.path_hash(p, 0), ref.path_hash(p.upper(), 0))

    def test_extra_bytes_rejected(self):
        with self.assertRaises(ref.Invalid):
            ref.parse(self.raw+b'\0')

    def test_payload_and_header_rejected(self):
        for off in (0, 8, 16, 24, 28, 48, 49, 53):
            b = bytearray(self.raw)
            b[off] ^= 1
            with self.subTest(off=off), self.assertRaises(ref.Invalid):
                ref.parse(b)

    def test_build_existing_output_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p = subprocess.run([sys.executable, '-B', str(HERE/'build.py'), '--out', d],
                               capture_output=True, text=True, timeout=10)
            self.assertEqual(p.returncode, 2)
            self.assertEqual(list(Path(d).iterdir()), [])

    def test_build_internal_output_rejected(self):
        out = HERE/'must-not-create-test-output'
        p = subprocess.run([sys.executable, '-B', str(HERE/'build.py'), '--out', str(out)],
                           capture_output=True, text=True, timeout=10)
        self.assertEqual(p.returncode, 2)
        self.assertFalse(out.exists())


if __name__ == '__main__':
    unittest.main()
