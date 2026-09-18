#!/usr/bin/env python3
"""Compare known Host artifacts OFFLINE. Never execute a Windows artifact."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
from inspect_pe import inspect

ORIGINAL = '010c4f656dbe68f0bcf667610accf6cc4e248872120c6acd299f0fca7c209c2d'
PREVIOUS = '62fc4b234ea145c6e3dadcc51366c0ebbca109f7b5a11dcb17deda32e927257f'
CURRENT = 'a5f50c5677608c9875eefb65fe75fd7efb3460808be2f53df7ea3ec6db195d97'


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def comparison(left, right):
    a = {s['name']: s for s in left['pe']['sections']}
    b = {s['name']: s for s in right['pe']['sections']}
    fa = {f['name']: f for f in left['go']['applicationFunctions']}
    fb = {f['name']: f for f in right['go']['applicationFunctions']}
    return {
        'byteIdentical': left['pe']['sha256'] == right['pe']['sha256'],
        'sameGoVersion': left['go']['goVersion'] == right['go']['goVersion'],
        'sameBuildSettings': left['go']['settings'] == right['go']['settings'],
        'sections': [{'name': n, 'sameRawBytes': n in a and n in b and a[n]['sha256'] == b[n]['sha256'],
                      'leftBytes': a[n]['rawSize'] if n in a else None,
                      'rightBytes': b[n]['rawSize'] if n in b else None} for n in sorted(a.keys() | b.keys())],
        'commonFunctionCount': len(fa.keys() & fb.keys()),
        'sameRawFunctionBytes': sorted(n for n in fa.keys() & fb.keys() if fa[n]['rawCodeSha256'] == fb[n]['rawCodeSha256']),
        'leftOnlyFunctions': sorted(fa.keys() - fb.keys()),
        'rightOnlyFunctions': sorted(fb.keys() - fa.keys()),
        'semanticEquivalenceEstablished': False,
    }


def run(argv, env, cwd):
    p = subprocess.run([str(s) for s in argv], cwd=cwd, env=env, capture_output=True,
                       text=True, encoding='utf-8', errors='strict', timeout=90)
    if p.returncode:
        raise ValueError('Static helper failed: ' + p.stderr.strip())
    return p.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--build-report', type=Path, required=True)
    parser.add_argument('--previous', type=Path, help='Optional S02A artifact, hash-pinned')
    parser.add_argument('--out', type=Path, required=True, help='NEW directory outside checkout')
    args = parser.parse_args()
    src = Path(__file__).resolve().parent
    repo = src.parents[3]
    out = args.out.resolve()
    try:
        if out.exists() or out == repo or repo in out.parents:
            raise ValueError('Output must be new and outside checkout')
        paths = {'original': repo/'PMM/PMM.exe', 'candidate': args.candidate.resolve()}
        pins = {'original': ORIGINAL, 'candidate': CURRENT}
        if args.previous:
            paths['previous'] = args.previous.resolve(); pins['previous'] = PREVIOUS
        for key, p in paths.items():
            if p.is_symlink() or not p.is_file() or p.stat().st_size > 128*1024*1024 or sha(p) != pins[key]:
                raise ValueError('Artifact pin mismatch: ' + key)
        br = json.loads(args.build_report.read_text(encoding='utf-8'))
        if br['candidate']['sha256'] != CURRENT or br['original']['sha256'] != ORIGINAL:
            raise ValueError('Build report does not bind these artifacts')
        expected_inputs = {p.name for p in src.glob('*.go')} | {'go.mod', 'build.py', 'inspect_pe.py'}
        if set(br['sourceSha256']) != expected_inputs:
            raise ValueError('Build report source coverage mismatch')
        for name, digest in br['sourceSha256'].items():
            if Path(name).name != name or sha(src/name) != digest:
                raise ValueError('Current source differs from build report: ' + name)
        env = dict(os.environ, GOTOOLCHAIN='local', GOPROXY='off', GOSUMDB='off',
                   GOWORK='off', GOFLAGS='', GOENV='off', CGO_ENABLED='0', GOEXPERIMENT='')
        go = shutil.which('go')
        if not go or run([go,'version'],env,src).split()[2] != 'go1.23.2':
            raise ValueError('Installed Go 1.23.2 required; no download is attempted')
        host_os, host_arch = run([go,'env','GOHOSTOS','GOHOSTARCH'],env,src).split()
        env.update(GOOS=host_os, GOARCH=host_arch)
        out.mkdir(parents=True, exist_ok=False)
        helper = out/('hostmeta.exe' if host_os == 'windows' else 'hostmeta')
        run([go,'build','-trimpath','-buildvcs=false','-o',helper,src/'tools/hostmeta.go'],env,src)
        data = {}
        for key, p in paths.items():
            data[key] = {'pe': inspect(p), 'go': json.loads(run([helper,p],env,src))}
            (out/(key+'.json')).write_text(json.dumps(data[key],indent=2)+'\n',encoding='utf-8')
        report = {
            'schema':'PMM_HOST_COMPARISON_S02B_V1',
            'method':'Static PE sections + debug/buildinfo + bounded Go pclntab function spans',
            'inputs':{key:{'sha256':v['pe']['sha256'],'sizeBytes':v['pe']['sizeBytes'],
                           'subsystem':v['pe']['subsystem'], 'certificateTableBytes':v['pe']['certificateTableBytes'],
                           'goVersion':v['go']['goVersion'], 'modulePath':v['go']['modulePath'],
                           'settings':v['go']['settings'], 'functionCount':len(v['go']['applicationFunctions'])}
                      for key,v in data.items()},
            'originalVsCandidate':comparison(data['original'],data['candidate']),
            'buildReportSha256':sha(args.build_report),
            'inspectorSourceSha256':sha(src/'tools/hostmeta.go'),
            'comparisonScriptSha256':sha(Path(__file__)),
            'windowsArtifactsExecuted':False,'functionalParityVerified':False,'replacementApproved':False,
            'limitations':[
                'Compiled function ranges do not recover the original source or all call semantics.',
                'Raw equality is a byte comparison, not a semantic equivalence proof.',
                'Code relocation, layout, metadata and added functions can change section bytes.',
                'The Windows desktop, CLI outcomes, focus and process supervision are NOT exercised.',
                'No Authenticode chain validation or antivirus scan is performed.',
            ],
        }
        if 'previous' in data:
            report['previousVsCandidate'] = comparison(data['previous'],data['candidate'])
        for key,p in paths.items():
            if sha(p) != pins[key]: raise ValueError('Input changed during inspection: '+key)
        (out/'comparison.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        (out/'COMPLETE.txt').write_text('Static comparison complete. NOT Windows acceptance.\n',encoding='utf-8')
        print(json.dumps(report,indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError, IndexError, subprocess.SubprocessError) as exc:
        print('Comparison failed: '+str(exc),file=sys.stderr)
        print('Do not use output without COMPLETE.txt. Packaged files unchanged.',file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
