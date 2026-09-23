#!/usr/bin/env python3
"""Migrate distributed PMMRuntime.exe callers to the unified PMM.exe runtime role.

NF02B safety properties:
- dry-run by default;
- refuses --apply unless PMM/PMM.exe matches the accepted NF02A candidate hash;
- refuses --apply until the five distributed native routes already use PMM.exe runtime ...;
- expects exactly the 18 callsites inventoried for v1.5.0.2 and aborts on drift;
- retains PMM/Engine/PMMRuntime.exe for NF02C;
- preserves each edited file's UTF-8 BOM choice and newline bytes.
"""
from __future__ import annotations

import argparse
import codecs
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys

SCHEMA = "PMM_NF02B_RUNTIME_CALLSITE_MIGRATION_V1"
EXPECTED_TOTAL = 18

EXPECTED_COMMANDS = {
    "PMM/Engine/Runner/Operations/start.ps1": 2,
    "PMM/Engine/Runner/Operations/validate.ps1": 1,
    "PMM/Modules/AIIO/AIIO.PendingDataService.ps1": 1,
    "PMM/Modules/AIIO/AIIO.ps1": 1,
    "PMM/Modules/AIIO/AIIO.ResponseService.ps1": 2,
    "PMM/Modules/AIIO/AIIO.SessionService.ps1": 1,
    "PMM/Modules/Bootstrap/Setup-Dependencies.ps1": 1,
    "PMM/Modules/CKL/KnowledgeContributionService.ps1": 1,
    "PMM/Modules/FixLab/FixLabService.ps1": 2,
    "PMM/Modules/Library/LibraryService.ps1": 1,
    "PMM/Modules/Merge/MergeEngine.ps1": 1,
    "PMM/Modules/Saves/SaveService.ps1": 2,
    "PMM/Modules/Theme/ThemeEditorService.ps1": 2,
}

PATH_HELPER = "PMM/Modules/Shared/Paths.ps1"
DIRECT_RE = re.compile(
    r"& \$runtime (archive (?:create|extract)|dependencies ensure|ui|self-test)\b"
)
UNPREFIXED_RE = re.compile(
    r"& \$runtime (?:archive|dependencies|ui|self-test)\b"
)
LEGACY_PHYSICAL_RE = re.compile(r"Engine[\\/]PMMRuntime\.exe", re.IGNORECASE)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_utf8_preserve(path: Path) -> tuple[str, bool]:
    data = path.read_bytes()
    bom = data.startswith(codecs.BOM_UTF8)
    if bom:
        data = data[len(codecs.BOM_UTF8):]
    try:
        return data.decode("utf-8"), bom
    except UnicodeDecodeError as e:
        raise RuntimeError(f"{path}: expected UTF-8 PowerShell source: {e}") from e


def encode_utf8_preserve(text: str, bom: bool) -> bytes:
    payload = text.encode("utf-8")
    return (codecs.BOM_UTF8 + payload) if bom else payload


