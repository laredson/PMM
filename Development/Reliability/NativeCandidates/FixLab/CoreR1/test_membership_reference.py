"""Synthetic membership oracle and local-module staging tests, never real assets."""
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
import build
import verify_membership as v


class MembershipToolTests(unittest.TestCase):
    def fixture(self):
        value = os.environ.get('PMM_R1_MEMBERSHIP_FIXTURES')
        if not value:
            self.skipTest('requires Go synthetic membership export')
        root = Path(value) / 'single'
        return root, json.loads(v.safe_read(root, 'report.json'))

    def test_independent_readback(self):
        root, report = self.fixture()
        self.assertEqual(v.check(root, report)['assets'], 19)

    def test_wrong_archive_owner_rejected(self):
        root, report = self.fixture()
        report['entries'][0]['archive'] = report['archives'][0]['file']
        with self.assertRaises(ValueError):
            v.check(root, report)

    def test_omitted_membership_rejected(self):
        root, report = self.fixture(); report['entries'].pop()
        with self.assertRaises(ValueError):
            v.check(root, report)

    def test_duplicate_membership_rejected(self):
        root, report = self.fixture(); report['entries'].append(copy.deepcopy(report['entries'][0]))
        with self.assertRaises(ValueError):
            v.check(root, report)

    def test_readiness_claim_rejected(self):
        root, report = self.fixture(); report['transformReady'] = True
        with self.assertRaises(ValueError):
            v.check(root, report)

    def test_ownership_policy_rejected(self):
        root, report = self.fixture(); report['currentOwnership'] = 'last-wins'
        with self.assertRaises(ValueError):
            v.check(root, report)

    def test_capture_binding_rejected(self):
        root, report = self.fixture(); report['captureReportSHA256'] = '0'*64
        with self.assertRaises(ValueError):
            v.check(root, report)

    def test_read_count_rejected(self):
        root, report = self.fixture(); report['archiveBytesRead'] += 1
        with self.assertRaises(ValueError):
            v.check(root, report)

    def test_safe_fixture_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            for path in ('../x', '/tmp/x', 'C:/x', 'a\\b'):
                with self.subTest(path=path), self.assertRaises(ValueError):
                    v.safe_read(Path(tmp), path)

    def test_stager_includes_actual_dependency(self):
        data = build.collect_sources(Path(__file__).resolve().parent)
        for key in ('CoreR1/membership.go', 'CoreR1/go.mod', 'PAKV11/reader.go', 'PAKV11/go.mod'):
            self.assertIn(key, data)
        self.assertFalse(any(k.startswith('PAKV11/') and k.endswith('_test.go') for k in data))

    def test_missing_dependency_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'CoreR1'; root.mkdir()
            (root / 'go.mod').write_text('module fixture\n')
            with self.assertRaises(ValueError):
                build.collect_sources(root)

    def test_source_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'CoreR1'; root.mkdir()
            (root / 'go.mod').write_text('module fixture\n')
            real = Path(tmp) / 'real'; real.write_text('package fixture\n')
            try:
                (root / 'bad.go').symlink_to(real)
            except OSError:
                self.skipTest('symlink creation unavailable')
            with self.assertRaises(ValueError):
                build.collect_sources(root)


if __name__ == '__main__':
    unittest.main()
