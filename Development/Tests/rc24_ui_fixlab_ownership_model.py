#!/usr/bin/env python3
"""Cross-platform regression for RC24 UI and merge-ownership boundaries."""

from __future__ import annotations

import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "PMM"


def read(relative: str) -> str:
    return (APP / relative).read_text(encoding="utf-8-sig")


def function_body(text: str, name: str) -> str:
    match = re.search(
        rf"(?im)^function\s+(?:script:)?{re.escape(name)}\b",
        text,
    )
    if not match:
        raise SystemExit(f"Function not found: {name}")
    following = re.search(r"(?im)^function\s+(?:script:)?[A-Za-z0-9_-]+\b", text[match.end() :])
    end = match.end() + following.start() if following else len(text)
    return text[match.start() : end]


bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
fixlab = read("Modules/FixLab/FixLabService.ps1")
library = read("Modules/Library/LibraryService.ps1")
merge_engine = read("Modules/Merge/MergeEngine.ps1")

deploy_fix = function_body(fixlab, "Deploy-PMMFixLabBuiltOutput")
restore_fix = function_body(fixlab, "Restore-PMMFixLabCase")
toggle_mod = function_body(library, "Set-PMMLibraryModEnabled")
delete_mod = function_body(library, "Remove-PMMLibraryMod")

reserved_merge = "zzzzzzzzzz_PMM_Merge_"
for label, body in (
    ("Deploy Fix", deploy_fix),
    ("Restore Fix", restore_fix),
    ("Enable/disable source mod", toggle_mod),
    ("Delete source mod", delete_mod),
):
    if reserved_merge.lower() in body.lower():
        raise SystemExit(f"{label} still addresses the reserved merge namespace")

ownership_markers = {
    "fix deploy ownership comment": "belongs exclusively to Mods & Merge" in deploy_fix,
    "fix restore preservation log": "deployed compatibility merge preserved" in restore_fix,
    "delete preserves patch state": "$state.Patch=$null" not in delete_mod,
    "delete preserves selection": "Set-PMMSelectedPatchName ''" not in delete_mod,
    "delete preservation log": "deployedMergePreserved=true" in delete_mod,
    "no legacy non-UI undeploy entry point": not re.search(
        r"(?im)^function\s+Restore-PMMDeployment\b", merge_engine
    ),
    "deferred refresh queue": "function Queue-PMMFixLabUiRefresh" in bootstrap,
    "context-idle refresh": "DispatcherPriority]::ContextIdle" in bootstrap,
    "one-minute cache": "$Script:FixLabRefreshIntervalSeconds=60" in bootstrap,
    "single discovery snapshot": "Get-PMMFixLabDiscoveryCandidates -IncludeBackups -BackupRows $backups" in bootstrap,
}
missing = [name for name, present in ownership_markers.items() if not present]
if missing:
    raise SystemExit("Missing RC24 invariant(s): " + ", ".join(missing))

singleton_guard = "@(@(Get-LibraryMods)+@(Get-PMMDisabledMods))"
if fixlab.count(singleton_guard) < 2:
    raise SystemExit("Fix Lab library/disabled-mod union can unwrap a singleton PSObject")

xaml_namespace = "http://schemas.microsoft.com/winfx/2006/xaml"
x_name = f"{{{xaml_namespace}}}Name"
reference_names: set[str] | None = None
for filename in ("MainWindow.xaml", "MainWindow.en.xaml", "MainWindow.es.xaml"):
    text = read(f"Resources/UI/{filename}")
    if text.count('<ColumnDefinition Width="*"/>') < 2:
        raise SystemExit(f"Equal responsive header columns missing in {filename}")
    if 'x:Name="GrdHeaderActions" Grid.Column="1" MinWidth="0" HorizontalAlignment="Stretch"' not in text:
        raise SystemExit(f"Responsive header controls missing in {filename}")
    document = ET.fromstring(text)
    names = [value for node in document.iter() if (value := node.attrib.get(x_name))]
    if len(names) != len(set(names)):
        raise SystemExit(f"Duplicate x:Name in {filename}")
    if names.count("BtnFixLabRefreshDashboard") != 1:
        raise SystemExit(f"Fix Lab Refresh button must exist exactly once in {filename}")
    current = set(names)
    if reference_names is None:
        reference_names = current
    elif current != reference_names:
        raise SystemExit(f"Localized XAML control parity mismatch in {filename}")

manifest = json.loads(read("Resources/Metadata/RELEASE_MANIFEST.json"))
expected = "PMM-v1.3.1-MOD-CREATION-PREVIEW"
if manifest.get("buildId") != expected:
    raise SystemExit("Unexpected current build ID while checking RC24 invariants")
if manifest.get("releaseCandidate") != "1.3.1-mod-creation-preview":
    raise SystemExit("Unexpected current release-candidate ID while checking RC24 invariants")
if (APP / "Resources/Metadata/BUILD_ID.txt").read_text(encoding="utf-8-sig").strip() != expected:
    raise SystemExit("BUILD_ID.txt does not match RC24 manifest")

print("RC24_UI_FIXLAB_OWNERSHIP_MODEL_OK")
