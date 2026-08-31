#!/usr/bin/env python3
"""Cross-platform structural/model regression for PMM 1.3.0 RC29."""

from __future__ import annotations

import json
import re
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "PMM"
EXPECTED_BUILD = "PMM-v1.3.1-MOD-CREATION-PREVIEW"
XAML_NS = "http://schemas.microsoft.com/winfx/2006/xaml"
X_NAME = f"{{{XAML_NS}}}Name"


def read(relative: str) -> str:
    return (APP / relative).read_text(encoding="utf-8-sig")


def function_body(text: str, name: str) -> str:
    match = re.search(rf"(?im)^function\s+(?:script:)?{re.escape(name)}\b", text)
    assert match, f"Function not found: {name}"
    following = re.search(r"(?im)^function\s+(?:script:)?[A-Za-z0-9_-]+\b", text[match.end() :])
    end = match.end() + following.start() if following else len(text)
    return text[match.start() : end]


def parent_map(root: ET.Element) -> dict[ET.Element, ET.Element]:
    return {child: parent for parent in root.iter() for child in parent}


def find_named(root: ET.Element, name: str) -> ET.Element:
    return next(node for node in root.iter() if node.attrib.get(X_NAME) == name)


def nearest_tab_header(node: ET.Element, parents: dict[ET.Element, ET.Element]) -> str:
    current = node
    while current in parents:
        current = parents[current]
        if current.tag.endswith("}TabItem"):
            return current.attrib.get("Header", "")
    return ""


def validate_identity_and_manifest() -> None:
    manifest = json.loads(read("Resources/Metadata/RELEASE_MANIFEST.json"))
    assert manifest["product"] == "Palworld Manager Merger"
    assert manifest["creator"] == "laredson"
    assert manifest["buildId"] == EXPECTED_BUILD
    assert manifest["releaseCandidate"] == "1.3.1-mod-creation-preview"
    assert manifest["aiioFeedbackSchema"] == "PMM_USER_FEEDBACK_V1"
    assert manifest["aiioRemoteUploadEnabled"] is False
    assert "manual" in manifest["aiioFeedbackTransport"].lower()
    assert read("Resources/Metadata/BUILD_ID.txt").strip() == EXPECTED_BUILD


def validate_localized_ui() -> None:
    expected_names: set[str] | None = None
    expected_tabs = {
        "MainWindow.xaml": ["AI assistance", "AI reception", "Feedback & Knowledge", "Color scheme editor", "Settings"],
        "MainWindow.en.xaml": ["AI assistance", "AI reception", "Feedback & Knowledge", "Color scheme editor", "Settings"],
        "MainWindow.es.xaml": ["Ayuda IA", "Recepcion IA", "Feedback y Knowledge", "Editor de esquemas de color", "Opciones IA"],
    }
    required = {
        "CmbAIHelpFeedbackType", "TxtAIHelpFeedbackTitle", "TxtAIHelpFeedbackComments",
        "CmbAIHelpFeedbackBuild", "BtnAIHelpCreateFeedback", "BtnAIHelpGenerateFeedback",
        "BtnAIHelpOpenFeedback", "BtnAIHelpUploadFeedback", "TxtAIHelpFeedbackStatus",
        "ChkAIIOAutoCreateErrorCases", "TxtAIIOSettingsStatus",
    }
    for filename, headers in expected_tabs.items():
        text = read(f"Resources/UI/{filename}")
        root = ET.fromstring(text)
        parents = parent_map(root)
        names = [node.attrib[X_NAME] for node in root.iter() if X_NAME in node.attrib]
        assert len(names) == len(set(names)) == 289, filename
        assert required.issubset(names), filename
        expected_names = set(names) if expected_names is None else expected_names
        assert set(names) == expected_names, filename

        ai_tabs = find_named(root, "AIHelpTabs")
        actual_headers = [child.attrib.get("Header", "") for child in ai_tabs if child.tag.endswith("}TabItem")]
        assert actual_headers == headers, (filename, actual_headers)

        detect = find_named(root, "BtnDetectGame")
        folders = find_named(root, "BtnOpenGame")
        auto = find_named(root, "TglAutoMode")
        assert detect.attrib.get("Grid.Row", "0") == "0"
        assert parents[folders].attrib.get("Grid.Row") == "1"
        current = auto
        while current in parents and "Grid.Row" not in current.attrib:
            current = parents[current]
        assert current.attrib.get("Grid.Row") == "2"

        assert nearest_tab_header(find_named(root, "ChkAIIOAutoCreateErrorCases"), parents) in {"Settings", "Opciones IA"}
        assert nearest_tab_header(find_named(root, "TxtGameReferenceSummary"), parents) in {"Settings", "Configuracion"}
        assert find_named(root, "BtnAIHelpUploadFeedback").attrib.get("IsEnabled") == "False"
        assert "Action required: press play" not in text

        data_grid_style = re.search(r'<Style TargetType="DataGridCell">(?P<body>.*?)</Style>', text, re.S)
        assert data_grid_style
        assert "SelectionBackground" in data_grid_style.group("body")
        assert "SelectionText" in data_grid_style.group("body")


