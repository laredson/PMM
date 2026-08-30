# RC27 static validation record

Candidate: `PMM-v1.3.0-RC27-AIIO-LOCAL-FIRST`  
Date: 2026-08-30

## Passed in the build environment

- 48 application JSON documents parsed.
- Default, English and Spanish XAML parsed with 271 unique `x:Name` controls each and exact control-set parity.
- All eleven official JSON themes match both release manifests and pass the exact 4.5:1 runtime contrast matrix; the lowest observed ratio is 5.2878:1.
- Every newly added PowerShell service parses without a tree-sitter error. Modified legacy files introduce no parse-error delta from the RC26 baseline.
- `Development/Tests/rc27_aiio_local_first_model.py` passes, including the RC25/RC26 theme, Gura, progress and exact semantic-rule models plus RC27 AIIO/header/theme-editor/Fix Lab ownership assertions.
- `PMM.exe`, `Engine/`, `MergeEngine.ps1`, `KnowledgeRecipeService.ps1`, `production-recipes.json` and `package-rules.json` are byte-identical to RC26.
- Fix Lab service differences from RC26 are user-facing `Deploy Fix` -> `Apply Fix` wording only; its deployed compatibility-merge isolation markers remain present.
- New AIIO/operation/save/theme-editor services contain no web-request client, credential token, `Invoke-Expression` or returned-code execution path.
- The portable tree contains no runtime `Workspace`, user PAK/UCAS/UTOC payload, Oodle DLL or `.git` metadata.
- Portable and repository application checksum manifests verify every included application file.

## Not proven here

The build environment does not provide Windows PowerShell 5.1, WPF, .NET/Go build toolchains, Steam or Palworld. Therefore startup, DPI/layout behavior, native/external-tool execution, audio, real ZIP round-trips, real Analyze/Build/Deploy and in-game semantics require the Windows acceptance checklist in `PMM/Documentation/TEST_THIS_BUILD_RC27.txt`.

Static PASS does not promote an experimental AI candidate or compatibility build to runtime-proven status.
