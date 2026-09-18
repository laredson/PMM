"""Synthetic tests of provenance tools; never execute FixLab or game tools."""
import base64
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import audit_source as a


def split(data):
    return [data[i:i+1] for i in range(7)] + [data[7:]]


class SourceAuditTests(unittest.TestCase):
    def test_valid_overlay_pin(self):
        data = b'synthetic archive bytes'
        self.assertEqual(a.decode_pinned_overlay(split(base64.b64encode(data)), a.sha(data)), data)

    def test_line_wrapping_only_ignored(self):
        data = b'synthetic archive bytes'
        parts = [p+b'\r\n' for p in split(base64.b64encode(data))]
        self.assertEqual(a.decode_pinned_overlay(parts, a.sha(data)), data)

    def test_wrong_part_count(self):
        with self.assertRaisesRegex(ValueError, 'eight'):
            a.decode_pinned_overlay([b''] * 7)

    def test_padding_not_repaired(self):
        with self.assertRaisesRegex(ValueError, 'INVALID_BASE64'):
            a.decode_pinned_overlay(split(b'Zml4bGFiIHRlc3Q'))

    def test_non_alphabet_rejected(self):
        with self.assertRaisesRegex(ValueError, 'INVALID_BASE64'):
            a.decode_pinned_overlay(split(b'Zml4bGFiIHRlc3Q=!'))

    def test_canonical_padding_bits_required(self):
        with self.assertRaisesRegex(ValueError, 'NONCANONICAL'):
            a.decode_pinned_overlay(split(b'Zh=='), a.sha(b'f'))

    def test_valid_base64_wrong_pin_rejected(self):
        with self.assertRaisesRegex(ValueError, 'HASH_MISMATCH'):
            a.decode_pinned_overlay(split(base64.b64encode(b'wrong archive')))

    def test_extra_or_missing_part_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            p = root/'.github/bootstrap'; p.mkdir(parents=True)
            for i in range(9):
                (p/('fixlab-r2-overlay.patch.xz.b64.part'+f'{i:02d}')).write_bytes(b'fixture')
            with self.assertRaisesRegex(ValueError, 'part set'):
                a.audit_overlay(root)

    def test_size_limit(self):
        with self.assertRaisesRegex(ValueError, 'limit'):
            a.decode_pinned_overlay([b'A' * (1 << 20)] * 8)

    def test_json_duplicates_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            json.loads('{"x":1,"x":2}', object_pairs_hook=a.unique)

    def test_unsafe_paths_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            for p in ('../secret', '/secret', 'a\\secret', 'C:/secret', 'a\x00b'):
                with self.subTest(p=p), self.assertRaises(ValueError):
                    a.read_file(Path(d), p)

    def test_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root/'real').write_bytes(b'data')
            try:
                (root/'alias').symlink_to(root/'real')
            except OSError:
                self.skipTest('No symlink support')
            with self.assertRaisesRegex(ValueError, 'Symlink'):
                a.read_file(root, 'alias')

    def test_bounded_read(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); (root/'f').write_bytes(b'12345')
            with self.assertRaisesRegex(ValueError, 'Oversize'):
                a.read_file(root, 'f', 4)

    def test_original_mismatch_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            path = root/'PMM/Resources/Metadata/RELEASE_MANIFEST.json'
            path.parent.mkdir(parents=True)
            path.write_text('{"fixLabEngine":{"engineSha256":"x"},"fixLabEngineSha256":"x"}')
            exe = root/'PMM/Engine/PMMFixLab.exe'; exe.parent.mkdir(parents=True)
            exe.write_bytes(b'fixture')
            with self.assertRaisesRegex(ValueError, 'pin mismatch'):
                a.audit_contracts(root)

    def test_payload_mismatch_rejected(self):
        manifest = {'fixLabEngine': {'engineSha256': a.ORIGINAL_SHA}, 'fixLabEngineSha256': a.ORIGINAL_SHA}
        recipe = {'schema':'PMM_FIXLAB_VARIANT_RECIPE_V2','variantId':a.VARIANTS[0],
                  'coreRecipe':'core.json', 'operations':[{'op':'patch','alternatives':[
                      {'patch':'payload-v2/a.pmmdlt','patchSha256':'0'*64}]}]}
        def files(root, rel, limit=0):
            return json.dumps(recipe).encode() if rel.endswith('-v2.json') else b'fixture'
        def dig(data):
            return a.ORIGINAL_SHA if data == b'fixture' else 'f'*64
        with patch.object(a, 'read_json', return_value=manifest), patch.object(a, 'read_file', side_effect=files), patch.object(a, 'sha', side_effect=dig):
            with self.assertRaisesRegex(ValueError, 'payload mismatch'):
                a.audit_contracts(Path('unused'))


if __name__ == '__main__':
    unittest.main()
