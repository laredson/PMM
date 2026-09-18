#!/usr/bin/env python3
"""Read our four artificial planner fixtures. No engine, game data or writes."""
import argparse
import hashlib
import json
from pathlib import Path

CASES = ('alternative', 'basic', 'bulk', 'provenance')
TARGETS = {'body': ['C/Body1.uasset', 'C/Body2.uasset'], 'hair': ['C/Hair1.uasset']}
SUPPORT = ['D/Mat/Test.uasset', 'D/Mat/Test.uexp', 'D/Skeleton.uasset', 'D/Skeleton.uexp']


def check(plan, recipe, donor, current, case):
    # Expectations come from the handwritten synthetic scenario, not the Go plan.
    if case not in CASES:
        raise ValueError('Unknown synthetic case')
    if plan['schema'] != 'PMM_CORE_R1_PLAN_V1' or plan['status'] != 'PLAN_VALID':
        raise ValueError('Plan status/schema')
    for key in ('inputBytesVerified', 'transformReady', 'buildReady', 'validated', 'installed'):
        if plan[key] is not False:
            raise ValueError('False acceptance: ' + key)
    for key, data in [('recipeSHA256', recipe), ('donorInventorySHA256', donor), ('currentInventorySHA256', current)]:
        if plan[key] != hashlib.sha256(data).hexdigest():
            raise ValueError('Identity mismatch: ' + key)
    inventory = json.loads(donor)
    if plan['declaredDonor']['sha256'] != inventory['providerSHA256']:
        raise ValueError('Wrong donor declaration')
    observed = {}
    for task in plan['tasks']:
        observed.setdefault(task['group'], []).append(task['target']['header']['path'])
        if task['donor']['header']['path'] != ('D/Body.uasset' if task['group'] == 'body' else 'D/Hair.uasset'):
            raise ValueError('Wrong donor mapping')
    if observed != TARGETS:
        raise ValueError('Targets differ from independent scenario')
    if [f['path'] for f in plan['supportFiles']] != SUPPORT or plan['excludedSupport'] != ['D/Mat/Excluded.uasset', 'D/Mat/Excluded.uexp']:
        raise ValueError('Support boundary/exclusion')
    expected = list(SUPPORT)
    for paths in TARGETS.values():
        for header in paths:
            expected.extend([header, header[:-7] + '.uexp'])
    if case == 'bulk':
        expected.extend(['C/Body1.ubulk', 'C/Body2.ubulk'])
    if [o['path'] for o in plan['outputs']] != sorted(expected):
        raise ValueError('Outputs differ')
    if len(plan['nameReferences']) != 1 or plan['nameReferences'][0]['path'] != 'C/Names.uasset':
        raise ValueError('Name source')
    schema = [x for x in plan['requirements'] if x['code'] == 'POSTPROCESS_SCHEMA_PROVENANCE']
    state = 'DECLARED_UNVERIFIED' if case == 'provenance' else 'MISSING'
    if len(schema) != 1 or schema[0]['state'] != state:
        raise ValueError('Schema provenance lost its blocker')
    if not any(x['code'] == 'CORE_EXECUTOR' and x['state'] == 'NOT_IMPLEMENTED' for x in plan['requirements']):
        raise ValueError('Missing executor blocker')
    return {'case': case, 'tasks': len(plan['tasks']), 'outputs': len(expected), 'transformReady': False}


def read(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 2 << 20:
        raise ValueError('Invalid fixture input')
    return path.read_bytes()


def verify(root):
    if root.is_symlink():
        raise ValueError('Symlink fixture root')
    result = []
    for case in CASES:
        d = root / case
        if d.is_symlink():
            raise ValueError('Symlink case directory')
        raw = read(d / 'plan.json')
        row = check(json.loads(raw), read(d / 'recipe.json'), read(d / 'donor.json'), read(d / 'current.json'), case)
        row['planSHA256'] = hashlib.sha256(raw).hexdigest()
        result.append(row)
    return {'schema': 'PMM_R1_SYNTHETIC_PLAN_CHECK_V1', 'fixtures': result,
            'method': 'Independent handwritten path/count oracle; not a second general recipe planner',
            'gameInputsVerified': False, 'repairsExecuted': False}


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('fixtures', type=Path)
    args = ap.parse_args()
    print(json.dumps(verify(args.fixtures), indent=2))
