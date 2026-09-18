"""Synthetic static-comparator tests: no inspected PE or child process is executed."""
import copy
from pathlib import Path
import tempfile
import unittest
import compare_runtime as subject


def record(digest='a', section='one', func='f'):
    return {'pe': {'sha256': digest, 'sections': [{'name': '.text', 'sha256': section, 'rawSize': 20}]},
            'go': {'goVersion': 'go1.23.2', 'settings': {},
                   'applicationFunctions': [{'name': func, 'rawCodeSha256': 'h'}]}}


class ComparisonTests(unittest.TestCase):
    def test_identity_does_not_claim_runtime_acceptance(self):
        a=record(); r=subject.comparison(a,a)
        self.assertTrue(r['byteIdentical'])
        self.assertFalse(r['semanticEquivalenceEstablished'])

    def test_changed_section_and_function_sets_are_visible(self):
        a,b=record(),record('b','two','other')
        r=subject.comparison(a,b)
        self.assertFalse(r['sections'][0]['sameRawBytes'])
        self.assertEqual(r['leftOnlyFunctions'],['f'])
        self.assertEqual(r['rightOnlyFunctions'],['other'])

    def test_same_raw_function_not_whole_program_equivalence(self):
        r=subject.comparison(record(),record('b','two'))
        self.assertEqual(r['sameRawFunctionBytes'],['f'])
        self.assertFalse(r['semanticEquivalenceEstablished'])

    def test_absent_section_has_no_false_match(self):
        a,b=record(),record(); b['pe']['sections']=[]
        r=subject.comparison(a,b)
        self.assertFalse(r['sections'][0]['sameRawBytes'])
        self.assertIsNone(r['sections'][0]['rightBytes'])

    def test_wrong_pin_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'fixture'; p.write_bytes(b'not an EXE')
            with self.assertRaisesRegex(ValueError, 'pin mismatch'):
                subject.check_artifact(p, '0'*64)

    def test_source_report_coverage_and_hash_binding(self):
        with tempfile.TemporaryDirectory() as d:
            src=Path(d)/'Runtime'; src.mkdir()
            names=['main.go','go.mod','build.py','inspect_pe.py','test_tools.py','tools/runtime_meta.go']
            for n in names:
                p=src/n; p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(n.encode())
            report={'originalSha256':subject.ORIGINAL,'candidateSha256':subject.CURRENT,
                    'sourceSha256':{n:subject.sha(src/n) for n in names}}
            shared=src.parent/'Supervision';shared.mkdir()
            for n in ['go.mod','process.go']:(shared/n).write_bytes(n.encode())
            report['sharedSupervisionSha256']={n:subject.sha(shared/n) for n in ['go.mod','process.go']}
            subject.bind_build_report(src,report)
            bad=copy.deepcopy(report); bad['sourceSha256']['../anything']='0'*64
            with self.assertRaisesRegex(ValueError,'coverage'):
                subject.bind_build_report(src,bad)
            (src/'main.go').write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError,'source mismatch'):
                subject.bind_build_report(src,report)




# Missing shared input evidence is rejected, even when candidate-local files match.
class SharedEvidenceTests(unittest.TestCase):
    def test_shared_input_required(self):
        with tempfile.TemporaryDirectory() as d:
            src=Path(d)/'Runtime';src.mkdir()
            names=['go.mod','build.py','inspect_pe.py','test_tools.py','tools/runtime_meta.go']
            for n in names:
                p=src/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(n.encode())
            report={'candidateSha256':subject.CURRENT,'originalSha256':subject.ORIGINAL,'sourceSha256':{n:subject.sha(src/n) for n in names}}
            with self.assertRaisesRegex(ValueError,'supervision source coverage'):
                subject.bind_build_report(src,report)

if __name__ == '__main__': unittest.main()
