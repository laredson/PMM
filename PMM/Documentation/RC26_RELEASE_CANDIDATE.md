# PMM 1.3.0 RC26 — official themes, immediate completion and restored compatibility

Build ID: `PMM-v1.3.0-RC26-OFFICIAL-THEMES-PROGRESS-COMPATIBILITY`

RC26 is the publication candidate built directly on RC25. It preserves the responsive 900×600 minimum, Gura package preflight, Fix Lab/deployed-merge isolation, Semiauto migration and effective-conflict patch reuse.

## Official and user schemes

The eleven validated JSON schemes are now part of the official PMM set. Legacy Night and Light remain official built-ins, so Settings presents thirteen official choices in total. Schemes imported into `Workspace\Themes` appear separately under **User schemes / Esquemas del usuario** and cannot replace an official ID.

PMM Crystal remains the fresh-install and Restore-defaults selection. Existing valid selections are preserved during upgrade.

## Progress completion

Determinate progress below 100% keeps the RC25 integer interpolation and never exceeds worker-reported progress. A worker-confirmed 100% update now clears any pending interpolation and appears immediately. The next task therefore cannot begin while the previous task still looks unfinished.

## FasterMounts + RushRoar

These mods are compatible in the captured runtime-proven case. RushRoar changes `Rows[Boar].WorkSuitability_MonsterFarm` from 0 to 1. FasterMounts changes that same field to 10 as part of its all-suitabilities behavior, so the value 10 preserves RushRoar's ranch-enablement requirement. RushRoar's separate Boar Blueprint and spawn-action assets remain installed normally.

RC25 could expose this as a generic 10-versus-1 decision when the current cooked-family hashes no longer matched the older exact-output recipe. RC26 adds a narrower semantic fallback:

- exact asset and property path;
- exact two competing provider names;
- exact canonical values 10 and 1;
- runtime-proven rule status;
- current cooked families rebuilt through the normal DataTable adapter.

Only that tuple is automatic and selects FasterMounts for the overlapping field. A changed path, provider set or value remains a real user decision. Schema-18 plans, decision-free Analyze caches and schema-9 patch reuse pin the compatibility-rule library hash and automatic-resolution signature.

## Windows acceptance before publication

1. Start with a clean RC26 folder and copy only the existing `Workspace` from the prior test build.
2. Open Settings. Confirm all eleven JSON schemes plus Night and Light appear under Official PMM schemes. Import one valid custom scheme and confirm it appears only under User schemes.
3. Run a workflow with a visible long progress interval. Intermediate ranges must animate; each confirmed 100% must appear immediately before the next operation starts.
4. Activate `FasterMounts4xAllWorkSuitabilitiesLevel10_P.pak` and `RushRoarLeatherDrop_v2_P.pak`, then run Analyze. `DT_PalMonsterParameter_Common.uasset` must be automatic and Resolution & Review must not ask which mod to choose for `Rows[Boar].WorkSuitability_MonsterFarm`.
5. Build once if RC26 invalidates the older rule-pinned manifest, then Deploy and verify both gameplay behaviors in Palworld. Repeat Analyze; the current patch should be reusable.
6. Negative control: alter the fixture only in a controlled development copy (provider/value/path mismatch). PMM must not apply the rule and must expose the resulting genuine decision.
7. Re-run RC25 responsive/DPI/Gura tests and the RC24 Fix Lab merge-ownership checks.
8. Run the repository Windows validator and smoke tests.

Cross-platform structural validation cannot certify Windows PowerShell 5.1, WPF, repak or in-game behavior. Publish only after the target-PC acceptance above passes.
