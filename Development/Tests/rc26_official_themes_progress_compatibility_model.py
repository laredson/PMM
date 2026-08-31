#!/usr/bin/env python3
"""Cross-platform structural/model regression for PMM 1.3.0 RC26.

Windows PowerShell 5.1, WPF, repak and Palworld remain runtime acceptance
gates. This model proves the release-owned data and the exact safety boundaries
introduced in RC26 without pretending to execute those Windows components.
"""

from __future__ import annotations

import json
import importlib.util
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "PMM"
EXPECTED_BUILD = "PMM-v1.3.0-RC29-AIHELP-FEEDBACK-UI-FIX"
ASSET = "Pal/Content/Pal/DataTable/Character/DT_PalMonsterParameter_Common.uasset"
PROPERTY = "Rows[Boar].WorkSuitability_MonsterFarm"
FASTER = "FasterMounts4xAllWorkSuitabilitiesLevel10_P.pak"
RUSHROAR = "RushRoarLeatherDrop_v2_P.pak"


def read(relative: str) -> str:
    return (APP / relative).read_text(encoding="utf-8-sig")


def load(relative: str) -> dict:
    return json.loads(read(relative))


def fallback_rule() -> tuple[dict, dict]:
    document = load("CKL/Stable/production-recipes.json")
    recipe = next(row for row in document["recipes"] if row["id"] == "rushroar-v2-fastermounts-palmonsterparameter-20260817")
    fallback = recipe["semanticFallback"]
    assert fallback["enabled"] is True
    assert fallback["class"] == "datatable-proven-dominance"
    rule = fallback["conflicts"][0]
    return recipe, rule


def model_rule_match(asset: str, path: str, providers: dict[str, str]) -> str | None:
    recipe, rule = fallback_rule()
    if asset.casefold() != recipe["asset"].casefold() or path != rule["path"]:
        return None
    expected = {row["name"]: row["canonicalValue"] for row in rule["providers"]}
    if rule["requireExactConflictProviders"] and sorted(providers) != sorted(expected):
        return None
    if any(providers.get(name) != value for name, value in expected.items()):
        return None
    return rule["selectProvider"] if rule["runtime"].startswith("proven") else None


def validate_exact_compatibility_rule() -> None:
    recipe, rule = fallback_rule()
    assert recipe["asset"] == ASSET
    assert rule["path"] == PROPERTY
    assert rule["selectProvider"] == FASTER
    assert model_rule_match(ASSET, PROPERTY, {FASTER: "10", RUSHROAR: "1"}) == FASTER

    # Negative controls: no generic "larger number wins" behavior is allowed.
    assert model_rule_match(ASSET, PROPERTY + "_Other", {FASTER: "10", RUSHROAR: "1"}) is None
    assert model_rule_match(ASSET, PROPERTY, {FASTER: "9", RUSHROAR: "1"}) is None
    assert model_rule_match(ASSET, PROPERTY, {FASTER: "10", RUSHROAR: "2"}) is None
    assert model_rule_match(ASSET, PROPERTY, {FASTER: "10", RUSHROAR: "1", "Third.pak": "1"}) is None

    merge = read("Modules/Merge/MergeEngine.ps1")
    knowledge = read("Modules/CKL/KnowledgeRecipeService.ps1")
    library = read("Modules/Library/LibraryService.ps1")
    for marker in (
        "Get-PMMPlanSchemaVersion { return 18 }",
        "Get-PMMDataTableCompatibilityResolution $Group $conflict $ProviderRecords",
        "DecisionKind='AutomaticCompatibility'",
        "if($rows.Count -eq 0){'DataTableAuto'}",
        "AutomaticResolutions=$automatic.ToArray()",
        "KnowledgeRulesSha256=(Get-PMMProductionRecipeLibrarySha256)",
        "automatic-compatibility-resolutions.json",
    ):
        assert marker in merge, marker
    for marker in (
        "function Get-PMMDataTableCompatibilityResolution",
        "requireExactConflictProviders",
        "Get-PMMConflictCanonicalValue",
    ):
        assert marker in knowledge, marker
    for marker in (
        "function Get-PMMAutomaticResolutionSignature",
        "knowledgeAuthorizedAssets",
        "KnowledgeRulesSha256",
        "Get-PMMAutomaticResolutionSignature $asset",
    ):
        assert marker in library, marker


