#!/usr/bin/env python3
"""Independent reader of OWN synthetic candidate bundles. Not a deployment tool.
Checks manifest/marker, report and PAK bytes against the pre-authored fixture
expectations; never executes Go, extracts the archive or installs anything.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import sys
from verify_execution import read, js, need, sha, pak, expected_files


def check(directory: Path) -> dict:
    receipt = js(read(directory / 'receipt.json'))
    name = receipt['candidateName']
    need(re.fullmatch(r'PMM-candidate-[0-9a-f]{32}', name), 'final candidate name')
    root = directory / name
    need(not root.is_symlink() and root.is_dir(), 'candidate directory')
    need({p.name for p in root.iterdir()} == {'candidate.pak', 'execution.json', 'MANIFEST.json', 'COMPLETE.json'}, 'fixture bundle coverage')
    raw = {n: read(root / n) for n in ('candidate.pak', 'execution.json', 'MANIFEST.json', 'COMPLETE.json')}
    manifest, completion, report = [js(raw[n]) for n in ('MANIFEST.json', 'COMPLETE.json', 'execution.json')]
    need(receipt['schema'] == 'PMM_R1_CANDIDATE_RECEIPT_V1', 'receipt schema')
    need(manifest['schema'] == 'PMM_R1_CANDIDATE_MANIFEST_V1' and manifest['profile'] == 'PMM_R1_ISOLATED_BUNDLE_V1', 'manifest schema/profile')
    need(completion['schema'] == 'PMM_R1_CANDIDATE_COMPLETE_V1', 'completion schema')
    need(manifest['candidateName'] == completion['candidateName'] == name, 'candidate binding')
    need(sha(raw['MANIFEST.json']) == completion['manifestSHA256'] == receipt['manifestSHA256'], 'manifest pin')
    need(receipt['pakSHA256'] == sha(raw['candidate.pak']) == report['pakSHA256'], 'PAK identity')
    need(receipt['reportSHA256'] == sha(raw['execution.json']), 'report identity')
    need(receipt['published'] is True and receipt['listedBytesVerified'] is True, 'publication state')
    for flag in ('gameAccepted', 'installed', 'crashDurabilityGuaranteed'):
        need(receipt[flag] is False, 'unsupported receipt claim')
    need(manifest['candidateOnly'] is True and not manifest['gameAccepted'] and not manifest['installed'], 'candidate boundary')
    expected_rows = [{'path': n, 'sha256': sha(raw[n]), 'sizeBytes': len(raw[n])} for n in ('candidate.pak','execution.json')]
    need(manifest['files'] == expected_rows, 'file bindings')
    need(manifest['executionPlanSHA256'] == report['executionPlanSHA256'] and manifest['recipeSHA256'] == report['recipeSHA256'], 'execution binding')
    for flag in ('schemaSemanticsVerified', 'reviewerAuthenticated', 'coreR1Complete', 'transformReady', 'buildReady', 'validated', 'installed'):
        need(report[flag] is False, 'unproven readiness')
    expected, _ = expected_files(directory.name)
    need(pak.parse(raw['candidate.pak']) == expected, 'independent byte-exact PAK check')
    need(report['outputs'] == [{'path': n, 'sha256': sha(b), 'sizeBytes': len(b)} for n,b in sorted(expected.items())], 'expected outputs')
    return {'fixture': directory.name, 'filesInBundle': 4, 'outputEntriesCompared': len(expected), 'pakSHA256': sha(raw['candidate.pak']), 'manifestSHA256': sha(raw['MANIFEST.json']), 'gameAccepted': False}


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('directory', type=Path)
    args = p.parse_args()
    try:
        results = [check(args.directory / k) for k in ('basic', 'masked', 'decoy')]
        print(json.dumps({'schema': 'PMM_R1_PUBLICATION_FIXTURE_VERIFICATION_V1', 'fixtures': results, 'realAssetsUsed': False}, indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError, StopIteration) as exc:
        print('Verification failed: ' + str(exc), file=sys.stderr)
        return 2

if __name__ == '__main__':
    raise SystemExit(main())
