"""Tests for the offline builder and fixed synthetic-plan oracle."""
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
import build
import verify_fixtures as verify


class ToolsTests(unittest.TestCase):
    def test_existing_output_rejected(self):
        with tempfile.TemporaryDirectory() as t:
            with self.assertRaises(ValueError):
                build.valid_output(Path(t) / 'repo', Path(t))

    def test_repository_output_rejected(self):
        with tempfile.TemporaryDirectory() as t:
            with self.assertRaises(ValueError):
                build.valid_output(Path(t), Path(t) / 'new')

    def test_outside_new_output_accepted(self):
        with tempfile.TemporaryDirectory() as t:
            self.assertEqual(build.valid_output(Path(t) / 'repo', Path(t) / 'new'), Path(t) / 'new')

    def test_symlink_input_rejected(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t); (root / 'real').write_text('{}')
            try:
                (root / 'link').symlink_to(root / 'real')
            except OSError:
                self.skipTest('symlinks unavailable')
            with self.assertRaises(ValueError):
                verify.read(root / 'link')

    def test_oversize_input_rejected(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t) / 'large'; p.write_bytes(b'x' * ((2 << 20) + 1))
            with self.assertRaises(ValueError):
                verify.read(p)

    def fixture(self):
        source = os.environ.get('PMM_R1_TOOL_FIXTURES')
        if not source:
            self.skipTest('synthetic Go export required for oracle negative tests')
        p = Path(source) / 'basic'
        raw = [verify.read(p / f) for f in ('recipe.json', 'donor.json', 'current.json')]
        return json.loads(verify.read(p / 'plan.json')), raw

    def test_oracle_accepts_handwritten_scenario(self):
        plan, raw = self.fixture()
        self.assertEqual(verify.check(plan, *raw, 'basic')['outputs'], 10)

    def test_false_acceptance_rejected(self):
        plan, raw = self.fixture(); plan['transformReady'] = True
        with self.assertRaises(ValueError):
            verify.check(plan, *raw, 'basic')

    def test_missing_target_rejected(self):
        plan, raw = self.fixture(); plan['tasks'].pop()
        with self.assertRaises(ValueError):
            verify.check(plan, *raw, 'basic')

    def test_wrong_source_rejected(self):
        plan, raw = self.fixture(); plan['recipeSHA256'] = '0' * 64
        with self.assertRaises(ValueError):
            verify.check(plan, *raw, 'basic')

    def test_output_omission_rejected(self):
        plan, raw = self.fixture(); plan['outputs'].pop()
        with self.assertRaises(ValueError):
            verify.check(plan, *raw, 'basic')


if __name__ == '__main__':
    unittest.main()
