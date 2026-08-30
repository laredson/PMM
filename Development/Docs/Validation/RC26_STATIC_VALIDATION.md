# RC26 static validation

Date: 2026-08-30  
Build: `PMM-v1.3.0-RC26-OFFICIAL-THEMES-PROGRESS-COMPATIBILITY`

## Passed in the cross-platform build workspace

- `Development/Tests/rc22_patch_reuse_model.py` — `RC22_REGRESSION_MODEL_OK`.
- updated `rc23_singleton_guard_model.py` — `RC23_SINGLETON_GUARD_MODEL_OK` with the expanded knowledge-authorized collection.
- updated `rc24_ui_fixlab_ownership_model.py` — `RC24_UI_FIXLAB_OWNERSHIP_MODEL_OK`.
- `rc26_official_themes_progress_compatibility_model.py` — `RC26_OFFICIAL_THEMES_PROGRESS_COMPATIBILITY_MODEL_OK`, including inherited RC25 theme contrast, Gura preflight, responsive UI and sub-100 progress behavior.
- The RC26 positive fixture selects FasterMounts for the exact `DT_PalMonsterParameter_Common` Boar MonsterFarm 10/1 conflict. Different path, 9/1, 10/2 and a third competing provider all remain unmatched.
- `rc26_semantic_compatibility_regression.ps1` has zero PowerShell tree-sitter error/missing nodes and is wired into the target Windows validator.
- New/changed PowerShell function bodies have zero tree-sitter errors. Full-file parser error/missing counts are identical to RC25 in Bootstrap, KnowledgeRecipeService, LibraryService and MergeEngine; the unchanged counts are known grammar limitations. Microsoft's parser remains the Windows authority.
- 48 application JSON documents parse in both portable and repository application trees.
- Default, English and Spanish XAML parse with 214 unique `x:Name` values each and exact control-name parity.
- Eleven JSON themes have unique IDs, matching official/bundled manifests and exact file hashes. Every bundled entry is `official-pack`; Aurora Confetti is included and no experiment is excluded. Night and Light remain two official built-ins.
- Schema-18 plans and decision-free group-cache keys pin the production-rule SHA-256. Schema-9 manifests preserve automatic resolutions; runtime/plan reuse requires the same production-rule hash and deterministic automatic-resolution signature.
- Build passes the hidden automatic resolution through the normal DataTable adapter; the stable JSON contains no cooked output bytes.
- 204 executable/DLL/mappings/sound/image/binary payload files are byte-identical to RC25. No native or managed binary was rebuilt.
- Internal SHA-256 inventories verify 454 portable files and 453 repository-application files, excluding each inventory file itself.
- Portable and repository `PMM/` are byte-identical outside the intentional portable-root `BUILD_ID.txt` and their tree-specific internal checksum inventories.
- No `Workspace`, user PAK/UCAS/UTOC, Oodle DLL, symlink, `.git` directory or generated Python cache is intended for either deliverable.

## Archive verification

- Portable ZIP: 455 extracted files.
- Git-root-ready ZIP: 689 extracted files.
- AIIO continuation ZIP: 47 extracted files.
- All three archives pass ZIP CRC and safe-name/case-collision/symlink checks.
- Each clean extraction is byte-identical to its staged source tree.
- Extracted portable, repository application and AIIO handoff checksum inventories verify successfully.
- Repeated forbidden-payload scans over all extracted trees return zero findings.

## Evidence and interpretation

The prior runtime-proven recipe records that RushRoar changes `Rows[Boar].WorkSuitability_MonsterFarm` to 1 while FasterMounts changes the same field to 10 and was the exact working output family. RushRoar's separate Boar Blueprint and spawn-action assets remain deployed. RC25 could expose 10 versus 1 as a generic decision when the exact cooked-family hash pins no longer matched. RC26 converts only this already-proven semantic relationship into an exact path/provider/value rule; it does not introduce a generic numeric preference.

## Not executable in this environment

The build workspace has no Windows PowerShell 5.1, WPF desktop, Windows DPI stack, Steam/Palworld installation or game runtime. These remain mandatory:

1. Microsoft PowerShell parser plus the Windows regression scripts, including `rc26_semantic_compatibility_regression.ps1`;
2. official/user theme rendering, selection/import/persistence and all-theme real-control review;
3. immediate confirmed 100% transition during a real multi-step workflow;
4. FasterMounts + RushRoar Analyze with zero user decision for the exact field, Build/Deploy and both behaviors in-game;
5. negative semantic-rule controls in a development fixture;
6. inherited RC25 responsive/DPI/Gura acceptance and RC24 deployed-merge ownership regression.

The user-facing checklist is in `PMM/Documentation/RC26_RELEASE_CANDIDATE.md` and `Development/Docs/Validation/TEST_THIS_BUILD.txt`.
