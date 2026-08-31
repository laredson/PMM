# PMM 1.3.0 RC22 — effective patch reuse and Semiauto correction

Build ID: `PMM-v1.3.0-RC22-EFFECTIVE-PATCH-REUSE-SEMIAUTO`

RC22 is a focused correction over RC21. It does not replace the RC19 functional baseline or the RC21 header, detection, Settings, ColorFlow and Analyze-cache work.

## Corrected behavior

- Enabling or disabling a source PAK that does not participate in any effective shared conflict no longer forces PMM to build an identical compatibility overlay.
- Analyze first proves current shared topology. Reuse requires the same patched assets, provider names and hashes, adapter modes, decisions, mappings, Vanilla identity and output-relevant priority winners. `KnownRecipeAuto` also pins the CKL production-recipe identity and exact cooked-output evidence.
- A newly added provider, new shared conflict, changed participant hash, changed decision, changed mappings or changed Vanilla identity still invalidates reuse and requires normal Analyze/Build.
- Deploy remains required when the active source list changed, because PMM must add/remove the corresponding source PAK in Palworld even when the compatibility overlay itself is unchanged.
- Saved conflict/package decisions survive the Analyze-state reset caused by enable/disable and are accepted only when the recomputed stable DecisionId still matches.
- New build manifests use schema 9 and persist `AnalyzedSharedAssets`, recipe identity/output evidence and the production-recipe library hash, allowing future automatic patches to prove unchanged topology before running expensive adapters. RC21 schema-8 patches containing a known recipe are revalidated through normal Analyze before reuse.
- Semiauto is enabled by default. RC21 configurations with sound-default schema 2 migrate once to schema 3; a configured sound other than `None` enables the per-step cue. Users can still mute it with `None` or by clearing `Sound each AUTO step`.

## Captured regression evidence

The supplied RC21 runtime captured three builds:

1. 50 active source mods;
2. 49 active mods with `BigInventory.pak` disabled;
3. 49 active mods with `AutoUnlockAllTechnology_V1_P.pak` disabled.

All three manifests contain the same six patched assets and the same cooked-output evidence signature:

`fb1b0eabdf2051fbf7fd8df6`

The PAK indexes also prove that both disabled mods are absent from all seven shared asset groups (six patched plus one Identical). They therefore change deployment membership, not compatibility-patch content.

The supplied configuration assigned Semiauto = `Ok` but stored `SoundSemiAutoEnabled = false`, confirming why changing the selected Semiauto sound produced no audible cue.

## Validation boundary

Static source, JSON/XAML, topology and captured-manifest regression checks are included with this candidate. Final acceptance still requires running the portable build on Windows with the real Palworld installation:

- build/deploy once with all 50 mods;
- disable only `BigInventory.pak`, run Analyze/AUTO and confirm Build is skipped while Deploy removes that source PAK;
- restore it, disable only `AutoUnlockAllTechnology_V1_P.pak` and confirm the same behavior;
- enable `Sound each AUTO step`, run AUTO and confirm the configured Semiauto cue plays after each successful step and the Auto cue plays only at terminal completion;
- add or enable a mod that really joins a patched asset and confirm PMM does not reuse the old overlay.