def validate_official_and_user_theme_separation() -> None:
    theme_root = APP / "Resources" / "Themes"
    files = sorted(theme_root.glob("PMM_COLOR_SCHEME_*.json"))
    bundled = load("Resources/Themes/BUNDLED_THEME_MANIFEST.json")
    official = load("Resources/Themes/OFFICIAL_THEME_MANIFEST.json")
    file_ids = {json.loads(path.read_text(encoding="utf-8-sig"))["id"] for path in files}
    bundled_ids = {row["id"] for row in bundled["themes"]}
    official_ids = {row["id"] for row in official["themes"]}
    assert len(files) == bundled["themeCount"] == official["officialThemeCount"] == 11
    assert file_ids == bundled_ids == official_ids
    assert all(row["source"] == "official-pack" for row in bundled["themes"])
    assert official["excludedExperiments"] == []
    assert "aurora-confetti" in official_ids

    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    for marker in (
        "$Script:PnlThemeOptions.Children.Clear();$Script:PnlUserThemeOptions.Children.Clear()",
        "$isOfficial=([bool]$t.Builtin -or $isBundled)",
        "$Script:PnlThemeOptions.Children.Add($rb)",
        "$Script:PnlUserThemeOptions.Children.Add($rb)",
        "Id='Night'",
        "Id='Light'",
    ):
        assert marker in bootstrap, marker

    namespace = "http://schemas.microsoft.com/winfx/2006/xaml"
    x_name = f"{{{namespace}}}Name"
    name_sets: list[set[str]] = []
    for filename in ("MainWindow.xaml", "MainWindow.en.xaml", "MainWindow.es.xaml"):
        root = ET.fromstring(read(f"Resources/UI/{filename}"))
        names = [value for node in root.iter() if (value := node.attrib.get(x_name))]
        assert len(names) == len(set(names))
        current = set(names)
        assert {"PnlThemeOptions", "PnlUserThemeOptions", "TxtUserThemeEmpty"}.issubset(current)
        name_sets.append(current)
    assert name_sets[0] == name_sets[1] == name_sets[2]


def validate_immediate_completion_progress() -> None:
    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    start = bootstrap.index("function Set-PMMSmoothedProgressBar")
    finish = bootstrap.index("function Reset-PMMSmoothedProgressBar", start)
    body = bootstrap[start:finish]
    completion = body.index("if($target -ge 100.0)")
    state_lookup = body.index("$state=$null;if($Script:ProgressAnimationStates.ContainsKey($Key))")
    assert completion < state_lookup
    for marker in (
        "ProgressAnimationStates.Remove($Key)",
        "$Bar.Value=100.0",
        "return 100.0",
    ):
        assert marker in body[:state_lookup]


def validate_release_identity() -> None:
    manifest = load("Resources/Metadata/RELEASE_MANIFEST.json")
    assert manifest["mergePlanSchema"] == 18
    assert manifest["buildId"] == EXPECTED_BUILD
    assert manifest["releaseCandidate"] == "rc29-aihelp-feedback-ui-fix"
    assert manifest["bundledThemeCount"] == 11
    assert manifest["officialThemeChoiceCount"] == 13
    assert (APP / "Resources/Metadata/BUILD_ID.txt").read_text(encoding="utf-8-sig").strip() == EXPECTED_BUILD
    assert not (APP / "Workspace").exists()


def validate_inherited_rc25_contracts() -> None:
    path = Path(__file__).with_name("rc25_release_model.py")
    spec = importlib.util.spec_from_file_location("pmm_rc25_regression", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    module.validate_themes()
    module.validate_gura_preflight()
    module.validate_progress_model()
    module.validate_ui_and_import_boundary()


def main() -> None:
    validate_inherited_rc25_contracts()
    validate_exact_compatibility_rule()
    validate_official_and_user_theme_separation()
    validate_immediate_completion_progress()
    validate_release_identity()
    print("RC26_OFFICIAL_THEMES_PROGRESS_COMPATIBILITY_MODEL_OK")


if __name__ == "__main__":
    main()
