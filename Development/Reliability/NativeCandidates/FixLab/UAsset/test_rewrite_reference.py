"""Fixtures for the independent oracle, not engine acceptance."""
import base64
import copy
import unittest
from testdata.make_fixtures import make
from verify_rewrite import expected, digest, names, decode


def packet():
    v = make('basic')
    h, x = decode(v['header']), decode(v['data'])
    return {'InputHeader':v['header'], 'InputData':v['data'], 'Fields':v['fields'],
            'Request':{'HeaderSHA256':digest(h), 'ExportSHA256':digest(x),
                       'Sources':[{'Header':v['header'],'SHA256':digest(h)}], 'Edits':[]}}


class RewriteReferenceTests(unittest.TestCase):
    def test_noop(self):
        p=packet();h,x,d=expected(p)
        self.assertEqual(h,decode(p['InputHeader']));self.assertEqual(x,decode(p['InputData']));self.assertEqual(d,0)

    def test_source_hash_required(self):
        p=packet();p['Request']['Sources'][0]['SHA256']='0'*64
        with self.assertRaisesRegex(ValueError,'source pin'):expected(p)

    def test_input_hash_required(self):
        p=packet();p['Request']['HeaderSHA256']='0'*64
        with self.assertRaisesRegex(ValueError,'input pin'):expected(p)

    def test_negative_index_rejected(self):
        p=packet();p['Request']['Edits']=[{'Index':-1,'Source':0,'SourceIndex':0}]
        with self.assertRaisesRegex(ValueError,'edit index'):expected(p)

    def test_duplicate_edit_rejected(self):
        p=packet();e={'Index':4,'Source':0,'SourceIndex':4};p['Request']['Edits']=[e,copy.copy(e)]
        with self.assertRaisesRegex(ValueError,'edit index'):expected(p)

    def test_opaque_growth_rejected(self):
        p=packet();p['Request']['Edits']=[{'Index':4,'Source':0,'SourceIndex':1}]
        with self.assertRaisesRegex(ValueError,'opaque'):expected(p)

    def test_names_truncation_rejected(self):
        h=decode(packet()['InputHeader'])
        with self.assertRaises(ValueError):names(h[:-1])

    def test_strict_base64(self):
        with self.assertRaises(ValueError):decode('invalid!')


if __name__=='__main__':unittest.main()
