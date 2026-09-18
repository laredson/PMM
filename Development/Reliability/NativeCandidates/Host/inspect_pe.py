#!/usr/bin/env python3
"""Bounded PE32+/amd64 static inspection. Never load or execute the PE."""
from pathlib import Path
import hashlib
import json
import re
import struct
import sys


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inspect(path):
    path = Path(path)
    if path.stat().st_size > 128 * 1024 * 1024:
        raise ValueError('PE exceeds inspection size limit')
    b = path.read_bytes()
    if len(b) < 64 or b[:2] != b'MZ':
        raise ValueError('Invalid DOS header')
    off = struct.unpack_from('<I', b, 60)[0]
    if off + 24 > len(b) or b[off:off+4] != b'PE\0\0':
        raise ValueError('Invalid PE header')
    machine, count = struct.unpack_from('<HH', b, off+4)
    size = struct.unpack_from('<H', b, off+20)[0]
    opt, table = off+24, off+24+size
    if machine != 0x8664 or size < 152 or table > len(b):
        raise ValueError('Only valid AMD64 PE32+ input is supported')
    if struct.unpack_from('<H', b, opt)[0] != 0x20b:
        raise ValueError('Not PE32+')
    if not 1 <= count <= 96 or table + count*40 > len(b):
        raise ValueError('Invalid section table')
    result = {
        'sha256': digest(b), 'sizeBytes': len(b), 'machine': 'amd64',
        'subsystem': struct.unpack_from('<H', b, opt+68)[0],
        'certificateTableBytes': struct.unpack_from('<I', b, opt+148)[0],
        'sections': [], 'executed': False, 'authenticodeChainVerified': False,
    }
    for i in range(count):
        entry = table+i*40
        name = b[entry:entry+8].rstrip(b'\0').decode('ascii', 'strict')
        virtual_size, rva, raw_size, raw_off = struct.unpack_from('<IIII', b, entry+8)
        if raw_size and (raw_off < table+count*40 or raw_off+raw_size > len(b)):
            raise ValueError('Invalid raw section bounds')
        data = b[raw_off:raw_off+raw_size]
        result['sections'].append({'name': name, 'rva': rva, 'virtualSize': virtual_size,
                                   'rawSize': raw_size, 'sha256': digest(data)})
    # These are name strings, not recovered source, a call graph or proof of execution.
    result['embeddedHostFunctionNames'] = sorted(set(m.decode('ascii') for m in re.findall(
        rb'\x00(main\.[A-Za-z0-9_.()*$/-]{1,150})(?=\x00)', b)))
    result['embeddedSourcePathNames'] = sorted(set(m.decode('ascii') for m in re.findall(
        rb'github\.com/laredson/pmm-host/[A-Za-z0-9_./-]+\.go', b)))
    return result


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: python inspect_pe.py <PE-file>')
    print(json.dumps(inspect(sys.argv[1]), indent=2))
