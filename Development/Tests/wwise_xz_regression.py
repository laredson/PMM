import sys
sys.dont_write_bytecode=True
import importlib.util
import lzma
import tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location("decoder",root/"PMM/Modules/Unreal/decompress_wwise.py")
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
with tempfile.TemporaryDirectory(dir=root/"Development/TestResults") as work:
    work=Path(work);source=work/"Unreal.5.0.tar.xz";out=work/"ok.tar"
    source.write_bytes(lzma.compress(b"expected tar bytes"))
    assert m.decompress(source,out)==18 and out.read_bytes()==b"expected tar bytes"
    try:m.decompress(source,out)
    except FileExistsError:pass
    else:raise AssertionError("Existing output overwritten")
    source.write_bytes(b"corrupted")
    try:m.decompress(source,work/"bad.tar")
    except lzma.LZMAError:pass
    else:raise AssertionError("Corrupt archive accepted")
    source.write_bytes(lzma.compress(b"12345"));m.MAX_BYTES=4
    try:m.decompress(source,work/"limit.tar")
    except ValueError:pass
    else:raise AssertionError("Size cap bypassed")
print("WWISE_XZ_OK: decode, corrupt input, existing output and size cap")
