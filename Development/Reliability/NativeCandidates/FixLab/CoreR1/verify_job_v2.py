#!/usr/bin/env python3
"""Independent reader for one OWN synthetic job V2 export.
It does not run Go, execute the candidate, extract it or install anything.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import sys
from verify_execution import read, js, need, sha, pak, expected_files


def descriptor(root: Path, row: dict) -> bytes:
    path = row['path']
    need(isinstance(path, str) and '\\' not in path and '..' not in path.split('/'), 'document path')
    data = read(root / path)
    need(len(data) == row['sizeBytes'] and sha(data) == row['sha256'], 'document descriptor')
    return data


def check(root: Path) -> dict:
    job_raw, result_raw = read(root / 'job.json'), read(root / 'result.json')
    job, result = js(job_raw), js(result_raw)
    need(read(root / 'job.sha256').decode().strip() == sha(job_raw), 'external job pin')
    need(job['schema'] == 'PMM_R1_CANDIDATE_JOB_V2', 'job schema')
    need(job['operation'] == 'EXECUTE_AND_PUBLISH_CANDIDATE_ONLY', 'job operation')
    need(job['candidateOnly'] is True and job['installRequested'] is False and job['deployRequested'] is False, 'negative capabilities')
    docs = root / 'documents'
    rows = job['documents']
    for key in ('recipe', 'donorInventory', 'currentInventory', 'currentProviderSet', 'executionPlan', 'executionReview'):
        descriptor(docs, rows[key])
    for row in rows['schemaClaims']:
        descriptor(docs, row)
    need(len(job['dossiers']) == 1, 'dossier coverage')
    layout_row = job['dossiers'][0]['layout']
    layout_raw = read(root / 'inputs' / 'schemas' / layout_row['path'])
    need(len(layout_raw) == layout_row['sizeBytes'] and sha(layout_raw) == layout_row['sha256'], 'layout descriptor')
    layout = js(layout_raw)
    need(layout['schema'] in ('PMM_FIXED_UNVERSIONED_SCHEMA_V1', 'PMM_FIXED_UNVERSIONED_SCHEMA_V2'), 'layout schema')
    fixture_kind = 'array' if layout['schema'] == 'PMM_FIXED_UNVERSIONED_SCHEMA_V2' else 'basic'
    need(result['schema'] == 'PMM_R1_CANDIDATE_JOB_RESULT_V2', 'result schema')
    need(result['state'] == 'CANDIDATE_PUBLISHED_NOT_GAME_ACCEPTED' and result['candidateOnly'] is True, 'candidate result')
    need('error' not in result and 'residueName' not in result, 'clean result')
    receipt = result['receipt']
    name = receipt['candidateName']
    need(re.fullmatch(r'PMM-candidate-[0-9a-f]{32}', name), 'candidate name')
    candidate = root / 'candidates' / name
    need(candidate.is_dir() and not candidate.is_symlink(), 'candidate directory')
    need({p.name for p in candidate.iterdir()} == {'candidate.pak', 'execution.json', 'MANIFEST.json', 'COMPLETE.json'}, 'bundle coverage')
    raw = {name: read(candidate / name) for name in ('candidate.pak', 'execution.json', 'MANIFEST.json', 'COMPLETE.json')}
    report, manifest, complete = js(raw['execution.json']), js(raw['MANIFEST.json']), js(raw['COMPLETE.json'])
    need(sha(raw['MANIFEST.json']) == receipt['manifestSHA256'] == complete['manifestSHA256'], 'manifest binding')
    need(sha(raw['candidate.pak']) == receipt['pakSHA256'] == report['pakSHA256'], 'pak binding')
    need(sha(raw['execution.json']) == receipt['reportSHA256'], 'report binding')
    need(manifest['candidateOnly'] is True and manifest['gameAccepted'] is False and manifest['installed'] is False, 'manifest boundary')
    for flag in ('gameAccepted', 'installed', 'crashDurabilityGuaranteed'):
        need(receipt[flag] is False, 'unsupported receipt claim')
    for flag in ('schemaSemanticsVerified', 'reviewerAuthenticated', 'coreR1Complete', 'transformReady', 'buildReady', 'validated', 'installed'):
        need(report[flag] is False, 'unsupported execution claim')
    expected, _ = expected_files(fixture_kind)
    need(pak.parse(raw['candidate.pak']) == expected, 'independent PAK contents')
    return {
        'schema': 'PMM_R1_CANDIDATE_JOB_FIXTURE_VERIFICATION_V1',
        'jobSHA256': sha(job_raw), 'state': result['state'],
        'candidateName': name, 'manifestSHA256': sha(raw['MANIFEST.json']),
        'outputEntriesCompared': len(expected), 'executionFixture': fixture_kind, 'candidateOnly': True,
        'gameAccepted': False, 'installed': False, 'realAssetsUsed': False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(check(args.directory), indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError, UnicodeError) as exc:
        print('Verification failed: ' + str(exc), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
