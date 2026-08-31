# Palworld Manager Merger 1.3.0 RC23

Build ID: `PMM-v1.3.0-RC23-POWERSHELL-SINGLETON-GUARD`

RC23 is a narrow Windows PowerShell 5.1 compatibility hotfix over RC22. It does not alter the merge algorithms, schema-9 proof model, effective-conflict reuse policy, Semiauto behavior, UI layout or deployment transaction model.

## Captured RC22 result

The user's real RC22 Build completed normally in the background worker and packed a valid 12-entry compatibility PAK before the UI error. The captured PAK is 1,602,837 bytes and its computed SHA-256 exactly matches the manifest `OutputHash`:

`2591474a38d20b880af3a9214e40807d7b52e197f57f1584513b701eb4acc1a5`

Its schema-9 manifest records six output assets, seven complete shared proofs, no decisions and exactly one `KnownRecipeAuto` asset. The UI then failed at `LibraryService.ps1:411` while evaluating the saved patch.

## Root cause

In Windows PowerShell, values written by an `if` branch pass through the success pipeline. An `@(...)` containing one object is therefore unwrapped when assigned outside the branch. Under StrictMode, the resulting `PSCustomObject` has no `.Count` property. Empty and singleton decision/asset collections in equivalent reuse paths had the same latent shape risk.

## Fix

- Initialize manifest/reuse collection variables as `@()`.
- Assign `@(...)` inside the conditional branch so the variable itself remains an array.
- Cover the runtime proof, plan proof, fast reuse, exact reuse and equivalent UI collection sites.
- Add `Development/Tests/rc23_singleton_collection_regression.ps1`, which exercises exactly one known recipe, zero decisions and one shared proof under StrictMode.
- Preserve the user's already-built PAK: copying the existing Workspace into RC23 should allow it to be recognized without another Build.

## Acceptance focus

Run RC23 against a copy of the supplied RC22 Workspace. First confirm the existing patch appears without an exception. Then test its Deploy and the RC22 unique-mod scenarios (`BigInventory.pak` and `AutoUnlockAllTechnology_V1_P.pak`), Semiauto cues, and one negative true-conflict change.
