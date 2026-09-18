#!/usr/bin/env python3
"""Compare pinned Runtime artifacts without executing them. Writes only a NEW output directory."""
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

ORIGINAL = 'e90341d8449b485cb04af3c00d357bc8c67e87070644ff6bf7d27121a00c422a'
PREVIOUS = '10effcaf7a5d02836104a5bb2bd90eeb52c755ac78fc4670b5eea11b235b938f'
CURRENT = '45e017190c379774afd24557084e7fa532bbef58b6ead6869294943bb72ed0be'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


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


def check_artifact(path, digest):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 128*1024*1024 or sha(path) != digest:
        raise ValueError('Artifact pin mismatch: ' + path.name)


def bind_build_report(src, report):
    if report['candidateSha256'] != CURRENT or report['originalSha256'] != ORIGINAL:
        raise ValueError('Build report does not bind the pinned artifacts')
    expected = {p.name for p in src.glob('*.go')} | {
        'go.mod', 'build.py', 'inspect_pe.py', 'test_tools.py', 'tools/runtime_meta.go'}
    if set(report['sourceSha256']) != expected:
        raise ValueError('Build report source coverage mismatch')
    for name, digest in report['sourceSha256'].items():
        path = src/name
        if path.is_symlink() or sha(path) != digest:
            raise ValueError('Build source mismatch: ' + name)


def run(argv, env, cwd):
    p = subprocess.run([str(v) for v in argv], cwd=cwd, env=env, capture_output=True,
                       text=True, encoding='utf-8', errors='strict', timeout=90)
    if p.returncode:
        raise ValueError('Static reader/build failed: ' + p.stderr.strip())
    return p.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--build-report', type=Path, required=True)
    parser.add_argument('--previous', type=Path, required=True, help='Pinned S03A artifact')
    parser.add_argument('--out', type=Path, required=True, help='NEW directory outside checkout')
    args = parser.parse_args()
    src = Path(__file__).resolve().parent
    repo, out = src.parents[3], args.out.resolve()
    try:
        if out.exists() or out == repo or repo in out.parents:
            raise ValueError('Output must be new and outside checkout')
        paths = {'original': repo/'PMM/Engine/PMMRuntime.exe',
                 's03a': args.previous.absolute(), 's03b': args.candidate.absolute()}
        pins = {'original': ORIGINAL, 's03a': PREVIOUS, 's03b': CURRENT}
        for label, path in paths.items():
            check_artifact(path, pins[label])
        br = json.loads(args.build_report.read_text(encoding='utf-8'))
        bind_build_report(src, br)
        go = shutil.which('go')
        if not go:
            raise ValueError('Go 1.23.2 must already be installed; no downloads')
        env = dict(os.environ, GOTOOLCHAIN='local', GOPROXY='off', GOSUMDB='off',
                   GOWORK='off', GOENV='off', GOFLAGS='', GOEXPERIMENT='', CGO_ENABLED='0')
        if run([go, 'version'], env, src).split()[2] != 'go1.23.2':
            raise ValueError('Go 1.23.2 required')
        host_os, host_arch = run([go, 'env', 'GOHOSTOS', 'GOHOSTARCH'], env, src).split()
        env.update(GOOS=host_os, GOARCH=host_arch)
        out.mkdir(parents=True, exist_ok=False)
        reader = out/('runtime-meta' + ('.exe' if host_os == 'windows' else ''))
        run([go, 'build', '-trimpath', '-buildvcs=false', '-o', reader, src/'tools/runtime_meta.go'], env, src)
        records = {}
        for label, path in paths.items():
            metadata = json.loads(run([reader, path], env, src))
            pe = inspect(path)
            if metadata['sha256'] != pins[label] or pe['sha256'] != pins[label]:
                raise ValueError('Input changed while inspected: ' + label)
            records[label] = {'pe': pe, 'go': metadata}
            (out/(label+'.json')).write_text(json.dumps(records[label], indent=2)+'\n', encoding='utf-8')
        bind_build_report(src, br)
        for label, path in paths.items():
            check_artifact(path, pins[label])
        review_files = [
            'PMM/Resources/Metadata/runtime-contract.json', 'PMM/Resources/Metadata/RELEASE_MANIFEST.json',
            'PMM/Engine/Runner/routes.json', 'PMM/Modules/Bootstrap/Start-PalModMerger.ps1',
            'Development/Source/Runtime/main.go', 'Development/Source/Runtime/deps.go',
            'Development/Reliability/NativeCandidates/Host/main.go']
        report = {
            'schema': 'PMM_RUNTIME_COMPARISON_S03B_V1',
            'method': 'PE + debug/buildinfo + Go pclntab; source-contract review is separate',
            'artifacts': {k: {'sha256': r['pe']['sha256'], 'sizeBytes': r['pe']['sizeBytes'],
                'subsystem': r['pe']['subsystem'], 'goVersion': r['go']['goVersion'],
                'applicationFunctionCount': len(r['go']['applicationFunctions'])} for k,r in records.items()},
            'originalVsS03A': comparison(records['original'], records['s03a']),
            'originalVsS03B': comparison(records['original'], records['s03b']),
            'S03AVsS03B': comparison(records['s03a'], records['s03b']),
            'reviewInputSha256': {p: sha(repo/p) for p in review_files},
            'toolSha256': {p: sha(src/p) for p in ('compare_runtime.py','inspect_pe.py','tools/runtime_meta.go')},
            'artifactReportSha256': {k+'.json': sha(out/(k+'.json')) for k in records},
            'windowsArtifactsExecuted': False, 'functionalParityVerified': False,
            'originalSourceRecovered': False, 'antivirusScanned': False,
            'limits': ['Function names/ranges are not source recovery or behavior proof.',
                       'Raw function hashes include addresses and padding; differences may reflect relocation.',
                       'Equal sections do not prove whole-program equivalence.',
                       'Only the local reader is executed, never the inspected EXEs.']}
        (out/'comparison.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
        (out/'COMPLETE.txt').write_text('Static Runtime comparison complete. Windows acceptance NOT_RUN.\n',encoding='utf-8')
        print(json.dumps(report['artifacts'], indent=2))
        return 0
    except (OSError,ValueError,KeyError,IndexError,subprocess.SubprocessError) as exc:
        print('Comparison failed: '+str(exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
