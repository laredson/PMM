"""Synthetic comparison tests. No EXE is executed, compiled or uploaded here."""
import copy
import unittest
from compare_host import comparison

class ComparisonTests(unittest.TestCase):
    def fixture(self):
        return {'pe':{'sha256':'artifact-a','sections':[{'name':'.text','sha256':'section-a','rawSize':12}]},
                'go':{'goVersion':'go1.23.2','settings':{'GOOS':'windows'},
                      'applicationFunctions':[{'name':'main.main','rawCodeSha256':'function-a'}]}}
    def test_identical_input_is_not_semantic_approval(self):
        a=self.fixture(); r=comparison(a,copy.deepcopy(a))
        self.assertTrue(r['byteIdentical'])
        self.assertFalse(r['semanticEquivalenceEstablished'])
        self.assertEqual(r['sameRawFunctionBytes'],['main.main'])
    def test_changed_text_is_reported(self):
        a=self.fixture(); b=copy.deepcopy(a)
        b['pe']['sha256']='artifact-b'; b['pe']['sections'][0]['sha256']='section-b'
        b['go']['applicationFunctions'][0]['rawCodeSha256']='function-b'
        r=comparison(a,b)
        self.assertFalse(r['byteIdentical']); self.assertFalse(r['sections'][0]['sameRawBytes'])
        self.assertEqual(r['sameRawFunctionBytes'],[])
    def test_added_removed_sections_and_functions(self):
        a=self.fixture(); b=copy.deepcopy(a)
        b['pe']['sections']=[{'name':'.data','sha256':'d','rawSize':4}]
        b['go']['applicationFunctions']=[{'name':'main.other','rawCodeSha256':'q'}]
        r=comparison(a,b)
        self.assertEqual(r['commonFunctionCount'],0)
        self.assertEqual(r['leftOnlyFunctions'],['main.main'])
        self.assertEqual(r['rightOnlyFunctions'],['main.other'])
        self.assertTrue(all(not s['sameRawBytes'] for s in r['sections']))
    def test_toolchain_or_settings_difference_is_visible(self):
        a=self.fixture(); b=copy.deepcopy(a)
        b['go']['goVersion']='different'; b['go']['settings']['GOOS']='different'
        r=comparison(a,b)
        self.assertFalse(r['sameGoVersion']); self.assertFalse(r['sameBuildSettings'])

if __name__=='__main__': unittest.main()
