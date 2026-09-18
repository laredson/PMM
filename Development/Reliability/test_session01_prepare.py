"""Synthetic maintenance-tool tests. No PMM EXE, network or Windows UI runs."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import session01_prepare as subject


class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.native = {}
        self.files = {}
        self.manifest = {
            'version': '1.3.4.1', 'releaseDate': '2026-09-16',
            'pmmCoreVersion': '0.9.0', 'mergePlanSchema': 19,
            'arbitraryExistingField': {'preserve': [1, 'example', True]},
            'releaseValidation': {'programRegression': 'historical PASS'},
            'managedRuntimeSha256': {}, 'dotnetRuntimeContract': 'fixture',
            'dotnetRuntimeInventory': 'Engine/dotnet/runtime.sha256.txt',
        }
        for path, (section, field, _) in subject.NATIVES.items():
            data = ('SYNTHETIC FIXTURE ' + path).encode()
            blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
            self.native[path] = (section, field, blob)
            self.files[path] = data
            self.manifest[section] = {field: subject.sha(data), 'version': 'fixture-component'}
        self.files['Engine/repak.exe'] = b'fixture-repak'
        self.files['Resources/Mappings/Mappings.usmap'] = b'fixture-mappings'
        self.files['Engine/dotnet/fixture/runtime.dll'] = b'fixture-runtime'
        inventory = (subject.sha(b'fixture-runtime') + '  runtime.dll\n').encode()
        self.files[self.manifest['dotnetRuntimeInventory']] = inventory
        self.manifest['dotnetRuntimeInventorySha256'] = subject.sha(inventory)
        self.manifest['repakSha256'] = subject.sha(b'fixture-repak')
        self.manifest['mappingsSha256'] = subject.sha(b'fixture-mappings')
        self.files[subject.MANIFEST] = subject.json_bytes(self.manifest)
        self.files[subject.META + 'VERSION.txt'] = b'1.5.0.0\n'
        self.files[subject.META + 'BUILD_ID.txt'] = b'old-build\n'
        self.files[subject.SUMS] = b'old-inventory\n'
        self.files['Modules/example.ps1'] = b'Write-Output example\n'
        self.mock = patch.object(subject, 'NATIVES', self.native)
        self.mock.start()
        self.addCleanup(self.mock.stop)

    def test_only_four_metadata_outputs_and_inputs_unchanged(self):
        before = copy.deepcopy(self.files)
        changes, report = subject.make_plan(self.files)
        self.assertEqual(before, self.files)
        self.assertEqual(set(changes), {subject.MANIFEST, subject.SUMS,
                         subject.META + 'VERSION.txt', subject.META + 'BUILD_ID.txt'})
        self.assertFalse(report['checkoutModified'])

    def test_identity_is_coherent_and_component_versions_are_preserved(self):
        changes, _ = subject.make_plan(self.files)
        result = json.loads(changes[subject.MANIFEST])
        self.assertEqual(result['version'], changes[subject.META + 'VERSION.txt'].decode().strip())
        self.assertEqual(result['buildId'], changes[subject.META + 'BUILD_ID.txt'].decode().strip())
        self.assertEqual(result['pmmCoreVersion'], self.manifest['pmmCoreVersion'])
        self.assertEqual(result['host']['version'], 'fixture-component')
        self.assertEqual(result['arbitraryExistingField'], self.manifest['arbitraryExistingField'])

    def test_checksums_cover_final_bytes_and_exclude_themselves(self):
        changes, _ = subject.make_plan(self.files)
        merged = dict(self.files, **changes)
        sums = dict((p, digest) for digest, p in
                    (line.split('  ', 1) for line in changes[subject.SUMS].decode().splitlines()))
        self.assertEqual(set(sums), set(merged) - {subject.SUMS})
        for p, digest in sums.items():
            self.assertEqual(digest, subject.sha(merged[p]))

    def test_historical_pass_is_not_reused_for_new_candidate(self):
        changes, report = subject.make_plan(self.files)
        result = json.loads(changes[subject.MANIFEST])
        self.assertEqual(result['inheritedReleaseValidation']['evidence'], self.manifest['releaseValidation'])
        self.assertIn('NOT_RUN', result['releaseValidation']['programRegression'])
        self.assertFalse(report['nativeSourceParityVerified'])
        self.assertFalse(result['stableCandidate'])

    def test_idempotent_planning(self):
        changes, _ = subject.make_plan(self.files)
        second, _ = subject.make_plan(dict(self.files, **changes))
        self.assertEqual(changes, second)

    def test_native_mismatch_is_rejected_not_repinned(self):
        self.files['PMM.exe'] = b'different'
        with self.assertRaisesRegex(ValueError, 'Native baseline mismatch'):
            subject.make_plan(self.files)

    def test_dependency_mismatch_is_rejected(self):
        self.files['Engine/repak.exe'] = b'different'
        with self.assertRaisesRegex(ValueError, 'Pinned dependency mismatch'):
            subject.make_plan(self.files)

    def test_runtime_mismatch_is_rejected(self):
        self.files['Engine/dotnet/fixture/runtime.dll'] = b'different'
        with self.assertRaisesRegex(ValueError, 'Pinned dependency mismatch'):
            subject.make_plan(self.files)

    def test_duplicate_manifest_keys_are_rejected(self):
        self.files[subject.MANIFEST] = b'{"version":"a","version":"b"}'
        with self.assertRaisesRegex(ValueError, 'Duplicate JSON key'):
            subject.make_plan(self.files)

    def test_unexpected_version_is_rejected(self):
        self.files[subject.META + 'VERSION.txt'] = b'1.6.0.0\n'
        with self.assertRaisesRegex(ValueError, 'Unexpected package version'):
            subject.make_plan(self.files)

    def test_unsafe_paths_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for value in ('../secret', '/absolute', 'C:/absolute', 'a\\b'):
                with self.subTest(value=value), self.assertRaises(ValueError):
                    subject.safe_file(root, value)

    def test_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'real').write_bytes(b'fixture')
            try:
                (root / 'link').symlink_to(root / 'real')
            except OSError:
                self.skipTest('Symlinks unavailable in this test environment')
            with self.assertRaisesRegex(ValueError, 'Symlink'):
                subject.safe_file(root, 'link')


if __name__ == '__main__':
    unittest.main()
