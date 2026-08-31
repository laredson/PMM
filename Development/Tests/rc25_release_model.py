#!/usr/bin/env python3
"""Cross-platform structural/model validation for PMM 1.3.0 RC25.

This intentionally avoids Windows/WPF execution. It verifies the release-owned
contracts that can be proved on any maintainer machine; Windows acceptance is a
separate release gate documented in the RC25 validation boundary.
"""

from __future__ import annotations

import hashlib
import json
import math
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "PMM"
EXPECTED_BUILD = "PMM-v1.3.0-RC30-LEAN-AI-VALIDATION-FLOW"


def read(relative: str) -> str:
    return (APP / relative).read_text(encoding="utf-8-sig")


def load_json(relative: str) -> dict:
    return json.loads(read(relative))


def rgb(value: str) -> tuple[float, float, float]:
    raw = value.removeprefix("#")
    if len(raw) == 8:
        raw = raw[2:]
    if len(raw) != 6:
        raise AssertionError(f"Unsupported color: {value}")
    return tuple(int(raw[index : index + 2], 16) / 255.0 for index in (0, 2, 4))


def luminance(value: str) -> float:
    channels = [part / 12.92 if part <= 0.04045 else ((part + 0.055) / 1.055) ** 2.4 for part in rgb(value)]
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast(foreground: str, background: str) -> float:
    first, second = luminance(foreground), luminance(background)
    return (max(first, second) + 0.05) / (min(first, second) + 0.05)


def validate_themes() -> None:
    theme_root = APP / "Resources" / "Themes"
    files = sorted(theme_root.glob("PMM_COLOR_SCHEME_*.json"))
    assert len(files) == 11

    required_palette = {
        "AppBackground", "HeaderBackground", "CardBackground", "CardAltBackground", "InputBackground",
        "CardBorder", "InputBorder", "PrimaryText", "MutedText", "SelectionBackground", "SelectionText",
        "GridLine", "Splitter", "StatusBackground", "SoftBlue", "SoftGreen", "SoftAmber", "SoftRed", "SoftGray",
        "FixHeaderBackground", "FixHeaderBorder", "NoticeBackground", "NoticeBorder", "DecisionNoticeBackground",
        "DecisionNoticeBorder", "DecisionNoticeHeading", "SourceBackground", "SourceBorder", "ConfigureBackground",
        "ConfigureBorder", "BuildBackground", "BuildBorder", "OutputBackground", "OutputBorder", "BackupBackground",
        "BackupBorder", "AdvancedBackground", "AccentHeadingBlue", "AccentHeadingAmber", "AccentHeadingPurple",
        "AccentHeadingGreen", "WarmHeading", "ButtonBackground", "ButtonHover", "ButtonForeground", "ButtonBorder",
    }
    pairs = (
        ("PrimaryText", "AppBackground"), ("PrimaryText", "CardBackground"),
        ("PrimaryText", "CardAltBackground"), ("PrimaryText", "InputBackground"),
        ("MutedText", "AppBackground"), ("MutedText", "CardBackground"),
        ("MutedText", "CardAltBackground"), ("ButtonForeground", "ButtonBackground"),
        ("ButtonForeground", "ButtonHover"), ("SelectionText", "SelectionBackground"),
        ("AccentHeadingBlue", "SourceBackground"), ("AccentHeadingAmber", "ConfigureBackground"),
        ("AccentHeadingPurple", "BuildBackground"), ("AccentHeadingGreen", "OutputBackground"),
        ("WarmHeading", "BackupBackground"), ("AccentHeadingGreen", "CardAltBackground"),
    )

    identities: set[str] = set()
    for path in files:
        definition = json.loads(path.read_text(encoding="utf-8-sig"))
        assert definition["schema"] == "PMM_COLOR_SCHEME_V1"
        assert re.fullmatch(r"[a-z0-9][a-z0-9._-]{0,63}", definition["id"])
        assert definition["id"] not in identities
        identities.add(definition["id"])
        assert set(definition["palette"]) == required_palette
        assert set(definition["colorFlow"]) == {"Import", "Analyze", "Build", "Deploy", "Play"}
        palette = definition["palette"]
        for foreground, background in pairs:
            assert contrast(palette[foreground], palette[background]) >= 4.5, (
                definition["id"], foreground, background
            )
        for state, colors in definition["colorFlow"].items():
            assert contrast("#FFFFFF", colors["Border"]) >= 4.5, (definition["id"], state, "Border")
            assert contrast(palette["PrimaryText"], colors["Progress"]) >= 4.5, (
                definition["id"], state, "Progress"
            )

    assert "pmm-crystal" in identities and "aurora-confetti" in identities
    manifest = load_json("Resources/Themes/BUNDLED_THEME_MANIFEST.json")
    assert manifest["themeCount"] == len(files) == len(manifest["themes"])
    assert manifest["defaultThemeId"] == "pmm-crystal"
    for row in manifest["themes"]:
        path = theme_root / row["file"]
        assert path.is_file()
        assert hashlib.sha256(path.read_bytes()).hexdigest() == row["sha256"]


