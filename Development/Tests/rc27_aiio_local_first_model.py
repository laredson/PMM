#!/usr/bin/env python3
"""Cross-platform structural/model validation for PMM 1.3.0 RC27.

This proves release-owned contracts without claiming to execute Windows
PowerShell 5.1, WPF, repak, PMMCore or Palworld. Those remain the separate
acceptance gate in PMM/Documentation/TEST_THIS_BUILD_RC27.txt.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "PMM"
EXPECTED_BUILD = "PMM-v1.3.1-MOD-CREATION-PREVIEW"


def read(relative: str) -> str:
    return (APP / relative).read_text(encoding="utf-8-sig")


def load(relative: str) -> dict:
    return json.loads(read(relative))


def function_body(text: str, name: str) -> str:
    match = re.search(rf"(?im)^function\s+(?:script:)?{re.escape(name)}\b", text)
    assert match, f"Function not found: {name}"
    following = re.search(r"(?im)^function\s+(?:script:)?[A-Za-z0-9_-]+\b", text[match.end() :])
    end = match.end() + following.start() if following else len(text)
    return text[match.start() : end]


def validate_inherited_rc26_contracts() -> None:
    path = Path(__file__).with_name("rc26_official_themes_progress_compatibility_model.py")
    spec = importlib.util.spec_from_file_location("pmm_rc26_regression", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    rc25_path = Path(__file__).with_name("rc25_release_model.py")
    rc25_spec = importlib.util.spec_from_file_location("pmm_rc25_regression_rc27", rc25_path)
    assert rc25_spec and rc25_spec.loader
    rc25 = importlib.util.module_from_spec(rc25_spec)
    sys.modules[rc25_spec.name] = rc25
    rc25_spec.loader.exec_module(rc25)
    rc25.validate_themes()
    rc25.validate_gura_preflight()
    rc25.validate_progress_model()
    module.validate_exact_compatibility_rule()
    module.validate_official_and_user_theme_separation()
    module.validate_immediate_completion_progress()


def validate_identity_and_package_boundary() -> None:
    manifest = load("Resources/Metadata/RELEASE_MANIFEST.json")
    assert manifest["product"] == "Palworld Manager Merger"
    assert manifest["creator"] == "laredson"
    assert manifest["buildId"] == EXPECTED_BUILD
    assert manifest["releaseCandidate"] == "1.3.1-mod-creation-preview"
    assert manifest["bundledThemeCount"] == 11
    assert manifest["officialThemeChoiceCount"] == 13
    assert manifest["aiioTransport"] == "manual local ZIP only"
    assert manifest["aiioRemoteUploadEnabled"] is False
    assert manifest["aiioProviderLoginEnabled"] is False
    assert manifest["aiioReturnedCodeExecutionEnabled"] is False
    assert "AIIOArtifactRefresh" in manifest["backgroundOperations"]
    assert read("Resources/Metadata/BUILD_ID.txt").strip() == EXPECTED_BUILD
    assert not (APP / "Workspace").exists()
    assert not list(APP.rglob("*.pak"))
    assert not [p for p in APP.rglob("*") if p.is_file() and p.name.lower().startswith("oo2core")]


def validate_localized_ui_and_header() -> None:
    namespace = "http://schemas.microsoft.com/winfx/2006/xaml"
    x_name = f"{{{namespace}}}Name"
    expected = None
    required = {
        "TabAIHelp", "AIHelpTabs", "LstAIIOSessions", "LstAIIOCandidates",
        "PnlThemeOptions", "PnlUserThemeOptions", "PnlThemeEditorRows",
        "BtnThemeEditorCreateAI", "BtnThemeEditorImportAI", "BtnAIHelpCleanup",
        "BtnAIIOOpenHandoff",
    }
    for filename in ("MainWindow.xaml", "MainWindow.en.xaml", "MainWindow.es.xaml"):
        text = read(f"Resources/UI/{filename}")
        root = ET.fromstring(text)
        names = [value for node in root.iter() if (value := node.attrib.get(x_name))]
        assert len(names) == len(set(names)), filename
        current = set(names)
        assert required.issubset(current), filename
        assert root.attrib["MinWidth"] == "900" and root.attrib["MinHeight"] == "600"
        assert text.count('<ColumnDefinition Width="*"/>') >= 2
        assert 'Width="148" Height="148"' in text
        assert 'FontSize="34"' in text
        assert 'x:Name="BtnDetectGame" Grid.Row="0" HorizontalAlignment="Stretch" MinWidth="0"' in text
        assert "Deploy Fix" not in text
        expected = current if expected is None else expected
        assert current == expected, filename


def validate_theme_architecture() -> None:
    theme_root = APP / "Resources" / "Themes"
    bundled = load("Resources/Themes/BUNDLED_THEME_MANIFEST.json")
    official = load("Resources/Themes/OFFICIAL_THEME_MANIFEST.json")
    assert bundled["themeCount"] == official["officialThemeCount"] == 11
    assert {row["id"] for row in bundled["themes"]} == {row["id"] for row in official["themes"]}
    for row in bundled["themes"]:
        path = theme_root / row["file"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == row["sha256"]
    for row in official["themes"]:
        path = APP / row["path"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == row["sha256"]
    for row in official["documents"]:
        path = APP / row["path"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == row["sha256"]

    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    service = read("Modules/Theme/ThemeService.ps1")
    editor = read("Modules/Theme/ThemeEditorService.ps1")
    for marker in (
        "Get-PMMBundledThemeFiles", "Bundled theme hash mismatch",
        "$Script:PnlThemeOptions.Children.Clear();$Script:PnlUserThemeOptions.Children.Clear()",
        "$Script:PnlUserThemeOptions.Children.Add($rb)", "already bundled",
        "official reserved id and cannot be replaced",
    ):
        assert marker in bootstrap + service, marker
    assert "function Get-PMMThemeEditorFields" in editor
    assert "function Set-PMMThemeDraftImage" in editor
    assert "function Import-PMMThemeAIResponse" in editor
    assert "PMM_COLOR_SCHEME_V2" in editor and "PMM_THEME_PACK_V1" in editor
    assert "external paths and URLs are forbidden" in read("Resources/UI/MainWindow.xaml")
    assert "$upload.Content=L 'Upload image' 'Subir imagen'" in bootstrap

    palette_keys = set(load("Resources/Themes/PMM_COLOR_SCHEME_PMM_CRYSTAL.json")["palette"])
    fields = function_body(editor, "Get-PMMThemeEditorFields")
    declared = set(re.findall(r"'([A-Za-z][A-Za-z0-9]+)'", fields))
    assert palette_keys.issubset(declared), sorted(palette_keys - declared)


def validate_aiio_trust_boundary() -> None:
    modules = [
        "Modules/AIIO/AIIO.SessionService.ps1",
        "Modules/AIIO/AIIO.DiagnosticService.ps1",
        "Modules/AIIO/AIIO.ResponseService.ps1",
        "Modules/AIIO/AIIO.ArtifactService.ps1",
        "Modules/AIIO/AIIO.ValidationService.ps1",
        "Modules/Operations/OperationJournal.ps1",
        "Modules/Saves/SaveActivityService.ps1",
    ]
    combined = "\n".join(read(path) for path in modules)
    for forbidden in (
        "Invoke-WebRequest", "Invoke-RestMethod", "System.Net.Http.HttpClient",
        "System.Net.WebClient", "Invoke-Expression", "iex ", "api_key", "Bearer ",
    ):
        assert forbidden.lower() not in combined.lower(), forbidden
    for marker in (
        "PMM_AIIO_SESSION_V2", "PMM_CAPABILITY_REGISTRY_V1", "PMM_AI_RESPONSE_V2",
        "Unsafe AI response path", "Duplicate AI response path",
        "AI response contains an undeclared payload",
        "Symbolic links are forbidden",
        "Executable content is forbidden", "Nested ZIP content is forbidden", "PMM_AIIO_CANDIDATE_RECORD_V1",
        "PMM_BUILD_VALIDATION_V1", "UploadAttempted=$false", "UploadAvailable=$false",
    ):
        assert marker in combined, marker

    response = read("Modules/AIIO/AIIO.ResponseService.ps1")
    activation = function_body(response, "Use-PMMAIIOCandidateForMerge")
    assert "PMM_MANUAL_SOLUTION_V1" in activation
    assert "Run Analyze again" in activation
    assert "Deploy-PMM" not in activation and "Invoke-PMMBuild" not in activation
    assert "AcceptedExperimental" in activation and "UNPROVEN" in activation

    worker = read("Modules/Operations/OperationWorker.ps1")
    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    for operation in (
        "AIIOPrepare", "AIIOPendingData", "AIIOImportResponse",
        "AIIOUseCandidate", "AIIOArtifactRefresh",
    ):
        assert operation in worker and operation in bootstrap, operation
    assert "Get-PMMArtifactStorageSummary -Refresh" in worker
    assert "Set-PMMAIIOProgress" in bootstrap


def validate_fixlab_deployment_ownership() -> None:
    fixlab = read("Modules/FixLab/FixLabService.ps1")
    library = read("Modules/Library/LibraryService.ps1")
    deploy_fix = function_body(fixlab, "Deploy-PMMFixLabBuiltOutput")
    restore_fix = function_body(fixlab, "Restore-PMMFixLabCase")
    delete_mod = function_body(library, "Remove-PMMLibraryMod")
    for body in (deploy_fix, restore_fix, delete_mod):
        assert "zzzzzzzzzz_PMM_Merge_".lower() not in body.lower()
    assert "belongs exclusively to Mods & Merge" in deploy_fix
    assert "deployed compatibility merge preserved" in restore_fix
    assert "deployedMergePreserved=true" in delete_mod
    assert "Apply Fix" in deploy_fix


def main() -> None:
    validate_inherited_rc26_contracts()
    validate_identity_and_package_boundary()
    validate_localized_ui_and_header()
    validate_theme_architecture()
    validate_aiio_trust_boundary()
    validate_fixlab_deployment_ownership()
    print("RC27_AIIO_LOCAL_FIRST_MODEL_OK")


if __name__ == "__main__":
    main()
