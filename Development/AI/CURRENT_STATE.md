# PMM — CURRENT STATE

## Release authority

- Product: **Palworld Manager Merger**
- Creator: **laredson**
- Candidate: **v1.3.0 RC30 — lean AI and validation flow**
- Build ID: `PMM-v1.3.0-RC30-LEAN-AI-VALIDATION-FLOW`
- Runnable authority: `PMM/`
- Native executables: unchanged from the accepted RC21 binary lineage

RC30 is built directly on the executed RC29 and preserves RC22–RC29. It fixes routed selection/rebinding, global refresh after validation, undersized repeat-validation controls, idle polling overhead, selected-case AI UX, direct new-case ZIP creation, response routing and false untouched-theme-draft contrast failures. Effective patch reuse, Fix Lab/merge ownership, responsive layout, Gura preflight, official/user theme separation, immediate confirmed 100%, deterministic validation, canonical deployment normalization, exact semantic rules and all local-first AIIO trust gates remain unchanged.

## Current product surface

`Mods & Merge -> FIX LAB -> AI & Help -> Saves -> Settings`

AI & Help provides five focused views: AI assistance, AI reception, Feedback & Knowledge, color-scheme editor and AI Settings. Selecting a case shows that case; New case exposes explicit PMM features and can save locally or create the safe ZIP directly. Standard responses route by embedded session ID, while a recognized standalone theme opens only as an uninstalled draft. Vanilla Game Reference is also in normal Settings. Long AIIO work and recursive artifact inventory run through `Modules/Operations/OperationWorker.ps1`, not the WPF dispatcher.

The only AI transport in RC30 is user-mediated ZIP. Feedback transport is inspectable local JSON and manual sharing. There is no provider authentication or automatic upload. AI data cannot execute arbitrary code, apply a fix, build, deploy, publish or promote Knowledge. Only an exact current manual cooked-family candidate can be explicitly submitted to normal Merge validation; it remains experimental/unproven and forces Analyze.

## Workflow and ownership

`Detect if needed -> Import -> Fix Lab if required -> Analyze -> Build if required -> Deploy -> Play ready`

Analyze plan schema is 18 and build-manifest schema is 9. Unique non-conflicting PAK changes can reuse an overlay only when the complete saved topology/evidence contract remains exact. Fix Lab Apply/Restore, source-mod operations and AI & Help preserve the deployed compatibility patch. Only Deploy/No compatibility patch, UNDEPLOY and Delete merge own that namespace.

## Packaging policy

`PMM/` is the distributable application. Never commit or ship `PMM/Workspace/`, user PAKs/saves/logs, Game Reference data, extracted Vanilla content, credentials, UCAS/UTOC files or `oo2core_9_win64.dll`.

The native source snapshot under `Development/Source/` is older/incomplete relative to the packaged binary behavior. Do not overwrite `PMM.exe`, `PMMRuntime.exe`, `PMMFixLab.exe` or managed binaries until source/binary reconciliation and Windows tests pass.

## Acceptance boundary

Static validation proves schemas, hashes, XAML parity, security invariants and archive integrity. Windows acceptance remains mandatory. Follow `PMM/Documentation/TEST_THIS_BUILD_RC30.txt` before publishing.
