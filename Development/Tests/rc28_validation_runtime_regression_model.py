#!/usr/bin/env python3
"""Cross-platform regression model for the RC28 validation/runtime fixes."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "PMM"
EXPECTED_BUILD = "PMM-v1.3.1-MOD-CREATION-PREVIEW"
EXPECTED_CANDIDATE = "1.3.1-mod-creation-preview"


def read(relative: str) -> str:
    return (APP / relative).read_text(encoding="utf-8-sig")


def function_body(text: str, name: str) -> str:
    match = re.search(rf"(?im)^function\s+(?:script:)?{re.escape(name)}\b", text)
    assert match, f"Function not found: {name}"
    following = re.search(r"(?im)^function\s+(?:script:)?[A-Za-z0-9_-]+\b", text[match.end() :])
    end = match.end() + following.start() if following else len(text)
    return text[match.start() : end]


def validate_inherited_rc27_contracts() -> None:
    path = Path(__file__).with_name("rc27_aiio_local_first_model.py")
    spec = importlib.util.spec_from_file_location("pmm_rc27_regression_rc28", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    module.validate_inherited_rc26_contracts()
    module.validate_identity_and_package_boundary()
    module.validate_localized_ui_and_header()
    module.validate_theme_architecture()
    module.validate_aiio_trust_boundary()
    module.validate_fixlab_deployment_ownership()


def deterministic_build_id() -> str:
    source_rows = sorted(
        (
            "ModA_P.pak:" + ("b" * 64) + ":2",
            "ModB_P.pak:" + ("c" * 64) + ":1",
        )
    )
    parts = [
        "PMM_BUILD_ID_V1",
        "a" * 64,
        "|".join(source_rows),
        "source-signature",
        "merge-order",
        "EFFECTIVE_ORDER_V2:ORDER-INDEPENDENT",
        "decision-signature",
        "d" * 64,
        "vanilla-signature",
        "PMMCore-v0.9.0",
        "recipe:recipe-one:case-one:Pal/Content/Data/Test.uasset",
    ]
    return hashlib.sha256("\n".join(parts).encode("utf-8")).hexdigest()


def validate_build_identity_contract() -> None:
    service = read("Modules/AIIO/AIIO.ValidationService.ps1")
    helper = function_body(service, "Get-PMMBuildIdentitySha256")
    generator = function_body(service, "Get-PMMDeterministicBuildId")
    summary_path = function_body(service, "Get-PMMBuildValidationSummaryPath")
    manifest_hash = function_body(service, "Get-PMMBuildManifestHash")
    assert "SHA256" in helper and "ToLowerInvariant" in helper
    assert "Substring(0,24)" not in helper
    assert "Get-PMMBuildIdentitySha256 ($parts -join" in generator
    assert "Get-PMMStableTextId" not in generator
    assert "Get-PMMBuildIdentitySha256" in manifest_hash
    assert "^[0-9a-f]{64}$" in summary_path
    build_id = deterministic_build_id()
    assert build_id == "f9384ae08e215151e8d8b885239f2c6190fdb0bfce2e4467983eef67ef26776c"
    assert re.fullmatch(r"[0-9a-f]{64}", build_id)


def normalize_timestamp(value: str) -> str:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    utc = parsed.astimezone(timezone.utc)
    return utc.strftime("%Y-%m-%dT%H:%M:%S.%f") + "0Z"


def normalize_schema3(state: dict) -> dict:
    managed = []
    seen = set()
    for row in state.get("SourceMods", []):
        if row.get("Deployed", True) is False:
            continue
        record = (row.get("Name", ""), row.get("Hash", row.get("Sha256", "")), "SourceMod")
        key = (record[0].casefold(), record[1].casefold())
        if record[0] and key not in seen:
            seen.add(key)
            managed.append(record)
    patch = state.get("Patch")
    selected = ""
    if patch:
        selected = patch.get("Name", "")
        record = (selected, patch.get("Hash", patch.get("Sha256", "")), "CompatibilityPatch")
        key = (record[0].casefold(), record[1].casefold())
        if record[0] and key not in seen:
            managed.append(record)
    return {
        "Present": True,
        "UpdatedUtc": normalize_timestamp(state.get("UpdatedUtc", state.get("Deployed", ""))),
        "SelectedPatch": selected or state.get("SelectedPatch", ""),
        "ManagedFiles": managed,
    }


def validate_deployment_schema3_contract() -> None:
    service = read("Modules/AIIO/AIIO.SessionService.ps1")
    timestamp = function_body(service, "ConvertTo-PMMAIIOUtcTimestamp")
    body = function_body(service, "Get-PMMAIIOCurrentDeploymentSnapshot")
    for marker in ("DateTimeOffset", "ToUniversalTime", "fffffff'Z'", "InvariantCulture"):
        assert marker in timestamp, marker
    for marker in (
        "PSObject.Properties.Name -contains 'ManagedFiles'",
        "PSObject.Properties.Name -contains 'SourceMods'",
        "Kind='SourceMod'",
        "Kind='CompatibilityPatch'",
        "Properties.Name -contains 'Deployed'",
        "elseif($state.PSObject.Properties.Name -contains 'Deployed')",
    ):
        assert marker in body, marker
    fixture = {
        "SchemaVersion": 3,
        "Deployed": "2026-08-30T14:32:14Z",
        "SourceMods": [
            {"Name": "Enabled_P.pak", "Hash": "1" * 64, "Deployed": True},
            {"Name": "Suppressed_P.pak", "Hash": "2" * 64, "Deployed": False},
        ],
        "Patch": {"Name": "zzzzzzzzzz_PMM_Merge_Test_P.pak", "Hash": "3" * 64},
    }
    result = normalize_schema3(fixture)
    assert result["UpdatedUtc"] == "2026-08-30T14:32:14.0000000Z"
    assert result["SelectedPatch"] == fixture["Patch"]["Name"]
    assert result["ManagedFiles"] == [
        ("Enabled_P.pak", "1" * 64, "SourceMod"),
        ("zzzzzzzzzz_PMM_Merge_Test_P.pak", "3" * 64, "CompatibilityPatch"),
    ]


def validate_singleton_candidate_contract() -> None:
    bootstrap = read("Modules/Bootstrap/Start-PalModMerger.ps1")
    body = function_body(bootstrap, "Refresh-PMMAIIOCandidates")
    assert "$rows=@()" in body
    assert "if($SessionId){$rows=@(Get-PMMAIIOCandidateRecords $SessionId)}" in body
    assert not re.search(r"\$rows\s*=\s*if\s*\(", body)
    dialog = function_body(bootstrap, "Show-PMMBuildValidationDialog")
    assert "$choices=@()" in dialog
    assert "[pscustomobject]@{Result='PASS';Label=" in dialog
    assert "$choice.Label" in dialog and "$choice.Result" in dialog
    assert not re.search(r"\$choices\s*=\s*if\s*\(", dialog)


def validate_release_identity() -> None:
    manifest = json.loads(read("Resources/Metadata/RELEASE_MANIFEST.json"))
    assert manifest["buildId"] == EXPECTED_BUILD
    assert manifest["releaseCandidate"] == EXPECTED_CANDIDATE
    assert read("Resources/Metadata/BUILD_ID.txt").strip() == EXPECTED_BUILD


def main() -> None:
    validate_inherited_rc27_contracts()
    validate_build_identity_contract()
    validate_deployment_schema3_contract()
    validate_singleton_candidate_contract()
    validate_release_identity()
    print("RC28_VALIDATION_RUNTIME_REGRESSION_MODEL_OK")


if __name__ == "__main__":
    main()
