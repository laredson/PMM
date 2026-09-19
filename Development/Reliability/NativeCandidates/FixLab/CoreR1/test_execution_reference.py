"""Negative oracle checks on OWN artifacts, never a product or game test."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
import build
import verify_execution as v


class ExecutionOracleTests(unittest.TestCase):
    def fixture(self):
        source=os.environ.get('PMM_R1_EXECUTION_FIXTURES')
        if not source:self.skipTest('synthetic export opt-in required')
        temporary=tempfile.TemporaryDirectory();self.addCleanup(temporary.cleanup)
        out=Path(temporary.name)/'basic';shutil.copytree(Path(source)/'basic',out)
        return out

    def edit(self,root,filename,key,value):
        path=root/filename;doc=json.loads(path.read_text());doc[key]=value;path.write_text(json.dumps(doc))

    def test_accepts_independent_bytes(self):
        self.assertEqual(v.check(self.fixture())['files'],10)

    def test_wrong_actual_bytes(self):
        d=self.fixture();p=d/'actual/C/Body1.uexp';p.write_bytes(p.read_bytes()+b'x')
        with self.assertRaisesRegex(ValueError,'actual file'):v.check(d)

    def test_wrong_expected_not_adopted(self):
        d=self.fixture();p=d/'expected/C/Body1.uexp';p.write_bytes(b'fake')
        with self.assertRaisesRegex(ValueError,'expected fixture'):v.check(d)

    def test_wrong_archive(self):
        d=self.fixture();p=d/'output.pak';raw=bytearray(p.read_bytes());raw[53]^=1;p.write_bytes(raw)
        with self.assertRaises(ValueError):v.check(d)

    def test_readiness_claim_rejected(self):
        d=self.fixture();self.edit(d,'report.json','transformReady',True)
        with self.assertRaisesRegex(ValueError,'readiness'):v.check(d)

    def test_binding_claim_rejected(self):
        d=self.fixture();self.edit(d,'report.json','membershipSHA256','0'*64)
        with self.assertRaisesRegex(ValueError,'binding'):v.check(d)

    def test_missing_output_descriptor(self):
        d=self.fixture();p=d/'report.json';doc=json.loads(p.read_text());doc['outputs'].pop();p.write_text(json.dumps(doc))
        with self.assertRaisesRegex(ValueError,'descriptors'):v.check(d)

    def test_duplicate_json_key_rejected(self):
        with self.assertRaises(ValueError):v.js(b'{"a":1,"a":2}')

    def test_fixture_generator_reproduces_vectors(self):
        path=Path(__file__).parent/'testdata/make_execution.py'
        spec=importlib.util.spec_from_file_location('own_execution_fixture',path)
        generator=importlib.util.module_from_spec(spec);spec.loader.exec_module(generator)
        self.assertEqual(generator.encoded(),path.with_name('execution-vectors.json').read_bytes())

    def test_builder_stages_both_real_libraries(self):
        files=build.collect_sources(Path(__file__).parent)
        self.assertIn('UAsset/rewrite.go',files);self.assertIn('UAsset/postprocess.go',files)
        self.assertIn('PAKV11/reader.go',files);self.assertIn('CoreR1/testdata/execution-vectors.json',files)
        self.assertFalse(any(n.startswith('UAsset/') and n.endswith('_test.go') for n in files))

    def test_builder_rejects_missing_dependency(self):
        with tempfile.TemporaryDirectory() as temp:
            here=Path(temp)/'CoreR1';here.mkdir();(here/'go.mod').write_text('module test\n')
            with self.assertRaises(ValueError):build.collect_sources(here)

    def test_unsafe_paths_and_duplicate_report_fields(self):
        for p in ('../escape','C:/escape','a\\b','NUL'):
            with self.subTest(path=p), self.assertRaises(ValueError):v.checked_path(Path('.'),p)


if __name__=='__main__':unittest.main()
