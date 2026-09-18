#!/usr/bin/env python3
"""Build S02C2B OUTSIDE the checkout, offline. Never execute/install the Host candidate."""
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
ORIGINAL_SHA = '010c4f656dbe68f0bcf667610accf6cc4e248872120c6acd299f0fca7c209c2d'
ICON_SHA = '6037c135e7651ac9bc799c8ba0d43c0be53021cb88def6649171709fe80a00fe'
HELPER_SHA = 'ca2d070517d943936aae58855ebb98d9ceac87a861dd1b390405890cde2efd5d'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path, help='NEW directory outside checkout')
    args = parser.parse_args()
    src = Path(__file__).resolve().parent
    repo = src.parents[3]
    out = args.out.resolve()
    log = []
    created_output = False
    try:
        if out.exists() or out == repo or repo in out.parents:
            raise ValueError('Output must be new and outside the repository')
        go = shutil.which('go')
        if not go:
            raise ValueError('Go 1.23.2 must already be installed; no toolchain is downloaded')
        env = dict(os.environ, GOTOOLCHAIN='local', GOPROXY='off', GOSUMDB='off',
                   GOWORK='off', GOFLAGS='', GOENV='off', CGO_ENABLED='0', GOEXPERIMENT='')

        def run(argv, cwd, execution_env):
            p = subprocess.run([str(v) for v in argv], cwd=cwd, env=execution_env,
                               capture_output=True, text=True, encoding='utf-8',
                               errors='replace', timeout=120)
            # Keep reports portable: no machine-specific tool/output directory names.
            clean = lambda text: text.replace(str(out), '<OUT>').replace(str(repo), '<REPO>').replace(go, 'go')
            log.append({'command': [clean(str(v)) for v in argv],
                        'exitCode': p.returncode, 'stdout': clean(p.stdout), 'stderr': clean(p.stderr)})
            if p.returncode:
                raise ValueError('Command failed: ' + clean(p.stderr))
            return p.stdout

        version = run([go, 'version'], src, env).strip()
        if version.split()[2] != GO_VERSION:
            raise ValueError('Expected ' + GO_VERSION + '; got ' + version)
        host_os, host_arch = run([go, 'env', 'GOHOSTOS', 'GOHOSTARCH'], src, env).split()
        original = repo/'PMM/PMM.exe'
        icon = repo/'PMM/Resources/UI/PMM.ico'
        helper = repo/'Development/Source/PEIcon/inject.go'
        for file, expected in ((original, ORIGINAL_SHA), (icon, ICON_SHA), (helper, HELPER_SHA)):
            if sha(file) != expected:
                raise ValueError('Input pin mismatch: ' + str(file.relative_to(repo)))
        support = src.parent/'Supervision'
        support_inputs = sorted([*support.glob('*.go'), support/'go.mod'])
        if any(p.is_symlink() or not p.is_file() for p in support_inputs):
            raise ValueError('Invalid shared supervision source')
        support_hashes = {p.name: sha(p) for p in support_inputs}
        bridge = src.parent/'UIBridge'
        bridge_inputs = sorted([*bridge.glob('*.go'), bridge/'go.mod'])
        if bridge.is_symlink() or any(p.is_symlink() or not p.is_file() for p in bridge_inputs):
            raise ValueError('Invalid shared UIBridge source')
        bridge_hashes = {p.name: sha(p) for p in bridge_inputs}
        inputs = sorted([*src.glob('*.go'), src/'go.mod', src/'build.py', src/'inspect_pe.py'])
        input_hashes = {p.name: sha(p) for p in inputs}
        original_before = inspect(original)
        out.mkdir(parents=True, exist_ok=False)
        created_output = True
        stage = out/'source'
        stage.mkdir()
        for file in inputs:
            shutil.copyfile(file, stage/file.name)
        support_stage = out/'Supervision'
        support_stage.mkdir()
        for file in support_inputs:
            shutil.copyfile(file, support_stage/file.name)
        bridge_stage = out/'UIBridge'
        bridge_stage.mkdir()
        for file in bridge_inputs:
            shutil.copyfile(file, bridge_stage/file.name)
        native_env = dict(env, GOOS=host_os, GOARCH=host_arch)
        win_env = dict(env, GOOS='windows', GOARCH='amd64', GOAMD64='v1')
        candidate = out/'PMMHost-candidate.exe'
        run([go, 'build', '-trimpath', '-buildvcs=false', '-ldflags=-s -w -H=windowsgui',
             '-o', candidate, '.'], stage, win_env)
        helper_exe = out/('peicon-helper.exe' if host_os == 'windows' else 'peicon-helper')
        # This is the repository's existing icon BUILD helper, not PMM or its runtime.
        run([go, 'build', '-trimpath', '-buildvcs=false', '-o', helper_exe, helper], stage, native_env)
        run([helper_exe, '-exe', candidate, '-ico', icon], stage, native_env)
        build_info = run([go, 'version', '-m', candidate], stage, env)
        candidate_report = inspect(candidate)
        if sha(original) != ORIGINAL_SHA:
            raise ValueError('Packaged original changed during build')
        for file in inputs:
            if sha(file) != input_hashes[file.name]:
                raise ValueError('Candidate source changed during build')
        if candidate_report['subsystem'] != 2:
            raise ValueError('Expected Windows GUI subsystem')
        if not any(s['name'] == '.rsrc' for s in candidate_report['sections']):
            raise ValueError('Candidate icon resources are missing')
        if any(sha(p) != support_hashes[p.name] for p in support_inputs):
            raise ValueError('Shared supervision source changed during build')
        report = {
            'schema': 'PMM_HOST_CANDIDATE_BUILD_V1', 'session': '02C-2B',
            'classification': 'RECONSTRUCTION_NOT_ORIGINAL_RECOVERED',
            'goVersion': GO_VERSION, 'buildHost': host_os+'/'+host_arch,
            'target': 'windows/amd64', 'sourceSha256': input_hashes,
            'iconSha256': ICON_SHA, 'peIconHelperSha256': HELPER_SHA,
            'original': original_before, 'candidate': candidate_report,
            'buildInfo': build_info, 'commands': log,
            'candidateExecuted': False, 'packagedBinaryReplaced': False,
            'functionalParityVerified': False, 'antivirusScanned': False,
            'warning': 'Static build evidence only. No equivalence or release approval.',
        }
        report['sharedSupervisionSha256'] = support_hashes
        if any(sha(p) != bridge_hashes[p.name] for p in bridge_inputs):
            raise ValueError('Shared UIBridge source changed during build')
        report['sharedUIBridgeSha256'] = bridge_hashes
        (out/'build-report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
        old = (repo/'Development/Source/Host/main.go').read_text().splitlines(keepends=True)
        new = (src/'main.go').read_text().splitlines(keepends=True)
        (out/'main-vs-snapshot.patch').write_text(''.join(difflib.unified_diff(old, new,
            fromfile='Development/Source/Host/main.go',
            tofile='Development/Reliability/NativeCandidates/Host/main.go')), encoding='utf-8')
        (out/'COMPLETE.txt').write_text('Build complete. CANDIDATE ONLY; do not replace PMM.exe.\n', encoding='utf-8')
        print(json.dumps({'candidateSha256': candidate_report['sha256'], 'output': str(out),
                          'candidateExecuted': False, 'packagedBinaryReplaced': False}, indent=2))
        return 0
    except (OSError, ValueError, KeyError, IndexError, subprocess.SubprocessError) as exc:
        print('Candidate build failed: '+str(exc), file=sys.stderr)
        if created_output:
            (out/'FAILED.json').write_text(json.dumps({'error': str(exc), 'commands': log}, indent=2), encoding='utf-8')
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
