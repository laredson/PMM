#!/usr/bin/env python3
"""Cross-platform structural/model regression for PMM 1.3.0 RC30."""

from __future__ import annotations

import json
import re
import xml.etree.ElementTree as ET
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


def event_block(text: str, start: str, end: str) -> str:
    first = text.index(start)
    last = text.index(end, first)
    return text[first:last]


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


def validate_identity() -> None:
    manifest = json.loads(read("Resources/Metadata/RELEASE_MANIFEST.json"))
    assert manifest["buildId"] == EXPECTED_BUILD
    assert manifest["releaseCandidate"] == "1.3.1-mod-creation-preview"
    assert manifest["releaseDate"] == "2026-08-31"
    assert manifest["aiioPublicTabs"] == [
        "AI assistance", "AI reception", "Feedback & Knowledge",
        "Color scheme editor", "Settings",
    ]
    assert manifest["aiioRemoteUploadEnabled"] is False
    assert "60 seconds" in manifest["backgroundCadence"]
    assert read("Resources/Metadata/BUILD_ID.txt").strip() == EXPECTED_BUILD


def validate_localized_ui() -> None:
    expected_names: set[str] | None = None
    expected_tabs = {
        "MainWindow.xaml": ["AI assistance", "AI reception", "Feedback & Knowledge", "Color scheme editor", "Settings"],
        "MainWindow.en.xaml": ["AI assistance", "AI reception", "Feedback & Knowledge", "Color scheme editor", "Settings"],
        "MainWindow.es.xaml": ["Ayuda IA", "Recepcion IA", "Feedback y Knowledge", "Editor de esquemas de color", "Opciones IA"],
    }
    required = {
        "BtnAIHelpNewCase", "BtnAIHelpCreateAndPrepareCase", "PnlAIHelpSelectedCase",
        "PnlAIHelpNewCase", "TxtAIHelpSelectedCaseDescription", "BtnAIIOImportResponse",
        "CmbAIHelpFeedbackBuild", "TxtGameReferenceSummary", "BtnBuildGameReference",
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
        actual = [child.attrib.get("Header", "") for child in ai_tabs if child.tag.endswith("}TabItem")]
        assert actual == headers, (filename, actual)
        assert nearest_tab_header(find_named(root, "TxtGameReferenceSummary"), parents) in {"Settings", "Configuracion"}
        assert find_named(root, "TxtGameReferenceSummary") not in set(ai_tabs.iter())
        assert find_named(root, "BtnAIHelpUploadFeedback").attrib.get("IsEnabled") == "False"
        assert "Action required: press play" not in text


def validate_routed_selection_and_targeted_refresh() -> None:
    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    main_tabs = event_block(bootstrap, "$Script:MainTabs.Add_SelectionChanged", "$Script:AIHelpTabs.Add_SelectionChanged")
    ai_tabs = event_block(bootstrap, "$Script:AIHelpTabs.Add_SelectionChanged", "# ---------------------------------------------------------------------------\n# Guided workflow")
    assert "$e.OriginalSource -ne $sender" in main_tabs
    assert "$e.OriginalSource -ne $sender" in ai_tabs
    assert "Refresh-UI" not in main_tabs

    feedback = function_body(bootstrap, "Refresh-PMMAIHelpFeedback")
    assert "CmbAIHelpFeedbackBuild.IsDropDownOpen" in feedback
    assert "selectedKey" in feedback and "Select-PMMSelectorItemId" in feedback

    validate = event_block(bootstrap, "$Script:BtnValidatePatch.Add_Click", "$Script:BtnDeletePatch.Add_Click")
    assert "Refresh-UI" not in validate
    assert "Update-PMMValidatedPatchRow" in validate
    assert "Show-PMMValidationContributionDialog" in validate
    assert "Open-PMMValidationFeedbackForPatch" in validate


def validate_dialog_and_feedback_flow() -> None:
    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    dialog = function_body(bootstrap, "Show-PMMBuildValidationDialog")
    for marker in ("$clientWidth=1040", "$clientWidth,360", "$buttonWidth=230", "$button.Height=76", "AutoEllipsis=$false"):
        assert marker in dialog, marker
    contribution = function_body(bootstrap, "Show-PMMValidationContributionDialog")
    assert "760,300" in contribution and "$yes.Width=245" in contribution

    open_feedback = function_body(bootstrap, "Open-PMMValidationFeedbackForPatch")
    assert "$Script:AIHelpTabs.SelectedIndex=2" in open_feedback
    assert "Refresh-PMMAIHelpFeedback -Force" in open_feedback
    assert "MERGE_COMMENT" in open_feedback


def validate_idle_and_worker_cadence() -> None:
    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    assert "UiResponsivenessTimer" not in bootstrap
    assert "UI dispatcher delay detected" not in bootstrap
    assert "FromSeconds(60)" in bootstrap
    check = function_body(bootstrap, "Check-PMMExternalModChanges")
    assert "LastExternalModsCheckUtc" in check
    assert "TotalSeconds -lt 60" in check
    heartbeat = event_block(bootstrap, "$Script:ExternalModsTimer.Add_Tick", "$Script:ExternalModsTimer.Start()")
    assert "$Window.IsActive" in heartbeat
    assert "WindowState]::Minimized" in heartbeat
    assert "Get-PMMActiveProcessingOperation" in heartbeat

    # High-frequency timers are operation-scoped and do not start at idle.
    assert bootstrap.count("FromMilliseconds(40)") == 1
    assert "Ensure-PMMProgressAnimationTimer" in function_body(bootstrap, "Set-PMMSmoothedProgressBar")
    assert "BackgroundOperationTimer=$timer" in bootstrap
    assert "GameReferenceTimer=$timer" in bootstrap


def validate_ai_assistance_and_reception() -> None:
    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    selected = function_body(bootstrap, "Update-PMMAIHelpDiagnosticSelection")
    assert "TxtAIHelpSelectedCaseTitle" in selected
    assert "TxtAIHelpSelectedCaseDescription" in selected
    assert "Get-PMMAIIOSessionForDiagnostic" in selected

    create_case = function_body(bootstrap, "New-PMMAIHelpCaseFromUi")
    assert "PMMFeature" in create_case and "AttentionEligible $false" in create_case
    assert "BtnAIHelpCreateAndPrepareCase.Add_Click" in bootstrap
    assert "BtnAIHelpPrepareDiagnostic.RaiseEvent" in bootstrap

    refresh = function_body(bootstrap, "Refresh-PMMAIHelpUi")
    assert "$tab -eq 0" in refresh and "$tab -eq 1" in refresh and "$tab -eq 4" in refresh
    assert "Refresh-PMMAIHelpFeedback;Refresh-PMMAIHelpKnowledge" in refresh

    response = read("Modules/AIIO/AIIO.ResponseService.ps1")
    hint = function_body(response, "Get-PMMAIIOResponsePackageHint")
    assert "PMM_THEME_AI_RESPONSE_V1" in hint and "Kind='ThemeResponse'" in hint
    assert "5,000 entries" in hint
    intake = event_block(bootstrap, "$Script:BtnAIIOImportResponse.Add_Click", "$Script:BtnAIIOContinue.Add_Click")
    assert "Get-PMMAIIOResponsePackageHint" in intake
    assert "Import-PMMThemeAIResponse" in intake
    assert "Get-PMMAIIOSession ([string]$hint.SessionId)" in intake


def validate_badge_theme_and_progress() -> None:
    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    badge = function_body(bootstrap, "Refresh-PMMAIHelpBadge")
    assert "AutomaticError" in badge and "PMM_ERROR" in badge and "Unsupported" in badge
    assert "'WaitingForAI'" not in re.sub(r"(?m)^\s*#.*$", "", badge)
    assert "PMM_BUILD_VALIDATION" not in badge

    apply_theme = function_body(bootstrap, "Apply-PMMTheme")
    assert "$Script:ActiveThemeId -ieq $resolvedId" in apply_theme
    settings = event_block(bootstrap, "$Script:BtnApplySettings.Add_Click", "$Script:BtnRestoreDefaults.Add_Click")
    assert "Apply-PMMTheme (Get-PMMSelectedThemeId) -Force" in settings
    assert "ThemeEditorDirtyFields" in bootstrap
    assert "Only copy fields the user actually edited" in bootstrap

    smooth = function_body(bootstrap, "Set-PMMSmoothedProgressBar")
    hundred = smooth.index("if($target -ge 100.0)")
    animate = smooth.index("Ensure-PMMProgressAnimationTimer")
    assert hundred < animate
    assert "$Bar.Value=100.0" in smooth[hundred:animate]

    guided = function_body(bootstrap, "Update-PMMGuidedActionState")
    play = guided[guided.index("if([string]$state.Action -eq 'Play')") :]
    assert "Close-PMMRequiredActionPopup" in play
    assert "Set-PMMRequiredAction" not in play.split("return", 1)[0]


def validate_json_and_control_binding() -> None:
    for path in APP.rglob("*.json"):
        json.loads(path.read_text(encoding="utf-8-sig"))

    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    names: set[str] = set()
    for filename in ("MainWindow.xaml", "MainWindow.en.xaml", "MainWindow.es.xaml"):
        root = ET.fromstring(read(f"Resources/UI/{filename}"))
        current = {node.attrib[X_NAME] for node in root.iter() if X_NAME in node.attrib}
        names = current if not names else names & current
    controls_match = re.search(r"\$controlNames\s*=\s*@\((?P<body>.*?)\)\s*foreach\s*\(\$name in \$controlNames\)", bootstrap, re.S)
    assert controls_match
    declared = set(re.findall(r"'([A-Za-z][A-Za-z0-9]+)'", controls_match.group("body")))
    assert declared.issubset(names), sorted(declared - names)


def main() -> None:
    validate_identity()
    validate_localized_ui()
    validate_routed_selection_and_targeted_refresh()
    validate_dialog_and_feedback_flow()
    validate_idle_and_worker_cadence()
    validate_ai_assistance_and_reception()
    validate_badge_theme_and_progress()
    validate_json_and_control_binding()
    print("RC30_LEAN_AI_VALIDATION_MODEL_OK")


if __name__ == "__main__":
    main()
