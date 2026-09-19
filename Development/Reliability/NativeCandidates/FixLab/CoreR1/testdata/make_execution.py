"""Own artificial fixtures. No game assets; never calls the Go executor.
Expected edits are authored from the known synthetic layout and fixed positions.
"""
import base64
import hashlib
import json
from pathlib import Path
import struct
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / 'UAsset' / 'testdata'))
from make_postprocess import make_case


def b64(b): return base64.b64encode(b).decode('ascii')
def unb64(s): return base64.b64decode(s)
def make():
    fixtures = []
    for kind in ('basic', 'masked', 'decoy'):
        v = make_case(kind)
        h, x = unb64(v['header']), unb64(v['data'])
        pos = struct.unpack_from('<i', h, v['positions']['fields']['nameOffset'])[0]
        entries = []
        for _ in range(13):
            n = struct.unpack_from('<i', h, pos)[0]
            end = pos + 4 + (n if n >= 0 else -n * 2) + 4
            entries.append((pos, end)); pos = end
        start, end = entries[12]
        raw = struct.pack('<i', 13) + b'OtherFixture\0' + struct.pack('<HH', 313, 719)
        assert len(raw) == end - start
        names = bytearray(h); names[start:end] = raw
        post_header = bytearray(unb64(v['expectedHeader'])); post_header[start:end] = raw
        req = v['request']
        fixtures.append(dict(id=kind, header=b64(h), data=b64(x),
            namesHeader=b64(names), afterNamesHeader=b64(names),
            finalPostHeader=b64(post_header), finalPostData=v['expectedData'],
            layout=req['schema'], slot=12, sourceSlot=12, sourceSpan=[start,end],
            post={k:req[k] for k in ('exportIndex','exportObject','stale','safe','preloadIndex','dependencyGroup','expectedSerializedOffset')},
            edits=dict(preload=v['positions']['preload'], property=v['positions']['property'])))
    return {'schema':'PMM_R1_EXECUTION_SYNTHETIC_V1','fixtures':fixtures}


def encoded(): return (json.dumps(make(), indent=2, sort_keys=True)+'\n').encode('ascii')
if __name__ == '__main__': HERE.joinpath('execution-vectors.json').write_bytes(encoded())
