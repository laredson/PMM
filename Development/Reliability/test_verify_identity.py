"""Synthetic verifier tests. No PMM binaries, network or Windows UI are executed."""
import hashlib
import json
import unittest
import verify_identity as v


class IdentityTests(unittest.TestCase):
    def setUp(self):
        self.files = {
            v.META + 'VERSION.txt': b'1.5.0.1\n',
            v.META + 'BUILD_ID.txt': b'fixture-build\n',
            v.META + 'RELEASE_MANIFEST.json': json.dumps({'version': '1.5.0.1', 'buildId': 'fixture-build'}).encode(),
            'example.txt': b'fixture',
        }
        self.rehash()

    def rehash(self):
        self.files[v.SUMS] = ''.join(hashlib.sha256(data).hexdigest() + '  ' + path + '\n'
                                   for path, data in sorted(self.files.items()) if path != v.SUMS).encode()

    def test_valid_input(self):
        result = v.verify(self.files, '1.5.0.1', 'fixture-build')
        self.assertEqual(result['checksumRows'], 4)
        self.assertFalse(result['pmmExecuted'])

    def test_changed_payload(self):
        self.files['example.txt'] = b'changed'
        with self.assertRaisesRegex(ValueError, 'Checksum mismatches'):
            v.verify(self.files, '1.5.0.1')

    def test_missing_file(self):
        self.files.pop('example.txt')
        with self.assertRaisesRegex(ValueError, 'Coverage mismatch'):
            v.verify(self.files, '1.5.0.1')

    def test_extra_file(self):
        self.files['extra.txt'] = b'x'
        with self.assertRaisesRegex(ValueError, 'Coverage mismatch'):
            v.verify(self.files, '1.5.0.1')

    def test_duplicate_checksum(self):
        self.files[v.SUMS] += self.files[v.SUMS].splitlines(keepends=True)[0]
        with self.assertRaisesRegex(ValueError, 'Duplicate checksum path'):
            v.verify(self.files, '1.5.0.1')

    def test_self_reference(self):
        self.files[v.SUMS] += b'0' * 64 + b'  ' + v.SUMS.encode() + b'\n'
        with self.assertRaisesRegex(ValueError, 'must not hash itself'):
            v.verify(self.files, '1.5.0.1')

    def test_version_disagreement_with_valid_hashes(self):
        self.files[v.META + 'VERSION.txt'] = b'1.3.4.1\n'
        self.rehash()
        with self.assertRaisesRegex(ValueError, 'version disagree'):
            v.verify(self.files, '1.5.0.1')

    def test_build_disagreement_with_valid_hashes(self):
        self.files[v.META + 'BUILD_ID.txt'] = b'other-build\n'
        self.rehash()
        with self.assertRaisesRegex(ValueError, 'build disagree'):
            v.verify(self.files, '1.5.0.1')


if __name__ == '__main__':
    unittest.main()
