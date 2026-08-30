# PMM 1.3.0 RC23 — Windows PowerShell singleton collection hotfix

Build ID: `PMM-v1.3.0-RC23-POWERSHELL-SINGLETON-GUARD`

RC23 is a focused compatibility hotfix over RC22. It preserves the complete RC19 functional baseline, the RC21 UI/detection/cache reconciliation and all RC22 effective-conflict patch reuse and Semiauto behavior.

## User-captured failure and diagnosis

The supplied RC22 execution successfully completed the real six-asset Build before the error:

- worker session ended normally after packing 12 files;
- output PAK: `zzzzzzzzzz_PMM_Merge_20260829_220149_P.pak`;
- output bytes: `1602837`;
- output SHA-256: `2591474a38d20b880af3a9214e40807d7b52e197f57f1584513b701eb4acc1a5`;
- manifest schema: 9;
- six output-producing assets, seven complete shared-asset proofs and exactly one `KnownRecipeAuto` asset.

The post-Build UI refresh then called `Test-PMMPatchRuntimeCompatible`. Windows PowerShell 5.1 pipeline-unrolled the one-element `KnownRecipeAuto` result emitted from an `if` branch into a single `PSCustomObject`. Under `Set-StrictMode -Version Latest`, reading `.Count` on that object raised `PropertyNotFoundStrict`.

The merge engine and generated PAK were not the failing components. The failure happened while the UI attempted to register and display the completed saved patch.

## Correction

- Manifest assets, decisions and known-recipe matches are now initialized as explicit arrays outside conditional output pipelines.
- The same singleton/empty-collection guard is applied to runtime compatibility, plan compatibility, fast patch reuse, exact-patch Analyze reuse and the two equivalent UI collection sites.
- A Windows PowerShell regression test covers exactly one known-recipe asset, zero decisions and one analyzed shared proof under StrictMode.
- No merge algorithm, recipe, binary, XAML layout, sound assignment or deployment transaction behavior changed from RC22.

## Recovery of the completed RC22 build

Keep the existing `Workspace`. RC23 can read and validate the PAK and schema-9 manifest already present in `Workspace/Builds/Current`; rebuilding it solely because of this UI exception should not be necessary. For a clean test, extract RC23 to a new folder and copy the complete existing `Workspace` folder into it before starting PMM.

## Required Windows acceptance

1. Start RC23 with a copy of the supplied RC22 `Workspace` and confirm that the saved patch appears without a `.Count` exception.
2. Confirm the existing patch is selectable/current and can be deployed without rebuilding.
3. Disable only `BigInventory.pak`, run Analyze/AUTO and confirm the overlay is reused, Build remains skipped and Deploy synchronizes the source removal.
4. Repeat with `AutoUnlockAllTechnology_V1_P.pak`.
5. Confirm the configured Semiauto cue sounds after successful intermediate AUTO steps.
6. Add or alter a true conflict provider and confirm reuse is rejected when the effective recipe changes.

Cross-platform validation cannot execute the Windows WPF/PowerShell 5.1 host or Palworld. Do not promote RC23 to final until this acceptance passes on the target machine.
