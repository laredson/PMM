"""Synthetic PE inspection and output guards only; never execute the candidate."""
from pathlib import Path
import json
import struct
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
import inspect_pe

ROOT = Path(__file__).resolve().parent


def fixture():
    b = bytearray(1024)
    b[:2] = b'MZ'
    struct.pack_into('<I', b, 60, 128)
    b[128:132] = b'PE\0\0'
    struct.pack_into('<HH', b, 132, 0x8664, 1)
    struct.pack_into('<H', b, 148, 240)
    struct.pack_into('<H', b, 152, 0x20b)
    struct.pack_into('<H', b, 220, 2)
    b[392:400] = b'.text\0\0\0'
    struct.pack_into('<IIII', b, 400, 16, 4096, 512, 512)
    return b


class ToolsTest(unittest.TestCase):
    def inspect_bytes(self, data):
        with tempfile.TemporaryDirectory() as temp:
            file = Path(temp)/'fixture.exe'
            file.write_bytes(data)
            return inspect_pe.inspect(file)

    def test_minimal_pe_hash_and_section(self):
        b = fixture()
        result = self.inspect_bytes(b)
        self.assertEqual(result['sha256'], inspect_pe.digest(b))
        self.assertEqual(result['sections'][0]['sha256'], inspect_pe.digest(b[512:]))
        self.assertEqual(result['subsystem'], 2)
        self.assertFalse(result['executed'])

    def test_adjacent_function_name_strings(self):
        b = fixture()
        names = b'\0main.one\0main.two\0'
        b[512:512+len(names)] = names
        self.assertEqual(self.inspect_bytes(b)['embeddedHostFunctionNames'], ['main.one', 'main.two'])

    def test_rejects_non_pe(self):
        with self.assertRaises(ValueError): self.inspect_bytes(b'not-a-pe')

    def test_rejects_out_of_bounds_header(self):
        b = fixture(); struct.pack_into('<I', b, 60, 100000)
        with self.assertRaises(ValueError): self.inspect_bytes(b)

    def test_rejects_truncated_sections(self):
        b = fixture(); struct.pack_into('<H', b, 134, 50)
        with self.assertRaises(ValueError): self.inspect_bytes(b)

    def test_rejects_wrong_architecture(self):
        b = fixture(); struct.pack_into('<H', b, 132, 0x14c)
        with self.assertRaises(ValueError): self.inspect_bytes(b)

    def test_rejects_raw_section_past_eof(self):
        b = fixture(); struct.pack_into('<I', b, 412, 9999)
        with self.assertRaises(ValueError): self.inspect_bytes(b)

    def test_existing_output_is_not_modified(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp)/'existing'; out.mkdir()
            (out/'keep').write_text('untouched')
            p = subprocess.run([sys.executable, '-B', str(ROOT/'build.py'), '--out', str(out)],
                               capture_output=True, timeout=10)
            self.assertEqual(p.returncode, 2)
            self.assertEqual([v.name for v in out.iterdir()], ['keep'])
            self.assertEqual((out/'keep').read_text(), 'untouched')

    def test_output_inside_checkout_is_rejected(self):
        out = ROOT/'OUTPUT_MUST_NOT_EXIST'
        self.assertFalse(out.exists())
        p = subprocess.run([sys.executable, '-B', str(ROOT/'build.py'), '--out', str(out)],
                           capture_output=True, timeout=10)
        self.assertEqual(p.returncode, 2)
        self.assertFalse(out.exists())


if __name__ == '__main__': unittest.main()
