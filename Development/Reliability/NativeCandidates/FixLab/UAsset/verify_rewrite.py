"""Independent byte-level oracle for SYNTHETIC name-rewrite packets only.
No Go code/imports, engine calls, or real assets. Not a general UAsset rewriter.
"""
import base64
import hashlib
import json
from pathlib import Path
import struct
import sys
from verify_reference import Cursor, inspect


def digest(b):
    return hashlib.sha256(b).hexdigest()


def decode(s):
    return base64.b64decode(s or '', validate=True)


def names(b):
    r = Cursor(b)
    if r.u() != 0x9e2a83c1 or r.i() != -8:
        raise ValueError('profile')
    for _ in range(5):
        r.i()
    total = r.i()
    if total != len(b):
        raise ValueError('header size')
    r.string(); r.u()
    count, offset = r.i(), r.i()
    if not 0 <= count <= 65536:
        raise ValueError('name count')
    r.p = offset
    slots = []
    for _ in range(count):
        start = r.p
        r.string(); r.raw(4)
        slots.append((start, r.p))
    return slots


def expected(packet):
    """Calculate expected bytes from independently positioned synthetic inputs."""
    h, x = decode(packet['InputHeader']), decode(packet['InputData'])
    req, fields = packet['Request'], packet['Fields']
    if digest(h) != req['HeaderSHA256'] or digest(x) != req['ExportSHA256']:
        raise ValueError('input pin')
    before = inspect(h, x)
    spans = names(h)
    sources = []
    for source in req.get('Sources') or []:
        b = decode(source['Header'])
        if digest(b) != source['SHA256']:
            raise ValueError('source pin')
        sources.append((b, names(b)))
    raw = [h[a:b] for a, b in spans]
    seen = set()
    for edit in req.get('Edits') or []:
        i, s, n = edit['Index'], edit['Source'], edit['SourceIndex']
        if i in seen or not 0 <= i < len(raw) or not 0 <= s < len(sources) or not 0 <= n < len(sources[s][1]):
            raise ValueError('edit index')
        seen.add(i)
        b, ss = sources[s]
        a, z = ss[n]
        raw[i] = b[a:z]
    if not spans:
        return h, x, 0
    a, z = spans[0][0], spans[-1][1]
    layout = any(len(b) != hi-lo for b, (lo, hi) in zip(raw, spans))
    if layout and (x or before['registryOffset'] or before['bulkDataStart']):
        raise ValueError('unsupported opaque relocation')
    table = b''.join(raw)
    delta = len(table)-(z-a)
    out = bytearray(h[:a]+table+h[z:])
    if layout:
        struct.pack_into('<i', out, fields['headerSize'], len(out))
        for label in ('nameOffset','softObjectOffset','gatherOffset','exportOffset','importOffset','dependsOffset','softPackageOffset','searchableOffset','thumbnailOffset','assetRegistryOffset','worldTileOffset','preloadOffset'):
            pos = fields[label]
            old, = struct.unpack_from('<i', h, pos)
            if a < old < z:
                raise ValueError('ambiguous marker')
            struct.pack_into('<i', out, pos, old+delta if old >= z else old)
        for entry in before['exports']:
            pos = entry['offset']+36
            new_pos = pos+delta if pos >= z else pos
            logical = entry['serialOffset']-len(h)+len(out)
            struct.pack_into('<q', out, new_pos, logical)
    return bytes(out), x, delta


def check(packet):
    h, x, delta = expected(packet)
    result = packet['Result']
    if decode(result['Header']) != h or decode(result['ExportData']) != x:
        raise ValueError('output bytes differ from independently constructed expectation')
    got = inspect(h, x)
    for key in ('names','imports','exports','depends','preload'):
        if (result['Package'][key] or []) != got[key]:
            raise ValueError('output metadata '+key)
    report = result['Report']
    if report['headerBefore'] != digest(decode(packet['InputHeader'])) or report['headerAfter'] != digest(h) or report['exportSha256'] != digest(x) or report['headerDelta'] != delta:
        raise ValueError('report identity/delta')
    return {'fixture': packet['ID'], 'headerSha256': digest(h), 'exportSha256': digest(x),
            'headerBytes': len(h), 'delta': delta, 'allBytesCompared': True}


def compare(folder):
    paths = sorted(Path(folder).glob('*.json'))
    if len(paths) != 12:
        raise ValueError('expected exactly twelve synthetic packets')
    rows = [check(json.loads(p.read_text(encoding='utf-8'))) for p in paths]
    return {'schema': 'PMM_UASSET_REWRITE_INDEPENDENT_V1', 'fixtureCount': len(rows),
            'fixtures': rows, 'gameAssetsUsed': False, 'engineCompatibilityVerified': False,
            'limit': 'Independent Python reconstruction and readback of synthetic bytes; not Unreal or original FixLab acceptance.'}


if __name__ == '__main__':
    try:
        if len(sys.argv) != 2:
            raise ValueError('usage: verify_rewrite.py <synthetic packets directory>')
        print(json.dumps(compare(sys.argv[1]), indent=2))
    except (OSError, ValueError, KeyError, IndexError, struct.error) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(2)
