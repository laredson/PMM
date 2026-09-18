import base64
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import unittest
import verify_reference as ref

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('synthetic',HERE/'testdata/make_fixtures.py')
synthetic=importlib.util.module_from_spec(spec);spec.loader.exec_module(synthetic)
class ReferenceTests(unittest.TestCase):
    def setUp(self):self.v=json.loads((HERE/'testdata/vectors.json').read_text())[0];self.b=bytearray(base64.b64decode(self.v['header']));self.data=base64.b64decode(self.v['data'])
    def test_frozen_vectors_reproduce(self):
        frozen=json.loads((HERE/'testdata/vectors.json').read_text())
        self.assertEqual(frozen,[synthetic.make(v['id']) for v in frozen])
    def test_expected_names_and_offsets(self):
        for v in json.loads((HERE/'testdata/vectors.json').read_text()):
            p=ref.inspect(base64.b64decode(v['header']),base64.b64decode(v['data']))
            self.assertEqual([n['text'] for n in p['names']],v['expected']['names']);self.assertEqual(p['summaryEnd'],v['expected']['summaryEnd']);self.assertEqual(p['headerSha256'],v['expected']['headerSha256'])
    def test_truncated_input(self):
        for i in range(len(self.b)):
            with self.assertRaises((ValueError,struct.error)):ref.inspect(self.b[:i],self.data)
    def test_bad_profile(self):
        struct.pack_into('<i',self.b,self.v['fields']['ue5'],1009)
        with self.assertRaises(ValueError):ref.inspect(self.b,self.data)
    def test_short_export_data(self):
        with self.assertRaises(ValueError):ref.inspect(self.b,self.data[:-1])
    def test_cursor_bounds(self):
        for n in (-1,9):
            with self.assertRaises(ValueError):ref.Cursor(b'1234').raw(n)
    def test_utf16_invalid(self):
        with self.assertRaises((ValueError,UnicodeError)):ref.Cursor(struct.pack('<i',-2)+b'\0\xd8\0\0').string()
    def test_boolean_invalid(self):
        with self.assertRaises(ValueError):ref.Cursor(struct.pack('<i',2)).boolean()
    def test_string_terminator(self):
        with self.assertRaises(ValueError):ref.Cursor(struct.pack('<i',3)+b'abc').string()
    def test_unknown_optional(self):
        struct.pack_into('<i',self.b,self.v['fields']['softObjectCount'],1)
        with self.assertRaises(ValueError):ref.inspect(self.b,self.data)

class BuildGuardTests(unittest.TestCase):
    def test_existing_output_rejected(self):
        import subprocess,tempfile,sys
        with tempfile.TemporaryDirectory() as d:
            p=subprocess.run([sys.executable,'-B',str(HERE/'build.py'),'--out',d],capture_output=True,text=True,timeout=15)
            self.assertEqual(p.returncode,2);self.assertIn('new and outside',p.stderr);self.assertEqual(list(Path(d).iterdir()),[])
    def test_internal_output_rejected(self):
        import subprocess,sys
        dst=HERE/'must-not-exist'
        p=subprocess.run([sys.executable,'-B',str(HERE/'build.py'),'--out',str(dst)],capture_output=True,text=True,timeout=15)
        self.assertEqual(p.returncode,2);self.assertFalse(dst.exists())

if __name__=='__main__':unittest.main()
