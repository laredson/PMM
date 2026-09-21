#!/usr/bin/env python3
"""Verify the prepared I04 package without reading Workspace or using the network."""
from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path
EXPECTED_BUILD="PMM-v1.5.0.1-reliability-i04-nexus-updates"
EXPECTED_BINARIES={"PMM.exe":"a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c","Engine/PMMRuntime.exe":"b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f","Engine/PMMFixLab.exe":"8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe"}
def sha(path:Path)->str:return hashlib.sha256(path.read_bytes()).hexdigest()
def verify(package:Path)->dict:
    sums=package/"Resources/Metadata/SHA256SUMS.txt";expected={}
    for line in sums.read_text(encoding="utf-8-sig").splitlines():
        digest,relative=line.split("  ",1)
        if relative in expected or len(digest)!=64:raise ValueError("invalid checksum inventory")
        expected[relative]=digest
    actual={p.relative_to(package).as_posix() for p in package.rglob("*") if p.is_file() and p!=sums and "Workspace" not in p.relative_to(package).parts}
    if set(expected)!=actual:raise ValueError(f"checksum coverage mismatch missing={sorted(actual-set(expected))} extra={sorted(set(expected)-actual)}")
    bad=[name for name,digest in expected.items() if sha(package/name)!=digest]
    if bad:raise ValueError(f"checksum mismatch: {bad}")
    build=(package/"Resources/Metadata/BUILD_ID.txt").read_text(encoding="utf-8-sig").strip();manifest=json.loads((package/"Resources/Metadata/RELEASE_MANIFEST.json").read_text(encoding="utf-8-sig"));modules=json.loads((package/"Modules/modules.json").read_text(encoding="utf-8-sig"))
    if build!=EXPECTED_BUILD or manifest.get("buildId")!=build:raise ValueError("build identity mismatch")
    ids=[m["Id"] for m in modules["Modules"]]
    for needed in ("analysis.nexus-client","analysis.updates","analysis.update-transaction","presentation.updates.ui"):
        if needed not in ids:raise ValueError(f"missing module: {needed}")
    frozen={name:sha(package/name) for name in EXPECTED_BINARIES}
    if frozen!=EXPECTED_BINARIES:raise ValueError("frozen executable changed")
    return {"schema":"PMM_I04_PACKAGE_CHECKS_V1","ok":True,"buildId":build,"packageFiles":len(actual)+1,"checksumRows":len(expected),"checksumMismatches":0,"checksumInventorySha256":sha(sums),"moduleCount":len(ids),"frozenExecutableSha256":frozen,"workspaceRead":False,"networkUsed":False,"liveNexusAccountTested":False,"palworldRuntimeTested":False}
def main()->int:
    parser=argparse.ArgumentParser();parser.add_argument("--package",type=Path,default=Path(__file__).resolve().parents[4]/"PMM");parser.add_argument("--json",type=Path);args=parser.parse_args();result=verify(args.package.resolve());text=json.dumps(result,indent=2);print(text)
    if args.json:args.json.parent.mkdir(parents=True,exist_ok=True);args.json.write_text(text+"\n",encoding="utf-8",newline="\n")
    return 0
if __name__=="__main__":raise SystemExit(main())