# PMM 1.3.0 RC23 validation record

- Build ID: `PMM-v1.3.0-RC23-POWERSHELL-SINGLETON-GUARD`
- Scope: Windows PowerShell 5.1 singleton/empty collection safety after Build and during saved-patch reuse.
- Captured execution: the RC22 worker completed normally; the UI stack trace identified `Test-PMMPatchRuntimeCompatible`, `LibraryService.ps1:411`.
- Captured artifact: schema-9 PAK hash and manifest `OutputHash` both equal `2591474a38d20b880af3a9214e40807d7b52e197f57f1584513b701eb4acc1a5`.

## Cross-platform gates

- Supplied `22.7z`: 8,624 archive entries checked for absolute/traversal paths before targeted extraction; no unsafe name found.
- Captured worker/build evidence: normal worker exit precedes the UI exception; PAK bytes/hash equal manifest `OutputBytes`/`OutputHash`; schema 9, six output assets, seven shared proofs, zero decisions and one known recipe confirmed.
- Captured post-Build compatibility proof: current plan and saved manifest match on the six output assets, provider sets/hashes, recipe identity/output provider, exact cooked-output evidence, source, mappings, Vanilla and effective-order identities (`RC23_CAPTURED_POSTBUILD_COMPATIBILITY_PROOF_OK`).
- RC22 safety-policy regression retained: `RC22_REGRESSION_MODEL_OK`.
- RC23 source guard model: `RC23_SINGLETON_GUARD_MODEL_OK`.
- PowerShell lexical/delimiter structure: 23 application scripts plus 4 repository validation/test scripts passed. This is not a Windows `System.Management.Automation` parser result.
- XAML: default/EN/ES parsed; 208 unique `x:Name` controls in each file with exact parity.
- JSON: 35 portable-application files and 48 repository-tree files parsed.
- SHA256SUMS: 432 portable entries and 431 repository-application entries regenerated and verified.
- Portable/repository PMM parity: 431 common application files are byte-identical outside the intentional release-root `BUILD_ID.txt` and tree-specific checksum manifests.
- Forbidden payload scan: no `Workspace`, PAK/UCAS/UTOC, `.git` directory or `oo2core_9_win64.dll` in either staged deliverable tree.
- Source authority: packaged native/managed binaries remain byte-identical to RC22/RC21; the functional RC23 delta is limited to editable PowerShell plus release metadata/docs.

## Archive verification

- Portable ZIP: 433 extracted files; CRC test reported no errors; extracted tree is byte-identical to release staging.
- Git-root-ready ZIP: 656 extracted files; CRC test reported no errors; extracted tree is byte-identical to repository staging.
- Repeated forbidden-payload scan across both extracted archives returned zero findings.

The included Windows PowerShell test `Development/Tests/rc23_singleton_collection_regression.ps1` cannot be executed in the cross-platform packaging environment. `Validate-v1.3.ps1` executes it on the target Windows validation pass.

## Required Windows acceptance

1. Copy the supplied RC22 `Workspace` into a clean RC23 folder and start PMM.
2. Confirm the existing schema-9 patch appears without `PropertyNotFoundStrict`/`.Count` errors.
3. Confirm it is selectable/current and Deploy succeeds without rebuilding.
4. Disable only `BigInventory.pak`; Analyze must reuse the overlay, skip Build and require Deploy only for source synchronization.
5. Repeat with `AutoUnlockAllTechnology_V1_P.pak`.
6. Confirm Semiauto audio during AUTO.
7. Change a true conflict provider/hash/order/decision and confirm unsafe reuse is rejected.

Cross-platform structure checks are not Windows WPF, Windows PowerShell 5.1 or Palworld runtime proof. Do not promote RC23 to final before this checklist passes.
