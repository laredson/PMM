#!/usr/bin/env python3
"""Dependency-free structural regression for RC23 collection-shape guards."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "PMM"


def read(relative: str) -> str:
    return (APP / relative).read_text(encoding="utf-8-sig")


library = read("Modules/Library/LibraryService.ps1")
merge = read("Modules/Merge/MergeEngine.ps1")
bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")

checks = {
    "knowledge-authorized assets initialized": "$knowledgeAuthorizedAssets=@()" in library,
    "knowledge-authorized branch array": "$knowledgeAuthorizedAssets=@($manifest.Assets|Where-Object" in library,
    "known recipe subset remains an array": "$knownRecipeAssets=@($knowledgeAuthorizedAssets|Where-Object" in merge,
    "stored decisions initialized": "$storedRows=@()" in library,
    "fast decisions initialized": "$decisions=@()" in merge,
    "fast assets initialized": "$patchAssets=@()" in merge,
    "exact decisions initialized": "$patchDecisions=@()" in merge,
    "fixlab rows initialized": "$pakRows=@()" in bootstrap,
    "ignore rows array": "$ignoreRows=@($ignoreDoc)" in bootstrap,
}
missing = [name for name, ok in checks.items() if not ok]
if missing:
    raise SystemExit("Missing RC23 guard(s): " + ", ".join(missing))

vulnerable = re.compile(
    r"\$(?:knowledgeAuthorizedAssets|knownRecipeAssets|storedRows|decisions|patchAssets|patchDecisions|pakRows|ignoreRows)"
    r"\s*=\s*if\s*\(",
    re.IGNORECASE,
)
for name, text in (("LibraryService", library), ("MergeEngine", merge), ("Bootstrap", bootstrap)):
    match = vulnerable.search(text)
    if match:
        raise SystemExit(f"Conditional pipeline can unwrap a guarded collection in {name}: {match.group(0)}")

manifest = json.loads(read("Resources/Metadata/RELEASE_MANIFEST.json"))
expected = "PMM-v1.3.0-RC30-LEAN-AI-VALIDATION-FLOW"
if manifest.get("buildId") != expected:
    raise SystemExit("Unexpected current build ID while checking the preserved RC23 guard")
if manifest.get("releaseCandidate") != "rc30-lean-ai-validation-flow":
    raise SystemExit("Unexpected current release-candidate ID while checking the preserved RC23 guard")
if (APP / "Resources/Metadata/BUILD_ID.txt").read_text(encoding="utf-8-sig").strip() != expected:
    raise SystemExit("BUILD_ID.txt does not match the current manifest")

print("RC23_SINGLETON_GUARD_MODEL_OK")
