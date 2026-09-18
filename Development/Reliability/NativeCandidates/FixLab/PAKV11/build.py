#!/usr/bin/env python3
"""Build the PAKV11 TEST harness offline into a NEW external directory. Never run it."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    src = Path(__file__).resolve().parent
    repo, out = src.parents[4], args.out.resolve()
    created, log = False, []
    try:
        if out.exists() or out == repo or repo in out.parents:
            raise ValueError('Output must be new and outside the repository')
        go = shutil.which('go')
        if go is None:
            raise ValueError('Install Go 1.23.2 separately; no download attempted')
        env = dict(os.environ, GOTOOLCHAIN='local', GOPROXY='off', GOSUMDB='off',
                   GOENV='off', GOWORK='off', GOFLAGS='', GOEXPERIMENT='', CGO_ENABLED='0')
        def run(argv, cwd):
            p = subprocess.run([str(a) for a in argv], cwd=cwd, env=env,
                               capture_output=True, text=True, timeout=120)
            def clean(s):
                return s.replace(str(out), '<OUT>').replace(str(repo), '<REPO>').replace(go, 'go')
            log.append({'command': [clean(str(a)) for a in argv], 'exitCode': p.returncode,
                        'stdout': clean(p.stdout), 'stderr': clean(p.stderr)})
            if p.returncode:
                raise ValueError('Build command failed: ' + clean(p.stderr))
            return p.stdout
        if run([go, 'version'], src).split()[2] != 'go1.23.2':
            raise ValueError('Requires locally installed Go 1.23.2')
        inputs = sorted([*src.glob('*.go'), src/'go.mod', src/'build.py',
                         src/'verify_reference.py', src/'test_reference.py', *src.glob('testdata/*')])
        if any(p.is_symlink() or not p.is_file() for p in inputs):
            raise ValueError('Invalid source input')
        hashes = {p.relative_to(src).as_posix(): sha(p) for p in inputs}
        out.mkdir(parents=True, exist_ok=False)
        created = True
        stage = out/'source'
        for p in inputs:
            q = stage/p.relative_to(src)
            q.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(p, q)
        env.update(GOOS='windows', GOARCH='amd64', GOAMD64='v1')
        artifact = out/'pakv11-tests.exe'
        run([go, 'test', '-c', '-trimpath', '-buildvcs=false', '-o', artifact, '.'], stage)
        run([go, 'vet', './...'], stage)
        if any(sha(p) != hashes[p.relative_to(src).as_posix()] for p in inputs):
            raise ValueError('Source changed during build')
        report = {'schema': 'PMM_PAKV11_TEST_BUILD_V1', 'goVersion': 'go1.23.2',
                  'target': 'windows/amd64', 'sourceSha256': hashes,
                  'artifactSha256': sha(artifact), 'artifactBytes': artifact.stat().st_size,
                  'commands': log, 'artifactExecuted': False, 'fixLabEngineBuilt': False}
        (out/'build-report.json').write_text(json.dumps(report, indent=2)+'\n')
        (out/'COMPLETE.txt').write_text('TEST HARNESS ONLY. Not FixLab. Not executed or installed.\n')
        print(json.dumps(report, indent=2))
        return 0
    except (OSError, ValueError, IndexError, subprocess.SubprocessError) as exc:
        print('Build failed: ' + str(exc), file=sys.stderr)
        if created:
            (out/'FAILED.txt').write_text(str(exc))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
