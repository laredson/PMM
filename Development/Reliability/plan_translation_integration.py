#!/usr/bin/env python3
"""Produce a read-only integration inventory; never fetch, merge or write files."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


class PlanningError(RuntimeError):
    """An integration inventory could not be produced safely."""


def git(repo: Path, *args: str) -> str:
    env = dict(os.environ, GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0")
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), *args],
            capture_output=True, text=True, encoding="utf-8", errors="strict",
            timeout=60, check=False, env=env,
        )
    except (OSError, subprocess.TimeoutExpired, UnicodeError) as exc:
        raise PlanningError(f"Cannot read Git repository: {exc}") from exc
    if result.returncode != 0:
        raise PlanningError(result.stderr.strip() or "Git read failed.")
    return result.stdout


def resolve(repo: Path, ref: str) -> str:
    return git(repo, "rev-parse", "--verify", "--end-of-options", ref + "^{commit}").strip()


def require_ancestor(repo: Path, base: str, tip: str) -> None:
    try:
        git(repo, "merge-base", "--is-ancestor", base, tip)
    except PlanningError as exc:
        raise PlanningError(
            f"Cannot confirm baseline {base} is an ancestor of {tip}. "
            "Check the selected refs and shallow-history limits; fetch history manually if needed."
        ) from exc


def changes(repo: Path, base: str, tip: str) -> dict[str, str]:
    output = git(
        repo, "diff", "--name-status", "-z", "--no-renames", "--no-ext-diff",
        "--no-textconv", base, tip, "--",
    )
    if not output:
        return {}
    fields = output.split("\0")
    if fields[-1] == "":
        fields.pop()
    if len(fields) % 2:
        raise PlanningError("Unexpected Git name/status output; no merge was attempted.")
    return {fields[i + 1]: fields[i] for i in range(0, len(fields), 2)}


def classify(path: str) -> str:
    if path.startswith("PMM/Resources/Localization/"):
        return "translation_catalogs"
    if path.startswith("Development/Localization/"):
        return "translation_tools_and_checks"
    if path.startswith(("PMM/Modules/Shared/Localization", "PMM/Resources/UI/MainWindow", "PMM/Resources/UI/strings.")):
        return "shared_localization_runtime_or_layout"
    if path.startswith("PMM/Resources/Metadata/"):
        return "release_metadata_reconcile_not_overwrite"
    if path == "PMM/PMM.exe" or path.startswith(("PMM/Engine/", "Development/Source/", "Development/Scripts/build/", ".github/")):
        return "runtime_binary_source_or_build_review"
    if path.startswith("PMM/Modules/"):
        return "shared_application_logic"
    if path.startswith(("Development/AI/", "Development/Reliability/")) or path in ("AGENTS.md", "RELIABILITY.md"):
        return "shared_handoff_or_branch_control"
    return "manual_review"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--translations", default="origin/v1.5.0.0-PMM-translated", help="Already-fetched local ref or full commit SHA")
    parser.add_argument("--target", default="HEAD", help="Local reliability ref or commit SHA")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    try:
        baseline_path = Path(__file__).with_name("BASELINE.json")
        baseline = json.loads(baseline_path.read_text(encoding="utf-8-sig"))
        base = resolve(repo, baseline["sourceCommit"])
        source = resolve(repo, args.translations)
        target = resolve(repo, args.target)
        require_ancestor(repo, base, source)
        require_ancestor(repo, base, target)
        donor_changes = changes(repo, base, source)
        target_changes = changes(repo, base, target)
        since_common = git(repo, "merge-base", "--all", target, source).splitlines()
        report = {
            "schema": "PMM_TRANSLATION_INTEGRATION_INVENTORY_V1",
            "targetVersion": baseline["targetVersion"],
            "baselineCommit": base,
            "translationCommit": source,
            "targetCommit": target,
            "currentCommonAncestors": since_common,
            "automaticMergeApproved": False,
            "filesWrittenByTool": False,
            "scope": "Cumulative path inventory since the original branch baseline, not a conflict simulation or test result.",
            "limitations": [
                "Renames appear as delete/add pairs and require manual review.",
                "Disjoint paths can still interact semantically.",
                "After an earlier integration, cumulative entries may already be merged; inspect current common ancestors.",
                "No network fetch, checkout, merge, build, tests or antivirus scan is performed.",
            ],
            "translationChanges": [
                {"path": path, "translationStatus": status,
                 "targetStatusSinceBaseline": target_changes.get(path),
                 "bothBranchesChangedPath": path in target_changes, "reviewGroup": classify(path)}
                for path, status in sorted(donor_changes.items())
            ],
            "targetOnlyChanges": [
                {"path": path, "status": status, "reviewGroup": classify(path)}
                for path, status in sorted(target_changes.items()) if path not in donor_changes
            ],
        }
        print(json.dumps(report, indent=2, ensure_ascii=True))
        return 0
    except (PlanningError, OSError, ValueError, KeyError, TypeError) as exc:
        print(f"Integration inventory failed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
