#!/usr/bin/env python3
"""Cross-platform structural and security model for PMM 1.3.1 Mod Creation."""

from __future__ import annotations

import hashlib
import json
import re
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "PMM"
X_NAME = "{http://schemas.microsoft.com/winfx/2006/xaml}Name"


def read(path: str) -> str:
    return (APP / path).read_text(encoding="utf-8-sig")


def body(text: str, name: str) -> str:
    start = re.search(rf"(?im)^function\s+{re.escape(name)}\b", text)
    assert start, name
    nxt = re.search(r"(?im)^function\s+[A-Za-z0-9_-]+\b", text[start.end() :])
    end = start.end() + nxt.start() if nxt else len(text)
    return text[start.start() : end]


def validate_identity_and_ui() -> None:
    manifest = json.loads(read("Resources/Metadata/RELEASE_MANIFEST.json"))
    assert manifest["version"] == "1.3.1"
    assert manifest["buildId"] == "PMM-v1.3.1-MOD-CREATION-PREVIEW"
    assert manifest["releaseCandidate"] == "1.3.1-mod-creation-preview"
    assert manifest["aiioCapabilitySet"] == "PMM_CAPABILITIES_V2"
    assert manifest["aiioModCreationCandidateSchema"] == "PMM_MOD_CREATION_CANDIDATE_V1"
    assert "AIIOModBuild" in manifest["backgroundOperations"]
    assert "AIIO.ModCreationService.ps1" in manifest["aiioServices"]
    assert manifest["stableCandidate"] is False

    expected: set[str] | None = None
    for filename in ("MainWindow.xaml", "MainWindow.en.xaml", "MainWindow.es.xaml"):
        root = ET.fromstring(read(f"Resources/UI/{filename}"))
        assert root.attrib["Title"] == "PMM - Palworld Manager Merger v1.3.1", filename
        names = [node.attrib[X_NAME] for node in root.iter() if X_NAME in node.attrib]
        assert len(names) == len(set(names)), filename
        assert {"BtnAIHelpNewModProject", "BtnAIIOOpenHandoff"}.issubset(names)
        expected_save_header = "Guardado del mundo" if filename.endswith(".es.xaml") else "World Save"
        assert any(node.tag.endswith("}TabItem") and node.attrib.get("Header") == expected_save_header for node in root.iter()), filename
        expected = set(names) if expected is None else expected
        assert set(names) == expected, filename


