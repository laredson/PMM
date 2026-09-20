#!/usr/bin/env python3
"""Assemble the real I01 trial application in a NEW directory; never change a checkout.

Requires the unchanged s01b package and the two already-built, pinned C2B binaries.
Does not download, compile, execute, sign, install or upload anything.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import sys

BASE_COMMIT = '96287f98f59b7387a00b29cec7c9316800bde098'
BASE_PACKAGE_TREE = '09df5c45aee3390c6b8ea235c8afa4e149a9f1fa'
BASE_BUILD = 'PMM-v1.5.0.1-reliability-s01b'
BUILD = 'PMM-v1.5.0.1-reliability-i01'
VERSION = '1.5.0.1'
META = 'Resources/Metadata/'
MANIFEST = META + 'RELEASE_MANIFEST.json'
SUMS = META + 'SHA256SUMS.txt'
CANDIDATES = {
    'PMM.exe': ('PMMHost-candidate.exe', 'a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c'),
    'Engine/PMMRuntime.exe': ('PMMRuntime-candidate.exe', 'b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f'),
}
ORIGINALS = {
    'PMM.exe': '010c4f656dbe68f0bcf667610accf6cc4e248872120c6acd299f0fca7c209c2d',
    'Engine/PMMRuntime.exe': 'e90341d8449b485cb04af3c00d357bc8c67e87070644ff6bf7d27121a00c422a',
    'Engine/PMMFixLab.exe': '8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe',
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def unique(pairs):
    result = {}
    for k, v in pairs:
        if k in result:
            raise ValueError('Duplicate JSON key: ' + k)
        result[k] = v
    return result


def encoded(value) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8')


def git_object(kind: str, data: bytes) -> bytes:
    return hashlib.sha1(kind.encode() + b' ' + str(len(data)).encode() + b'\0' + data).digest()


def tree_id(files: dict[str, bytes]) -> str:
    nested = {}
    for path, data in files.items():
        parts = path.split('/')
        node = nested
        for part in parts[:-1]:
            node = node.setdefault(part, {})
        node[parts[-1]] = data

    def walk(node):
        rows = []
        for name, value in node.items():
            directory = isinstance(value, dict)
            h = walk(value) if directory else git_object('blob', value)
            rows.append(((name + ('/' if directory else '')).encode(),
                         ('40000 ' if directory else '100644 ').encode() + name.encode() + b'\0' + h))
        return git_object('tree', b''.join(value for _, value in sorted(rows)))
    return walk(nested).hex()


def no_symlink(path: Path) -> Path:
    path = path.absolute()
    for part in [*reversed(path.parents), path]:
        if part.is_symlink():
            raise ValueError('Symlink input/output path rejected: ' + str(part))
    return path


def read_package(root: Path) -> dict[str, bytes]:
    root = no_symlink(root)
    if not root.is_dir():
        raise ValueError('Package directory missing')
    files = {}
    for directory, dirs, names in os.walk(root, followlinks=False):
        here = Path(directory)
        # Never read user state or redistribute the optional local proprietary DLL.
        if here == root:
            dirs[:] = [d for d in dirs if d != 'Workspace']
        for d in dirs:
            no_symlink(here / d)
        for name in names:
            file = here / name
            rel = file.relative_to(root).as_posix()
            if rel == 'Engine/oo2core_9_win64.dll':
                continue
            no_symlink(file)
            if not file.is_file():
                raise ValueError('Not a regular file: ' + rel)
            if file.stat().st_size > 256 * 1024 * 1024:
                raise ValueError('Unexpected oversize input: ' + rel)
            files[rel] = file.read_bytes()
    return files


def check_sums(files: dict[str, bytes]) -> None:
    rows = {}
    for line in files[SUMS].decode('utf-8-sig').splitlines():
        h, path = line.split('  ', 1)
        if path in rows or len(h) != 64:
            raise ValueError('Invalid inventory')
        rows[path] = h
    if set(rows) != set(files) - {SUMS}:
        raise ValueError('Inventory coverage mismatch')
    if any(sha(files[p]) != h for p, h in rows.items()):
        raise ValueError('Inventory hash mismatch')


def assemble(files: dict[str, bytes], candidates: dict[str, bytes]):
    """Pure transformation from pinned baseline bytes; five package files change."""
    if tree_id(files) != BASE_PACKAGE_TREE:
        raise ValueError('Not the pinned s01b package. Do not update pins to force acceptance.')
    check_sums(files)
    if files[META + 'BUILD_ID.txt'].decode('utf-8-sig').strip() != BASE_BUILD:
        raise ValueError('Unexpected input BUILD_ID')
    for path, expected in ORIGINALS.items():
        if sha(files[path]) != expected:
            raise ValueError('Original binary pin mismatch: ' + path)
    for path, (_, expected) in CANDIDATES.items():
        if sha(candidates[path]) != expected:
            raise ValueError('Candidate binary pin mismatch: ' + path)
    original = json.loads(files[MANIFEST].decode('utf-8-sig'), object_pairs_hook=unique)
    result = copy.deepcopy(original)
    result.update(version=VERSION, buildId=BUILD,
                  release='PMM v1.5.0.1 I01 - experimental Host/Runtime integration',
                  releaseName='1.5.0.1', releaseCandidate='1.5.0.1-reliability-i01',
                  releaseDate=None, stableCandidate=False)
    result['releaseValidation'] = {
        'programRegression': 'PENDING user Windows acceptance of integrated I01 application',
        'gameRuntime': 'NOT_VERIFIED', 'freeAccount': 'NOT_VERIFIED',
        'inventoryModIncluded': False,
    }
    result['host']['sha256'] = CANDIDATES['PMM.exe'][1]
    result['host']['source'] = 'Development/Reliability/NativeCandidates/Host/'
    result['host']['sourceStatus'] = 'RECONSTRUCTED_C2B_INTEGRATED_FOR_USER_TRIAL_WINDOWS_ACCEPTANCE_PENDING'
    result['host']['startupSplashSource'] = 'C2B candidate integrated for I01 user trial, not the historical RC21 source.'
    # Do not retain a historical source hash as though it identifies this reconstruction.
    result['host'].pop('startupSplashSourceSha256', None)
    result['runtime']['sha256'] = CANDIDATES['Engine/PMMRuntime.exe'][1]
    result['runtime']['source'] = 'Development/Reliability/NativeCandidates/Runtime/'
    result['runtime']['build'] = 'Development/Reliability/NativeCandidates/Runtime/build.py'
    result['runtime']['sourceStatus'] = 'RECONSTRUCTED_C2B_INTEGRATED_FOR_USER_TRIAL_WINDOWS_ACCEPTANCE_PENDING'
    result['runtime']['nativeUiSource'] = 'Development/Reliability/NativeCandidates/Runtime/native_shell_windows.go'
    result['runtime'].pop('nativeUiSourceSha256', None)
    result['reliabilityPreparation'] = {
        'session': 'I01', 'state': 'host-runtime-integrated-for-user-trial',
        'nativeSourceParityVerified': False, 'nativeBinariesRebuilt': True,
        'antivirusScanned': False, 'publicReleaseCreated': False,
    }
    result['integrationTrial'] = {
        'id': 'I01', 'sourceCommit': BASE_COMMIT,
        'integrated': ['Host-C2B', 'Runtime-C2B', 'Supervision-C1-C2B', 'UIBridge-C2B'],
        'fixLabExecutableReplaced': False, 'fixLabReconstructionIntegrated': False,
        'componentVersionNote': 'Native internal 1.2.1 constants and third-party component versions are retained.',
        'windowsAcceptance': 'PENDING_USER_TEST', 'startupSpeedupMeasured': False,
        'defaultSecurityPoliciesChanged': False, 'codeSigned': False,
        'remainingInheritedBehaviors': ['PowerShell script policy arguments', 'automatic dependency repair paths'],
        'sourceBuildHistory': 'Candidate build recipes retain the s01b input guard; rebuild from that baseline.',
    }
    output = dict(files)
    output.update(candidates)
    output[META + 'BUILD_ID.txt'] = (BUILD + '\n').encode()
    output[MANIFEST] = encoded(result)
    output[SUMS] = ''.join(sha(data) + '  ' + path + '\n'
                          for path, data in sorted(output.items()) if path != SUMS).encode()
    check_sums(output)
    changed = [p for p in sorted(output) if output[p] != files[p]]
    expected_changes = {*CANDIDATES, META + 'BUILD_ID.txt', MANIFEST, SUMS}
    if set(changed) != expected_changes:
        raise ValueError('Unexpected integration scope')
    return output, {
        'schema': 'PMM_I01_ASSEMBLY_RECEIPT_V1',
        'buildId': BUILD, 'version': VERSION, 'baseSourceCommit': BASE_COMMIT,
        'basePackageTree': BASE_PACKAGE_TREE, 'integratedPackageTree': tree_id(output),
        'packageFiles': len(output), 'checksumRows': len(output)-1,
        'changedFiles': [{'path': p, 'beforeSHA256': sha(files[p]), 'afterSHA256': sha(output[p])} for p in changed],
        'unchangedFiles': len(files)-len(changed), 'fixLabPreserved': True,
        'windowsExecuted': False, 'functionalParityVerified': False,
        'antivirusScanned': False, 'gitHubBinaryUpload': 'NOT_PERFORMED_BY_THIS_TOOL',
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[4])
    ap.add_argument('--binaries', type=Path, required=True,
                    help='Directory containing pinned PMMHost-candidate.exe and PMMRuntime-candidate.exe')
    ap.add_argument('--out', type=Path, required=True, help='NEW output directory outside repository')
    args = ap.parse_args()
    try:
        repo = no_symlink(args.repo)
        out = no_symlink(args.out)
        if out.exists() or out == repo or repo in out.parents or out in repo.parents:
            raise ValueError('Output must be a NEW independent directory outside repository')
        if not out.parent.is_dir():
            raise ValueError('Output parent must already exist')
        files = read_package(repo / 'PMM')
        binaries = {}
        for target, (name, _) in CANDIDATES.items():
            p = no_symlink(args.binaries / name)
            if not p.is_file() or p.stat().st_size > 32 * 1024 * 1024:
                raise ValueError('Candidate missing or oversize: ' + name)
            binaries[target] = p.read_bytes()
        output, receipt = assemble(files, binaries)
        out.mkdir()
        for path, data in output.items():
            p = out / 'PMM' / path
            p.parent.mkdir(parents=True, exist_ok=True)
            with p.open('xb') as f:
                f.write(data)
        check_sums(read_package(out/'PMM'))
        (out/'I01_ASSEMBLY_RECEIPT.json').write_bytes(encoded(receipt))
        (out/'ASSEMBLY_COMPLETE.txt').write_text('I01 real application assembled. Windows acceptance PENDING. Not a Nexus release.\n', encoding='utf-8')
        print(json.dumps(receipt, indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print('I01 assembly failed: ' + str(exc), file=sys.stderr)
        print('Source checkout unchanged. Do not use output without ASSEMBLY_COMPLETE.txt.', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
