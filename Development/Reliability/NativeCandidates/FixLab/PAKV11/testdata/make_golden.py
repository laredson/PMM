#!/usr/bin/env python3
"""Print a hand-laid-out synthetic vector; no Go code or PAK tools are invoked.
Explicit offsets are independently calculated for three files; fixture is frozen
in golden.json so future tests do not regenerate their oracle with the writer.
"""
import hashlib
import json
import struct
P = lambda fmt, *n: struct.pack('<' + fmt, *n)
S = lambda s: P('i', len(s) + 1) + s.encode('ascii') + b'\0'
H = lambda b: hashlib.sha1(b).digest()
expected = {'a.txt': b'abc', 'dir/B.bin': b'\x00\x01\xff', 'dir/empty': b''}
body = b''.join(P('QQQI', 0, len(v), len(v), 0) + H(v) + P('BI', 0, 0) + v for v in expected.values())
records = P('III', 0xe0000000, 0, 3) + P('III', 0xe0000000, 56, 3) + P('III', 0xe0000000, 112, 0)
hashes = []
for path in expected:
    h = 0xcbf29ce484222325
    for x in path.lower().encode('utf-16le'):
        h = ((h ^ x) * 0x100000001b3) & 0xffffffffffffffff
    hashes.append(h)
phi = P('I', 3) + b''.join(P('QI', h, offset) for h, offset in zip(hashes, (0, 12, 24))) + P('I', 0)
fdi = P('I', 2) + S('/') + P('I', 1) + S('a.txt') + P('I', 0)
fdi += S('dir/') + P('I', 2) + S('B.bin') + P('I', 12) + S('empty') + P('I', 24)
assert (len(body), len(records), len(phi), len(fdi)) == (165, 36, 44, 69)
primary = S('../../../') + P('IQ', 3, 0) + P('IQQ', 1, 315, 44) + H(phi)
primary += P('IQQ', 1, 359, 69) + H(fdi) + P('I', 36) + records + P('I', 0)
assert len(primary) == 150
footer = bytes(17) + P('IIQQ', 0x5a6f12e1, 11, 165, 150) + H(primary) + bytes(160)
raw = body + primary + phi + fdi + footer
assert len(raw) == 649
print(json.dumps({'origin': 'hand-laid-out synthetic vector, not UnrealPak/FixLab output',
                  'sha256': hashlib.sha256(raw).hexdigest(), 'archiveHex': raw.hex(),
                  'expected': {p: b.hex() for p, b in expected.items()},
                  'pathHashes': {p: f'{h:016x}' for p, h in zip(expected, hashes)}}, indent=2))
