# PMM — CURRENT STATE

## Release authority

- Product: **Palworld Manager Merger**
- Creator: **laredson**
- Candidate: **v1.3.1 Mod Creation preview**
- Build ID: `PMM-v1.3.1-MOD-CREATION-PREVIEW`
- Base commit: `9886c4fcb58654c81894f429a60bba5a704af6de`
- Runnable authority: `PMM/`
- Native executables: unchanged from the accepted RC21 binary lineage

The branch preserves the complete RC22–RC30 regression chain and the published
stable fixes on `main`. It adds a separate `CREATE_MOD` exchange, exact/bounded
current Game Reference evidence, hostile cooked-tree candidate validation and
an explicit background standalone-PAK build. Compatibility merges, Fix Lab,
deployment ownership and the stable binaries remain unchanged.

## Current product surface

`Mods & Merge -> FIX LAB -> AI & Help -> World Save -> Settings`

AI & Help provides five focused views: AI assistance, AI reception, Feedback & Knowledge, color-scheme editor and AI Settings. Selecting a case shows that case; New case exposes explicit PMM features and can save locally or create the safe ZIP directly. Standard responses route by embedded session ID, while a recognized standalone theme opens only as an uninstalled draft. Vanilla Game Reference is also in normal Settings. Long AIIO work and recursive artifact inventory run through `Modules/Operations/OperationWorker.ps1`, not the WPF dispatcher.

The only AI transport is user-mediated ZIP. Feedback transport is inspectable
local JSON and manual sharing. There is no provider authentication or automatic
upload. Returned compatibility candidates keep the RC30 exact-case gate. A
`PMM_MOD_CREATION_CANDIDATE_V1` can be explicitly built only as a local,
undeployed standalone PAK after current-reference, source/output hash and
AssetReader checks; it is never published or promoted and remains `UNPROVEN`.

## Workflow and ownership

`Detect if needed -> Import -> Fix Lab if required -> Analyze -> Build if required -> Deploy -> Play ready`

Analyze plan schema is 18 and build-manifest schema is 9. Unique non-conflicting PAK changes can reuse an overlay only when the complete saved topology/evidence contract remains exact. Fix Lab Apply/Restore, source-mod operations and AI & Help preserve the deployed compatibility patch. Only Deploy/No compatibility patch, UNDEPLOY and Delete merge own that namespace.

## Packaging policy

`PMM/` is the distributable application. Never commit or ship `PMM/Workspace/`, user PAKs/saves/logs, Game Reference data, extracted Vanilla content, credentials, UCAS/UTOC files or `oo2core_9_win64.dll`.

The native source snapshot under `Development/Source/` is older/incomplete relative to the packaged binary behavior. Do not overwrite `PMM.exe`, `PMMRuntime.exe`, `PMMFixLab.exe` or managed binaries until source/binary reconciliation and Windows tests pass.

## Acceptance boundary

Static validation proves schemas, hashes, XAML parity, security invariants and
archive integrity. Windows acceptance remains mandatory. Follow
`PMM/Documentation/TEST_THIS_BUILD_1_3_1_MOD_CREATION.txt` before promoting the
preview.
