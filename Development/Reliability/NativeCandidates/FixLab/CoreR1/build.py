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


def collect_sources(here):
    """Stage the real sibling module, not a second implementation or download."""
    files = {}
    for module in (here, here.parent / 'PAKV11', here.parent / 'UAsset'):
        if module.is_symlink() or not module.is_dir():
            raise ValueError('Missing module or module symlink')
        paths = sorted(module.rglob('*.go')) + [module / 'go.mod'] if module == here else sorted(module.glob('*.go')) + [module / 'go.mod']
        for p in paths:
            if module.name != 'CoreR1' and p.name.endswith('_test.go'):
                continue
            if p.is_symlink() or not p.is_file() or p.stat().st_size > (1 << 20):
                raise ValueError('Missing, symlink or oversized source')
            relative = p.relative_to(module).as_posix()
            files[module.name + '/' + relative] = p.read_bytes()
    if not any(n.startswith('PAKV11/') and n.endswith('.go') for n in files):
        raise ValueError('PAKV11 source absent')
    fixture = here / 'testdata' / 'execution-vectors.json'
    if fixture.parent.is_symlink() or fixture.is_symlink() or not fixture.is_file() or fixture.stat().st_size > (1 << 20):
        raise ValueError('Missing, symlink or oversized embedded fixture')
    files['CoreR1/testdata/execution-vectors.json'] = fixture.read_bytes()
    return files


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
    files = collect_sources(here)
    out.mkdir(parents=True, exist_ok=False)
    source = out / 'source'
    for name, data in files.items():
        dest = source / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
    command = ['go', 'test', '-c', '-trimpath', '-buildvcs=false', '-mod=readonly', '-o', str(out / 'CoreR1-tests.exe'), '.']
    p = subprocess.run(command, cwd=source / 'CoreR1', env=env, capture_output=True, text=True, timeout=90)
    if p.returncode:
        raise ValueError('Compilation failed: ' + p.stderr)
    cli_command = ['go', 'build', '-trimpath', '-buildvcs=false', '-mod=readonly', '-o', str(out / 'CoreR1-candidate.exe'), './cmd/candidatecli']
    p = subprocess.run(cli_command, cwd=source / 'CoreR1', env=env, capture_output=True, text=True, timeout=90)
    if p.returncode:
        raise ValueError('Candidate CLI compilation failed: ' + p.stderr)
    if collect_sources(here) != files:
        raise ValueError('Source or local dependency changed during build')
    artifact = (out / 'CoreR1-tests.exe').read_bytes()
    cli = (out / 'CoreR1-candidate.exe').read_bytes()
    report = {'schema': 'PMM_CORE_R1_CANDIDATE_CLI_BUILD_V2', 'artifact': 'TEST harness plus candidate-only CLI; neither is PMMFixLab',
              'goVersion': version, 'target': 'windows/amd64', 'sha256': sha(artifact), 'bytes': len(artifact),
              'candidateCLI': {'file': 'CoreR1-candidate.exe', 'sha256': sha(cli), 'bytes': len(cli),
                               'candidateOnly': True, 'installs': False, 'deploys': False},
              'command': [x.replace(str(out), '<OUT>') for x in command],
              'cliCommand': [x.replace(str(out), '<OUT>') for x in cli_command],
              'sourceSHA256': {n: sha(b) for n, b in files.items()},
              'windowsExecuted': False, 'engineBuilt': False}
    (out / 'build-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    (out / 'COMPLETE.txt').write_text('TEST HARNESS AND CANDIDATE-ONLY CLI. Not executed against game data or installed.\n', encoding='utf-8')
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
