# Palworld Manager Merger 1.3.0 RC25

Build ID: `PMM-v1.3.0-RC25-RESPONSIVE-THEMES-ANALYZE-PROGRESS`

RC25 is an editable PowerShell/XAML/data delta over RC24. No native executable, managed DLL, mappings file, runtime recipe payload or schema version changed.

## Real RC24 Analyze evidence

The supplied `24.7z` Workspace contained two active complete Gura outputs: Hooded (~200 MiB) and Full Replacement (~207 MiB). The support log records 79 started shared groups before cancellation, 72 of them involving this exact pair. Early hair families were quick, but female outfit variants took approximately 40–43 seconds each. Every sampled large family ended in the existing safe rejection paths: contained-delta size guard or a secondary `.uasset` size change.

This was not a deadlocked `repak` child; every extraction already had a 180-second timeout. It was valid but useless traversal of mutually exclusive full replacements.

## Implementation delta

- `CKL/Stable/package-rules.json`: five Gura Fix Lab outputs are `anyTwoActive` alternatives with one single-output choice each.
- `MergeEngine.ps1`: explicit package-rule trigger handling runs before `Get-PMMAssetGroups`; an unresolved choice returns immediately. After choice, only the selected effective provider set is enumerated and the others become deployment suppressions.
- Analyze progress now names the current `index/count` asset leaf and logs groups taking at least five seconds.
- Fresh layout is 1460×900; normal minimum is 900×600; startup clamps against WPF work area. Highly scaled extreme widths relax the two main column minima and reflow header actions to row two.
- Eleven complete schemes ship under `Resources/Themes`; PMM Crystal is fresh/Restore default while existing valid selections remain unchanged.
- `Modules/Theme/ThemeService.ps1` owns bundled/user discovery, strict ID/schema parsing, contrast checks and transactional bounded JSON/ZIP import.
- Disabled Detect uses an opaque neutral surface. This fixes Aurora Confetti's prior real-state contrast issue; all eleven pass the same matrix.
- Shared `DispatcherTimer` presentation smooths universal, AIIO, Fix Lab and Game Reference progress bars. Visible values are floored and never exceed the worker target.

## Regression assets

- `Development/Tests/rc25_release_model.py`
- inherited `rc24_ui_fixlab_ownership_regression.ps1` and model
- inherited RC23 singleton and RC22 patch-reuse models
- `Development/Docs/Validation/RC25_STATIC_VALIDATION.md`

Windows/WPF/Palworld acceptance remains mandatory before changing the label from release candidate to final.
