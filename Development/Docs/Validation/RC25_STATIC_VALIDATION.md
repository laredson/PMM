# RC25 static validation

Date: 2026-08-30  
Build: `PMM-v1.3.0-RC25-RESPONSIVE-THEMES-ANALYZE-PROGRESS`

## Passed in the cross-platform build workspace

- `Development/Tests/rc22_patch_reuse_model.py` — `RC22_REGRESSION_MODEL_OK`
- `Development/Tests/rc23_singleton_guard_model.py` — `RC23_SINGLETON_GUARD_MODEL_OK`
- `Development/Tests/rc24_ui_fixlab_ownership_model.py` — `RC24_UI_FIXLAB_OWNERSHIP_MODEL_OK`
- `Development/Tests/rc25_release_model.py` — `RC25_RELEASE_MODEL_OK`
- 48 release JSON documents parsed successfully.
- all three localized XAML documents parsed successfully, have unique `x:Name` values and identical control-name sets.
- all eleven bundled schemes have unique V1 IDs, exactly 46 palette keys, all five ColorFlow states and pass the implemented 4.5:1 contrast matrix.
- the ten official theme files match their source handoff SHA-256 values; the eleven-file RC25 bundled manifest also matches every file.
- the Gura rule resolves the supplied Hooded + Full Replacement pair to exactly two available choices and suppresses the unselected output.
- source ordering proves package-choice preflight occurs before `Get-PMMAssetGroups` enumeration.
- the progress model proves 10→22 as integer steps over 3000 ms, and a newer 30 target while behind catches up only to the proven 22 before animating 23→30 over 3000 ms. Repeated same-target status messages do not reset pacing.
- PowerShell tree-sitter scan found zero parse-error regressions versus RC24 in existing files; the new `ThemeService.ps1` has zero error/missing nodes. This is an additional structural check, not a substitute for Microsoft's Windows PowerShell parser.
- 341 existing executable/DLL/mappings/recipe-payload/sound/image assets are byte-identical to RC24.
- the standalone release tree and repository `PMM/` tree are byte-identical apart from the intentional release-root-only `BUILD_ID.txt` and the corresponding one-line difference in their internal checksum manifests.
- no `Workspace`, user state, PAK/UCAS/UTOC, Oodle DLL or symlink is shipped.

## Evidence from the supplied RC24 Workspace

- active complete alternatives: `GawrGura_hooded-gura_P.pak` and `GawrGura_fullreplacement-3skins_P.pak`;
- 79 shared groups started before cancellation;
- 72 groups involved that exact pair;
- the pair occupied at least 347 seconds of the captured run;
- sampled female-outfit groups took about 40–43 seconds each;
- sampled outcomes were safe Unsupported results caused by the contained-delta size guard or changed secondary `.uasset` size;
- each `repak get` already had a 180-second timeout, so the correction is early package intent, not weakening the merge adapters or merely extending a timeout.

## Not executable in this environment

The build workspace has no Windows PowerShell 5.1, WPF desktop, Windows DPI stack, Steam/Palworld installation or game runtime. Therefore the following remain mandatory before final promotion:

1. Microsoft's PowerShell parser and repository Windows regression scripts;
2. WPF startup, resize and multi-DPI acceptance;
3. all-theme real-control review and JSON/ZIP import behavior;
4. real supplied Gura pair preflight → choice → second Analyze;
5. Build/reuse/Deploy/Play-ready and RC24 deployed-merge ownership regression;
6. in-game acceptance.

The user-facing checklist is in `PMM/Documentation/RC25_RELEASE_CANDIDATE.md`.
