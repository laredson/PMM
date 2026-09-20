"""Synthetic packaging tests, not execution of the Windows PMM application."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import assemble as a


class AssemblyTests(unittest.TestCase):
    def setUp(self):
        self.files = {
            'PMM.exe': b'original-host', 'Engine/PMMRuntime.exe': b'original-runtime',
            'Engine/PMMFixLab.exe': b'original-fixlab',
            a.META+'BUILD_ID.txt': (a.BASE_BUILD+'\n').encode(),
            a.META+'VERSION.txt': b'1.5.0.1\n',
            'Resources/Localization/es.json': b'{"nativeName":"Espana"}\n',
            'Engine/test.dll': b'unchanged-managed-library',
        }
        self.manifest = {
            'version':'1.5.0.1', 'buildId':a.BASE_BUILD,
            'host': {'version':'1.2.1', 'sha256':a.sha(self.files['PMM.exe']), 'startupSplashSourceSha256':'historical'},
            'runtime': {'version':'1.2.1', 'sha256':a.sha(self.files['Engine/PMMRuntime.exe']), 'nativeUiSourceSha256':'historical'},
            'fixLabEngine': {'engineSha256':a.sha(self.files['Engine/PMMFixLab.exe']), 'version':'0.2.0'},
            'managedRuntimeSha256': {'Engine/test.dll':a.sha(self.files['Engine/test.dll'])},
            'dotnetRuntimeContract':'8.0.30', 'arbitraryPreservedField': {'preserve':True},
        }
        self.files[a.MANIFEST] = a.encoded(self.manifest)
        self.resum()
        self.new = {'PMM.exe':b'new-host', 'Engine/PMMRuntime.exe':b'new-runtime'}
        ps = [patch.object(a,'BASE_PACKAGE_TREE',a.tree_id(self.files)),
              patch.object(a,'ORIGINALS',{p:a.sha(self.files[p]) for p in a.ORIGINALS}),
              patch.object(a,'CANDIDATES',{p:(v[0],a.sha(self.new[p])) for p,v in a.CANDIDATES.items()})]
        for p in ps:p.start();self.addCleanup(p.stop)

    def resum(self):
        self.files[a.SUMS]=''.join(a.sha(b)+'  '+p+'\n' for p,b in sorted(self.files.items()) if p!=a.SUMS).encode()

    def test_five_files_changed(self):
        result,receipt=a.assemble(self.files,self.new)
        self.assertEqual(len(receipt['changedFiles']),5)
        self.assertEqual(len(result),len(self.files))
        self.assertFalse(receipt['windowsExecuted'])

    def test_component_versions_and_fixlab_preserved(self):
        result,_=a.assemble(self.files,self.new);m=json.loads(result[a.MANIFEST])
        for field in ('fixLabEngine','dotnetRuntimeContract','managedRuntimeSha256','arbitraryPreservedField'):
            self.assertEqual(m[field],self.manifest[field])
        self.assertEqual(m['host']['version'],'1.2.1')
        self.assertEqual(m['runtime']['version'],'1.2.1')
        self.assertEqual(result['Engine/PMMFixLab.exe'],self.files['Engine/PMMFixLab.exe'])

    def test_no_input_mutation(self):
        old=copy.deepcopy(self.files);new=copy.deepcopy(self.new)
        a.assemble(self.files,self.new)
        self.assertEqual(self.files,old);self.assertEqual(self.new,new)

    def test_final_inventory_matches_actual_bytes(self):
        result,_=a.assemble(self.files,self.new);a.check_sums(result)
        self.assertNotIn(a.SUMS,result[a.SUMS].decode())
        result['PMM.exe']+=b'x'
        with self.assertRaisesRegex(ValueError,'hash mismatch'):a.check_sums(result)

    def test_deterministic_output(self):
        self.assertEqual(a.assemble(self.files,self.new),a.assemble(self.files,self.new))

    def test_wrong_baseline_rejected(self):
        self.files['Engine/PMMFixLab.exe']+=b'x'
        with self.assertRaisesRegex(ValueError,'pinned s01b'):a.assemble(self.files,self.new)

    def test_wrong_candidate_rejected(self):
        self.new['PMM.exe']=b'not-the-candidate'
        with self.assertRaisesRegex(ValueError,'Candidate binary pin'):a.assemble(self.files,self.new)

    def test_unknown_extra_file_rejected(self):
        self.files['unexpected.exe']=b'extra'
        with self.assertRaisesRegex(ValueError,'pinned s01b'):a.assemble(self.files,self.new)

    def test_duplicate_json_rejected(self):
        with self.assertRaisesRegex(ValueError,'Duplicate JSON'):json.loads('{"x":1,"x":2}',object_pairs_hook=a.unique)

    def test_changed_metadata_never_claims_acceptance(self):
        result,_=a.assemble(self.files,self.new);m=json.loads(result[a.MANIFEST])
        self.assertFalse(m['stableCandidate'])
        self.assertFalse(m['reliabilityPreparation']['nativeSourceParityVerified'])
        self.assertFalse(m['integrationTrial']['fixLabExecutableReplaced'])
        self.assertNotIn('startupSplashSourceSha256',m['host'])
        self.assertEqual(m['buildId'],result[a.META+'BUILD_ID.txt'].decode().strip())

    def test_workspace_and_local_oodle_are_not_distributed(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);(p/'Workspace').mkdir();(p/'Workspace'/'private.txt').write_text('private')
            (p/'Engine').mkdir();(p/'Engine/oo2core_9_win64.dll').write_bytes(b'private-dll')
            (p/'file').write_bytes(b'packaged')
            self.assertEqual(a.read_package(p),{'file':b'packaged'})

    def test_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);(p/'real').write_bytes(b'bytes')
            try:(p/'alias').symlink_to(p/'real')
            except OSError:self.skipTest('symlinks unavailable')
            with self.assertRaisesRegex(ValueError,'Symlink'):a.read_package(p)


if __name__=='__main__':unittest.main()
