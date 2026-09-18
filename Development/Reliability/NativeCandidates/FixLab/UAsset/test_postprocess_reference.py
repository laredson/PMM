"""Tests of the independent synthetic verifier, not the FixLab application."""
import base64
import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).with_name('testdata')))
from make_postprocess import all_cases, make_case, sha, b64, jsonb, encoded_cases
from verify_postprocess import verify, property_offset


def packet(v):
    return dict(Input=dict(id=v['id'],Header=v['header'],Data=v['data'],Request=v['request'],
                           ExpectedHeader=v['expectedHeader'],ExpectedData=v['expectedData']),
                ResultHeader=v['expectedHeader'],ResultData=v['expectedData'],
                Report=dict(parsedPrefixEnd=v['positions']['prefixEnd'],schemaIndex=len(json.loads(base64.b64decode(v['request']['schema']))['fields'])-1,
                            exportRelativeOffset=v['positions']['property']-6,functionalParityVerified=False))


class PostProcessReferenceTests(unittest.TestCase):
    def test_vectors_reproduce(self):
        self.assertEqual(json.loads(Path(__file__).with_name('testdata').joinpath('postprocess-vectors.json').read_text()),encoded_cases())
    def test_all_seven(self):
        for v in all_cases():self.assertTrue(verify(packet(v))['allBytesCompared'])
    def test_tamper_outside_edit(self):
        p=packet(make_case());x=bytearray(base64.b64decode(p['ResultData']));x[-1]^=1;p['ResultData']=b64(x)
        with self.assertRaisesRegex(ValueError,'unexpected changed'):verify(p)
    def test_safe_reference_is_not_serialized(self):
        p=packet(make_case());x=bytearray(base64.b64decode(p['ResultData']));x[120:124]=b'\xfa\xff\xff\xff';p['ResultData']=b64(x)
        with self.assertRaises(ValueError):verify(p)
    def test_offset_not_authority(self):
        p=packet(make_case());p['Input']['Request']['expectedSerializedOffset']=114
        with self.assertRaisesRegex(ValueError,'derived offset'):verify(p)
    def test_schema_identity(self):
        p=packet(make_case());p['Input']['Request']['schemaSha256']='0'*64
        with self.assertRaisesRegex(ValueError,'input pins'):verify(p)
    def test_wrong_field_type_even_when_repinned(self):
        p=packet(make_case());s=json.loads(base64.b64decode(p['Input']['Request']['schema']));s['fields'][-1]['type']='IntProperty';b=jsonb(s)
        p['Input']['Request'].update(schema=b64(b),schemaSha256=sha(b))
        with self.assertRaisesRegex(ValueError,'class reference'):verify(p)
    def test_no_false_parity_report(self):
        p=packet(make_case());p['Report']['functionalParityVerified']=True
        with self.assertRaisesRegex(ValueError,'false parity'):verify(p)
    def test_truncated_prefix(self):
        v=make_case();s=json.loads(base64.b64decode(v['request']['schema']))
        with self.assertRaises(ValueError):property_offset(b'\x00',0,1,s)
    def test_schema_class_and_import_identity(self):
        p=packet(make_case());p['Input']['Request']['safe']['path']='/Other.Body'
        with self.assertRaisesRegex(ValueError,'import identity'):verify(p)
    def test_scope_decoy_preserved(self):
        v=make_case('decoy');p=packet(v);verify(p)
        self.assertEqual(base64.b64decode(p['ResultData']).count(b'\xfc\xff\xff\xff'),1)


if __name__=='__main__':unittest.main()
