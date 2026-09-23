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
import subprocess
import sys

GO_VERSION = "go1.23.2"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


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

    # Compile Windows-only Host tests without executing them on a non-Windows host.
    winenv = dict(env, GOOS="windows", GOARCH="amd64")
    host_test = out / "host.test.exe"
    result = run([go, "test", "-c", "-o", host_test, "./internal/host"], src, winenv)
    commands.append(result)
    if result["exitCode"] != 0:
        (out / "FAILED.json").write_text(json.dumps({"commands": commands}, indent=2) + "\n", encoding="utf-8")
        return result["exitCode"]

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

    report = {
        "schema": "PMM_NF02A_UNIFIED_BUILD_V1",
        "classification": "CANDIDATE_NOT_PACKAGED",
        "goVersion": GO_VERSION,
        "target": "windows/amd64",
        "candidate": candidate.name,
        "candidateSha256": sha256(candidate),
        "candidateSizeBytes": candidate.stat().st_size,
        "hostTestBinarySha256": sha256(host_test),
        "commands": commands,
        "packagedBinaryReplaced": False,
        "pmMRuntimeRemoved": False,
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
