#!/usr/bin/env python3
"""Independent Python PAK11-profile verifier. No Go imports, process launch or extraction.
Reference: repak entry/footer/pak.rs at 355b5f62 and Epic FPakInfo; see FORMAT.md.
Independent implementation is NOT independent engine or Palworld acceptance.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import struct

MAX_ARCHIVE = 256 << 20
MAX_INDEX = 32 << 20
MAX_FILE = 64 << 20
MAX_FILES = 16384


class Invalid(ValueError):
    pass


def need(condition, message):
    if not condition:
        raise Invalid(message)


class Reader:
    def __init__(self, data):
        self.data, self.pos = memoryview(data), 0

    def take(self, size):
        need(0 <= size <= len(self.data) - self.pos, 'truncated field')
        result = self.data[self.pos:self.pos + size]
        self.pos += size
        return result

    def number(self, code):
        return struct.unpack('<' + code, self.take(struct.calcsize('<' + code)))[0]

    def string(self, maxlen=1025):
        n = self.number('i')
        need(1 <= n <= maxlen + 1, 'unsupported FString')
        raw = bytes(self.take(n))
        need(raw[-1:] == b'\0' and b'\0' not in raw[:-1], 'bad string terminator')
        try:
            return raw[:-1].decode('ascii')
        except UnicodeDecodeError as exc:
            raise Invalid('non-ASCII FString') from exc

    def end(self):
        need(self.pos == len(self.data), 'trailing bytes')


def safe_path(path):
    need(0 < len(path) <= 1024, 'path length')
    parts = path.split('/')
    need(len(parts) <= 32, 'path depth')
    reserved = {'CON', 'PRN', 'AUX', 'NUL', 'CONIN$', 'CONOUT$', 'CLOCK$'}
    reserved.update(f'{prefix}{n}' for prefix in ('COM', 'LPT') for n in range(1, 10))
    for part in parts:
        need(bool(part) and len(part) <= 255 and part not in ('.', '..') and
             not part.endswith(('.', ' ')), 'unsafe component')
        need(all(32 <= ord(c) <= 126 and c not in '<>:"\\|?*' for c in part), 'unsafe character')
        need(part.split('.')[0].rstrip(' ').upper() not in reserved, 'reserved component')
    return parts


def path_hash(path, seed):
    h = (0xcbf29ce484222325 + seed) & ((1 << 64) - 1)
    for value in path.lower().encode('utf-16le'):
        h = ((h ^ value) * 0x100000001b3) & ((1 << 64) - 1)
    return h


def parse(data):
    need(221 <= len(data) <= MAX_ARCHIVE, 'archive size')
    view = memoryview(data)
    end = len(view) - 221
    f = Reader(view[end:])
    need(bytes(f.take(17)) == bytes(17), 'encryption/guid unsupported')
    need(f.number('I') == 0x5a6f12e1 and f.number('I') == 11, 'magic/version')
    start, size, expected = f.number('Q'), f.number('Q'), bytes(f.take(20))
    need(bytes(f.take(160)) == bytes(160), 'compression methods unsupported')
    f.end()
    need(start <= end and size <= end - start and end - start <= MAX_INDEX, 'index region')

    def indexed(off, length, digest):
        need(off <= end and length <= end - off, 'invalid index range')
        block = view[off:off + length]
        need(hashlib.sha1(block).digest() == digest, 'index hash')
        return Reader(block)

    p = indexed(start, size, expected)
    need(p.string() == '../../../', 'mount point')
    count, seed = p.number('I'), p.number('Q')
    need(count <= MAX_FILES, 'file count')
    indexes = []
    for _ in range(2):
        need(p.number('I') == 1, 'missing secondary index')
        indexes.append((p.number('Q'), p.number('Q'), bytes(p.take(20))))
    encoded_size = p.number('I')
    need(encoded_size == count * 12, 'compact-entry array size')
    records = Reader(p.take(encoded_size))
    need(p.number('I') == 0, 'unencoded entries unsupported')
    p.end()
    pos = start + size
    for off, length, _ in indexes:
        need(off == pos and length <= end - pos, 'secondary index overlap/gap')
        pos += length
    need(pos == end, 'trailing bytes before footer')
    entries = []
    for _ in range(count):
        need(records.number('I') == 0xe0000000, 'unsupported compact flags')
        off, length = records.number('I'), records.number('I')
        need(length <= MAX_FILE, 'file size')
        entries.append((off, length))
    records.end()
    ph = indexed(*indexes[0])
    need(ph.number('I') == count, 'path hash count')
    hashes, locations = {}, set()
    for _ in range(count):
        h, loc = ph.number('Q'), ph.number('i')
        need(0 <= loc < encoded_size and loc % 12 == 0 and loc not in locations and
             h not in hashes, 'duplicate/invalid path hash entry')
        hashes[h] = loc
        locations.add(loc)
    need(ph.number('I') == 0, 'pruned index unsupported')
    ph.end()
    directory = indexed(*indexes[1])
    nd = directory.number('I')
    need(1 <= nd <= 1 + count * 32, 'directory count')
    paths, dirs, used, folded, ancestry = {}, set(), set(), set(), {'/'}
    dir_case = {}
    for _ in range(nd):
        d = directory.string()
        need(d not in dirs, 'duplicate directory')
        dirs.add(d)
        if d != '/':
            need(d.endswith('/'), 'directory slash')
            safe_path(d[:-1])
        n = directory.number('I')
        need(n <= count - len(paths), 'directory entries count')
        for _ in range(n):
            name, loc = directory.string(), directory.number('i')
            need('/' not in name and 0 <= loc < encoded_size and loc % 12 == 0 and
                 loc not in used, 'directory location')
            path = name if d == '/' else d + name
            parts = safe_path(path)
            need(path.lower() not in folded, 'case/duplicate file')
            need(hashes.get(path_hash(path, seed)) == loc, 'path hash disagrees')
            folded.add(path.lower())
            used.add(loc)
            paths[path] = entries[loc // 12]
            for depth in range(1, len(parts)):
                parent = '/'.join(parts[:depth])
                need(dir_case.get(parent.lower(), parent) == parent, 'case-colliding directory')
                dir_case[parent.lower()] = parent
                ancestry.add(parent + '/')
    directory.end()
    need(len(paths) == count and dirs == ancestry, 'incomplete full directory index')
    need(not (folded & set(dir_case)), 'file/directory collision')
    index_budget = 136 + 24 * count + sum(len(p.split('/')[-1]) + 9 for p in paths)
    index_budget += sum(len(p) + 10 for p in dir_case.values())
    need(index_budget <= MAX_INDEX, 'index growth')
    position = 0
    for off, length in sorted(entries):
        need(off == position and off <= start and 53 + length <= start - off, 'entry overlap/gap/range')
        h = Reader(view[off:off + 53])
        need(h.number('Q') == 0 and h.number('Q') == length and h.number('Q') == length and
             h.number('I') == 0, 'header sizes/method')
        digest = bytes(h.take(20))
        need(h.number('B') == 0 and h.number('I') == 0, 'entry flags/block size')
        h.end()
        need(hashlib.sha1(view[off + 53:off + 53 + length]).digest() == digest, 'payload hash')
        position = off + 53 + length
    need(position == start, 'unreferenced data')
    # Readback only; no extraction or mutation of the archive's referenced paths.
    return {p: bytes(view[o + 53:o + 53 + n]) for p, (o, n) in sorted(paths.items())}


def verify(data, expected=None):
    actual = parse(data)
    if expected is not None:
        need(actual == expected, 'expected file names/bytes differ')
    return {'archiveSha256': hashlib.sha256(data).hexdigest(),
            'byteExact': expected is not None,
            'files': [{'path': p, 'bytes': len(b), 'sha256': hashlib.sha256(b).hexdigest()}
                      for p, b in actual.items()]}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--corpus', type=Path, required=True)
    args = ap.parse_args()
    results = []
    try:
        for pak in sorted(args.corpus.glob('*.pak')):
            need(not pak.is_symlink() and pak.stat().st_size <= MAX_ARCHIVE, 'unsafe corpus file')
            with pak.open('rb') as f:
                raw = f.read(MAX_ARCHIVE + 1)
            fixture = json.loads(pak.with_suffix('.json').read_text())
            expected = {p: bytes.fromhex(b) for p, b in fixture['expected'].items()}
            report = verify(raw, expected)
            need(report == fixture['goReport'], 'independent Go/Python report disagreement')
            results.append({'fixture': pak.stem, **report})
        need(bool(results), 'empty corpus')
        print(json.dumps({'method': 'independent Python parser + supplied synthetic bytes',
                          'fixtures': results, 'engineCompatibilityVerified': False}, indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print('Verification failed: ' + str(exc))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
