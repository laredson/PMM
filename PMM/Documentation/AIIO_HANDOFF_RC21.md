# AIIO continuation handoff — PMM 1.3.0 RC21

> Historical RC21 reference. Continue from `AIIO_HANDOFF_RC24.md`, which preserves this baseline, the RC22 effective-conflict/Semiauto corrections, the RC23 Windows PowerShell singleton guard and the RC24 UI/deployment-ownership boundary.

## Start here

Use this document together with the separate AIIO continuity package. In that package, read `PMM_AIIO_MASTER_HANDOFF_2026-08-29.md` first; it remains the authority for AIIO product decisions. Then inspect the exact RC21 source tree supplied with this handoff before changing code. Do not redesign AIIO from scratch and do not use either RC20 implementation as a replacement baseline.

Product identity:

- **Palworld Manager Merger (PMM)**
- Creator: **laredson**
- Stable development baseline: **1.3.0 RC21**
- Build ID: `PMM-v1.3.0-RC21-CLEAN-RECONCILED-RELEASE-CANDIDATE`

## RC21 authority and provenance

RC21 preserves the complete RC19 functional tree and selectively integrates only the successful header/detection ideas from RC20-1. The GitHub `1.3.0final` RC20-2 implementation lost large parts of the RC19 bootstrap and XAML and must not be used as a base. Keep an unmodified RC21 checkpoint before beginning AI & Help work.

## Stable UI/workflow contract

`Detect if needed → Import → [Fix Lab if needed: Game Reference → choose output → Repair → Deploy Fix] → Analyze → Build → Deploy → Play ready`

- Startup attempts Palworld detection automatically.
- Header detection status is itself a button. It remains visible and is disabled once the path is valid; a failed click falls back to choosing Steam or Palworld.
- `Auto ON` continues a user-started action; `AUTO` is a one-shot continuation.
- `Run Palworld after Deploy` controls automatic launch only. ColorFlow always ends on the illuminated Play button after a current deployment.
- The ready hint is `Everything is ready to play.` / `Ya está todo listo para jugar.`
- Settings changes are staged. Restore defaults does not touch language, paths, library content or user data.
- Visible sound profiles remain Auto, Semiauto, Manual, Attention required and Error. The Error default is labeled `3 beeps` / `3 pitidos`; keep internal ID `Microwave3` and `PMM_microwave_3beeps.wav` for compatibility.

## Analyze cache contract

RC21 plan schema is 17. These caches are performance aids, never new merge authorities:

- `Workspace\Cache\PakIndexesV1`: entry names only, fingerprinted by full path, size and UTC write time.
- `Workspace\Cache\AnalyzeGroupsV2`: only decision-free `Identical`, `BinaryAuto`, `StaticItemAuto`, `DataTableAuto`, `SupersetAuto`, `ContainedSupersetAuto` and `RelocatableAuto` results.
- Exact-plan reuse requires zero rows, exclusively those safe modes, and unchanged source, priority, mappings and Vanilla identity.
- Never cache Unsupported, PackageChoice, KnownRecipeAuto, ManualSolutionExperimental or any decision-bearing result.
- `Analyze -Force` bypasses exact-plan and group-result reuse.

Do not broaden those modes merely to improve a benchmark. Any future cache expansion needs an explicit proof that it cannot conceal a changed decision, recipe, provenance record or Unsupported case.

## Existing AIIO safety contract

Entrypoint: `Modules/AIIO/AIIO.ps1`.

- Analyze is separate from AIIO.
- AIIO packages only exact current Unsupported review cases after explicit user action.
- Never include whole source PAKs.
- Extract only exact provider/Vanilla file families and keep origins separate.
- Validate current plan identity, provider/source hashes, input hashes and case schema.
- Preserve raw/compressed budgets, safe Windows archive semantics, transient cleanup and cross-process serialization.
- An AI/manual solution remains experimental until the exact output is tested in game; structural validation is not runtime proof.
- Do not enable unsigned remote Knowledge or automatic feedback upload.

## Planned user-facing module

The visible tab is **AI & Help**; AIIO is the internal engine. Move/reuse existing service actions rather than duplicating implementations:

1. Ask AI / repair and compatibility help.
2. Current Unsupported cases and bounded handoff creation.
3. CKL/Knowledge inspection.
4. Tested community contribution packaging.
5. Optional `PMM_COLOR_SCHEME_V1` customization help.
6. Diagnostics/help and emergency handoff paths.

The visible action that makes a repair effective is **Apply Fix**. Keep PAK work off the WPF dispatcher, reuse supervised workers/progress, avoid modal success dialogs, preserve rollback and exact-hash provenance, and do not turn UI refresh failures into processing failures.

## Primary files to audit

- `Modules/AIIO/AIIO.ps1`
- `Modules/Bootstrap/Start-PalModMerger.ps1`
- `Modules/Operations/OperationWorker.ps1`
- `Modules/Merge/MergeEngine.ps1`
- `Modules/Merge/PakService.ps1`
- `Modules/Library/LibraryService.ps1`
- `Modules/FixLab/FixLabService.ps1`
- `Modules/GameReference/*`
- `Modules/Shared/Paths.ps1`
- `Resources/UI/MainWindow*.xaml`
- `Resources/Metadata/RELEASE_MANIFEST.json`
- `CKL/*`
- `Documentation/AI_HANDOFF_AND_KNOWLEDGE.md`
- `Documentation/MANUAL_SOLUTION_CONTRACT.md`

## Handoff hygiene

The repository/source package and AIIO continuity package are separate attachments and should be supplied together. Do not include `Workspace`, user mods/saves/logs, game PAK/UCAS/UTOC files, test assets, secrets or a proprietary Oodle DLL in development handoffs or public builds.
