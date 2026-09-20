#!/usr/bin/env python3
"""Independent verifier of the four OWN synthetic execution exports.
Reads bytes/metadata only. Does not use the Go executor or run any game tools.
The fixed byte edits come from the authored fixture specification, not the output.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('pmm_pak_reference', HERE.parent / 'PAKV11' / 'verify_reference.py')
pak = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pak)


def sha(b): return hashlib.sha256(b).hexdigest()
def need(ok, message):
    if not ok: raise ValueError(message)

def read(p, limit=16 << 20):
    need(not p.is_symlink() and p.is_file(), 'missing/symlink fixture')
    with p.open('rb') as f: data = f.read(limit + 1)
    need(len(data) <= limit, 'oversized fixture')
    return data


def unique(pairs):
    d = {}
    for k, v in pairs:
        need(k not in d, 'duplicate key'); d[k] = v
    return d

def js(b): return json.loads(b, object_pairs_hook=unique)
def checked_path(root, relative):
    pak.safe_path(relative)
    p = root
    for part in relative.split('/'):
        p = p / part
        need(not p.is_symlink(), 'symlink ancestor')
    return p


def expected_files(kind):
    vectors = js(read(HERE / 'testdata/execution-vectors.json'))['fixtures']
    fixture = next(v for v in vectors if v['id'] == kind)
    h, x = base64.b64decode(fixture['header']), base64.b64decode(fixture['data'])
    names = base64.b64decode(fixture['namesHeader'])
    start, end = fixture['sourceSpan']
    # Manual format-specific changes using SYNTHETIC offsets: no production parser.
    changed = bytearray(h); changed[start:end] = names[start:end]
    need(len(changed) == len(h), 'expected fixed width')
    final_h, final_x = bytearray(changed), bytearray(x)
    dep, prop = fixture['edits']['preload'], fixture['edits']['property']
    need(struct.unpack_from('<i', h, dep)[0] == -4 and struct.unpack_from('<i', x, prop)[0] == -4, 'fixture prior refs')
    struct.pack_into('<i', final_h, dep, -6); struct.pack_into('<i', final_x, prop, 0)
    need(bytes(changed) == base64.b64decode(fixture['afterNamesHeader']) and
         bytes(final_h) == base64.b64decode(fixture['finalPostHeader']) and
         bytes(final_x) == base64.b64decode(fixture['finalPostData']), 'fixture authoring discrepancy')
    result = {'C/Body1.uasset':bytes(final_h), 'C/Body1.uexp':bytes(final_x),
              'C/Body2.uasset':bytes(final_h), 'C/Body2.uexp':bytes(final_x),
              'C/Hair1.uasset':bytes(changed), 'C/Hair1.uexp':x}
    for stem in ('D/Mat/Test', 'D/Skeleton'):
        result[stem + '.uasset'] = h; result[stem + '.uexp'] = x
    return result, fixture


def check(directory):
    kind = directory.name
    expected, fixture = expected_files(kind)
    raw = {f:read(directory / (f+'.json')) for f in ('execution', 'review', 'capture', 'membership', 'plan', 'report')}
    plan, review, report = js(raw['execution']), js(raw['review']), js(raw['report'])
    capture, member, declared = js(raw['capture']), js(raw['membership']), js(raw['plan'])
    need(report['schema'] == 'PMM_R1_BOUNDED_EXECUTION_REPORT_V1', 'report schema')
    for field, name in [('executionPlanSHA256','execution'), ('reviewSHA256','review'), ('captureSHA256','capture'), ('membershipSHA256','membership')]:
        need(report[field] == sha(raw[name]), 'report binding')
    need(review['executionPlanSHA256'] == sha(raw['execution']), 'review binding')
    need(plan['planSHA256'] == sha(raw['plan']) == capture['planSHA256'] == member['planSHA256'], 'plan binding')
    need(plan['captureSHA256'] == sha(raw['capture']) == member['captureReportSHA256'], 'capture binding')
    need(plan['membershipSHA256'] == sha(raw['membership']) and report['recipeSHA256'] == declared['recipeSHA256'], 'membership/recipe')
    for flag in ('schemaSemanticsVerified','reviewerAuthenticated','coreR1Complete','transformReady','buildReady','validated','installed'):
        need(report[flag] is False, 'unproven readiness')
    need(report['outputPinsChecked'] is True and report['pakReadbackByteEqual'] is True, 'verification flag')
    need(not declared['transformReady'] and not member['transformReady'] and not capture['transformReady'], 'prior evidence promoted')
    expected_rows = [{'path':p,'sha256':sha(b),'sizeBytes':len(b)} for p,b in sorted(expected.items())]
    need(report['outputs'] == expected_rows, 'output descriptors')
    need(sorted(plan['outputs'],key=lambda f:f['path']) == expected_rows, 'external output pins')
    need(len(report['families']) == 3 and sum('postProcess' in f for f in report['families']) == 2, 'family coverage')
    for name, data in expected.items():
        need(read(checked_path(directory/'expected',name)) == data, 'expected fixture altered')
        need(read(checked_path(directory/'actual',name)) == data, 'actual file mismatch')
    archive = read(directory/'output.pak')
    need(pak.parse(archive) == expected, 'independent PAK readback')
    need(sha(archive) == report['pakSHA256'] and len(archive) == report['pakBytes'], 'PAK identity')
    # Structural offset assertions are NOT derived from whatever the executor reports.
    for f in report['families']:
        need(not f['names']['nameLayoutChanged'] and f['names']['headerDelta'] == 0, 'layout changed')
        if 'postProcess' in f:
            edits = f['postProcess']['edits']
            need(len(edits) == 2 and edits[0]['offset'] == fixture['edits']['preload'] and edits[1]['offset'] == fixture['edits']['property'], 'postprocess extents')
    return {'fixture':kind,'files':len(expected),'families':3,'postProcessFamilies':2,
            'pakSHA256':sha(archive),'bytes':len(archive),'allOutputBytesCompared':True,
            'unrealAccepted':False,'gameDataUsed':False}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('directory',type=Path);args=parser.parse_args()
    try:
        result=[check(args.directory / k) for k in ('basic','masked','decoy','array')]
        print(json.dumps({'schema':'PMM_R1_EXECUTION_INDEPENDENT_V1','fixtures':result,'method':'Authored Python byte edits plus independent PAK reader; not engine acceptance'},indent=2));return 0
    except (OSError,ValueError,KeyError,TypeError,StopIteration) as exc:
        print('Verification failed: '+str(exc),file=sys.stderr);return 2
if __name__=='__main__':raise SystemExit(main())