def validate_gura_preflight() -> None:
    package_rules = load_json("CKL/Stable/package-rules.json")
    rule = next(row for row in package_rules["rules"] if row["id"] == "pmm-fixlab-gawr-gura-case-001-variants-v1")
    assert rule["trigger"] == "anyTwoActive"
    assert len(rule["members"]) == len(rule["choices"]) == 5
    assert len(set(rule["members"])) == 5

    # Mirrors the exact pair from the supplied RC24 execution workspace.
    active = {"GawrGura_hooded-gura_P.pak", "GawrGura_fullreplacement-3skins_P.pak"}
    available = [row for row in rule["choices"] if set(row["enabled"]).issubset(active)]
    assert len(available) == 2
    selected = next(row for row in available if row["id"] == "full-replacement")
    assert "GawrGura_hooded-gura_P.pak" in selected["suppressed"]

    merge = read("Modules/Merge/MergeEngine.ps1")
    scan_start = merge.index("function Invoke-PMMScan")
    preflight = merge.index("Get-PMMPackageChoiceAnalyses $mods $previous", scan_start)
    enumeration = merge.index("Get-PMMAssetGroups $analysisMods", scan_start)
    assert preflight < enumeration
    assert "'anyTwoActive' {$triggerAccepted=($present.Count -ge 2)}" in merge
    assert "Analyze slow-group complete:" in merge


@dataclass
class ProgressState:
    displayed: float
    target: float
    interval_ms: float = 250.0

    def report(self, target: float) -> None:
        target = math.floor(max(0.0, min(100.0, target)))
        if target > self.target and self.displayed < self.target:
            self.displayed = self.target
        if target < self.displayed or target == 0:
            self.displayed = target
        self.target = target
        gap = max(0.0, self.target - self.displayed)
        if gap:
            self.interval_ms = max(50.0, min(500.0, 3000.0 / gap))

    def finish(self) -> list[int]:
        sequence: list[int] = []
        while self.displayed < self.target:
            self.displayed = min(self.target, self.displayed + 1.0)
            sequence.append(int(self.displayed))
            assert self.displayed <= self.target
        return sequence


def validate_progress_model() -> None:
    state = ProgressState(10, 10)
    state.report(22)
    assert state.interval_ms == 250.0
    assert state.finish() == list(range(11, 23))
    assert state.interval_ms * 12 == 3000.0

    # When a newer real target arrives while presentation is behind, it may
    # catch up only to the old proven target, then animates the new range.
    state = ProgressState(14, 22)
    state.report(30)
    assert state.displayed == 22
    assert state.interval_ms == 375.0
    assert state.finish() == list(range(23, 31))
    assert state.interval_ms * 8 == 3000.0

    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    for marker in (
        "function Set-PMMSmoothedProgressBar",
        "3000.0/$gap",
        "[Math]::Min(500.0",
        "state.Displayed=$priorTarget",
        "$start=if($target -le 1){$target}else{0.0}",
        "if($target -ne $priorTarget){$state.LastStepUtc=",
        "[Math]::Floor([Math]::Max(0.0",
    ):
        assert marker in bootstrap


