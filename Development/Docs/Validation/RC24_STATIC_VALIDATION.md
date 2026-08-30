# PMM 1.3.0 RC24 validation record

- Build ID: `PMM-v1.3.0-RC24-UI-FIXLAB-DEPLOYMENT-ISOLATION`
- Scope: responsive header geometry, deferred/optimized Fix Lab refresh and exclusive compatibility-merge deployment ownership.
- Basis: complete RC23 release tree plus the supplied real RC23 Workspace/log/transaction evidence.

## Completed static/cross-platform checks

- All 35 application JSON documents and all three XAML documents parse in both staged application trees.
- Default/English/Spanish contain the same unique `x:Name` set, no duplicates, the 245-DIP title column, stretch action grid and exactly one visible `BtnFixLabRefreshDashboard` each.
- `RC22_REGRESSION_MODEL_OK`, `RC23_SINGLETON_GUARD_MODEL_OK` and `RC24_UI_FIXLAB_OWNERSHIP_MODEL_OK` pass.
- The changed PowerShell files retain the same tree-sitter parser-error profile as RC23; the new RC24 regression script parses without a new grammar error. The Windows validator performs the authoritative `System.Management.Automation` parse/run.
- Fix Lab Deploy/Restore and source Enable/Disable/Delete function bodies do not address `zzzzzzzzzz_PMM_Merge_`.
- Source Delete does not clear deployment Patch state, deployment timestamp or saved-patch selection.
- The unused legacy `Restore-PMMDeployment` bulk-undeploy entry point is absent.
- Staged portable/repository trees contain 435/662 files and no Workspace, `.git`, PAK, UCAS, UTOC, Oodle or Python-cache payload.
- Portable/repository application content is byte-identical outside the release-only root `BUILD_ID.txt` and tree-specific checksum manifest.
- All 193 packaged EXE/DLL files are byte-identical to RC23/RC21 authority.
- Application SHA256SUMS contain 434 portable entries and 433 repository-application entries and verify successfully.

ZIP CRC, extracted-byte parity and final outer hashes are recorded after archive assembly.

## Target Windows acceptance

Static checks cannot prove WPF layout timing, PowerShell 5.1 dispatcher overload behavior or real Palworld deployment. Run the RC24 section of `TEST_THIS_BUILD.txt`, with special attention to continuous resize/DPI movement, immediate tab/Advanced painting, manual Refresh, and SHA-256 preservation of a deployed merge across Apply Fix, Restore original and source Delete.

Do not label RC24 final/runtime-tested until those Windows checks pass.
