"""Independent wire-parser/tool fixtures; no game files or engine execution."""
import hashlib
from pathlib import Path
import struct
import tempfile
import unittest
import zlib
import audit_corpus as a
import build


def wrap(body):
 return b'PMMDLT1\n'+zlib.compress(body)


class WireToolTests(unittest.TestCase):
 def test_empty(self):
  i=a.inspect(wrap(struct.pack('<QI',0,0)))
  self.assertEqual((i['outputBytes'],i['operations']),(0,0))
 def test_copy_literal(self):
  body=struct.pack('<QI',5,2)+struct.pack('<BHQQ',0,3,100,2)+struct.pack('<BQ',1,3)+b'abc'
  i=a.inspect(wrap(body));self.assertEqual(i['copyBytes'],2);self.assertEqual(i['literalBytes'],3)
  self.assertEqual(i['references'],[dict(index=3,minimumBytes=102)])
 def test_bad_magic(self):
  with self.assertRaises(ValueError):a.inspect(b'wrong')
 def test_corrupt_checksum(self):
  b=bytearray(wrap(struct.pack('<QI',0,0)));b[-1]^=1
  with self.assertRaises(zlib.error):a.inspect(bytes(b))
 def test_trailing_compressed(self):
  with self.assertRaises(ValueError):a.inspect(wrap(struct.pack('<QI',0,0))+b'x')
 def test_trailing_decoded(self):
  with self.assertRaises(ValueError):a.inspect(wrap(struct.pack('<QI',0,0)+b'x'))
 def test_unknown_opcode(self):
  with self.assertRaises(ValueError):a.inspect(wrap(struct.pack('<QI',0,1)+b'\x02'))
 def test_truncated_literal(self):
  with self.assertRaises(ValueError):a.inspect(wrap(struct.pack('<QI',3,1)+struct.pack('<BQ',1,3)+b'a'))
 def test_canonical_aggregate(self):
  row=dict(path='p',info=a.inspect(wrap(struct.pack('<QI',0,0))))
  report=dict(files=[row])
  self.assertEqual(a.summarize(report)['metadataSha256'],hashlib.sha256(a.canonical_row(row)).hexdigest())
 def test_output_guard(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d)/'repo';root.mkdir()
   for p in [root,root/'new',Path(d)]:
    with self.assertRaises(ValueError):build.check_output(root,p)
   build.check_output(root,Path(d)/'new-external')


if __name__=='__main__':unittest.main()