def validate_ui_and_import_boundary() -> None:
    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    common = read("Modules/Shared/Common.ps1")
    paths = read("Modules/Shared/Paths.ps1")
    service = read("Modules/Theme/ThemeService.ps1")
    assert "Theme='pmm-crystal'" in common
    assert "UiWindowWidth=1460;UiWindowHeight=900" in common
    assert "BundledThemes=Join-Path $appRoot 'Resources\\Themes'" in paths
    assert "$maxWidth=[Math]::Max(640.0" in bootstrap
    assert "$minWidth=[Math]::Min(900.0,$maxWidth)" in bootstrap
    assert "$Script:ColAnalysisWorkspace.MinWidth=if($extreme){330.0}else{460.0}" in bootstrap
    assert "SetRow($Script:GrdHeaderActions,1)" in bootstrap

    safety_markers = (
        "Theme ZIP exceeds 25 MiB", "Archive contains more than 200 entries",
        "Archive expands beyond 75 MiB", "Nested archives are not allowed",
        "Executable content is not allowed", "Symbolic-link entry is not allowed",
        "official reserved id and cannot be replaced", "legacy built-in reserved id",
        "Invalid or unsafe PMM_COLOR_SCHEME_V1 definition",
        "'.pyw'", "'.psd1'", "'.lnk'",
        "backupRoot=Join-Path $themeRoot 'Backups'", "$dest=$existing",
    )
    for marker in safety_markers:
        assert marker in service
    assert "Deploy-PMM" not in service and "Get-PMMDeployment" not in service

    namespace = "http://schemas.microsoft.com/winfx/2006/xaml"
    x_name = f"{{{namespace}}}Name"
    reference_names: set[str] | None = None
    for filename in ("MainWindow.xaml", "MainWindow.en.xaml", "MainWindow.es.xaml"):
        text = read(f"Resources/UI/{filename}")
        root = ET.fromstring(text)
        assert root.attrib["Width"] == "1460" and root.attrib["Height"] == "900"
        assert root.attrib["MinWidth"] == "900" and root.attrib["MinHeight"] == "600"
        names = [value for node in root.iter() if (value := node.attrib.get(x_name))]
        assert len(names) == len(set(names)), f"Duplicate x:Name in {filename}"
        current = set(names)
        assert {"GrdHeaderLayout", "GrdHeaderActions", "ColLibrary", "ColAnalysisWorkspace"}.issubset(current)
        if reference_names is None:
            reference_names = current
        else:
            assert current == reference_names, f"Localized control mismatch in {filename}"
        assert 'x:Name="BtnDetectGame" Grid.Row="0" HorizontalAlignment="Stretch" MinWidth="0"' in text
        assert 'Background" Value="{DynamicResource CardAltBackground}"' in text


def validate_release_identity() -> None:
    manifest = load_json("Resources/Metadata/RELEASE_MANIFEST.json")
    assert manifest["buildId"] == EXPECTED_BUILD
    assert manifest["releaseCandidate"] == "rc30-lean-ai-validation-flow"
    assert manifest["bundledThemeCount"] == 11
    assert manifest["settingsDefaults"]["theme"] == "pmm-crystal"
    assert (APP / "Resources/Metadata/BUILD_ID.txt").read_text(encoding="utf-8-sig").strip() == EXPECTED_BUILD
    assert not (APP / "Workspace").exists()


def main() -> None:
    validate_themes()
    validate_gura_preflight()
    validate_progress_model()
    validate_ui_and_import_boundary()
    validate_release_identity()
    print("RC25_RELEASE_MODEL_OK")


if __name__ == "__main__":
    main()