def validate_capability_and_candidate_boundaries() -> None:
    session = read("Modules/AIIO/AIIO.SessionService.ps1")
    response = read("Modules/AIIO/AIIO.ResponseService.ps1")
    service = read("Modules/AIIO/AIIO.ModCreationService.ps1")
    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    worker = read("Modules/Operations/OperationWorker.ps1")

    for marker in (
        "query_game_reference",
        "extract_game_reference_asset",
        "extract_reference_neighborhood",
        "PMM_CAPABILITIES_V2",
    ):
        assert marker in session
    assert "Capability set: PMM_CAPABILITIES_V1" not in session
    request = body(response, "Test-PMMAIIOCapabilityRequest")
    assert "TaskType -ne 'CREATE_MOD'" in request
    assert "maximumResults must be between 1 and 200" in request
    assert "maximumFamilies must be between 1 and 32" in request
    export = body(response, "Export-PMMAIIORequestedData")
    assert "Search-PMMAIIOGameReferenceFamilies" in export
    assert "Export-PMMAIIOGameReferenceAsset" in export
    assert "Export-PMMAIIOGameReferenceNeighborhood" in export

    for marker in (
        "PMM_MOD_CREATION_CANDIDATE_V1",
        "standalone-cooked-tree",
        "Get-PMMAIIOGameReferenceProof -RequireCurrent",
        "Source-family proof does not match",
        "Standalone mod candidate files do not match",
        "PMM/Metadata/created-with-pmm.json",
        "This mod was created with PMM assistance.",
        "AutomaticallyDeployed=$false",
        "AutomaticallyPublished=$false",
        "KnowledgeStatus='UNPROVEN'",
        "Invoke-PMMManualSolutionProbe",
    ):
        assert marker in service, marker

    build = body(service, "Build-PMMAIIOModCandidate")
    for forbidden in (
        "Deploy-PMM",
        "Invoke-PMMDeploy",
        "Deploy-Patch",
        "Pal\\Content\\Paks\\~mods",
        "Invoke-WebRequest",
        "Invoke-RestMethod",
    ):
        assert forbidden not in build, forbidden
    assert "Pack-Pak $packRoot $tempPak" in build
    assert "Get-PMMAIIOSessionPath $SessionId" in build
    assert "AttributionPakEntry" in build
    assert "entries.Count -ne (@($tree.Files).Count+1)" in build

    assert bootstrap.index("AIIO.ModCreationService.ps1") < bootstrap.index("AIIO.ResponseService.ps1")
    assert worker.index("AIIO.ModCreationService.ps1") < worker.index("AIIO.ResponseService.ps1")
    assert "-Operation AIIOModBuild" in bootstrap
    assert "Build-PMMAIIOModCandidate" in worker
    assert "New-PMMAIIOSession -Title" in bootstrap and "-TaskType CREATE_MOD" in bootstrap
    dialog = body(bootstrap, "Show-PMMModCreationProjectDialog")
    for marker in (
        'SizeToContent="Height"',
        'VerticalScrollBarVisibility="Auto"',
        'MinWidth="620"',
        "$form.Owner=$Window",
        "TxtModProjectValidation",
        "$form.DialogResult=$true",
    ):
        assert marker in dialog, marker
    assert "System.Windows.Forms.Form" not in dialog
    assert ".Left=" not in dialog and ".Top=" not in dialog

    assert "$Script:ActiveThemeId=''" in bootstrap
    apply_theme = body(bootstrap, "Apply-PMMTheme")
    assert "$Script:ActiveThemeDefinition -and" in apply_theme
    auto_preferences = body(bootstrap, "Save-PMMAutoPreferences")
    assert "AutoMode=" in auto_preferences and "AutoIncludePlay=" in auto_preferences
    assert "Theme=" not in auto_preferences and "Sound" not in auto_preferences
    assert "$enabled=[bool]$Script:TglAutoMode.IsChecked;Save-PMMAutoPreferences" in bootstrap

    latest = body(session, "Get-PMMAIIOLatestHandoffPath")
    for marker in ("session.Iteration", "requests\\request-{0:D4}", "PMM_AIIO_REQUEST_", "Test-PMMPathInside"):
        assert marker in latest, marker

    workflow = (ROOT / ".github/workflows/validate.yml").read_text(encoding="utf-8-sig")
    smoke = (ROOT / "Development/Tests/SmokeTest.ps1").read_text(encoding="utf-8-sig")
    assert "'1.3.1-*'" in workflow
    assert "manifest.version -eq '1.3.1'" in smoke


def validate_hash_binding_model() -> None:
    """Model the exact candidate file proof and show tampering changes identity."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        cooked = root / "cooked/Pal/Content/Pal/Blueprint/Character/Player"
        cooked.mkdir(parents=True)
        asset = cooked / "BP_PlayerBase.uasset"
        asset.write_bytes(b"fixture-current-cooked-family")
        rel = asset.relative_to(root).as_posix()
        proof = {
            "relativePath": rel,
            "bytes": asset.stat().st_size,
            "sha256": hashlib.sha256(asset.read_bytes()).hexdigest(),
        }
        observed = (rel.lower(), asset.stat().st_size, hashlib.sha256(asset.read_bytes()).hexdigest())
        declared = (proof["relativePath"].lower(), proof["bytes"], proof["sha256"])
        assert observed == declared
        asset.write_bytes(asset.read_bytes() + b"tampered")
        changed = (rel.lower(), asset.stat().st_size, hashlib.sha256(asset.read_bytes()).hexdigest())
        assert changed != declared


def validate_docs() -> None:
    user_doc = read("Documentation/MOD_CREATION_AIIO.md")
    test_doc = read("Documentation/TEST_THIS_BUILD_1_3_1_MOD_CREATION.txt")
    for text in (user_doc, test_doc):
        assert "This mod was created with PMM assistance." in text
        assert "PMM/Metadata/created-with-pmm.json" in text
        assert "UNPROVEN" in text
    assert (ROOT / "Development/Docs/PMM_1_3_1_MOD_CREATION.md").is_file()
    current = (ROOT / "Development/AI/CURRENT_STATE.md").read_text(encoding="utf-8-sig")
    continuation = (ROOT / "Development/AI/AI_CONTINUE_HERE.md").read_text(encoding="utf-8-sig")
    assert "PMM-v1.3.1-MOD-CREATION-PREVIEW" in current
    assert "TEST_THIS_BUILD_1_3_1_MOD_CREATION.txt" in continuation


def main() -> None:
    validate_identity_and_ui()
    validate_capability_and_candidate_boundaries()
    validate_hash_binding_model()
    validate_docs()
    for path in APP.rglob("*.json"):
        json.loads(path.read_text(encoding="utf-8-sig"))
    print("PMM_V131_MOD_CREATION_MODEL_OK")


if __name__ == "__main__":
    main()
