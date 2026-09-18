#!/usr/bin/env python3
"""Independent, read-only wire-format check of the pinned packaged patch corpus.
Never apply a patch, read donor/game assets, execute FixLab or write a report file.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import sys
import zlib

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from audit_source import read_file, unique

CASE = 'CKL/FixLab/Cases/FIXLAB-CASE-001-GAWR-GURA/'
RECIPES = {
 'original_fullreplacement': '6a82559b7f2a9fc151437a6caa266e77351ce1138976b9ef3ff72d106bfb295e',
 'normal_locked': '24f6325b6e44adc8371014bfac4b524e61b22f591b0417bf403b8d1cfab20131',
 'red_locked': 'd8fba8b7998686531af7ee23c47a7980cea04658ee3205a68000c6e7d2c9160c',
 'hooded_locked': '9897d452bc3a104f5dd168d3a30526065b3091aa2d79d6c856108d77834c14b6',
 'hair2_panties': 'e5986a26a6b9501b9c4870748e5219c3f988055e1f5f128f77f915aac3e72c86',
}


def digest(b):
 return hashlib.sha256(b).hexdigest()


def inspect(patch):
 if not patch.startswith(b'PMMDLT1\n') or len(patch) > 16 << 20:
  raise ValueError('magic or encoded limit')
 z = zlib.decompressobj()
 body = z.decompress(patch[8:], (64 << 20) + 1)
 if len(body) > 64 << 20 or not z.eof or z.unused_data or z.unconsumed_tail:
  raise ValueError('zlib length, integrity or suffix')
 if len(body) < 12:
  raise ValueError('truncated header')
 target, count = struct.unpack_from('<QI', body)
 if target > 256 << 20 or count > 1_000_000:
  raise ValueError('profile limit')
 pos, copied, literal = 12, 0, 0
 nc, nl, used = 0, 0, {}
 for _ in range(count):
  opcode = body[pos]; pos += 1
  if opcode == 0:
   rid, off, size = struct.unpack_from('<HQQ', body, pos); pos += 18
   if rid >= 1024 or off + size > 256 << 20:
    raise ValueError('copy bounds/profile')
   used[rid] = max(used.get(rid, 0), off + size); nc += 1; copied += size
  elif opcode == 1:
   size, = struct.unpack_from('<Q', body, pos); pos += 8
   if size > len(body) - pos:
    raise ValueError('literal truncated')
   pos += size; nl += 1; literal += size
  else:
   raise ValueError('unknown opcode')
  if copied + literal > target:
   raise ValueError('output overrun')
 if pos != len(body) or copied + literal != target:
  raise ValueError('instruction count, output length or suffix')
 return dict(patchSha256=digest(patch), patchBytes=len(patch), decodedBytes=len(body),
             outputBytes=target, operations=count, copyOperations=nc,
             literalOperations=nl, copyBytes=copied, literalBytes=literal,
             references=[dict(index=i, minimumBytes=n) for i,n in sorted(used.items())] or None)


def canonical_row(row):
 i = row["info"]
 keys = ("patchSha256", "patchBytes", "decodedBytes", "outputBytes", "operations",
         "copyOperations", "literalOperations", "copyBytes", "literalBytes")
 bounds = ",".join(str(r["index"])+":"+str(r["minimumBytes"]) for r in i["references"] or [])
 return ("\t".join([row["path"]]+[str(i[k]) for k in keys]+[bounds])+"\n").encode("utf-8")


def summarize(report):
 rows = report["files"]
 result = {k:v for k,v in report.items() if k != "files"}
 result["metadataSha256"] = digest(b"".join(canonical_row(r) for r in rows))
 result["maxima"] = {k:max(r["info"][k] for r in rows) for k in ("patchBytes", "decodedBytes", "outputBytes", "operations")}
 result["copyOperations"] = sum(r["info"]["copyOperations"] for r in rows)
 result["literalOperations"] = sum(r["info"]["literalOperations"] for r in rows)
 return result


def audit(package):
 rows, refs = {}, 0
 for variant, expected in RECIPES.items():
  b = read_file(package, CASE + 'recipe-' + variant + '-v2.json')
  if digest(b) != expected:
   raise ValueError('recipe pin mismatch')
  recipe = json.loads(b.decode('utf-8-sig'), object_pairs_hook=unique)
  for op in recipe['operations']:
   for alt in op.get('alternatives', []):
    path = CASE + alt['patch']; b = read_file(package, path)
    if digest(b) != alt['patchSha256']:
     raise ValueError('payload pin mismatch')
    info = inspect(b)
    if any(u['index'] >= len(alt['references']) for u in info['references'] or []):
     raise ValueError('reference index not supplied by recipe')
    row = dict(path=path, info=info)
    if path in rows and rows[path] != row:
     raise ValueError('conflicting metadata')
    rows[path] = row; refs += 1
 payloads = [p for p in (package / CASE / 'payload-v2').glob('*.pmmdlt')]
 if len(rows) != len(payloads) or any((CASE+'payload-v2/'+p.name) not in rows for p in payloads):
  raise ValueError('corpus coverage mismatch')
 return dict(schema='PMM_PMMDLT1_CORPUS_STRUCTURE_V1', method='independent Python zlib/struct parser',
             recipeCount=len(RECIPES), recipePatchReferences=refs, uniquePayloads=len(rows),
             operations=sum(r['info']['operations'] for r in rows.values()),
             sourceAssetsRead=False, patchesApplied=False, outputHashesVerified=False,
             files=[rows[p] for p in sorted(rows)])


if __name__ == '__main__':
 ap = argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--package', type=Path, required=True)
 ap.add_argument('--summary', action='store_true', help='Emit aggregate metadata instead of per-payload rows')
 args = ap.parse_args()
 try:
  report = audit(args.package.resolve())
  print(json.dumps(summarize(report) if args.summary else report, indent=2, ensure_ascii=True))
 except (OSError, ValueError, KeyError, TypeError, IndexError, struct.error, zlib.error) as e:
  print('Corpus audit failed: '+str(e), file=sys.stderr); sys.exit(2)
