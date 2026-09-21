#!/usr/bin/env python3
"""Finalize PMM package metadata for the I03 localization integration."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

INPUT_BUILD="PMM-v1.5.0.1-reliability-i02"
OUTPUT_BUILD="PMM-v1.5.0.1-reliability-i03"
TARGET_BASE="fcd4b5ef8401ada4b6b8c2d79b9477738e15a3ee"
DONOR_COMMIT="681f7994474ebfd6c2538775767d2002014170f7"
BINARIES={
 "PMM.exe":"a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c",
 "Engine/PMMRuntime.exe":"b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f",
 "Engine/PMMFixLab.exe":"8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe",
}
ENABLED=["en","es","fr","it","pt-BR","ro","de","pl","nl","ga","cs","uk","ru","ja","zh-CN","zh-TW","ko","hi","th","id","vi","tr","ar"]
RESERVE=["bn","ur","mr","te","arz","pcm","ha"]

def sha256(path:Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def load_json(path:Path)->dict[str,Any]:
    value=json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value,dict): raise ValueError(f"{path}: JSON root must be an object")
    return value

def write_json(path:Path,value:dict[str,Any])->None:
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")

def regenerate_checksums(package:Path)->tuple[int,int]:
    sums=package/"Resources"/"Metadata"/"SHA256SUMS.txt"
    files=sorted((p for p in package.rglob("*") if p.is_file() and p!=sums and "Workspace" not in p.relative_to(package).parts),key=lambda p:p.relative_to(package).as_posix())
    rows=[f"{sha256(p)}  {p.relative_to(package).as_posix()}\n" for p in files]
    sums.write_text("".join(rows),encoding="utf-8",newline="\n")
    return len(files)+1,len(rows)

def prepare(package:Path)->dict[str,Any]:
    metadata=package/"Resources"/"Metadata"
    build_path=metadata/"BUILD_ID.txt"
    manifest_path=metadata/"RELEASE_MANIFEST.json"
    version=(metadata/"VERSION.txt").read_text(encoding="utf-8").strip()
    if version!="1.5.0.1": raise ValueError(f"Unexpected product version: {version!r}")
    current_build=build_path.read_text(encoding="utf-8").strip()
    if current_build not in (INPUT_BUILD,OUTPUT_BUILD): raise ValueError(f"Unexpected input build: {current_build!r}")
    actual_binaries={path:sha256(package/path) for path in BINARIES}
    mismatches={path:{"expected":BINARIES[path],"actual":actual} for path,actual in actual_binaries.items() if actual!=BINARIES[path]}
    if mismatches: raise ValueError(f"Frozen executable hash mismatch: {mismatches}")
    manifest=load_json(manifest_path)
    if manifest.get("version")!="1.5.0.1": raise ValueError("Manifest version is not 1.5.0.1")
    if manifest.get("buildId") not in (INPUT_BUILD,OUTPUT_BUILD): raise ValueError(f"Unexpected manifest buildId: {manifest.get('buildId')!r}")
    manifest["releaseCandidate"]="1.5.0.1-reliability-i03"
    manifest["buildId"]=OUTPUT_BUILD
    manifest["release"]="PMM v1.5.0.1 I03 - reliability localization integration"
    manifest["releaseValidation"]["programRegression"]="PENDING full Windows acceptance of I03; owner reports I02 startup works and vi/uk/cs/ga worked in the donor build"
    manifest["reliabilityPreparation"]["session"]="I03"
    manifest["reliabilityPreparation"]["state"]="host-runtime-integrated-with-workspace-local-desktop-project-and-23-enabled-languages"
    manifest["localizationIntegration"]={
      "schema":"PMM_LOCALIZATION_INTEGRATION_V1","id":"I03","targetBaseCommit":TARGET_BASE,
      "donorBranch":"v1.5.0.0-PMM-translated","donorCommit":DONOR_COMMIT,
      "registeredLanguageCount":30,"enabledLanguageCount":23,"enabledLanguages":ENABLED,
      "reserveLanguages":RESERVE,"defaultLanguage":"en","fallbackLanguage":"en",
      "languageChangePolicy":"select, apply, save and restart PMM; no live switch",
      "spanishCompatibilityExtraKeys":58,"latestOwnerTestedLanguages":["vi","uk","cs","ga"],
      "fullWindowsAcceptance":False,
    }
    build_path.write_text(OUTPUT_BUILD+"\n",encoding="utf-8",newline="\n")
    write_json(manifest_path,manifest)
    package_files,checksum_rows=regenerate_checksums(package)
    return {"schema":"PMM_I03_PREPARATION_V1","buildId":OUTPUT_BUILD,"version":version,
      "targetBaseCommit":TARGET_BASE,"donorCommit":DONOR_COMMIT,"packageFiles":package_files,
      "checksumRows":checksum_rows,"executableSha256":actual_binaries}

def main()->int:
    parser=argparse.ArgumentParser()
    parser.add_argument("--package",type=Path,default=Path(__file__).resolve().parents[4]/"PMM")
    args=parser.parse_args()
    print(json.dumps(prepare(args.package.resolve()),ensure_ascii=False,indent=2))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
