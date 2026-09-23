#!/usr/bin/env python3
"""Build the NF02A unified PMM candidate outside the repository.

This script is intentionally offline and never replaces PMM/PMM.exe.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys

GO_VERSION = "go1.23.2"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def source_inventory(src: Path) -> dict[str, str]:
    files: list[Path] = []
    for path in src.rglob("*"):
        if not path.is_file():
            continue
        if "__pycache__" in path.parts or path.suffix in {".pyc", ".pyo"}:
            continue
        files.append(path)
    return {
        path.relative_to(src).as_posix(): sha256(path)
        for path in sorted(files)
    }


def pe_metadata(path: Path) -> dict[str, int]:
    data = path.read_bytes()
    if len(data) < 0x100 or data[:2] != b"MZ":
        raise RuntimeError("candidate is not a valid DOS/PE image")
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    if pe_offset + 24 + 70 > len(data) or data[pe_offset:pe_offset + 4] != b"PE\0\0":
        raise RuntimeError("candidate is missing a valid PE signature")
    machine, sections = struct.unpack_from("<HH", data, pe_offset + 4)
    optional = pe_offset + 24
    magic = struct.unpack_from("<H", data, optional)[0]
    subsystem = struct.unpack_from("<H", data, optional + 68)[0]
    return {
        "machine": machine,
        "sections": sections,
        "optionalHeaderMagic": magic,
        "subsystem": subsystem,
    }


def run(argv, cwd: Path, env):
    p = subprocess.run(
        [str(x) for x in argv],
        cwd=cwd,
        env=env,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=180,
    )
    return {
        "argv": [str(x) for x in argv],
        "exitCode": p.returncode,
        "stdout": p.stdout,
        "stderr": p.stderr,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    src = Path(__file__).resolve().parent
    repo = src.parents[2]
    out = args.out.resolve()

    if out.exists() or out == repo or repo in out.parents:
        raise SystemExit("--out must be a new directory outside the repository")

    go = shutil.which("go")
    if not go:
        raise SystemExit("Go 1.23.2 must already be installed")

    version = subprocess.check_output([go, "version"], text=True, encoding="utf-8").strip()
    if GO_VERSION not in version:
        raise SystemExit(f"expected {GO_VERSION}, got: {version}")

    out.mkdir(parents=True)
    env = dict(
        os.environ,
        GOTOOLCHAIN="local",
        GOPROXY="off",
        GOSUMDB="off",
        GOWORK="off",
        GOENV="off",
        GOFLAGS="",
        CGO_ENABLED="0",
        GOEXPERIMENT="",
    )

    commands = []

    # Cross-platform logic can run on the current host.
    for pkg in (
        "./internal/dispatch",
        "./internal/runtime",
        "./internal/supervision",
        "./internal/uibridge",
    ):
        result = run([go, "test", pkg], src, env)
        commands.append(result)
        if result["exitCode"] != 0:
            (out / "FAILED.json").write_text(json.dumps({"commands": commands}, indent=2) + "\n", encoding="utf-8")
            return result["exitCode"]

    # Cross-compile every package test set for Windows so Windows-only files are
    # at least compiled even when this build runs on Linux.
    winenv = dict(env, GOOS="windows", GOARCH="amd64")
    windows_test_bins = {}
    for pkg in (
        "dispatch",
        "host",
        "runtime",
        "supervision",
        "uibridge",
    ):
        test_bin = out / f"{pkg}.test.exe"
        result = run([go, "test", "-c", "-o", test_bin, f"./internal/{pkg}"], src, winenv)
        commands.append(result)
        if result["exitCode"] != 0:
            (out / "FAILED.json").write_text(json.dumps({"commands": commands}, indent=2) + "\n", encoding="utf-8")
            return result["exitCode"]
        windows_test_bins[pkg] = {
            "file": test_bin.name,
            "sha256": sha256(test_bin),
            "sizeBytes": test_bin.stat().st_size,
        }

    candidate = out / "PMMUnified-candidate.exe"
    result = run([
        go, "build",
        "-trimpath",
        "-buildvcs=false",
        "-ldflags=-s -w -H=windowsgui",
        "-o", candidate,
        "./cmd/pmm",
    ], src, winenv)
    commands.append(result)
    if result["exitCode"] != 0:
        (out / "FAILED.json").write_text(json.dumps({"commands": commands}, indent=2) + "\n", encoding="utf-8")
        return result["exitCode"]

    pe = pe_metadata(candidate)
    if pe["machine"] != 0x8664 or pe["optionalHeaderMagic"] != 0x20B or pe["subsystem"] != 2:
        raise RuntimeError(f"unexpected Windows candidate PE contract: {pe}")

    report = {
        "schema": "PMM_NF02A_UNIFIED_BUILD_V2",
        "classification": "CANDIDATE_NOT_PACKAGED",
        "goVersion": GO_VERSION,
        "target": "windows/amd64",
        "sourceSha256": source_inventory(src),
        "candidate": candidate.name,
        "candidateSha256": sha256(candidate),
        "candidateSizeBytes": candidate.stat().st_size,
        "candidatePE": pe,
        "windowsTestBinaries": windows_test_bins,
        "commands": commands,
        "packagedBinaryReplaced": False,
        "pmmRuntimeRemoved": False,
        "fixLabMerged": False,
        "windowsExecuted": False,
        "note": "NF02A candidate only. Copy beside a complete PMM package for Windows acceptance; do not replace the release binary until acceptance passes.",
    }
    (out / "build-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (out / "COMPLETE.txt").write_text("NF02A unified candidate built outside repository; not installed.\n", encoding="utf-8")
    print(json.dumps({k: report[k] for k in ("candidate", "candidateSha256", "candidateSizeBytes")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
