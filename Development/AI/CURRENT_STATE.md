# PMM — CURRENT STATE

## Release authority

- Product: **Palworld Manager Merger**
- Creator: **laredson**
- Candidate: **v1.3.0 RC27 — AIIO local-first**
- Build ID: `PMM-v1.3.0-RC27-AIIO-LOCAL-FIRST`
- Runnable authority: `PMM/`
- Native executables: unchanged from the accepted RC21 binary lineage

RC27 is built directly on RC26 and preserves RC22–RC26: effective compatibility-patch reuse after unrelated mod-list changes, singleton collection guards, Fix Lab/merge deployment isolation, responsive 900×600/high-DPI layout, Gura variant preflight, official/user theme separation, immediate confirmed 100% and the exact runtime-proven FasterMounts/RushRoar semantic rule.

## Current product surface

`Mods & Merge -> FIX LAB -> AI & Help -> Saves -> Settings`

AI & Help now exists. It provides local diagnostics, persistent AIIO sessions, manual bounded ZIP exchanges, strict response staging, Knowledge/storage/recovery views, build validation/feedback and the theme editor. Long AIIO work and recursive artifact inventory run through `Modules/Operations/OperationWorker.ps1`, not the WPF dispatcher.

The only AI transport in RC27 is user-mediated ZIP. There is no provider authentication or automatic upload. AI data cannot execute arbitrary code, apply a fix, build, deploy, publish or promote Knowledge. Only an exact current manual cooked-family candidate can be explicitly submitted to normal Merge validation; it remains experimental/unproven and forces Analyze.

## Workflow and ownership

`Detect if needed -> Import -> Fix Lab if required -> Analyze -> Build if required -> Deploy -> Play ready`

Analyze plan schema is 18 and build-manifest schema is 9. Unique non-conflicting PAK changes can reuse an overlay only when the complete saved topology/evidence contract remains exact. Fix Lab Apply/Restore, source-mod operations and AI & Help preserve the deployed compatibility patch. Only Deploy/No compatibility patch, UNDEPLOY and Delete merge own that namespace.

## Packaging policy

`PMM/` is the distributable application. Never commit or ship `PMM/Workspace/`, user PAKs/saves/logs, Game Reference data, extracted Vanilla content, credentials, UCAS/UTOC files or `oo2core_9_win64.dll`.

The native source snapshot under `Development/Source/` is older/incomplete relative to the packaged binary behavior. Do not overwrite `PMM.exe`, `PMMRuntime.exe`, `PMMFixLab.exe` or managed binaries until source/binary reconciliation and Windows tests pass.

## Acceptance boundary

Static validation proves schemas, hashes, XAML parity, security invariants and archive integrity. Windows acceptance remains mandatory. Follow `PMM/Documentation/TEST_THIS_BUILD_RC27.txt` before publishing.
