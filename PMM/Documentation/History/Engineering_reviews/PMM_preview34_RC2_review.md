# Palworld Manager Merger preview34 RC2 review

## Purpose

RC2 is the final requested lifecycle/branding adjustment after preview34 RC1 passed
user testing. PMMCore 0.8.1 and the production merge adapters remain frozen.

## Changes

- Public product name: **Palworld Manager Merger (PMM)**.
- Patch library includes **No compatibility patch / source mods only** as a real
  radio choice.
- Manager-only Deploy is allowed without Analyze.
- Manager-only Deploy synchronizes active source PAKs, removes managed PMM
  overlays from the game, retains saved overlays locally, and suppresses only
  byte-identical duplicate source PAKs.
- Selecting/building a compatibility patch returns to normal merger deployment.
- Startup console/window branding updated.
- Release Documentation draft included and updated for the new name and
  manager-only mode.

## Frozen regression baseline

Byte-identical to RC1:

- complete `Tools/PMMCore` tree;
- `Mappings/Mappings.usmap`;
- `Core/SaveService.ps1`;
- ContainedDeltaSupersetAdapter;
- RelocatableDeltaAdapter;
- StaticItemDataAssetAdapter;
- DataTableMergeAdapter.

`Core/MergeEngine.ps1` changes only public branding text.

## Static QA

52 checks passed, 0 failed. The final ZIP contains 104 files in its internal
SHA256 manifest; all 104 verified after re-extraction. ZIP integrity test passed.

## Remaining user acceptance test

1. Deploy a normal known-working PMM patch.
2. Select **No compatibility patch**.
3. Deploy and confirm the PMM overlay disappears from `~mods` while active source
   mods remain.
4. Toggle one source mod and Deploy again without Analyze.
5. Select a saved compatible patch and Deploy; confirm normal merger deployment
   returns and the selected overlay becomes Current.
