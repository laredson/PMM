# Palworld Manager Merger 1.3.0 RC26

Build ID: `PMM-v1.3.0-RC26-OFFICIAL-THEMES-PROGRESS-COMPATIBILITY`

RC26 is an editable PowerShell/XAML/data delta over RC25. Native executables, managed binaries, mappings and build-manifest schema remain unchanged.

## Implementation delta

- Settings renders release/built-in schemes in `PnlThemeOptions` and imported definitions in `PnlUserThemeOptions`. All eleven validated JSON definitions, including Aurora Confetti, are official; Night and Light remain official built-ins.
- `Set-PMMSmoothedProgressBar` treats a reported 100% as an immediate operation boundary and removes pending animation state before returning.
- The production FasterMounts/RushRoar recipe contains one runtime-proven `semanticFallback` for the exact Boar MonsterFarm DataTable path and exact canonical 10/1 provider tuple.
- `Get-PMMDataTableCompatibilityResolution` evaluates that data rule only after PMMCore independently exposes the current scalar conflict. Matching conflicts become hidden `AutomaticResolutions`; unmatched conflicts remain normal decision rows.
- Build passes automatic resolutions back through `DataTableScalarTransfer-v2`, so current cooked families are merged rather than copying historical output bytes.
- Analyze plan schema is 18. Plans and decision-free group-cache keys pin `KnowledgeRulesSha256`.
- Patch manifests retain `AutomaticResolutions`; runtime/plan reuse pins `ProductionRecipesSha256` and compares deterministic automatic-resolution signatures.

## Regression assets

- `Development/Tests/rc26_official_themes_progress_compatibility_model.py`
- `Development/Tests/rc26_semantic_compatibility_regression.ps1` (target Windows PowerShell 5.1)
- inherited RC25 responsive/theme/Gura/progress model
- inherited RC24 deployment-ownership, RC23 singleton and RC22 reuse models
- `Development/Docs/Validation/RC26_STATIC_VALIDATION.md`

Windows PowerShell 5.1, WPF and Palworld acceptance remain mandatory before public promotion.
