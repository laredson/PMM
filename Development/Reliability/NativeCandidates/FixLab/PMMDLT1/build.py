#!/usr/bin/env python3
"""Compile an offline Windows TEST harness for the codec, never the FixLab engine."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

GO = 'go1.23.2'


def digest(path):
 return hashlib.sha256(path.read_bytes()).hexdigest()


def check_output(root, out):
 if out.exists() or out == root or root in out.parents:
  raise ValueError('Output must be NEW and outside the repository')


def main():
 ap = argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--out', required=True, type=Path)
 args = ap.parse_args()
 src = Path(__file__).resolve().parent
 root, out = src.parents[4], args.out.resolve()
 created, log = False, []
 try:
  check_output(root, out)
  go = shutil.which('go')
  if not go:
   raise ValueError('Go 1.23.2 must already be installed; no downloads')
  env = dict(os.environ, GOTOOLCHAIN='local', GOPROXY='off', GOSUMDB='off',
             GOENV='off', GOWORK='off', GOFLAGS='', GOEXPERIMENT='', CGO_ENABLED='0')
  def run(argv, cwd):
   p = subprocess.run([str(v) for v in argv], cwd=cwd, env=env,
                      capture_output=True, text=True, encoding='utf-8', timeout=120)
   def clean(s):
    return s.replace(str(out), '<OUT>').replace(str(root), '<REPO>').replace(go, 'go')
   log.append(dict(command=[clean(str(v)) for v in argv], exitCode=p.returncode,
                   stdout=clean(p.stdout), stderr=clean(p.stderr)))
   if p.returncode:
    raise ValueError(clean(p.stderr))
   return p.stdout
  if run([go, 'version'], src).split()[2] != GO:
   raise ValueError('Expected '+GO)
  inputs = sorted([*src.glob('*.go'), *src.glob('*.py'), src/'go.mod', src/'evidence/corpus-summary.json'])
  if any(p.is_symlink() or not p.is_file() for p in inputs):
   raise ValueError('Non-regular source rejected')
  hashes = {p.relative_to(src).as_posix(): digest(p) for p in inputs}
  out.mkdir(parents=True, exist_ok=False); created = True
  stage = out/'source'
  for p in inputs:
   target = stage/p.relative_to(src); target.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(p,target)
  env.update(GOOS='windows',GOARCH='amd64',GOAMD64='v1')
  exe=out/'pmmdlt1-tests-windows-amd64.exe'
  run([go,'test','-c','-trimpath','-buildvcs=false','-ldflags=-s -w','-o',exe,'.'],stage)
  if any(digest(p)!=hashes[p.relative_to(src).as_posix()] for p in inputs):
   raise ValueError('Inputs changed during build')
  report=dict(schema='PMM_PMMDLT1_TEST_BUILD_V1',session='04A-2',goVersion=GO,
              target='windows/amd64',sourceSha256=hashes,testHarnessSha256=digest(exe),
              testHarnessBytes=exe.stat().st_size,commands=log,
              engineBuilt=False,originalSourceRecovered=False,windowsExecuted=False,
              packagedBinaryReplaced=False,antivirusScanned=False)
  (out/'build-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
  (out/'COMPLETE.txt').write_text('Codec TEST harness only. NOT a FixLab engine; do not install.\n',encoding='utf-8')
  print(json.dumps(report,indent=2));return 0
 except (OSError,ValueError,IndexError,subprocess.SubprocessError) as e:
  if created:
   (out/'FAILED.json').write_text(json.dumps(dict(error=str(e),commands=log)),encoding='utf-8')
  print('Build failed: '+str(e),file=sys.stderr);return 2


if __name__=='__main__':
 sys.exit(main())
