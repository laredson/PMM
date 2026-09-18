"""Negative controls of the independent oracle; requires synthetic fixture export."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import verify_capture as v


class CaptureOracleTests(unittest.TestCase):
    def get_root(self):
        path = os.environ.get('PMM_R1_CAPTURE_FIXTURES')
        if not path:
            self.skipTest('Synthetic export not supplied')
        return Path(path) / 'with-schema'

    def test_positive_fixture(self):
        result = v.check(self.get_root())
        self.assertEqual(result['assetFiles'], 19)
        self.assertEqual(result['files'], 23)

    def changed_report(self, mutate):
        root = self.get_root()
        old = v.load
        report = old(root, 'report.json')
        mutate(report)
        with patch.object(v, 'load', side_effect=lambda r, n: report if n == 'report.json' else old(r, n)):
            with self.assertRaises(ValueError):
                v.check(root)

    def test_false_ready(self):
        self.changed_report(lambda r: r.update(transformReady=True))

    def test_false_membership(self):
        self.changed_report(lambda r: r.update(extractionMembershipVerified=True))

    def test_missing_row(self):
        self.changed_report(lambda r: r['files'].pop())

    def test_duplicate_row(self):
        self.changed_report(lambda r: r['files'].append(r['files'][0]))

    def test_wrong_hash(self):
        self.changed_report(lambda r: r['files'][0]['file'].update(sha256='0' * 64))

    def test_false_schema_semantics(self):
        self.changed_report(lambda r: r['dossiers'][0].update(layoutSemanticsVerified=True))

    def test_wrong_total(self):
        self.changed_report(lambda r: r.update(snapshotBytes=0))

    def test_duplicate_json(self):
        with self.assertRaises(ValueError):
            json.loads('{"x":1,"x":2}', object_pairs_hook=v.unique)

    def test_path_escape(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                v.read(Path(tmp), '../outside')


if __name__ == '__main__':
    unittest.main()
