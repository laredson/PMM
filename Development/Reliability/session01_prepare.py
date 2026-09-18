#!/usr/bin/env python3
"""Prepare identity fixes and native evidence OFFLINE; never edit the checkout."""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import zipfile

BRANCH = 'v1.5.0.1-PMM-reliability'
VERSION = '1.5.0.1'
BUILD = 'PMM-v1.5.0.1-reliability-s01'
META = 'Resources/Metadata/'
MANIFEST = META + 'RELEASE_MANIFEST.json'
SUMS = META + 'SHA256SUMS.txt'
NATIVES = {
    'PMM.exe': ('host', 'sha256', 'a49a3edd4c6dca197f02a7a58b0249d351463d4b'),
    'Engine/PMMRuntime.exe': ('runtime', 'sha256', '068cb479ef4746de7cf360f6ab50113529af07c0'),
    'Engine/PMMFixLab.exe': ('fixLabEngine', 'engineSha256', 'e2a7c8269215f5f02db1408429ddee58fc445b52'),
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON key: ' + key)
        result[key] = value
    return result


def json_bytes(value) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8')


def git(repo: Path, *args: str) -> str:
    env = dict(os.environ, GIT_OPTIONAL_LOCKS='0', GIT_TERMINAL_PROMPT='0')
    p = subprocess.run(['git', '-C', str(repo), *args], capture_output=True,
                       encoding='utf-8', errors='strict', timeout=60, env=env)
    if p.returncode:
        raise ValueError(p.stderr.strip() or 'Git read failed')
    return p.stdout


def safe_file(root: Path, relative: str) -> Path:
    rel = PurePosixPath(relative)
    if rel.is_absolute() or '..' in rel.parts or '\\' in relative or ':' in relative or any(ord(c) < 32 for c in relative):
        raise ValueError('Unsafe relative path: ' + relative)
    path = root
    for part in rel.parts:
        path = path / part
        if path.is_symlink():
            raise ValueError('Symlink is not allowed: ' + relative)
    if not path.is_file():
        raise ValueError('Missing regular file: ' + relative)
    return path


def make_plan(files: dict[str, bytes]) -> tuple[dict[str, bytes], dict]:
    """Pure transformation. Inputs are actual file bytes, not inherited hashes."""
    manifest = json.loads(files[MANIFEST].decode('utf-8-sig'), object_pairs_hook=unique_object)
    before = files[META + 'VERSION.txt'].decode('utf-8-sig').strip()
    if before not in ('1.5.0.0', VERSION):
        raise ValueError('Unexpected package version; this tool is only for session 01')
    native = []
    for path, (section, field, expected_blob) in NATIVES.items():
        data = files[path]
        actual = sha(data)
        expected = manifest[section][field]
        blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
        if actual.lower() != str(expected).lower() or blob != expected_blob:
            raise ValueError('Native baseline mismatch: ' + path + '. Do not replace its pin.')
        native.append({'path': path, 'size': len(data), 'sha256': actual,
                       'gitBlob': blob, 'sourceParityVerified': False})
    # Check independently pinned redistributables before generating any inventory.
    pins = dict(manifest.get('managedRuntimeSha256', {}))
    pins['Engine/repak.exe'] = manifest['repakSha256']
    pins['Resources/Mappings/Mappings.usmap'] = manifest['mappingsSha256']
    inv_path = manifest['dotnetRuntimeInventory']
    pins[inv_path] = manifest['dotnetRuntimeInventorySha256']
    runtime_prefix = 'Engine/dotnet/' + manifest['dotnetRuntimeContract'] + '/'
    for line in files[inv_path].decode('utf-8-sig').splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r'([0-9a-fA-F]{64})  (.+)', line)
        if not match:
            raise ValueError('Malformed runtime inventory')
        pins[runtime_prefix + match[2].replace('\\', '/')] = match[1]
    for path, expected in pins.items():
        if path not in files or sha(files[path]).lower() != str(expected).lower():
            raise ValueError('Pinned dependency mismatch: ' + path)
    runtime_expected = {p for p in pins if p.startswith(runtime_prefix)}
    runtime_actual = {p for p in files if p.startswith(runtime_prefix)}
    if runtime_expected != runtime_actual:
        raise ValueError('Runtime inventory coverage mismatch')
    result = copy.deepcopy(manifest)
    result['version'] = VERSION
    result['buildId'] = BUILD
    result['releaseName'] = VERSION
    result['release'] = 'PMM v1.5.0.1 Reliability - development'
    result['releaseCandidate'] = '1.5.0.1-reliability-s01'
    result['stableCandidate'] = False
    # Do not relabel historical test results as validation of this candidate.
    if 'inheritedReleaseValidation' not in result:
        result['inheritedReleaseValidation'] = {
            'manifestVersion': manifest.get('version'),
            'releaseDate': manifest.get('releaseDate'),
            'evidence': manifest.get('releaseValidation'),
        }
    result['releaseValidation'] = {
        'programRegression': 'NOT_RUN for this development candidate',
        'gameRuntime': 'NOT_VERIFIED', 'freeAccount': 'NOT_VERIFIED',
        'inventoryModIncluded': False,
    }
    result['releaseDate'] = None
    result['reliabilityPreparation'] = {
        'session': '01', 'state': 'identity-prepared-native-source-unresolved',
        'nativeSourceParityVerified': False, 'nativeBinariesRebuilt': False,
        'antivirusScanned': False, 'publicReleaseCreated': False,
    }
    for section in ('host', 'runtime', 'fixLabEngine'):
        result[section]['sourceStatus'] = 'UNVERIFIED_REFERENCE_NOT_REPRODUCIBLE_BUILD_PROOF'
    patch = {
        META + 'VERSION.txt': (VERSION + '\n').encode(),
        META + 'BUILD_ID.txt': (BUILD + '\n').encode(),
        MANIFEST: json_bytes(result),
    }
    merged = dict(files, **patch)
    patch[SUMS] = ''.join(sha(merged[p]) + '  ' + p + '\n'
                          for p in sorted(merged) if p != SUMS).encode('utf-8')
    report = {
        'schema': 'PMM_REL_SESSION01_PREPARATION_V1', 'preparedOnly': True,
        'checkoutModified': False, 'versionBefore': before,
        'manifestVersionBefore': manifest.get('version'), 'targetVersion': VERSION,
        'targetBuildId': BUILD, 'packageFiles': len(files),
        'nativeEvidence': native, 'nativeSourceRecovered': False,
        'nativeSourceParityVerified': False, 'windowsRuntimeTested': False,
        'antivirusScanned': False, 'metadataPatchSha256': {p: sha(b) for p, b in patch.items()},
        'notice': 'A checksum inventory proves byte identity, not safety or source parity.',
    }
    return patch, report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--out', type=Path, required=True,
                        help='NEW directory outside the repository; no files are uploaded')
    args = parser.parse_args()
    repo, out = args.repo.resolve(), args.out.resolve()
    try:
        if repo == out or repo in out.parents or out.exists():
            raise ValueError('Output must be a new directory outside the repository')
        if git(repo, 'branch', '--show-current').strip() != BRANCH:
            raise ValueError('Select ' + BRANCH + ' locally first; no branch is changed by this tool')
        if git(repo, 'status', '--porcelain', '--untracked-files=normal', '--', 'PMM'):
            raise ValueError('PMM tracked/package files must be clean; ignored Workspace is not read')
        commit = git(repo, 'rev-parse', 'HEAD').strip()
        tracked = [p for p in git(repo, 'ls-files', '-z', '--', 'PMM').split('\0') if p]
        files = {}
        case_paths = set()
        for p in tracked:
            rel = p.removeprefix('PMM/')
            if rel == p or rel.startswith('Workspace/'):
                raise ValueError('Unexpected tracked package path: ' + p)
            if rel.casefold() in case_paths:
                raise ValueError('Case-colliding package path: ' + p)
            case_paths.add(rel.casefold())
            files[rel] = safe_file(repo, p).read_bytes()
        patch, report = make_plan(files)
        report['inputCommit'] = commit
        # Capture only explicit maintenance paths, never Workspace or .git contents.
        source_paths = [p for p in git(repo, 'ls-files', '-z', '--',
                        'Development/Source', 'Development/Scripts/build').split('\0') if p]
        sources = {p: safe_file(repo, p).read_bytes() for p in source_paths}
        if git(repo, 'status', '--porcelain', '--untracked-files=normal', '--', 'Development/Source', 'Development/Scripts/build'):
            raise ValueError('Commit or separately preserve local source changes before exporting')
        # Abort if a tracked input changed during the capture.
        for rel, data in files.items():
            if safe_file(repo, 'PMM/' + rel).read_bytes() != data:
                raise ValueError('Package changed during capture: ' + rel)
        for rel, data in sources.items():
            if safe_file(repo, rel).read_bytes() != data:
                raise ValueError('Source changed during capture: ' + rel)
        if git(repo, 'rev-parse', 'HEAD').strip() != commit:
            raise ValueError('HEAD changed during capture; repeat after the checkout is stable')
        out.parent.mkdir(parents=True, exist_ok=True)
        # All inputs are validated before any output is created.
        out.mkdir(exist_ok=False)
        for rel, data in patch.items():
            dest = out / 'metadata-patch' / 'PMM' / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
        with zipfile.ZipFile(out / 'session01-packet.zip', 'x', zipfile.ZIP_DEFLATED) as z:
            for rel in NATIVES:
                z.writestr('native-evidence/PMM/' + rel, files[rel])
            for rel in (MANIFEST, META + 'VERSION.txt', META + 'BUILD_ID.txt', SUMS):
                z.writestr('native-evidence/baseline/PMM/' + rel, files[rel])
            for rel, data in sources.items():
                z.writestr('native-evidence/' + rel, data)
            for rel, data in patch.items():
                z.writestr('metadata-patch/PMM/' + rel, data)
            z.writestr('report.json', json_bytes(report))
        (out / 'report.json').write_bytes(json_bytes(report))
        (out / 'COMPLETE.txt').write_text('Preparation finished. Checkout unchanged. Not a release.\n', encoding='utf-8')
        print(json.dumps(report, indent=2))
        print('Prepared in: ' + str(out))
        return 0
    except (OSError, ValueError, KeyError, TypeError, UnicodeError, subprocess.SubprocessError) as exc:
        print('Preparation failed: ' + str(exc), file=sys.stderr)
        print('Do not use incomplete output without COMPLETE.txt. Checkout was not modified.', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
