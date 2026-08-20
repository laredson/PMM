# Palworld Manager Merger preview34 RC5 - targeted release-candidate hotfix

Date: 2026-08-17

## Runtime issue found in RC4

After deploying **No compatibility patch**, selecting a previously saved compatible patch changed the radio selection but left **Deploy** disabled until Analyze was run again.

The saved patch itself was valid. Analyze merely refreshed state and made the button available again.

## Root cause

RC4 had two Analyze gates that were too strict:

1. `Start-PalModMerger.ps1::Update-BuildButtonState` returned early whenever no current Analyze plan existed. It had an explicit no-Analyze exception only for manager-only mode, not for a saved compatible patch.
2. `Core/LibraryService.ps1::Get-PMMDeploymentContext` also required a current Analyze plan before Deploy whenever a compatibility patch was selected.

This contradicted the saved-patch design: a saved patch already carries its source signature, mappings hash, output hash and deployment suppressions.

## RC5 behavior

A saved patch may be deployed without Analyze only when `Get-PMMSelectedManagedPatch` accepts it, which requires the patch to have:

- a readable manifest;
- a valid output hash;
- the exact active source-library signature/hashes; and
- matching mappings hash when present.

If those checks fail and no current Analyze plan exists, Deploy remains unavailable and the deployment context requires Analyze.

Manager-only mode remains Analyze-optional.

Analyze is still required to inspect conflicts or build a new compatibility patch.

## Frozen merge engine

Compared with RC4, RC5 keeps byte-identical:

- PMMCore 0.8.1 and every adapter;
- `Mappings.usmap`;
- `MergeEngine.ps1`;
- `PakService.ps1`;
- `SaveService.ps1`;
- `SemanticLab.ps1`;
- `Common.ps1`.

The functional change is limited to saved-patch deployment gating in `Start-PalModMerger.ps1` and `Core/LibraryService.ps1`, plus RC5 tests/branding/docs.

## Acceptance test

1. Have a saved compatibility patch for the current active source set.
2. Select **No compatibility patch** and Deploy; the PMM overlay should be removed.
3. Do **not** Analyze.
4. Select the saved patch radio button.
5. Deploy must enable immediately.
6. Deploy it; the selected PMM overlay must return.
7. Close/reopen PMM and confirm the patch/deployed state remains coherent.

If this passes, RC5 is a suitable code freeze candidate for 1.0.
