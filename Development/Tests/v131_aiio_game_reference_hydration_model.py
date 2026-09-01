from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
AIIO = ROOT / 'PMM' / 'Modules' / 'AIIO'
HYDRATION = AIIO / 'AIIO.GameReferenceHydrationService.ps1'
PENDING = AIIO / 'AIIO.PendingDataService.ps1'
ARTIFACT = AIIO / 'AIIO.ArtifactService.ps1'


def normalize(path: str) -> str:
    n = (path or '').strip().lstrip('\ufeff').replace('\\', '/')
    while n.startswith('/'):
        n = n[1:]
    while n.startswith('../'):
        n = n[3:]
    return n


def validate_source_contracts():
    h = HYDRATION.read_text(encoding='utf-8-sig')
    r = PENDING.read_text(encoding='utf-8-sig')
    a = ARTIFACT.read_text(encoding='utf-8-sig')

    assert 'function Initialize-PMMAIIOFastPakIndexType' in h
    assert 'public sealed class PMMAIIOFastPakIndexCatalog' in h
    assert 'function Ensure-PMMAIIOGameReferenceFamiliesExact' in h
    assert "Context 'AIIO Game Reference batch hydration'" in h
    assert 'Get-PakEntry $pak ([string]$row.RawEntry) $stageFile' in h
    assert "HydrationPolicy='AIIO_ON_DEMAND_BATCH_V2'" in h

    assert 'function Write-PMMAIIOPendingDataProgress' in r
    assert 'Ensure-PMMAIIOGameReferenceFamiliesExact -LogicalPaths' in r
    assert "Schema='PMM_AIIO_REQUEST_FAILURE_V1'" in r
    assert 'FulfillmentStatus=$fulfillment' in r
    assert "'Partial'" in r

    assert 'AIIO.GameReferenceHydrationService.ps1' in a
    assert 'AIIO.SessionRecoveryService.ps1' in a
    assert 'AIIO.GameReferenceFastIndexService.ps1' not in a
    assert 'AIIO.PendingDataProgressService.ps1' not in a
    assert 'AIIO.PendingDataService.ps1' in a
    assert not (AIIO / 'AIIO.GameReferenceFastIndexService.ps1').exists()
    assert not (AIIO / 'AIIO.PendingDataProgressService.ps1').exists()

    # Regression for the startup crash: no wrapper should read an undefined
    # Script-scoped capture variable at module import time.
    assert 'PMMAIIOBaseExportRequestedData' not in '\n'.join((h, r, a))


def validate_normalization_model():
    assert normalize('../Pal/Content/Foo.uasset') == 'Pal/Content/Foo.uasset'
    assert normalize('../../../Pal/Content/Foo.uasset') == 'Pal/Content/Foo.uasset'
    assert normalize('\\Pal\\Content\\Foo.uasset') == 'Pal/Content/Foo.uasset'
    assert normalize('\ufeffEngine/Config/Base.ini') == 'Engine/Config/Base.ini'


def validate_batch_shape():
    h = HYDRATION.read_text(encoding='utf-8-sig')
    # One batch repak unpack path, plus exact fallback only when a file was
    # genuinely missed by the selective bulk extraction.
    assert h.count("Context 'AIIO Game Reference batch hydration'") == 1
    assert "foreach($entry in @($rawEntries.ToArray())){$args+=@('--include',[string]$entry)}" in h
    assert re.search(r"if\(-not\(Test-Path -LiteralPath \$stageFile -PathType Leaf\)\).*?Get-PakEntry", h, re.S)


def optional_live_index_regression():
    index = ROOT / 'PMM' / 'Workspace' / 'GameReference' / 'current' / 'index' / 'pak-index.txt'
    if not index.exists():
        return
    lines = {normalize(x) for x in index.read_text(encoding='utf-8-sig').splitlines() if x.strip()}
    # Known current-Palworld examples from the 2026-08-31 CREATE_MOD test.
    assert 'Pal/Content/Pal/Blueprint/Spawner/SheetsVariant/BP_PalSpawner_Sheets_green_A.uasset' in lines
    assert 'Pal/Content/Pal/Blueprint/Spawner/SheetsVariant/BP_PalSpawner_Sheets_3_1_volcano_1.uasset' in lines
    assert 'Pal/Content/Pal/Blueprint/Spawner/SheetsVariant/BP_PalSpawner_Sheets_81_1_forest_FBOSS_1.uasset' in lines
    # These were erroneous exact requests in the recovery test and must remain
    # recognized as unavailable rather than silently aliased/fabricated.
    assert 'Pal/Content/Pal/Blueprint/Spawner/SheetsVariant/BP_PalSpawner_Sheets_3_1_volcano.uasset' not in lines
    assert 'Pal/Content/Pal/Blueprint/Spawner/SheetsVariant/BP_PalSpawner_Sheets_81_1_forest_FBOSS.uasset' not in lines


def main():
    validate_source_contracts()
    validate_normalization_model()
    validate_batch_shape()
    optional_live_index_regression()
    print('PMM_V131_AIIO_GAME_REFERENCE_HYDRATION_MODEL_OK')


if __name__ == '__main__':
    main()
