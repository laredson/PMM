# PMM 1.3.0 RC22 validation record

- Build ID: `PMM-v1.3.0-RC22-EFFECTIVE-PATCH-REUSE-SEMIAUTO`
- Scope: effective-conflict-set saved-overlay reuse and Semiauto enabled-default correction over RC21.
- User evidence: 50-source baseline plus two 49-source variants (BigInventory disabled; AutoUnlockAllTechnology disabled).
- Evidence topology: seven shared groups, six output-producing assets and one Identical group in every variant.
- Evidence output identity: all three build manifests recorded the same `PatchContentSignature`.
- Evidence audio root cause: assigned Semiauto profile `Ok` with `SoundSemiAutoEnabled = false`.

## Cross-platform gates completed

- Dependency-free policy model: `RC22_REGRESSION_MODEL_OK`, including unique-mod positive cases and provider/hash/topology/mappings/Vanilla/order/decision/CKL/output-evidence negative controls.
- Captured three-manifest model: `RC22_CAPTURED_EVIDENCE_REGRESSION_OK`; source counts 50/49/49, exact removed names verified, common content signature verified and the legacy KnownRecipe output bytes matched the current runtime-proven CKL recipe.
- PowerShell lexical/delimiter structure: 23 application scripts plus 3 repository validation scripts passed. This is not a Windows `System.Management.Automation` parser result.
- XAML: default/EN/ES parsed; 208 unique `x:Name` controls in each file with exact parity.
- JSON: 35 portable-application files and 48 repository-tree files parsed.
- SHA256SUMS: 430 portable entries and 429 repository-application entries regenerated and verified.
- Portable/repository PMM parity: identical application file set and bytes outside the intentional release-root `BUILD_ID.txt` and tree-specific checksum manifests.
- Forbidden payload scan: no `Workspace`, PAK/UCAS/UTOC, `.git` directory or `oo2core_9_win64.dll`.
- Source authority: packaged native/managed binaries remain byte-identical to RC21; RC22 changes only editable PowerShell/XAML/docs/metadata contracts.

Archive CRC and extracted-byte verification are performed on the final ZIP artifacts after staging.

## Required Windows acceptance

1. Start RC22 with the existing RC21 Workspace and verify schema-2 audio settings migrate to schema 3.
2. Enable AUTO/Auto ON and confirm the selected Semiauto cue sounds after a successful intermediate step; confirm `None` and the checkbox mute it.
3. From a deployed valid patch, disable `BigInventory.pak`, run Analyze and verify PMM reuses the existing overlay, leaves Build disabled and enables Deploy to remove only that source PAK.
4. Repeat with `AutoUnlockAllTechnology_V1_P.pak`.
5. Re-enable each unique mod and verify the same reuse/deployment behavior.
6. Add or change a real conflict provider and verify fast reuse is rejected; normal Analyze must run and Build must be requested when the recipe differs.
7. Change an output-relevant conflict priority/decision and verify the old overlay is not silently treated as the new output.
8. Run forced Analyze and verify patch/group/plan reuse is bypassed.
9. Complete real Build, Deploy, Undeploy/rollback and Play-ready ColorFlow smoke tests in both UI languages.

Cross-platform checks are not Windows WPF or Palworld runtime proof. Do not promote RC22 to final until the checklist above passes on the target machine.
