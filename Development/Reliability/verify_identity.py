#!/usr/bin/env python3
"""Read-only identity/checksum verification. No PMM execution, network or repair."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

META = 'Resources/Metadata/'
SUMS = META + 'SHA256SUMS.txt'


def object_unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON key: ' + key)
        result[key] = value
    return result


def safe_read(root: Path, relative: str) -> bytes:
    p = PurePosixPath(relative)
    if not relative or p.is_absolute() or '..' in p.parts or '\\' in relative or ':' in relative or any(ord(c) < 32 for c in relative):
        raise ValueError('Unsafe relative path: ' + relative)
    target = root
    for part in p.parts:
        target = target / part
        if target.is_symlink():
            raise ValueError('Symlink not permitted: ' + relative)
    if not target.is_file():
        raise ValueError('Missing regular file: ' + relative)
    return target.read_bytes()


def verify(files: dict[str, bytes], version: str, build_id: str | None = None) -> dict:
    expected = {}
    folded = set()
    for line in files[SUMS].decode('utf-8-sig').splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r'([0-9a-fA-F]{64})  (.+)', line)
        if not match:
            raise ValueError('Malformed checksum row')
        digest, path = match.groups()
        if path.casefold() in folded:
            raise ValueError('Duplicate checksum path: ' + path)
        folded.add(path.casefold())
        expected[path] = digest.lower()
    if SUMS in expected:
        raise ValueError('Inventory must not hash itself')
    actual = set(files) - {SUMS}
    if len({p.casefold() for p in files}) != len(files):
        raise ValueError('Case-colliding package paths')
    if set(expected) != actual:
        raise ValueError('Coverage mismatch: missing=' + repr(sorted(actual-set(expected))) + '; extra=' + repr(sorted(set(expected)-actual)))
    mismatches = sorted(p for p in actual if hashlib.sha256(files[p]).hexdigest() != expected[p])
    if mismatches:
        raise ValueError('Checksum mismatches: ' + repr(mismatches))
    manifest = json.loads(files[META + 'RELEASE_MANIFEST.json'].decode('utf-8-sig'), object_pairs_hook=object_unique)
    declared_version = files[META + 'VERSION.txt'].decode('utf-8-sig').strip()
    declared_build = files[META + 'BUILD_ID.txt'].decode('utf-8-sig').strip()
    if manifest.get('version') != declared_version or declared_version != version:
        raise ValueError('VERSION/manifest/expected version disagree')
    if not declared_build or manifest.get('buildId') != declared_build or (build_id is not None and build_id != declared_build):
        raise ValueError('BUILD_ID/manifest/expected build disagree')
    return {'scope': 'static identity and checksum consistency only', 'version': declared_version,
            'buildId': declared_build, 'packageFiles': len(files), 'checksumRows': len(expected),
            'checksumMismatches': 0, 'pmmExecuted': False, 'antivirusScanned': False,
            'sourceParityVerified': False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    choice = parser.add_mutually_exclusive_group()
    choice.add_argument('--repo', type=Path, help='Check Git-tracked PMM files; ignored local data are not read')
    choice.add_argument('--package', type=Path, help='Check EVERY file in a clean distributable PMM directory')
    parser.add_argument('--expected-version', default='1.5.0.1')
    parser.add_argument('--expected-build')
    args = parser.parse_args()
    try:
        if args.package:
            root = args.package.resolve(strict=True)
            paths = []
            for p in root.rglob('*'):
                if p.is_symlink():
                    raise ValueError('Package contains a symlink')
                if p.is_file():
                    paths.append(p.relative_to(root).as_posix())
            mode = 'all package files'
        else:
            repo = (args.repo or Path(__file__).resolve().parents[2]).resolve(strict=True)
            command = subprocess.run(['git', '-C', str(repo), 'ls-files', '-z', '--', 'PMM/'],
                                     capture_output=True, text=True, encoding='utf-8', timeout=60,
                                     env=dict(os.environ, GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0'))
            if command.returncode:
                raise ValueError(command.stderr.strip() or 'Cannot read Git index')
            paths = [p[4:] for p in command.stdout.split('\0') if p.startswith('PMM/')]
            root = repo / 'PMM'
            mode = 'Git-tracked PMM files only'
        result = verify({p: safe_read(root, p) for p in paths}, args.expected_version, args.expected_build)
        result['inputMode'] = mode
        print(json.dumps(result, indent=2))
        return 0
    except (OSError, UnicodeError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        print('IDENTITY_CHECK_FAILED: ' + str(exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