def validate_aiio_callbacks_and_deduplication() -> None:
    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    assert "$Script:LstAIIOSessions.SelectedValue" not in bootstrap
    assert "$Script:LstAIHelpDiagnostics.SelectedValue" not in bootstrap
    for helper in (
        "Complete-PMMAIIOPrepareUi", "Complete-PMMAIIOImportResponseUi",
        "Complete-PMMAIIOPendingDataUi", "Complete-PMMAIIOModBuildUi",
        "Complete-PMMAIIOUseCandidateUi",
    ):
        assert helper in bootstrap
    closure_calls = re.findall(
        r"\$done=\{param\(\$result\)\s+(Complete-PMMAIIO[A-Za-z]+Ui[^\r\n}]*)\}\.GetNewClosure\(\)",
        bootstrap,
    )
    assert len(closure_calls) == 7
    assert all("$Script:" not in call and "SelectedValue" not in call for call in closure_calls)
    assert "-OnSuccess {param($result) Complete-PMMAIIOCandidateAnalyzeUi $result}" in bootstrap

    selector = function_body(bootstrap, "Select-PMMSelectorItemId")
    assert "$Control.SelectedItem=$item" in selector
    diagnostic_session = function_body(bootstrap, "Get-PMMAIIOSessionForDiagnostic")
    assert "PrimaryTarget.Kind -eq 'DiagnosticCase'" in diagnostic_session
    diagnostic_selection = function_body(bootstrap, "Update-PMMAIHelpDiagnosticSelection")
    assert "Status -eq 'Open'" in diagnostic_selection
    repair = function_body(bootstrap, "Repair-PMMDuplicateDiagnosticSessions")
    assert "Set-PMMAIIOSessionArchived" in repair and "Select-Object -Skip 1" in repair
    assert "if([string]$session.Status -ne 'Draft')" in bootstrap
    assert "if([string]$case.Status -ne 'Open')" in bootstrap

    handler = function_body(bootstrap, "Handle-UIError")
    assert "$Script:HandlingUIError" in handler
    assert "Register-PMMAutomaticErrorCase" in handler
    assert "-not$NoDiagnostic" in handler
    ai_settings = function_body(bootstrap, "Save-PMMAIHelpSettings")
    assert "AIIOAutoCreateErrorCases" in ai_settings
    assert "Theme" not in ai_settings and "CompletionSound" not in ai_settings


def validate_badge_and_play_ready_state() -> None:
    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    badge = function_body(bootstrap, "Refresh-PMMAIHelpBadge")
    assert "CandidateReady" in badge and "NeedsData" in badge and "Unsupported" in badge
    assert "'WaitingForAI'" not in badge
    assert "Validation" not in badge

    guided = function_body(bootstrap, "Update-PMMGuidedActionState")
    play_branch = re.search(r"if\(\[string\]\$state\.Action -eq 'Play'\)\{(?P<body>.*?)\n\s*\}", guided, re.S)
    assert play_branch
    assert "Close-PMMRequiredActionPopup" in play_branch.group("body")
    assert "Set-PMMRequiredAction" not in play_branch.group("body")


def validate_feedback_and_legacy_migration() -> None:
    validation = read("Modules/AIIO/AIIO.ValidationService.ps1")
    feedback = function_body(validation, "New-PMMUserFeedbackFile")
    for marker in (
        "PMM_USER_FEEDBACK_V1", "GENERAL_COMMENT", "MERGE_COMMENT",
        "KNOWLEDGE_CKL_COMMENT", "PMM_FEEDBACK_TRANSPORT_V1",
        "UploadAttempted=$false", "UploadAvailable=$false",
    ):
        assert marker in feedback, marker
    assert "ContainsPakContents=$false" in feedback and "ContainsSaveData=$false" in feedback

    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    exact_handler = bootstrap[bootstrap.index("$Script:BtnAIHelpGenerateFeedback.Add_Click") :]
    exact_handler = exact_handler[: exact_handler.index("$Script:BtnAIHelpOpenFeedback.Add_Click")]
    assert "Get-PMMAIHelpFeedbackPatch" in exact_handler
    assert "$Script:LstPatches.SelectedItem" not in exact_handler
    assert "-NoDiagnostic" in exact_handler

    diagnostic = read("Modules/AIIO/AIIO.DiagnosticService.ps1")
    register = function_body(diagnostic, "Register-PMMAutomaticErrorCase")
    migration = function_body(diagnostic, "Resolve-PMMKnownLegacyUiDiagnostics")
    assert "OccurrenceCount" in register and "Fingerprint" in register
    assert "AIIOPrepare completion" in migration and "Generate local validation feedback" in migration
    assert "SelectedValue" in migration and "select a compatibility merge" in migration
    assert "ResolvedByUpgrade" in migration and "EvidencePreserved=$true" in migration


def validate_dialog_theme_and_encoding() -> None:
    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    dialog = function_body(bootstrap, "Show-PMMBuildValidationDialog")
    for marker in ("$clientWidth=1040", "$clientWidth,360", "$buttonWidth=230", "$button.Height=76", "Segoe UI Semibold"):
        assert marker in dialog, marker
    assert "System.Drawing.Size" in dialog and "System.Drawing.Font" in dialog

    refresh = function_body(bootstrap, "Refresh-PMMThemeSelectionVisuals")
    apply_theme = function_body(bootstrap, "Apply-PMMThemeDefinition")
    assert "LstPatches" in refresh and "Items.Refresh()" in refresh
    assert "DispatcherPriority]::Render" in apply_theme

    for path in (APP / "Modules").rglob("*.ps1"):
        data = path.read_bytes()
        if data.startswith(b"\xef\xbb\xbf"):
            continue
        data.decode("ascii")


def main() -> None:
    validate_identity_and_manifest()
    validate_localized_ui()
    validate_aiio_callbacks_and_deduplication()
    validate_badge_and_play_ready_state()
    validate_feedback_and_legacy_migration()
    validate_dialog_theme_and_encoding()
    print("RC29_AIHELP_FEEDBACK_UI_MODEL_OK")


if __name__ == "__main__":
    main()
