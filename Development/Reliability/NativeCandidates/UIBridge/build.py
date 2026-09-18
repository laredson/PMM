#!/usr/bin/env python3
"""Build/test the isolated UIBridge library offline; never run a Windows EXE."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    source = Path(__file__).resolve().parent
    repo = source.parents[3]
    out = args.out.resolve()
    if out.exists() or out == repo or repo in out.parents:
        ap.error('Output must be NEW and OUTSIDE the repository')
    go = shutil.which('go')
    if not go:
        ap.error('Install Go 1.23.2 separately; this tool never downloads it')
    env = dict(os.environ, GOENV='off', GOTOOLCHAIN='local', GOPROXY='off',
               GOSUMDB='off', GOWORK='off', GOFLAGS='', GOEXPERIMENT='')
    for key in list(env):
        if key.startswith('PMM_UIBRIDGE_'):
            del env[key]
    logs = []

    def run(argv, cwd, execution_env):
        p = subprocess.run([str(a) for a in argv], cwd=cwd, env=execution_env,
                           capture_output=True, text=True, encoding='utf-8',
                           errors='replace', timeout=90, check=False)
        def clean(s):
            return s.replace(str(out), '<OUT>').replace(str(repo), '<REPO>').replace(go, 'go')
        logs.append({'command': [clean(str(a)) for a in argv],
                     'exitCode': p.returncode, 'stdout': ('<model-tests.jsonl sha256='+hashlib.sha256(p.stdout.encode()).hexdigest()+'>' if '-json' in argv else clean(p.stdout)), 'stderr': clean(p.stderr)})
        if p.returncode:
            raise ValueError(clean(p.stderr or p.stdout))
        return p.stdout

    try:
        version = run([go, 'version'], source, env).strip()
        if version.split()[2] != 'go1.23.2':
            raise ValueError('Go 1.23.2 required for this evidence')
        host_os, host_arch = run([go, 'env', 'GOHOSTOS', 'GOHOSTARCH'], source, env).split()
        files = sorted([*source.glob('*.go'), source/'go.mod', source/'build.py'])
        if source.is_symlink() or any(p.is_symlink() for p in files):
            raise ValueError('Source symlinks rejected')
        hashes = {p.name: digest(p) for p in files}
        out.mkdir(parents=True, exist_ok=False)
        stage = out/'source'
        stage.mkdir()
        for file in files:
            shutil.copyfile(file, stage/file.name)
        native_env = dict(env, GOOS=host_os, GOARCH=host_arch)
        model_tests = None
        race_tested = False
        if host_os != 'windows':
            events = run([go, 'test', '-count=1', '-json', '.'], stage, native_env)
            (out/'model-tests.jsonl').write_text(events, encoding='utf-8')
            entries = [json.loads(line) for line in events.splitlines() if line.startswith('{')]
            model_tests = [x['Test'] for x in entries if x.get('Action') == 'pass'
                           and x.get('Test', '').startswith('Test') and '/' not in x['Test']]
            # Race requires a local C compiler; no installation or remote runner.
            if host_os == 'linux' and host_arch == 'amd64' and shutil.which('gcc'):
                race = run([go, 'test', '-race', '-count=1', '.'], stage, dict(native_env, CGO_ENABLED='1'))
                (out/'race-tests.txt').write_text(race, encoding='utf-8')
                race_tested = True
        target = out/'UIBridge-S02C2A.test.exe'
        win_env = dict(env, GOOS='windows', GOARCH='amd64', GOAMD64='v1', CGO_ENABLED='0')
        run([go, 'test', '-c', '-trimpath', '-buildvcs=false', '-o', target, '.'], stage, win_env)
        info = run([go, 'version', '-m', target], stage, env)
        data = target.read_bytes()
        pe = struct.unpack_from('<I', data, 0x3c)[0]
        if data[:2] != b'MZ' or data[pe:pe+4] != b'PE\0\0' or struct.unpack_from('<H', data, pe+4)[0] != 0x8664:
            raise ValueError('Expected Windows AMD64 test executable')
        if any(digest(p) != hashes[p.name] for p in files):
            raise ValueError('Source changed during build')
        report = {
            'schema': 'PMM_UIBRIDGE_S02C2A_BUILD_V1', 'goVersion': version,
            'scope': 'isolated library and Windows adapter test compilation, NOT Host/Runtime integration',
            'inputSourceSha256': hashes, 'windowsTestExecutableSha256': digest(target),
            'windowsTestExecutableBytes': target.stat().st_size,
            'modelTestFunctionsPassed': model_tests, 'modelTestFunctionCount': len(model_tests or []),
            'linuxRaceTested': race_tested, 'windowsAdaptersExecuted': False,
            'hostRuntimeIntegrated': False, 'pmmExecuted': False, 'antivirusScanned': False,
            'packagedFilesModified': False, 'buildInfo': info, 'commands': logs,
        }
        (out/'build-report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
        (out/'COMPLETE.txt').write_text('UIBridge library only. Windows test EXE NOT RUN. Not an update to PMM.\n', encoding='utf-8')
        print(json.dumps({k: report[k] for k in ('modelTestFunctionCount', 'linuxRaceTested', 'windowsTestExecutableSha256', 'hostRuntimeIntegrated')}, indent=2))
        return 0
    except (OSError, ValueError, IndexError, subprocess.SubprocessError) as exc:
        print('Build failed: '+str(exc))
        if out.is_dir():
            (out/'FAILED.json').write_text(json.dumps({'error': str(exc), 'commands': logs}, indent=2), encoding='utf-8')
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
