#!/usr/bin/env python3
"""Compile a UAsset TEST harness offline, outside the repo. Never run/install PMM."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--out',required=True,type=Path);a=ap.parse_args()
    src=Path(__file__).resolve().parent;repo=src.parents[4];out=a.out.resolve();commands=[]
    try:
        if out.exists() or out==repo or repo in out.parents:raise ValueError('Output must be new and outside repository')
        go=shutil.which('go')
        if not go:raise ValueError('Go1.23.2 must be installed separately')
        env=dict(os.environ,GOTOOLCHAIN='local',GOPROXY='off',GOSUMDB='off',GOWORK='off',GOENV='off',GOFLAGS='',GOEXPERIMENT='',CGO_ENABLED='0')
        def run(args,cwd):
            p=subprocess.run([str(x) for x in args],cwd=cwd,env=env,capture_output=True,text=True,encoding='utf-8',errors='strict',timeout=120)
            def clean(s):return s.replace(str(src),'<SOURCE>').replace(str(out),'<OUT>').replace(go,'go')
            commands.append(dict(command=[clean(str(x)) for x in args],exitCode=p.returncode,stdout=clean(p.stdout),stderr=clean(p.stderr)))
            if p.returncode:raise ValueError(clean(p.stderr))
            return p.stdout
        version=run([go,'version'],src).split()
        if version[2]!='go1.23.2':raise ValueError('Expected go1.23.2')
        files=sorted([*src.glob('*.go'),src/'go.mod',src/'build.py',src/'testdata/vectors.json',src/'testdata/postprocess-vectors.json'])
        if any(p.is_symlink() or not p.is_file() for p in files):raise ValueError('Invalid source input')
        hashes={p.relative_to(src).as_posix():sha(p) for p in files}
        out.mkdir(parents=True,exist_ok=False);stage=out/'source'
        for p in files:
            dst=stage/p.relative_to(src);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dst)
        env.update(GOOS='windows',GOARCH='amd64',GOAMD64='v1')
        exe=out/'UAsset-tests.exe'
        run([go,'test','-c','-trimpath','-buildvcs=false','-o',exe,'.'],stage)
        # Vet Unix/Windows syscall-free parser; warnings abort this recipe.
        run([go,'vet','./...'],stage)
        if any(sha(p)!=hashes[p.relative_to(src).as_posix()] for p in files):raise ValueError('Source changed during build')
        report=dict(schema='PMM_UASSET_TEST_BUILD_V1',session='04A-4C',artifact='UAsset TEST harness, not FixLab',
                    goVersion='go1.23.2',buildHost=version[3],target='windows/amd64',sourceSha256=hashes,
                    sha256=sha(exe),bytes=exe.stat().st_size,commands=commands,windowsExecuted=False,engineBuilt=False,packagedBinaryReplaced=False)
        (out/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
        (out/'COMPLETE.txt').write_text('Test harness only. NOT executed. NOT PMMFixLab.exe.\n')
        print(json.dumps({'sha256':report['sha256'],'bytes':report['bytes'],'windowsExecuted':False}));return 0
    except (OSError,ValueError,UnicodeError,subprocess.SubprocessError) as e:
        print('Build failed: '+str(e),file=sys.stderr);return 2
if __name__=='__main__':raise SystemExit(main())
