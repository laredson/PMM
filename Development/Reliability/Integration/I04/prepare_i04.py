#!/usr/bin/env python3
"""Finalize PMM package metadata for the I04 Nexus update integration."""
from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path
from typing import Any

INPUT_BUILD = "PMM-v1.5.0.1-reliability-i03"
OUTPUT_BUILD = "PMM-v1.5.0.1-reliability-i04-nexus-updates"
BINARIES = {
    "PMM.exe": "a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c",
    "Engine/PMMRuntime.exe": "b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f",
    "Engine/PMMFixLab.exe": "8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe",
}

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def load_json(path: Path) -> dict[str, Any]:
    value=json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value,dict): raise ValueError(f"{path}: JSON root must be an object")
    return value

def write_json(path: Path,value: dict[str,Any]) -> None:
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+"\n",encoding="utf-8",newline="\n")

def regenerate_checksums(package: Path) -> tuple[int,int,str]:
    sums=package/"Resources"/"Metadata"/"SHA256SUMS.txt"
    files=sorted((p for p in package.rglob("*") if p.is_file() and p!=sums and "Workspace" not in p.relative_to(package).parts),key=lambda p:p.relative_to(package).as_posix())
    sums.write_text("".join(f"{sha256(p)}  {p.relative_to(package).as_posix()}\n" for p in files),encoding="utf-8",newline="\n")
    return len(files)+1,len(files),sha256(sums)

def prepare(package: Path) -> dict[str,Any]:
    metadata=package/"Resources"/"Metadata";build_path=metadata/"BUILD_ID.txt";manifest_path=metadata/"RELEASE_MANIFEST.json"
    version=(metadata/"VERSION.txt").read_text(encoding="utf-8-sig").strip()
    if version!="1.5.0.1": raise ValueError(f"Unexpected product version: {version!r}")
    current=build_path.read_text(encoding="utf-8-sig").strip()
    if current not in (INPUT_BUILD,OUTPUT_BUILD): raise ValueError(f"Unexpected input build: {current!r}")
    actual={name:sha256(package/name) for name in BINARIES};bad={name:{"expected":BINARIES[name],"actual":digest} for name,digest in actual.items() if digest!=BINARIES[name]}
    if bad: raise ValueError(f"Frozen executable hash mismatch: {bad}")
    manifest=load_json(manifest_path)
    manifest["releaseCandidate"]="1.5.0.1-reliability-i04-nexus-updates";manifest["buildId"]=OUTPUT_BUILD;manifest["release"]="PMM v1.5.0.1 I04 - safe Nexus updates"
    manifest["releaseValidation"]["programRegression"]="PASS static/PS5.1 update, rollback, recovery, worker, WPF EN/ES and 23-language catalog regressions; live Nexus account and Palworld runtime remain NOT_VERIFIED"
    for operation in ("UpdateCheck","UpdateApply","UpdateRestore"):
        if operation not in manifest["backgroundOperations"]: manifest["backgroundOperations"].append(operation)
    manifest["deepAnalysis"]["checkUpdatesByDefault"]=False;manifest["deepAnalysis"]["updateSource"]="Consumes the current PMM_UPDATE_PLAN_V1; it does not repeat provider network queries."
    manifest["architecture133"]["ui"]="Five top-level areas; Mods & Merge owns seven ordered workflow subtabs."
    manifest["architecture133"]["modsMergeSubtabs"]=["Library & Import","Updates","Fix Lab","Analyze & Resolve","Deep Analysis","Build & Deploy","AI Assistant"]
    manifest["reliabilityPreparation"].update({"session":"I04","state":"safe-nexus-update-workflow-prepared","nativeBinariesChanged":False,"publicReleaseCreated":False})
    manifest["nexusUpdates"]={
      "schema":"PMM_NEXUS_UPDATE_INTEGRATION_V1","id":"I04","apiClient":"isolated official Nexus API adapter; v1 endpoints retained for MD5, successor metadata and download links",
      "credentials":"personal development API key encrypted with Windows DPAPI under Workspace/State; SSO remains disabled until PMM registration",
      "accountModes":["Premium direct download","Free per-file Nexus web confirmation via validated nxm:// callback"],
      "originSchema":"PMM_MOD_ORIGIN_V2 with V1 read compatibility","planSchema":"PMM_UPDATE_PLAN_V1","transactionSchema":"PMM_MOD_UPDATE_TRANSACTION_V1","nxmSchema":"PMM_NXM_REQUEST_V1",
      "variantPolicy":"Only a unique exact Nexus FileId successor chain is eligible; forks, cycles and name similarity are blocked.",
      "automaticPackagePolicy":"Exactly one safe PAK; unchanged installed hash; current plan/fingerprint; sufficient Deep Analysis coverage; no new blocking findings, pending removals or stale deployed compatibility patch.",
      "archive":"Workspace/ModUpdates/Archive; indefinite retention until explicit user deletion; restore supported.",
      "deployment":"Uses the existing PMM deployment transaction for managed ~mods synchronization and keeps a separate update rollback record.",
      "batchPlan":"After each verified commit, PMM advances the saved fingerprint only to the exact resulting library; remaining cached candidates are reanalyzed against that library.",
      "gameRunning":"Download and analysis may finish while Palworld runs; commit is persisted locally and resumes automatically after the game exits.",
      "protocolRegistration":"Explicit opt-in; previous nxm handler preserved and restorable.","liveNexusAccountValidation":"NOT_VERIFIED","palworldRuntimeValidation":"NOT_VERIFIED"
    }
    build_path.write_text(OUTPUT_BUILD+"\n",encoding="utf-8",newline="\n");write_json(manifest_path,manifest)
    package_files,rows,inventory=regenerate_checksums(package)
    return {"schema":"PMM_I04_PREPARATION_V1","buildId":OUTPUT_BUILD,"version":version,"packageFiles":package_files,"checksumRows":rows,"checksumInventorySha256":inventory,"executableSha256":actual}

def main() -> int:
    parser=argparse.ArgumentParser();parser.add_argument("--package",type=Path,default=Path(__file__).resolve().parents[4]/"PMM");args=parser.parse_args();print(json.dumps(prepare(args.package.resolve()),indent=2));return 0
if __name__=="__main__": raise SystemExit(main())