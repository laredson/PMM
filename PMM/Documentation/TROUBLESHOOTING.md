# Troubleshooting

## Analyze says Unsupported

This is not necessarily proof that the mods are incompatible. It means no current safe adapter proved the composition.

Try:

1. Open the blocked asset details.
2. Review the involved providers.
3. Use the suggested least-impact disable option if you just want a build now.
4. Or use **CREATE AI HANDOFF** to export one AIIO bundle containing all current Unsupported cases and only their exact source files.

## Build is disabled

Common reasons:

- unresolved True Conflict;
- Unsupported asset with no accepted manual solution;
- Analyze state is stale after changing source mods;
- source hashes/mappings changed since Analyze.

Analyze again after changing the library.

## Deploy is disabled

A matching current/saved patch may not exist yet. Run Analyze: PMM accepts either an exact source-set match or a saved patch whose effective conflict participants, hashes, adapters, decisions, mappings and Vanilla identity still match.

## A saved patch radio button is disabled

That patch has not been proven for the current active set. Run Analyze so PMM can test effective-conflict-set compatibility. If a conflict participant, provider hash, adapter, decision, mapping or Vanilla identity changed, re-enable the original source set or build a new patch.

## Game folder contains an unknown same-name PAK

PMM intentionally refuses to overwrite/delete a file it cannot identify as managed. Move/rename/inspect the external PAK yourself before retrying.

## A manual AI solution imports but does not work in-game

Structural validation is not gameplay validation. Remove/disable the experimental solution, return to a known safe source set, and keep the handoff + solution + FAIL runtime report for further investigation.

## Save restore

Do not interrupt restore deliberately. PMM creates a safety backup before replacing the world, but keeping independent backups is still recommended.

## Build completion reports that `Count` does not exist

RC22 could finish packing a valid compatibility PAK and then show this Windows PowerShell error while refreshing the saved-patch list when the manifest contained exactly one `KnownRecipeAuto` asset. RC23 and later keep zero/one/many manifest results as explicit arrays and fix the equivalent reuse paths. Keep the existing `Workspace`: after starting the current build, the completed PAK and schema-9 manifest in `Workspace/Builds/Current` should be recognized without rebuilding.

## Resizing leaves only the logo or makes the header fill the window

RC23 could starve the title column when the action column kept its minimum width, especially near the minimum window size or after a DPI transition. The wrapped subtitle then became nearly one character wide and made the automatic header row extremely tall. RC24 gives the title a stable width and lets the action area stretch/wrap. If this still occurs, send the current window dimensions, Windows scaling percentages and `Workspace/State/config.json`.

## Fix Lab Apply/Restore removed a deployed compatibility merge

RC23 intentionally treated the existing merge as stale and removed its PAK plus sidecar during Fix Lab Apply/Restore. RC24 removes that cross-module behavior. Fix Lab and source-mod deletion preserve the deployed merge; only Deploy with a selected patch or `No compatibility patch`, UNDEPLOY, or Delete merge in **Compatibility patches** may change it. If RC23 already removed the merge, start RC24, run Analyze to reselect/reuse the saved build, then Deploy it once.

## Fix Lab takes time to appear or Advanced pauses when expanded

RC24 paints tab/expander changes before dashboard hydration, reuses cached state for sixty seconds and performs one shared discovery snapshot instead of duplicate scans. Use **Refresh Fix Lab** in the Fix Lab header when you want an immediate filesystem refresh.

## Logs

Use `Workspace/Logs/PalModMerger.log` for setup/Analyze/Build/Deploy history and send that **single file** when reporting a problem. v1.1.1 uses an append-only Smart Log: every physical line is timestamped, process sessions are marked, and exact consecutive repeats are coalesced into count + first/last-time checkpoints instead of flooding the file. Distinct diagnostic lines are preserved rather than rotated or truncated away. For developer reports, include PMM version, active source hashes where practical, the relevant AI_HANDOFF/review case, and exact error text.


## Compatibility patch row closes PMM / `EditItem`

RC6 could terminate the WPF UI when a user clicked a saved compatibility-patch row. The patch table was populated through `DataGrid.Items` but was incorrectly declared editable, so WPF could call `IEditableCollectionView.EditItem` on a view that does not permit edit transactions. RC7 made the patch table read-only while preserving radio selection and the Validate/Archive/Delete buttons. A non-selectable saved merge remains visible; import its exact sources or run Analyze so current PMM can prove whether its effective conflict recipe is still valid.
