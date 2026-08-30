# AIIO continuation handoff — PMM 1.3.0 RC22

> Historical RC22 baseline. Continue from `AIIO_HANDOFF_RC24.md`; RC24 preserves this complete contract, the RC23 Windows PowerShell singleton-collection guard and the newer UI/deployment-ownership corrections.

## Start here

Use this document together with the separate AIIO continuity package. Read `PMM_AIIO_MASTER_HANDOFF_2026-08-29.md` there first; it remains the authority for AIIO product decisions. Then inspect the exact RC22 source tree supplied with this handoff. Do not redesign AIIO from scratch and do not replace this baseline with either RC20 implementation.

Product identity:

- **Palworld Manager Merger (PMM)**
- Creator: **laredson**
- Continuation baseline: **1.3.0 RC22**
- Build ID: `PMM-v1.3.0-RC22-EFFECTIVE-PATCH-REUSE-SEMIAUTO`

## Authority and RC22 delta

RC22 keeps the complete RC19 functional base and RC21 UI/detection/cache reconciliation. It adds two focused corrections proven by the user's captured RC21 runtime:

1. A saved compatibility overlay is reusable after current Analyze when the effective conflict recipe is unchanged, even if unrelated unique/non-conflicting source PAKs were enabled or disabled. Exact conflict assets, provider identities and hashes, adapter modes, decisions, mappings, Vanilla identity and output-relevant priority winners must still match.
2. Semiauto is enabled by default. RC21 sound-schema-2 settings migrate once to schema 3 so an assigned Semiauto sound is audible unless its profile is `None`; choosing a concrete Semiauto sound also enables the per-step switch.

New build manifests use schema 9 and store `AnalyzedSharedAssets` so future automatic patches can prove the complete shared topology before expensive adapters run. `KnownRecipeAuto` additionally pins RecipeId/output provider, exact cooked-output evidence and the production-recipe library hash. RC21 schema-8 patches may use the fast path only when every unpatched shared group has an exact safe `Identical` cache proof and no unpinned known recipe is involved. Otherwise normal Analyze runs; Build is skipped only after the complete resulting recipe/output evidence matches.

Do not simplify this to a patched-mod-name subset check. A newly added provider, shared group, provider hash, adapter/decision, mappings/Vanilla identity or relevant winner must invalidate reuse and force normal analysis/build handling.

## Stable UI/workflow contract

`Detect if needed → Import → [Fix Lab if needed: Game Reference → choose output → Repair → Deploy Fix] → Analyze → [Build only when needed] → Deploy → Play ready`

- Startup attempts Palworld detection automatically.
- Header detection status is the Detect button and disables itself once the path is valid.
- `Auto ON` continues a user-started action; `AUTO` is a one-shot continuation.
- ColorFlow always ends on Play after a current deployment; automatic launch remains separately opt-in.
- Settings Restore defaults does not touch language, paths, library content or user data.
- Sound profiles remain Auto, Semiauto, Manual, Attention required and Error. The Error default label is `3 beeps` / `3 pitidos`; keep internal ID `Microwave3`.

## Analyze and saved-patch safety contract

Plan schema remains 17. Caches and saved-patch proofs are performance aids, not new merge authorities:

- `PakIndexesV1` stores entry names only.
- `AnalyzeGroupsV2` stores only decision-free safe automatic results.
- Exact-plan reuse still requires unchanged complete plan identity.
- Effective-patch reuse deliberately ignores only unique/non-conflicting source-set differences after proving current topology.
- Unsupported, unresolved PackageChoice/decisions, mismatched provider topology/hashes, changed mappings/Vanilla/engine, changed output-relevant order and experimental manual solutions outside an exact source set cannot reuse a patch.
- `Analyze -Force` bypasses plan, group and patch reuse.
- Deploy must synchronize the current active/disabled source PAKs even when the overlay itself is reused.

## Existing AIIO safety contract

Entrypoint: `Modules/AIIO/AIIO.ps1`.

- Analyze is separate from AIIO.
- AIIO packages only exact current Unsupported review cases after explicit user action.
- Never include whole source PAKs.
- Keep provider and Vanilla origins separate.
- Validate current plan identity, provider/source hashes, input hashes and case schema.
- Preserve budgets, safe Windows archive semantics, cleanup and cross-process serialization.
- Structural validation is not runtime proof; AI/manual outputs remain experimental until tested in game.
- Do not enable unsigned remote Knowledge or automatic feedback upload.

## Planned user-facing module

The visible tab is **AI & Help**; AIIO remains the internal engine. Reuse the existing AIIO, CKL, Game Reference, Fix Lab, Operations, Library and deployment services. The visible action that makes a repair effective is **Apply Fix**. Keep expensive work off the WPF dispatcher and preserve supervised workers, progress, cancellation, exact-hash provenance and rollback.

## Primary files to audit

- `Modules/AIIO/AIIO.ps1`
- `Modules/Bootstrap/Start-PalModMerger.ps1`
- `Modules/Operations/OperationWorker.ps1`
- `Modules/Merge/MergeEngine.ps1`
- `Modules/Merge/PakService.ps1`
- `Modules/Library/LibraryService.ps1`
- `Modules/FixLab/FixLabService.ps1`
- `Modules/GameReference/*`
- `Modules/Shared/Common.ps1`
- `Modules/Shared/Paths.ps1`
- `Resources/UI/MainWindow*.xaml`
- `Resources/Metadata/RELEASE_MANIFEST.json`
- `CKL/*`

## Handoff hygiene and validation boundary

Keep the repository/source ZIP and AIIO continuity ZIP as separate attachments and supply them together. Never include `Workspace`, user mods/saves/logs, game PAK/UCAS/UTOC files, test assets, secrets or proprietary Oodle DLLs.

RC22 has cross-platform static/model validation but still requires Windows WPF plus real Palworld acceptance. Before calling it final, test startup, both languages, Semiauto in AUTO, unique-mod enable/disable reuse, negative conflict/provider changes, Deploy synchronization, forced Analyze, Build, rollback and Play-ready ColorFlow.
