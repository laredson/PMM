#!/usr/bin/env python3
"""Build S03A outside the checkout, offline; never run/install PMMRuntime."""
from pathlib import Path
import argparse
import difflib
import hashlib
import json
import os
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
from inspect_pe import inspect

GO_VERSION = 'go1.23.2'
ORIGINAL_SHA = 'e90341d8449b485cb04af3c00d357bc8c67e87070644ff6bf7d27121a00c422a'
ICON_SHA = '6037c135e7651ac9bc799c8ba0d43c0be53021cb88def6649171709fe80a00fe'
HELPER_SHA = 'ca2d070517d943936aae58855ebb98d9ceac87a861dd1b390405890cde2efd5d'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path, help='NEW directory outside checkout')
    args = parser.parse_args()
    src = Path(__file__).resolve().parent
    repo, out = src.parents[3], args.out.resolve()
    log, created = [], False
    try:
        if out.exists() or out == repo or repo in out.parents:
            raise ValueError('Output must be new and outside the repository')
        go = shutil.which('go')
        if not go:
            raise ValueError('Install Go 1.23.2 separately; this recipe never downloads tools')
        env = dict(os.environ, GOTOOLCHAIN='local', GOPROXY='off', GOSUMDB='off',
                   GOWORK='off', GOFLAGS='', GOENV='off', CGO_ENABLED='0', GOEXPERIMENT='')

        def clean(text):
            return text.replace(str(out), '<OUT>').replace(str(repo), '<REPO>').replace(go, 'go')

        def run(argv, cwd, execution_env):
            p = subprocess.run([str(v) for v in argv], cwd=cwd, env=execution_env,
                               capture_output=True, text=True, encoding='utf-8',
                               errors='replace', timeout=120)
            log.append({'command': [clean(str(v)) for v in argv], 'exitCode': p.returncode,
                        'stdout': clean(p.stdout), 'stderr': clean(p.stderr)})
            if p.returncode:
                raise ValueError('Command failed: ' + clean(p.stderr))
            return p.stdout

        version = run([go, 'version'], src, env).strip()
        if version.split()[2] != GO_VERSION:
            raise ValueError('Expected '+GO_VERSION+'; got '+version)
        host_os, host_arch = run([go, 'env', 'GOHOSTOS', 'GOHOSTARCH'], src, env).split()
        original = repo/'PMM/Engine/PMMRuntime.exe'
        icon, helper = repo/'PMM/Resources/UI/PMM.ico', repo/'Development/Source/PEIcon/inject.go'
        for file, expected in ((original, ORIGINAL_SHA), (icon, ICON_SHA), (helper, HELPER_SHA)):
            if sha(file) != expected:
                raise ValueError('Input pin mismatch: '+str(file.relative_to(repo)))
        inputs = sorted([*src.glob('*.go'), src/'go.mod', src/'build.py',
                         src/'inspect_pe.py', src/'test_tools.py', src/'tools/runtime_meta.go'])
        if any(p.is_symlink() for p in inputs):
            raise ValueError('Source symlinks are not permitted')
        input_hashes = {p.relative_to(src).as_posix(): sha(p) for p in inputs}
        out.mkdir(parents=True, exist_ok=False)
        created = True
        stage = out/'source'
        for file in inputs:
            dest = stage/file.relative_to(src)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(file, dest)
        native_env = dict(env, GOOS=host_os, GOARCH=host_arch)
        win_env = dict(env, GOOS='windows', GOARCH='amd64', GOAMD64='v1')
        candidate = out/'PMMRuntime-candidate.exe'
        run([go, 'build', '-trimpath', '-buildvcs=false', '-ldflags=-s -w',
             '-o', candidate, '.'], stage, win_env)
        suffix = '.exe' if host_os == 'windows' else ''
        helper_exe, reader = out/('peicon-helper'+suffix), out/('runtime-meta'+suffix)
        # These two local executables are BUILD/READ tools, never the PMM candidate.
        run([go, 'build', '-trimpath', '-buildvcs=false', '-o', helper_exe, helper], stage, native_env)
        run([helper_exe, '-exe', candidate, '-ico', icon], stage, native_env)
        run([go, 'build', '-trimpath', '-buildvcs=false', '-o', reader,
             stage/'tools/runtime_meta.go'], stage, native_env)
        metadata = {}
        for label, file in (('original', original), ('candidate', candidate)):
            # Reader output is persisted separately rather than duplicated in the command log.
            raw = run([reader, file], stage, native_env)
            metadata[label] = json.loads(raw)
            (out/(label+'-go.json')).write_text(raw, encoding='utf-8')
            log[-1]['stdout'] = '<see '+label+'-go.json>'
        reports = {label: inspect(file) for label, file in (('original', original), ('candidate', candidate))}
        if reports['candidate']['subsystem'] != 3 or not any(s['name']=='.rsrc' for s in reports['candidate']['sections']):
            raise ValueError('Expected console-subsystem Runtime with icon resources')
        for file, expected in ((original, ORIGINAL_SHA), (icon, ICON_SHA), (helper, HELPER_SHA)):
            if sha(file) != expected:
                raise ValueError('Pinned input changed during build')
        if any(sha(file) != input_hashes[file.relative_to(src).as_posix()] for file in inputs):
            raise ValueError('Source changed during build')
        names = {k: {f['name'] for f in v['applicationFunctions']} for k,v in metadata.items()}
        sections = {k: {s['name']:s['sha256'] for s in v['sections']} for k,v in reports.items()}
        comparison = {
            'schema':'PMM_RUNTIME_BASIC_COMPARISON_V1',
            'originalSha256':ORIGINAL_SHA, 'candidateSha256':reports['candidate']['sha256'],
            'byteIdentical':ORIGINAL_SHA==reports['candidate']['sha256'],
            'equalRawSections':[n for n in sections['original'] if sections['candidate'].get(n)==sections['original'][n]],
            'originalApplicationFunctionCount':len(names['original']),
            'candidateApplicationFunctionCount':len(names['candidate']),
            'onlyInOriginal':sorted(names['original']-names['candidate']),
            'onlyInCandidate':sorted(names['candidate']-names['original']),
            'originalGoVersion':metadata['original']['goVersion'],
            'candidateGoVersion':metadata['candidate']['goVersion'],
            'originalSettings':metadata['original']['settings'],
            'candidateSettings':metadata['candidate']['settings'],
            'sourceRecovered':False, 'functionalParityVerified':False, 'windowsExecuted':False,
            'limit':'PE/buildinfo/pclntab only; names and raw section equality are not semantic equivalence.'}
        (out/'basic-comparison.json').write_text(json.dumps(comparison,indent=2)+'\n',encoding='utf-8')
        # Preserve complete PE summaries in the downloadable evidence; root report stays compact.
        for label, report in reports.items():
            (out/(label+'-pe.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        report = {'schema':'PMM_RUNTIME_CANDIDATE_BUILD_V1', 'session':'03A',
                  'classification':'RECONSTRUCTION_NOT_ORIGINAL_RECOVERED',
                  'goVersion':GO_VERSION, 'buildHost':host_os+'/'+host_arch, 'target':'windows/amd64',
                  'sourceSha256':input_hashes, 'iconSha256':ICON_SHA,'peIconHelperSha256':HELPER_SHA,
                  'originalSha256':ORIGINAL_SHA, 'candidateSha256':reports['candidate']['sha256'],
                  'candidateSizeBytes':reports['candidate']['sizeBytes'],
                  'commands':log, 'evidenceSha256':{f.name:sha(f) for f in sorted(out.glob('*.json'))},
                  'candidateExecuted':False,'packagedBinaryReplaced':False,'functionalParityVerified':False,
                  'antivirusScanned':False,'warning':'Candidate only. Not a release or Windows acceptance.'}
        (out/'build-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        patch=[]
        for file in sorted(src.glob('*.go')):
            old = repo/'Development/Source/Runtime'/file.name
            patch.extend(difflib.unified_diff(old.read_text().splitlines(keepends=True) if old.exists() else [],
                file.read_text().splitlines(keepends=True), fromfile='snapshot/'+file.name if old.exists() else '/dev/null',
                tofile='candidate/'+file.name))
        (out/'from-snapshot.patch').write_text(''.join(patch),encoding='utf-8')
        (out/'COMPLETE.txt').write_text('S03A built, NOT executed or installed. Do not replace PMMRuntime.exe.\n',encoding='utf-8')
        print(json.dumps({'candidateSha256':reports['candidate']['sha256'],'output':str(out),
                          'candidateExecuted':False,'packagedBinaryReplaced':False},indent=2))
        return 0
    except (OSError,ValueError,KeyError,IndexError,subprocess.SubprocessError) as exc:
        print('Candidate build failed: '+str(exc),file=sys.stderr)
        if created:
            (out/'FAILED.json').write_text(json.dumps({'error':str(exc),'commands':log},indent=2),encoding='utf-8')
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
