# Palworld Manager Merger 1.3.0 RC22

Build ID: `PMM-v1.3.0-RC22-EFFECTIVE-PATCH-REUSE-SEMIAUTO`

RC22 is a focused correction over RC21. It preserves the complete RC19 functional baseline and RC21 header, detection, Settings, Play-ready ColorFlow and conservative Analyze caches.

## Effective-conflict-set patch reuse

RC21 compared the complete active source signature before treating a saved compatibility patch as current. The supplied runtime evidence showed why that was too broad: disabling `BigInventory.pak` or `AutoUnlockAllTechnology_V1_P.pak` changed the source list but neither mod appeared in any of the seven shared groups. All three builds reconciled the same six assets and produced the same `PatchContentSignature`.

RC22 still requires Analyze after an enable/disable change so PMM can discover a new provider or shared asset. It skips Build only when it can prove the saved overlay recipe is unchanged:

- exact patched asset identities;
- exact provider sets and provider PAK hashes;
- identical adapter modes and decision signature;
- for `KnownRecipeAuto`, the current recipe identity/output provider and exact saved cooked-output family evidence;
- identical engine, mappings and Vanilla identity;
- identical output-relevant priority winner;
- no Unsupported or unresolved decision/package state;
- experimental manual solutions only on the exact complete source set.

New build manifests use schema 9 and persist `AnalyzedSharedAssets`, production-recipe identity/output fields and the recipe-library hash. That lets a future automatic patch prove the complete current shared topology before expensive adapters. Legacy schema-8 patches may take the fast path only when every unpatched group has an exact safe `Identical` group-cache proof and no unpinned known recipe is involved. A legacy known-recipe patch is revalidated through normal Analyze, then its saved cooked-output evidence is compared with the currently authorized recipe before Build can be skipped.

Deploy always synchronizes the current active/disabled source PAKs. Reusing the overlay never means reusing an old deployment list.

## Semiauto sound correction

The supplied RC21 configuration contained `SoundSemiAuto = Ok` together with `SoundSemiAutoEnabled = false`. That independent switch explains why changing the selected Semiauto sound did not make it audible.

RC22:

- enables Semiauto on new/default settings;
- migrates sound-default schema 2 to schema 3 once, enabling any assigned profile other than `None`;
- makes selecting a concrete Semiauto sound enable the per-step switch;
- keeps `None` and the checkbox as explicit mute controls.

## Validation boundary

The repository includes `Development/Tests/rc22_patch_reuse_model.py` and expanded static smoke assertions. Cross-platform source, JSON, XAML, archive and evidence-model checks do not replace Windows WPF or real Palworld runtime acceptance. Use the checklist in `Development/Docs/Validation/RC22_STATIC_VALIDATION.md` before promotion.
