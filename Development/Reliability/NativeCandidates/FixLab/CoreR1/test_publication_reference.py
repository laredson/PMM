"""Own synthetic publication exports, no game or executable loading."""
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
import verify_publication as v


class PublicationReferenceTests(unittest.TestCase):
    def fixture(self):
        source = os.environ.get('PMM_R1_PUBLICATION_FIXTURES')
        if not source:
            self.skipTest('requires synthetic publication export')
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        dst = Path(tmp.name) / 'basic'
        shutil.copytree(Path(source) / 'basic', dst)
        receipt = v.js(v.read(dst / 'receipt.json'))
        return dst, dst / receipt['candidateName']

    def test_bundle_and_pre_authored_expectations(self):
        d, _ = self.fixture()
        self.assertEqual(v.check(d)['outputEntriesCompared'], 10)

    def test_missing_completion(self):
        d, r = self.fixture(); (r / 'COMPLETE.json').unlink()
        with self.assertRaises(ValueError): v.check(d)

    def test_wrong_report_bytes(self):
        d, r = self.fixture(); (r / 'execution.json').write_text('{}')
        with self.assertRaises((ValueError, KeyError)): v.check(d)

    def test_wrong_pak(self):
        d, r = self.fixture(); (r / 'candidate.pak').write_bytes(b'not a PAK')
        with self.assertRaises(ValueError): v.check(d)

    def test_staging_not_accepted(self):
        d, r = self.fixture()
        p = v.js(v.read(d / 'receipt.json')); p['candidateName'] = r.name.replace('PMM-candidate-', '.pmm-stage-')
        (d / 'receipt.json').write_text(json.dumps(p))
        with self.assertRaises(ValueError): v.check(d)

    def test_receipt_cannot_claim_game_acceptance(self):
        d, _ = self.fixture(); p = v.js(v.read(d / 'receipt.json')); p['installed'] = True
        (d / 'receipt.json').write_text(json.dumps(p))
        with self.assertRaises(ValueError): v.check(d)

    def test_manifest_pin(self):
        d, _ = self.fixture(); p = v.js(v.read(d / 'receipt.json')); p['manifestSHA256'] = '0' * 64
        (d / 'receipt.json').write_text(json.dumps(p))
        with self.assertRaises(ValueError): v.check(d)

    def test_unexpected_fixture_file(self):
        d, r = self.fixture(); (r / 'foreign').write_bytes(b'fixture')
        with self.assertRaises(ValueError): v.check(d)

if __name__ == '__main__': unittest.main()
