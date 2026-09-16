"""Meaningful integrity/non-overwrite tests for the PowerShell backup restorer."""
import hashlib,json,pathlib,subprocess,tempfile,zipfile,os
ROOT=pathlib.Path(__file__).resolve().parents[2]
SCRIPT=ROOT/'PMM/Resources/Unreal/Restore-OfflineBackup.ps1'
PS=os.path.join(os.environ['SystemRoot'],'System32/WindowsPowerShell/v1.0/powershell.exe')
BASE=ROOT/'Development/TestResults'
BASE.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='restore-',dir=BASE) as work:
    tmp=pathlib.Path(work)
    name='Wwise-2021.1.11/Wwise_2021.1.11.7933/bundle/sample.tar.xz'
    payload=b'original offline package bytes'
    def bundle(label, entries, records=None, schema='PMM_OFFLINE_BACKUP_V1'):
        path=tmp/(label+'.zip')
        if records is None:records=[{'path':n,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()} for n,b in entries]
        with zipfile.ZipFile(path,'w') as z:
            z.writestr('OFFLINE_INVENTORY.json',json.dumps({'schema':schema,'files':records}))
            for n,b in entries:z.writestr(n,b)
        return path
    def run(path,dest,ok=True,verify=False,sha=None):
        args=[PS,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(SCRIPT),'-Archive',str(path),'-ExpectedSha256',sha or hashlib.sha256(path.read_bytes()).hexdigest(),'-PmmRoot',str(dest)]
        if verify:args+=['-VerifyOnly']
        p=subprocess.run(args,capture_output=True,text=True)
        if (p.returncode==0)!=ok:raise AssertionError(p.stdout+'\n'+p.stderr)
    good=bundle('good',[(name,payload)])
    dest=tmp/'pmm'
    run(good,dest,verify=True);assert not dest.exists()
    run(good,dest);file=dest/'Workspace/Dependencies/Offline'/name;assert file.read_bytes()==payload
    before=file.stat().st_mtime_ns
    run(good,dest);assert file.stat().st_mtime_ns==before
    run(good,tmp/'wronghash',ok=False,sha='0'*64);assert not (tmp/'wronghash').exists()
    file.write_bytes(b'user existing file')
    run(good,dest,ok=False);assert file.read_bytes()==b'user existing file'
    rec=[{'path':name,'bytes':len(payload),'sha256':'0'*64}]
    for label,path in [
        ('hash',bundle('badcontent',[(name,payload)],rec)),
        ('traversal',bundle('traversal', [('Wwise-2021.1.11/../../escape.exe',payload)])),
        ('casecollision',bundle('collision', [(name,payload),(name.upper(),payload)])),
        ('schema',bundle('schema',[(name,payload)],schema='OTHER')),
        ('extra',bundle('extra',[(name,payload),('extra.exe',payload)], [{'path':name,'bytes':len(payload),'sha256':hashlib.sha256(payload).hexdigest()}]))
    ]:
        target=tmp/('reject-'+label);run(path,target,ok=False);assert not target.exists()
    print('RESTORE_REGRESSION_OK: verify-only, real copy, idempotence, archive/file hash failures, conflict preservation, traversal, collision, schema and unexpected entries')
