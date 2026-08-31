# PMM 1.3.0 RC25 — responsive themes and bounded Analyze

Build ID: `PMM-v1.3.0-RC25-RESPONSIVE-THEMES-ANALYZE-PROGRESS`

RC25 is the publication candidate built directly on RC24. It keeps the RC24 Fix Lab/merge-deployment ownership boundary, deferred dashboard refresh, the RC23 PowerShell 5.1 singleton guards, and RC22 effective-conflict patch reuse.

## What changed

### 1080p and DPI layout

- Fresh size is 1460×900 DIPs; the normal minimum is 900×600.
- Startup clamps saved/default dimensions to the current Windows work area.
- Below the normal minimum on highly scaled screens, the library and analysis columns temporarily relax instead of forcing a pane off-screen.
- Below 840 DIPs, header actions move to a second row; the logo/title and tab workspace remain visible.
- Compact resizing does not overwrite the user's remembered wide library divider.

A standard 1920×1080 desktop therefore fits the default window. Windows scaling still needs the acceptance run below because this package cannot execute WPF in the cross-platform build environment.

### Color schemes

RC25 bundles eleven complete `PMM_COLOR_SCHEME_V1` schemes. PMM Crystal is the fresh-install/Restore-defaults choice; upgrades preserve a valid existing Night, Light or custom ID.

Settings accepts one/many JSON files or a bounded ZIP. Import is data-only and parse-all-before-commit. It rejects traversal, links, nested archives and executable/script content; protects bundled IDs; confirms/backs up user replacements; and applies the same 4.5:1 real-surface contrast matrix used for the bundled set.

The original ten-theme handoff manifest is retained as source provenance. `Resources/Themes/BUNDLED_THEME_MANIFEST.json` is the RC25 runtime manifest and adds the separately supplied Aurora Confetti after the detected-install control moved to an unfaded neutral surface. All eleven pass.

### Analyze 60–77% diagnosis and correction

The supplied RC24 Workspace contained both:

- `GawrGura_hooded-gura_P.pak` (about 200 MiB);
- `GawrGura_fullreplacement-3skins_P.pak` (about 207 MiB).

They are complete alternatives, not two independent mods to merge. The log records 79 started shared groups before cancellation; 72 involved that exact pair. Large female-outfit families each consumed roughly 40–43 seconds because PMM extracted both providers and Vanilla and then correctly rejected the structural composition (`contained-delta size guard exceeded` / changed `.uasset` size). The worker was progressing, but through work that could never produce a valid combined output.

RC25 declares all five Gura Fix Lab outputs mutually exclusive. When any two are active, Analyze pauses **before PAK asset enumeration**, presents only the available variants in Resolution & Review, and asks the user to choose. Run Analyze again after the choice; the alternative remains available in PMM's local library but is excluded from analysis and the next deployment. Existing 180-second per-`repak get` timeouts remain in force for unrelated malformed/stalled extraction cases.

### Honest smoothed progress

Determinate WPF bars now present each newly proven range in integer points over approximately three seconds. For example, 10→22 is shown as 11, 12 … 22. If the worker reports 30 while that animation is behind, presentation may catch up only to the already proven 22 and then animate 23 … 30. It never displays more than the worker has reported. Indeterminate phases and new operations reset stale percentages.

## Windows acceptance before final promotion

1. Open on a 1920×1080 desktop at 100%, then test 125%, 150% and any available multi-monitor DPI transition. Resize continuously to the minimum. No state may leave only the logo visible.
2. Check all four tabs in English and Spanish at default and minimum sizes; verify Settings remains vertically scrollable and Fix Lab paints before refresh.
3. Apply every bundled theme. Check buttons, disabled Detect, selected/alternate rows, Fix Lab cards, Resolution & Review and all ColorFlow states. Restart and confirm the chosen scheme persists.
4. Import a valid JSON and the official ZIP pack; verify duplicates are skipped. Try traversal/nested archive/script content and an invalid-contrast scheme; the whole invalid selection must remain uncommitted.
5. With Hooded + Full Replacement active, run Analyze. It must stop quickly at one package decision without extracting female-model families. Choose Full Replacement and Analyze again; Hooded must be listed in deployment suppressions and the normal non-Gura conflicts must still analyze.
6. Repeat with only one Gura output: no package decision is expected.
7. Observe a real progress jump with a long operation. The bar moves one integer point at a time, never exceeds worker progress, resets on a new operation and still reaches the final result.
8. Re-run the RC24 merge-ownership test: Fix Lab Apply/Restore and source enable/disable/delete must preserve the deployed compatibility merge and sidecar byte-for-byte.
9. Run the repository Windows validation/smoke scripts, then a normal Analyze → Build/reuse → Deploy → Play-ready cycle in Palworld.

Cross-platform structural/model validation is necessary but is not Windows/WPF/Palworld runtime proof. Promote RC25 to final only after this checklist passes on the target PC.
