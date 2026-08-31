# Palworld Manager Merger 1.3.0 RC21

Build ID: `PMM-v1.3.0-RC21-CLEAN-RECONCILED-RELEASE-CANDIDATE`

RC21 is a clean reconciliation over the complete user-tested RC19 application tree. RC20-1 was used only as a design reference for the successful header/detection concept and initial cache idea. The GitHub RC20-2 implementation was inspected read-only and rejected as a runtime base because it had lost major RC19 bootstrap/XAML behavior.

## User-visible changes

- Transparent 512×512 PMM logo and three-line PALWORLD / MANAGER / MERGER header.
- Installation status is the Detect action; it remains visible and is disabled when Palworld is valid.
- Automatic startup detection with one Steam-or-Palworld fallback chooser after a failed user-triggered search.
- Apply changes and Restore defaults at the upper right of Settings. Restore stages only interface, hint and audio defaults.
- ColorFlow always ends on Play with the localized ready-to-play hint after a current deployment; auto-launch remains opt-in.
- The separate Error cue is labeled `3 beeps` / `3 pitidos`, retaining the RC19-tested audio and internal compatibility ID.

## Analyze optimization

- Plan schema 17.
- Persistent `repak list` entry-name cache: `Workspace/Cache/PakIndexesV1`.
- Safe deterministic group cache: `Workspace/Cache/AnalyzeGroupsV2`.
- Exact-plan reuse only for unchanged plans with zero rows and exclusively safe automatic modes.
- Unsupported, PackageChoice, KnownRecipeAuto, ManualSolutionExperimental and all decision-bearing results are never cached.
- Forced Analyze bypasses exact-plan and group-result reuse.

## Preserved baseline

RC19 Fix Lab, package-choice handling, decision guards/styling, event-sound UI, Saves, Game Reference, AIIO safety, deployment hash checks and rollback behavior remain intact. No RC20 file was copied wholesale over those functional areas.

## Validation

Run `Development/Scripts/validation/RUN_VALIDATION.cmd` on Windows. Static validation is not a substitute for final Windows WPF and real Palworld Analyze/Build/Deploy testing.
