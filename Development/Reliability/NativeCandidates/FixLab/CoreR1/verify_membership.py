#!/usr/bin/env python3
"""Independent readback of synthetic membership evidence; never extracts a PAK.
Uses the separate Python PAKV11 parser, never Go, repak, or the original engine.
This is a test oracle, not the production filesystem capture or a trust authority.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path, PurePosixPath

PROFILE = 'PAKV11_ASCII_COMPACT32_PHI_FDI_UNCOMPRESSED_V1'
POLICY = 'UNIQUE_OWNER_ONLY_V1'
source = Path(__file__).resolve().parent.parent / 'PAKV11' / 'verify_reference.py'
spec = importlib.util.spec_from_file_location('pak_readback_reference', source)
pak = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pak)


def sha(b):
    return hashlib.sha256(b).hexdigest()


def need(condition, message):
    if not condition:
        raise ValueError(message)


def safe_read(root, relative, limit=256 << 20):
    p = PurePosixPath(relative)
    need(relative and not p.is_absolute() and '..' not in p.parts and '\\' not in relative and ':' not in relative, 'unsafe fixture path')
    path = root
    for part in p.parts:
        path = path / part
        need(not path.is_symlink(), 'fixture symlink')
    need(path.is_file() and path.stat().st_size <= limit, 'missing/large fixture')
    with path.open('rb') as f:
        data = f.read(limit + 1)
    need(len(data) <= limit, 'large fixture')
    return data


def check(root, report=None):
    cap_raw = safe_read(root, 'capture.json', 8 << 20)
    plan_raw = safe_read(root, 'plan.json', 8 << 20)
    provider_raw = safe_read(root, 'provider-set.json', 128 << 10)
    cap, plan, providers = map(json.loads, (cap_raw, plan_raw, provider_raw))
    if report is None:
        report = json.loads(safe_read(root, 'report.json', 8 << 20))
    need(report['schema'] == 'PMM_R1_MEMBERSHIP_REPORT_V1' and
         report['status'] == 'LISTED_ENTRIES_VERIFIED_NOT_TRANSFORM_READY' and
         report['profile'] == PROFILE and report['currentOwnership'] == POLICY, 'wrong contract')
    need(report['scope'] == 'ALL_DECLARED_DONOR_AND_CURRENT_FILES_IN_LISTED_PROVIDERS_ONLY', 'scope')
    need(report['captureReportSHA256'] == sha(cap_raw) and report['planSHA256'] == sha(plan_raw) == cap['planSHA256'], 'snapshot binding')
    need(report['providerSetSHA256'] == sha(provider_raw) == cap['providerSetSHA256'] == plan['declaredCurrentProvider'], 'provider binding')
    for field in ('listedEntriesMembershipVerified', 'allListedProvidersParsed', 'uniqueCurrentOwners'):
        need(report[field] is True, 'missing proof flag')
    for field in ('providerOrderUsedAsPriority', 'unlistedPathsOwnershipChecked',
                  'extractionProcessAuthenticated', 'completeFilesystemInventory',
                  'completeProviderUniverse', 'atomicFilesystemSnapshot', 'buildAuthenticated',
                  'schemaSemanticsVerified', 'transformReady', 'buildReady', 'validated', 'installed'):
        need(report[field] is False, 'unsupported claim: ' + field)
    need(report['blockers'] and not cap['extractionMembershipVerified'] and not plan['transformReady'], 'changed capture/plan')
    archive_rows = [x['file'] for x in cap['files'] if x['role'] == 'archive']
    candidates = [f for f in archive_rows if f['sha256'] == plan['declaredDonor']['sha256']]
    need(len(candidates) == 1, 'ambiguous donor fixture')
    donor = candidates[0]
    archives = [donor] + providers['providers']
    need(sorted(archives, key=lambda f: f['path']) == sorted(archive_rows, key=lambda f: f['path']), 'archive set mismatch')
    actual = []
    for f in archives:
        b = safe_read(root, 'archives/' + f['path'])
        need(len(b) == f['sizeBytes'] and sha(b) == f['sha256'], 'archive pin')
        actual.append(pak.parse(b))  # Separate cursor/struct/SHA parser, not Go.
    rows, counts = [], [0] * len(archives)
    for x in cap['files']:
        role, f = x['role'], x['file']
        if role not in ('donor', 'current'):
            continue
        b = safe_read(root, 'assets/' + role + '/' + f['path'], 64 << 20)
        need(x['retainedInMemory'] and sha(b) == f['sha256'] and len(b) == f['sizeBytes'], 'asset pin')
        owners = []
        for i in ([0] if role == 'donor' else range(1, len(archives))):
            for path, data in actual[i].items():
                if path.lower() == f['path'].lower():
                    owners.append((i, path, data))
        need(len(owners) == 1, 'membership missing or ambiguous')
        i, path, data = owners[0]
        need(path == f['path'] and data == b, 'membership bytes/case')
        counts[i] += 1
        rows.append({'role': role, 'file': f, 'archive': archives[i],
                     'providerOrdinal': i-1, 'entryPath': path, 'byteEqual': True})
    rows.sort(key=lambda x: (x['role'], x['file']['path']))
    need(report['entries'] == rows, 'membership rows differ from independent readback')
    expected_archives = [{'role': 'donor' if i == 0 else 'current', 'file': f,
                          'providerOrdinal': i-1, 'entries': len(actual[i]),
                          'matchedDeclaredFiles': counts[i]} for i, f in enumerate(archives)]
    need(report['archives'] == expected_archives, 'archive metadata mismatch')
    need(report['archiveBytesRead'] == sum(f['sizeBytes'] for f in archives), 'read count')
    return {'assets': len(rows), 'archives': len(archives),
            'allArchiveEntries': sum(len(x) for x in actual),
            'reportSHA256': sha(safe_read(root, 'report.json', 8 << 20)),
            'membershipCheckedAgainstIndependentPythonParser': True,
            'engineCompatibilityVerified': False}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('corpus', type=Path)
    args = ap.parse_args()
    results = {name: check(args.corpus / name) for name in ('single', 'split', 'extras')}
    print(json.dumps({'schema': 'PMM_R1_MEMBERSHIP_INDEPENDENT_V1', 'fixtures': results,
                      'realAssetsRead': False, 'repakExecuted': False,
                      'scope': 'Synthetic byte membership, not original-engine acceptance'}, indent=2))


if __name__ == '__main__':
    main()
