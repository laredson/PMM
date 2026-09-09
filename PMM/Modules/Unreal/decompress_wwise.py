"""Decode the offline integration XZ with Unreal's embedded Python, under a size cap.
Archive paths and entry types are checked by PMM before extraction from the TAR.
"""
import argparse
import lzma
from pathlib import Path

MAX_BYTES = 2 * 1024**3

def decompress(source, destination):
    source, destination = Path(source), Path(destination)
    if source.name != "Unreal.5.0.tar.xz" or source.stat().st_size > 512 * 1024**2:
        raise ValueError("Unexpected Wwise integration archive")
    total = 0
    with lzma.open(source, "rb") as src, destination.open("xb") as dst:
        while True:
            block = src.read(1024 * 1024)
            if not block:
                break
            total += len(block)
            if total > MAX_BYTES:
                raise ValueError("Wwise integration exceeds 2 GiB")
            dst.write(block)
    return total

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("destination")
    args = parser.parse_args()
    print(decompress(args.source, args.destination))
