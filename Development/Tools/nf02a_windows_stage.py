#!/usr/bin/env python3
"""Create a disposable NF02A Windows acceptance package.

This never modifies PMM/ in the repository. It replaces PMM.exe only in a new
staging copy and rewrites native Host routes to PMM.exe runtime <command>.
PMMRuntime.exe is deliberately retained until NF02B callsite migration proves
that no external module still requires it.
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


BUILD_SCHEMAS = {"PMM_NF02A_UNIFIED_BUILD_V1", "PMM_NF02A_UNIFIED_BUILD_V2"}
STAGE_SCHEMA = "PMM_NF02A_WINDOWS_STAGE_V1"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def run_capture(argv: list[str], cwd: Path, timeout: int = 120) -> dict:
    p = subprocess.run(
        argv,
        cwd=cwd,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
    )
    return {
        "argv": argv,
        "exitCode": p.returncode,
        "stdout": p.stdout,
        "stderr": p.stderr,
    }


def rewrite_runtime_routes(routes_path: Path) -> list[dict]:
    doc = json.loads(routes_path.read_text(encoding="utf-8-sig"))
    if doc.get("schema") != "PMM_HOST_ROUTES_V1" or not isinstance(doc.get("routes"), dict):
        raise RuntimeError("unexpected routes.json schema")
    changes = []
    for name, route in doc["routes"].items():
        if not isinstance(route, dict) or str(route.get("kind", "")).lower() != "native":
            continue
        executable = str(route.get("executable", "")).replace("\\", "/").lower()
        if executable != "engine/pmmruntime.exe":
            continue
        old_args = list(route.get("arguments") or [])
        route["executable"] = "PMM.exe"
        route["arguments"] = ["runtime", *old_args]
        changes.append({
            "route": name,
            "fromExecutable": "Engine/PMMRuntime.exe",
            "toExecutable": "PMM.exe",
            "fromArguments": old_args,
            "toArguments": route["arguments"],
        })
    if not changes:
        raise RuntimeError("no PMMRuntime native routes found to stage")
    routes_path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    return changes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--candidate", required=True, type=Path)
    ap.add_argument("--build-report", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--run-diagnostics", action="store_true")
    args = ap.parse_args()

    script = Path(__file__).resolve()
    repo = script.parents[2]
    package = repo / "PMM"
    candidate = args.candidate.resolve()
    report_path = args.build_report.resolve()
    out = args.out.resolve()

    if not package.is_dir():
        raise SystemExit("repository PMM/ package directory not found")
    if not candidate.is_file() or not report_path.is_file():
        raise SystemExit("candidate/build-report not found")
    if out.exists() or out == repo or repo in out.parents:
        raise SystemExit("--out must be a new directory outside the repository")

    report = json.loads(report_path.read_text(encoding="utf-8"))
    if report.get("schema") not in BUILD_SCHEMAS:
        raise SystemExit("unsupported NF02A build-report schema")
    candidate_hash = sha256(candidate)
    if candidate_hash.lower() != str(report.get("candidateSha256", "")).lower():
        raise SystemExit("candidate SHA-256 does not match build-report")

    stage = out / "PMM"
    shutil.copytree(package, stage, copy_function=shutil.copy2)

    current_exe = stage / "PMM.exe"
    previous_hash = sha256(current_exe)
    shutil.copy2(candidate, current_exe)

    route_changes = rewrite_runtime_routes(stage / "Engine" / "Runner" / "routes.json")

    manifest = {
        "schema": STAGE_SCHEMA,
        "classification": "DISPOSABLE_WINDOWS_ACCEPTANCE_STAGE",
        "candidateSha256": candidate_hash,
        "candidateSizeBytes": current_exe.stat().st_size,
        "previousPMMExeSha256": previous_hash,
        "stagedPMMExeSha256": sha256(current_exe),
        "pmmRuntimeRetained": (stage / "Engine" / "PMMRuntime.exe").is_file(),
        "fixLabRetained": (stage / "Engine" / "PMMFixLab.exe").is_file(),
        "runtimeRouteChanges": route_changes,
        "repositoryPackageModified": False,
        "windowsDiagnostics": "NOT_RUN",
    }

    diagnostics = []
    if args.run_diagnostics:
        if os.name != "nt":
            raise SystemExit("--run-diagnostics requires Windows")
        commands = [
            [str(current_exe), "doctor", "--json"],
            [str(current_exe), "security", "status", "--json"],
            [str(current_exe), "runtime", "self-test"],
            [str(current_exe), "runtime", "doctor"],
            [str(current_exe), "runtime", "security"],
        ]
        for i, cmd in enumerate(commands, start=1):
            result = run_capture(cmd, stage)
            diagnostics.append(result)
            (out / f"diagnostic-{i:02d}.json").write_text(
                json.dumps(result, indent=2) + "\n", encoding="utf-8"
            )
        manifest["windowsDiagnostics"] = "PASS" if all(x["exitCode"] == 0 for x in diagnostics) else "FAIL"
        manifest["diagnosticExitCodes"] = [x["exitCode"] for x in diagnostics]

    (out / "NF02A_STAGING.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (out / "RUN_MANUAL_WINDOWS_GATE.txt").write_text(
        "NF02A manual gate\n"
        "1. Run PMM.exe normally from the staged PMM folder.\n"
        "2. Verify splash -> WPF foreground handoff.\n"
        "3. Close the UI normally and inspect Workspace/State/HostSessions.\n"
        "4. In a disposable copy, induce a Runtime-child startup failure and verify Host survives and records it.\n"
        "5. Verify no unexpected console window.\n"
        "6. Do not delete PMMRuntime.exe yet; NF02B must migrate remaining direct callsites first.\n",
        encoding="utf-8",
    )

    print(json.dumps({
        "stage": str(stage),
        "candidateSha256": candidate_hash,
        "routesRewritten": len(route_changes),
        "diagnostics": manifest["windowsDiagnostics"],
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
