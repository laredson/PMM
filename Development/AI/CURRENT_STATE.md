# PMM — CURRENT STATE

## Release authority

- Product: **Palworld Manager Merger**
- Creator: **laredson**
- Candidate: **v1.3.0 RC29 — AI & Help feedback and UI fix**
- Build ID: `PMM-v1.3.0-RC29-AIHELP-FEEDBACK-UI-FIX`
- Runnable authority: `PMM/`
- Native executables: unchanged from the accepted RC21 binary lineage

RC29 is built directly on the executed RC28 and preserves RC22–RC28: effective compatibility-patch reuse after unrelated mod-list changes, singleton collection guards, Fix Lab/merge deployment isolation, responsive 900×600/high-DPI layout, Gura variant preflight, official/user theme separation, immediate confirmed 100%, full SHA-256 validation IDs, schema-3 deployment normalization, the exact runtime-proven FasterMounts/RushRoar semantic rule and the local-first AIIO workspace. RC29 fixes delayed callback scope, duplicate error/session creation, badge semantics, validation-dialog sizing, header order, optional Play readiness and stale selected-row colors after a theme change.

## Current product surface

`Mods & Merge -> FIX LAB -> AI & Help -> Saves -> Settings`

AI & Help provides described Help and AI repair views, inspectable manual Feedback, persistent AIIO sessions, manual bounded ZIP exchanges, strict response staging, Knowledge/storage/recovery, the theme editor and AI-specific Settings. Long AIIO work and recursive artifact inventory run through `Modules/Operations/OperationWorker.ps1`, not the WPF dispatcher.

The only AI transport in RC29 is user-mediated ZIP. Feedback transport is inspectable local JSON and manual sharing. There is no provider authentication or automatic upload. AI data cannot execute arbitrary code, apply a fix, build, deploy, publish or promote Knowledge. Only an exact current manual cooked-family candidate can be explicitly submitted to normal Merge validation; it remains experimental/unproven and forces Analyze.

## Workflow and ownership

`Detect if needed -> Import -> Fix Lab if required -> Analyze -> Build if required -> Deploy -> Play ready`

Analyze plan schema is 18 and build-manifest schema is 9. Unique non-conflicting PAK changes can reuse an overlay only when the complete saved topology/evidence contract remains exact. Fix Lab Apply/Restore, source-mod operations and AI & Help preserve the deployed compatibility patch. Only Deploy/No compatibility patch, UNDEPLOY and Delete merge own that namespace.

## Packaging policy

`PMM/` is the distributable application. Never commit or ship `PMM/Workspace/`, user PAKs/saves/logs, Game Reference data, extracted Vanilla content, credentials, UCAS/UTOC files or `oo2core_9_win64.dll`.

The native source snapshot under `Development/Source/` is older/incomplete relative to the packaged binary behavior. Do not overwrite `PMM.exe`, `PMMRuntime.exe`, `PMMFixLab.exe` or managed binaries until source/binary reconciliation and Windows tests pass.

## Acceptance boundary

Static validation proves schemas, hashes, XAML parity, security invariants and archive integrity. Windows acceptance remains mandatory. Follow `PMM/Documentation/TEST_THIS_BUILD_RC29.txt` before publishing.