def replace_exact(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one source contract, found {count}")
    return text.replace(old, new, 1)


def transform_direct(text: str) -> tuple[str, int]:
    def repl(match: re.Match[str]) -> str:
        return "& $runtime runtime " + match.group(1)

    return DIRECT_RE.subn(repl, text)


def transform_file(rel: str, text: str) -> tuple[str, int]:
    if rel == PATH_HELPER:
        text = replace_exact(
            text,
            "function Get-PMMRuntimePath { Join-PMMPath 'Engine' 'PMMRuntime.exe' }",
            "function Get-PMMRuntimePath { Join-PMMPath 'App' 'PMM.exe' }",
            rel,
        )
        return text, 0

    if rel == "PMM/Modules/Bootstrap/Setup-Dependencies.ps1":
        text = replace_exact(
            text,
            "$Runtime=Join-Path $Root 'Engine\\PMMRuntime.exe'",
            "$Runtime=Join-Path $Root 'PMM.exe'",
            rel + " path",
        )
        text = replace_exact(
            text,
            "$argsList=@('dependencies','ensure')",
            "$argsList=@('runtime','dependencies','ensure')",
            rel + " args",
        )
        return text, 1

    if rel in {
        "PMM/Engine/Runner/Operations/start.ps1",
        "PMM/Engine/Runner/Operations/validate.ps1",
    }:
        text = replace_exact(
            text,
            "$runtime=Join-Path $Root 'Engine\\PMMRuntime.exe'",
            "$runtime=Join-Path $Root 'PMM.exe'",
            rel + " path",
        )

    if rel == "PMM/Modules/Library/LibraryService.ps1":
        text = replace_exact(
            text,
            "-Arguments @('archive','extract',$Path,$stage)",
            "-Arguments @('runtime','archive','extract',$Path,$stage)",
            rel + " cancelable archive args",
        )
        return text, 1

    return transform_direct(text)


def verify_routes_integrated(repo: Path) -> dict:
    path = repo / "PMM/Engine/Runner/routes.json"
    doc = json.loads(path.read_text(encoding="utf-8-sig"))
    if doc.get("schema") != "PMM_HOST_ROUTES_V1" or not isinstance(doc.get("routes"), dict):
        raise RuntimeError("unexpected PMM Host routes schema")
    expected = {
        "start": "start",
        "runtime-self-test": "self-test",
        "runtime-doctor": "doctor",
        "runtime-security": "security",
        "runtime-native-ui": "ui-native",
    }
    status = {}
    for name, command in expected.items():
        route = doc["routes"].get(name)
        if not isinstance(route, dict):
            raise RuntimeError(f"missing required native route: {name}")
        executable = str(route.get("executable", "")).replace("\\", "/")
        arguments = list(route.get("arguments") or [])
        ok = (
            str(route.get("kind", "")).lower() == "native"
            and executable.lower() == "pmm.exe"
            and arguments == ["runtime", command]
        )
        status[name] = ok
        if not ok:
            raise RuntimeError(
                f"NF02A package integration is not complete for route {name}: "
                f"executable={executable!r} arguments={arguments!r}"
            )
    return status


def verify_apply_gate(repo: Path, accepted_hash: str | None) -> dict:
    if not accepted_hash or not re.fullmatch(r"[0-9a-fA-F]{64}", accepted_hash):
        raise RuntimeError("--apply requires --accepted-candidate-sha256 with a 64-hex SHA-256")
    pmm = repo / "PMM/PMM.exe"
    legacy = repo / "PMM/Engine/PMMRuntime.exe"
    if not pmm.is_file():
        raise RuntimeError("PMM/PMM.exe is missing")
    if not legacy.is_file():
        raise RuntimeError("PMMRuntime.exe must still be retained during NF02B")
    actual = sha256(pmm)
    if actual.lower() != accepted_hash.lower():
        raise RuntimeError(
            "PMM/PMM.exe does not match the accepted NF02A candidate: "
            f"expected={accepted_hash.lower()} actual={actual.lower()}"
        )
    routes = verify_routes_integrated(repo)
    return {
        "acceptedCandidateSha256": accepted_hash.lower(),
        "integratedPMMExeSha256": actual.lower(),
        "pmmRuntimeRetained": True,
        "routes": routes,
    }


def atomic_write_preserve(path: Path, data: bytes) -> None:
    mode = stat.S_IMODE(path.stat().st_mode)
    tmp = path.with_name(path.name + ".nf02b.tmp")
    try:
        with tmp.open("wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=None, help="repository root; defaults from this script")
    ap.add_argument("--apply", action="store_true", help="write the migration; default is dry-run")
    ap.add_argument("--accepted-candidate-sha256", default=None)
    ap.add_argument("--report", type=Path, default=None)
    args = ap.parse_args()

    repo = args.root.resolve() if args.root else Path(__file__).resolve().parents[2]
    if not (repo / "PMM").is_dir():
        raise SystemExit(f"PMM package not found under repository root: {repo}")

    gate = {"mode": "DRY_RUN", "nf02aIntegrationRequiredForApply": True}
    if args.apply:
        gate = verify_apply_gate(repo, args.accepted_candidate_sha256)
        gate["mode"] = "APPLY"

    targets = list(EXPECTED_COMMANDS) + [PATH_HELPER]
    prepared: list[tuple[Path, bytes]] = []
    files_report = []
    total = 0

    for rel in targets:
        path = repo / rel
        if not path.is_file():
            raise RuntimeError(f"missing migration target: {rel}")
        original_bytes = path.read_bytes()
        text, bom = read_utf8_preserve(path)
        transformed, migrated = transform_file(rel, text)
        expected = EXPECTED_COMMANDS.get(rel, 0)
        if migrated != expected:
            raise RuntimeError(f"{rel}: expected {expected} command migrations, got {migrated}")
        if UNPREFIXED_RE.search(transformed):
            raise RuntimeError(f"{rel}: unprefixed PMM runtime invocation remains after transform")
        if LEGACY_PHYSICAL_RE.search(transformed):
            raise RuntimeError(f"{rel}: active Engine/PMMRuntime.exe path remains after transform")
        new_bytes = encode_utf8_preserve(transformed, bom)
        prepared.append((path, new_bytes))
        total += migrated
        files_report.append({
            "path": rel,
            "commandMigrations": migrated,
            "changed": new_bytes != original_bytes,
            "beforeSha256": hashlib.sha256(original_bytes).hexdigest(),
            "afterSha256": hashlib.sha256(new_bytes).hexdigest(),
            "utf8BomPreserved": bom,
        })

    if total != EXPECTED_TOTAL:
        raise RuntimeError(f"expected {EXPECTED_TOTAL} total command migrations, got {total}")

    changed = sum(1 for item in files_report if item["changed"])
    report = {
        "schema": SCHEMA,
        "classification": "NF02B_PREVIEW" if not args.apply else "NF02B_APPLIED",
        "repositoryRoot": str(repo),
        "expectedCommandMigrations": EXPECTED_TOTAL,
        "commandMigrations": total,
        "targetFiles": len(targets),
        "changedFiles": changed,
        "gate": gate,
        "files": files_report,
        "pmmRuntimeRemoved": False,
        "note": "NF02B migrates callers only. PMMRuntime.exe remains until NF02C zero-active-caller proof.",
    }

    if args.apply:
        for path, data in prepared:
            atomic_write_preserve(path, data)

    if args.report:
        report_path = args.report.resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"NF02B migration failed: {e}", file=sys.stderr)
        raise SystemExit(2)
