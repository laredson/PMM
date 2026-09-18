#!/usr/bin/env python3
"""Offline TEST harness build. Never builds/installs PMMFixLab.exe."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def sha(data):
    return hashlib.sha256(data).hexdigest()


def valid_output(root, out):
    # resolve() also prevents outputs reached through a symlink into the repo.
    root, out = root.resolve(), out.resolve()
    if out == root or root in out.parents or out.exists():
        raise ValueError('Output must be new and outside the repository')
    return out


def build(out):
    here = Path(__file__).resolve().parent
    root = here.parents[4]
    out = valid_output(root, out)
    env = dict(os.environ, GOTOOLCHAIN='local', GOPROXY='off', GOSUMDB='off',
               GOENV='off', GOWORK='off', GOFLAGS='', GOEXPERIMENT='', CGO_ENABLED='0',
               GOOS='windows', GOARCH='amd64', GOAMD64='v1')
    version = subprocess.run(['go', 'version'], check=True, capture_output=True, text=True, env=env, timeout=15).stdout.strip()
    if version.split()[2] != 'go1.23.2':
        raise ValueError('Install Go 1.23.2 separately; this script never downloads it')
    files = {p.name: p.read_bytes() for p in sorted(here.glob('*.go')) if not p.is_symlink()}
    files['go.mod'] = (here / 'go.mod').read_bytes()
    if not files or any(p.is_symlink() for p in here.glob('*.go')) or (here / 'go.mod').is_symlink():
        raise ValueError('Missing source or source symlink')
    out.mkdir(parents=True, exist_ok=False)
    source = out / 'source'; source.mkdir()
    for name, data in files.items():
        (source / name).write_bytes(data)
    command = ['go', 'test', '-c', '-trimpath', '-buildvcs=false', '-o', str(out / 'CoreR1-tests.exe'), '.']
    p = subprocess.run(command, cwd=source, env=env, capture_output=True, text=True, timeout=90)
    if p.returncode:
        raise ValueError('Compilation failed: ' + p.stderr)
    for name, data in files.items():
        if (here / name).read_bytes() != data:
            raise ValueError('Source changed during build')
    artifact = (out / 'CoreR1-tests.exe').read_bytes()
    report = {'schema': 'PMM_CORE_R1_TEST_BUILD_V1', 'artifact': 'TEST harness only; not FixLab',
              'goVersion': version, 'target': 'windows/amd64', 'sha256': sha(artifact), 'bytes': len(artifact),
              'command': [x.replace(str(out), '<OUT>') for x in command],
              'sourceSHA256': {n: sha(b) for n, b in files.items()},
              'windowsExecuted': False, 'engineBuilt': False}
    (out / 'build-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    (out / 'COMPLETE.txt').write_text('TEST HARNESS ONLY. Not executed or installed.\n', encoding='utf-8')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(build(args.out), indent=2))
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print('Build failed: ' + str(exc), file=sys.stderr)
        sys.exit(2)
