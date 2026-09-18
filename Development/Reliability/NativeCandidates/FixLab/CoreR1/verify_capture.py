#!/usr/bin/env python3
"""Independent oracle for the TWO artificial capture exports, never a game tool."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath


def sha(b):
    return hashlib.sha256(b).hexdigest()


def read(root, relative):
    p = PurePosixPath(relative)
    if p.is_absolute() or '..' in p.parts or '\\' in relative or ':' in relative:
        raise ValueError('Unsafe fixture path')
    target = root
    for part in p.parts:
        target = target / part
        if target.is_symlink():
            raise ValueError('Fixture symlink')
    if not target.is_file() or target.stat().st_size > (2 << 20):
        raise ValueError('Missing/oversize fixture')
    return target.read_bytes()


def unique(pairs):
    out = {}
    for k, v in pairs:
        if k in out:
            raise ValueError('Duplicate JSON key')
        out[k] = v
    return out


def load(root, name):
    return json.loads(read(root, name), object_pairs_hook=unique)


def check(root):
    report, plan = load(root, 'report.json'), load(root, 'plan.json')
    donor, current = load(root, 'donor.json'), load(root, 'current.json')
    providers = load(root, 'provider-set.json')
    if report['schema'] != 'PMM_R1_CAPTURE_REPORT_V1' or report['status'] != 'SNAPSHOT_BYTES_VERIFIED_NOT_TRANSFORM_READY':
        raise ValueError('Wrong report')
    for key in ('transformReady', 'buildReady', 'validated', 'installed', 'buildAuthenticated',
                'atomicFilesystemSnapshot', 'completeFilesystemInventory', 'extractionMembershipVerified'):
        if report[key] is not False:
            raise ValueError('Unproved readiness or provenance')
    for key in ('inputBytesVerified', 'transformReady', 'buildReady', 'validated', 'installed'):
        if plan[key] is not False:
            raise ValueError('Planner was promoted')
    if plan['status'] != 'PLAN_VALID' or report['planSHA256'] != sha(read(root, 'plan.json')):
        raise ValueError('Plan binding')
    for key, name in (('recipeSHA256', 'recipe.json'), ('donorInventorySHA256', 'donor.json'),
                      ('currentInventorySHA256', 'current.json')):
        if plan[key] != sha(read(root, name)):
            raise ValueError('Plan document mismatch')
    set_hash = sha(read(root, 'provider-set.json'))
    if current['providerSHA256'] != set_hash or report['providerSetSHA256'] != set_hash:
        raise ValueError('Provider set mismatch')
    expected, snapshot_size, archive_size = {}, 0, 0
    for role, inv in (('donor', donor), ('current', current)):
        for f in inv['files']:
            b = read(root, role + '/' + f['path'])
            if not b.startswith(b'SYNTHETIC ASSET BYTES ') or f['sha256'] != sha(b) or f['sizeBytes'] != len(b):
                raise ValueError('Fixture/inventory mismatch')
            expected[(role, f['path'])] = (f, True)
            snapshot_size += len(b)
    d = read(root, 'archives/donor.pak')
    if donor['providerSHA256'] != sha(d):
        raise ValueError('Donor pin mismatch')
    for f in [{'path': 'donor.pak', 'sha256': sha(d), 'sizeBytes': len(d)}] + providers['providers']:
        b = read(root, 'archives/' + f['path'])
        if not b.startswith(b'SYNTHETIC ') or sha(b) != f['sha256'] or len(b) != f['sizeBytes']:
            raise ValueError('Archive mismatch')
        expected[('archive', f['path'])] = (f, False)
        archive_size += len(b)
    for dr in report['dossiers']:
        claim = load(root, 'claim.json')
        if dr['claimSHA256'] != sha(read(root, 'claim.json')) or dr['state'] != 'BYTES_AND_BINDINGS_CHECKED_NOT_AUTHENTICATED':
            raise ValueError('Dossier claim mismatch')
        if not dr['bytesVerified'] or not dr['bindingsChecked'] or dr['layoutSemanticsVerified'] or dr['reviewerAuthenticated']:
            raise ValueError('False dossier claim')
        for key, pin in (('layout', 'layoutSHA256'), ('review', 'reviewRecordSHA256')):
            f = dr[key]; b = read(root, 'schemas/' + f['path'])
            if sha(b) != f['sha256'] or sha(b) != claim[pin] or len(b) != f['sizeBytes']:
                raise ValueError('Dossier bytes mismatch')
            expected[('schema', f['path'])] = (f, True)
            snapshot_size += len(b)
        layout, review = load(root, 'schemas/layout.json'), load(root, 'schemas/review.json')
        if len(layout['fields']) != dr['fieldCount']:
            raise ValueError('Layout summary mismatch')
        for key in ('recipeSHA256', 'donorHeaderSHA256', 'donorExportSHA256', 'currentProviderSHA256',
                    'layoutSHA256', 'profile', 'classPath', 'origin', 'revision'):
            if review[key] != claim[key]:
                raise ValueError('Review binding mismatch')
    observed = {}
    for row in report['files']:
        key = row['role'], row['file']['path']
        if key in observed:
            raise ValueError('Duplicate report row')
        observed[key] = (row['file'], row['retainedInMemory'])
    if observed != expected or snapshot_size != report['snapshotBytes'] or archive_size != report['archiveBytesRead']:
        raise ValueError('Report coverage/byte totals mismatch')
    if len(donor['files']) != 12 or len(current['files']) != 7:
        raise ValueError('Not the specified artificial scenario')
    if not report['listedAssetBytesVerified'] or not report['listedArchiveBytesVerified']:
        raise ValueError('Checks not completed')
    return {'files': len(observed), 'assetFiles': 19, 'dossiers': len(report['dossiers']),
            'snapshotBytes': snapshot_size, 'archiveBytes': archive_size,
            'reportSHA256': sha(read(root, 'report.json')), 'transformationAuthorized': False}


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('directory', type=Path)
    args = ap.parse_args()
    results = {name: check(args.directory / name) for name in ('without-schema', 'with-schema')}
    print(json.dumps({'schema': 'PMM_R1_CAPTURE_INDEPENDENT_FIXTURES_V1', 'fixtures': results,
                      'realAssetsRead': False, 'scope': 'Artificial exports only; not archive membership or schema semantics'}, indent=2))
