#!/usr/bin/env python3
"""Read-only FixLab provenance audit. Never launch FixLab or apply an overlay."""
from __future__ import annotations
import argparse
import base64
import binascii
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys

ORIGINAL_SHA = '8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe'
OVERLAY_SHA = '39622b989a4b4a1056f3efc6b527828c3325359c90e5f7ffe399776c6536fcbb'
PART_PREFIX = '.github/bootstrap/fixlab-r2-overlay.patch.xz.b64.part'
CASE = 'PMM/CKL/FixLab/Cases/FIXLAB-CASE-001-GAWR-GURA/'
VARIANTS = ('original_fullreplacement', 'normal_locked', 'red_locked', 'hooded_locked', 'hair2_panties')
HASH_RE = re.compile(r'[0-9a-f]{64}')


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def blob(data: bytes) -> str:
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def unique(pairs):
    obj = {}
    for key, value in pairs:
        if key in obj:
            raise ValueError('Duplicate JSON key: ' + key)
        obj[key] = value
    return obj


def read_file(root: Path, relative: str, limit: int = 8 << 20) -> bytes:
    # Pin auditing must not follow symlinks or read an escaped recipe reference.
    p = PurePosixPath(relative)
    if (not relative or p.is_absolute() or '..' in p.parts or '\\' in relative
            or ':' in relative or any(ord(c) < 32 for c in relative)):
        raise ValueError('Unsafe relative path: ' + relative)
    path = root
    for part in p.parts:
        path = path / part
        if path.is_symlink():
            raise ValueError('Symlink input: ' + relative)
    if not path.is_file():
        raise ValueError('Missing input: ' + relative)
    with path.open('rb') as f:
        data = f.read(limit + 1)
    if len(data) > limit:
        raise ValueError('Oversize input: ' + relative)
    return data


def read_json(root: Path, relative: str):
    return json.loads(read_file(root, relative).decode('utf-8-sig'), object_pairs_hook=unique)


def decode_pinned_overlay(parts: list[bytes], expected: str = OVERLAY_SHA) -> bytes:
    if len(parts) != 8:
        raise ValueError('Expected exactly eight ordered parts')
    if not HASH_RE.fullmatch(expected):
        raise ValueError('Invalid expected SHA-256')
    raw = b''.join(parts)
    if len(raw) > 2 << 20:
        raise ValueError('Overlay text exceeds limit')
    # Only line wrapping is ignored, never missing symbols or automatic padding.
    encoded = raw.translate(None, b'\r\n\t ')
    try:
        data = base64.b64decode(encoded, validate=True)
    except binascii.Error as exc:
        raise ValueError('INVALID_BASE64: ' + str(exc)) from exc
    if base64.b64encode(data) != encoded:
        raise ValueError('NONCANONICAL_BASE64')
    if sha(data) != expected:
        raise ValueError('ARCHIVE_HASH_MISMATCH')
    return data


def audit_overlay(root: Path) -> dict:
    expected_names = {Path(PART_PREFIX + f'{i:02d}').name for i in range(8)}
    found_names = {p.name for p in (root/'.github/bootstrap').glob('fixlab-r2-overlay.patch.xz.b64.part*')}
    if found_names != expected_names:
        raise ValueError('Overlay part set differs from the eight expected files')
    parts, rows = [], []
    for i in range(8):
        relative = PART_PREFIX + f'{i:02d}'
        data = read_file(root, relative, 256 << 10)
        parts.append(data)
        rows.append({'path': relative, 'bytes': len(data), 'gitBlob': blob(data), 'sha256': sha(data)})
    encoded = b''.join(parts).translate(None, b'\r\n\t ')
    result = {'parts': rows, 'encodedBytes': len(encoded), 'lengthModulo4': len(encoded) % 4,
              'expectedArchiveSha256': OVERLAY_SHA, 'archivePinVerified': False,
              'sourceRecovered': False, 'overlayApplied': False, 'bootstrapExecuted': False}
    try:
        data = decode_pinned_overlay(parts)
    except ValueError as exc:
        result.update(status='BLOCKED', reason=str(exc))
    else:
        result.update(status='PIN_VERIFIED_REQUIRES_SOURCE_REVIEW', archivePinVerified=True,
                      actualArchiveSha256=sha(data), archiveBytes=len(data))
    return result


def audit_contracts(root: Path) -> dict:
    manifest = read_json(root, 'PMM/Resources/Metadata/RELEASE_MANIFEST.json')
    executable = read_file(root, 'PMM/Engine/PMMFixLab.exe', 16 << 20)
    actual = sha(executable)
    pins = [manifest['fixLabEngine']['engineSha256'], manifest['fixLabEngineSha256']]
    if actual != ORIGINAL_SHA or any(p != ORIGINAL_SHA for p in pins):
        raise ValueError('Original FixLab pin mismatch; do not repin')
    rows, payloads, references = [], {}, 0
    for variant in VARIANTS:
        relative = CASE + 'recipe-' + variant + '-v2.json'
        data = read_file(root, relative)
        recipe = json.loads(data.decode('utf-8-sig'), object_pairs_hook=unique)
        if recipe['schema'] != 'PMM_FIXLAB_VARIANT_RECIPE_V2' or recipe['variantId'] != variant:
            raise ValueError('Recipe identity mismatch: ' + relative)
        core = recipe['coreRecipe']
        core_data = read_file(root, CASE + core)
        counts = {}
        for operation in recipe['operations']:
            name = operation['op']
            counts[name] = counts.get(name, 0) + 1
            for alternative in operation.get('alternatives', []):
                path, expected = alternative['patch'], alternative['patchSha256']
                if not HASH_RE.fullmatch(expected):
                    raise ValueError('Invalid payload hash')
                b = read_file(root, CASE + path)
                if sha(b) != expected:
                    raise ValueError('Recipe payload mismatch: ' + path)
                if path in payloads and payloads[path]['sha256'] != expected:
                    raise ValueError('Conflicting payload pins')
                payloads[path] = {'path': path, 'sha256': expected, 'bytes': len(b)}
                references += 1
        rows.append({'path': relative, 'sha256': sha(data), 'variant': variant,
                     'coreRecipe': core, 'coreSha256': sha(core_data),
                     'outputName': recipe['outputName'], 'operations': counts})
    return {'originalSha256': actual, 'originalGitBlob': blob(executable), 'originalBytes': len(executable),
            'manifestPinsMatched': True, 'engineVersionFromManifest': manifest['fixLabEngine']['version'],
            'sourceReference': manifest['fixLabEngine']['source'],
            'sourceDirectoryPresent': (root / 'Development/Source/FixLabEngine').is_dir(),
            'recipes': rows, 'payloadReferenceCount': references,
            'uniquePayloadCount': len(payloads), 'payloads': sorted(payloads.values(), key=lambda x: x['path']),
            'repairsExecuted': False, 'gameDataRead': False, 'originalExecuted': False,
            'limit': 'Pinned packaged recipes/payloads only; no transformations, provider verification, or game acceptance.'}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[4])
    args = parser.parse_args()
    try:
        root = args.repo.resolve()
        result = {'schema': 'PMM_FIXLAB_PROVENANCE_AUDIT_V1', 'contracts': audit_contracts(root),
                  'overlay': audit_overlay(root), 'filesWritten': False, 'sourceParityVerified': False}
        print(json.dumps(result, indent=2, ensure_ascii=True))
        # A blocked source recovery is not a successful candidate build.
        return 2 if result['overlay']['status'] == 'BLOCKED' else 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print('Audit failed: ' + str(exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
