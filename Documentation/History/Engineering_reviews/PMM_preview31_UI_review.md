# PalModMerger preview31 — UI/UX engineering review

## Why this version

The preview30 screenshot demonstrates the target compatibility routing:
`Shared 4 | auto 3 | decisions 1 | unsupported 0 | identical 0`. At this stage,
the highest-value work is not another merger architecture change; it is making
that information understandable and giving the workspace enough flexibility for
large mod libraries.

## Main changes

- Replaced the old one-line Analyze text box with an **Analysis Plan** dashboard.
- Added five counters: Shared, Auto merged, Decisions, Unsupported, Identical.
- Added one row per shared asset with result, adapter, provider mods and change count.
- Selecting an analysis row reveals full cooked path and adapter/reason detail.
- Added a scope line naming the mods whose shared changes enter the compatibility overlay.
- Added mod-library filter plus active / disabled / PMM-patch counts.
- Added draggable splitters for library/workspace, Analyze/conflicts and conflict list/details.
- Persisted window size and the three primary splitter positions in config.
- Added **Reset workspace layout** in Settings.
- Removed the obsolete Strategy ComboBox; ConflictGroups remains the fixed internal production mode.
- Moved close/force-close deployment settings beside Build/Deploy.
- Put Build, Deploy, Remerge, Rebuild and Restore in one action row.
- Changed Blocked shared assets to an Expander that stays compact when count is zero.
- Added a draggable divider to Saves.
- Applied a restrained card/table visual hierarchy and improved list selection/padding.

## Safety boundary

This is intentionally not a merge-engine iteration.

- PMMCore tree: unchanged from preview30.
- Mappings.usmap: unchanged from preview30.
- Core/LibraryService.ps1: unchanged from preview30 (Deploy transaction unchanged).
- Core/SaveService.ps1: unchanged from preview30.
- MergeEngine differences are only preview-number labels/log wording.
- AssetReader difference is only preview-number wording in one error message.

## Static QA

57 structured/control/contract checks passed with zero failures. XAML/XML/JSON
parse, all script-required XAML names match, the obsolete Strategy selector is
absent, the five lifecycle buttons share one action row, and critical proven
files match preview30 by hash.

This environment cannot execute Windows WPF, so visual clipping/interaction and
the final Palworld regression remain the user acceptance gate.

## Recommended acceptance pass

1. Start preview31 at normal window size.
2. Use the same Triple + Quad fixture and run Analyze.
3. Confirm 4 / 3 / 1 / 0 / 0 remains unchanged.
4. Confirm the four shared assets are visible in Analysis Plan with the correct providers.
5. Drag all three workspace splitters; close/reopen PMM and verify positions persist.
6. Confirm Blocked shared assets is collapsed at zero.
7. Resolve Triple, Build and Deploy.
8. Perform a short Palworld smoke test of Fly + Triple and the previously validated mods.
9. Use Settings > Reset workspace layout and verify the default layout returns.
