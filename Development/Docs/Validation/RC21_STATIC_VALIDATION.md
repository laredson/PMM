# PMM 1.3.0 RC21 static validation — 2026-08-30

- Build ID: `PMM-v1.3.0-RC21-CLEAN-RECONCILED-RELEASE-CANDIDATE`
- Authority: complete user-tested RC19 application reconciled with the accepted RC21 delta.
- JSON parsed: 35 files.
- XAML parsed with name parity: 208 controls per language.
- Bootstrap control bindings found in XAML: 207.
- Tree-sitter PowerShell error-node counts match clean RC19 for the three changed scripts: `{"Modules/Bootstrap/Start-PalModMerger.ps1": 13, "Modules/Merge/MergeEngine.ps1": 4, "Modules/Merge/PakService.ps1": 0}`.
- Release SHA256SUMS verified: 428 files.
- Repository PMM SHA256SUMS verified: 427 files.
- Forbidden/runtime-local payload gate: no Workspace, PAK/UCAS/UTOC, `.git`, or `oo2core_9_win64.dll` included.
- Source-authority gate: packaged native binaries were preserved; the older/incomplete native source snapshot was not rebuilt.

Environment limitation: Go, Windows PowerShell/WPF, PMM.exe, Steam and Palworld are unavailable in this Linux packaging environment. The final acceptance gate remains the documented Windows `Validate-v1.3.ps1`, `SmokeTest.ps1`, packaged binary self-tests and a real Import/Analyze/Build/Deploy/Play smoke test.
