"""Negative checks for the independent OWN synthetic job V2 verifier."""
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
import verify_job_v2 as verifier


class JobV2ReferenceTests(unittest.TestCase):
    def fixture(self):
        source = os.environ.get('PMM_R1_JOB_V2_FIXTURES')
        if not source:
            self.skipTest('requires synthetic job V2 export')
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        destination = Path(temporary.name) / 'job'
        shutil.copytree(Path(source), destination)
        return destination

    def test_fixture(self):
        self.assertEqual(verifier.check(self.fixture())['outputEntriesCompared'], 10)

    def test_install_claim_rejected(self):
        root = self.fixture()
        result = json.loads((root / 'result.json').read_text())
        result['receipt']['installed'] = True
        (root / 'result.json').write_text(json.dumps(result))
        with self.assertRaises(ValueError):
            verifier.check(root)

    def test_job_pin_rejected(self):
        root = self.fixture()
        (root / 'job.sha256').write_text('0' * 64)
        with self.assertRaises(ValueError):
            verifier.check(root)

    def test_foreign_bundle_file_rejected(self):
        root = self.fixture()
        result = json.loads((root / 'result.json').read_text())
        candidate = root / 'candidates' / result['receipt']['candidateName']
        (candidate / 'foreign.bin').write_bytes(b'foreign')
        with self.assertRaises(ValueError):
            verifier.check(root)


if __name__ == '__main__':
    unittest.main()
