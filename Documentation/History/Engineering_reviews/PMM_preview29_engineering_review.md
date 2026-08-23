# PalModMerger engineering review - 2026-08-16

Reviewed base: `PalModMerger v1-preview28` / `PMMCore 0.7.1`.
Resulting candidate: `v1-preview29`.

## Current product model

PMM is a compatibility overlay builder, not a load-order winner picker. The source of truth is the portable PMM mod library. Analyze derives a deterministic plan from exact source PAK hashes and mappings. Build creates a local overlay. Deploy is the only normal boundary that changes Palworld `~mods`.

For every shared cooked family, PMM should preserve the union of compatible changes. A decision is created only for the smallest property/byte identity that can be proven to disagree. `Unsupported` is a hard build blocker, not permission to choose a whole mod and discard independent changes.

The production reader/writer boundary is correct: AssetReader/UAssetAPI is read-only; production merge operations patch copied cooked bytes and validate preconditions. No generic `UAsset.Write()` path should return.

## Runtime evidence update

The latest user test reports that the preview28 target set works, including MultiJump Triple with Fly and the other active stress-test mods. Delete/Deploy and the save workflow also appeared to work. That result is more important than another speculative adapter expansion: the merge algorithms that produced it should be held stable while lifecycle and regression guarantees improve.

## Architecture reviewed

### Orchestration

- `Core/MergeEngine.ps1`: shared-family discovery, Vanilla/provider extraction, adapter routing, decision persistence, Build and patch manifest.
- `Core/LibraryService.ps1`: source library, disabled/deleted state, managed patch discovery and game deployment.
- `Core/PakService.ps1`: pinned repak access and exact PAK extraction/packing.
- `Core/SaveService.ps1`: read-only discovery plus ZIP backup/restore.
- `Start-PalModMerger.ps1` + XAML: thin WPF shell.

### Proven merge stack

- BinaryRangeMerge-v2: Vanilla-relative same-layout byte deltas.
- StaticItemDataAssetAdapter/v0.4.0: stale-layout semantic intent -> fixed-size current-layout patches, including Float32, Int32 and supported SoftObject leaves.
- SupersetAnchor-v1: accept a structural superset only after it is proven to contain all secondary requested bytes.
- DataTableScalarTransfer-v2: scalar semantic transfer into a structural anchor with preconditions.
- RelocatableDelta-v2: anchor/alignment/relocation composition for small variable-size cooked families, including the MultiJump Triple/Quad + Fly pattern.

These adapters are deliberately specialized. Their refusal modes are part of correctness.

## Concrete defects found in preview28

### 1. PMMCore startup health version mismatch

`Core/Common.ps1` required assembly version 0.7.1 but matched the self-test output against 0.7.0. `MergeEngine.ps1` and setup used the correct 0.7.1 contract. This inconsistency could cause needless dependency repair or an incorrect unhealthy-Core status.

Preview29 derives the self-test marker from one explicit 0.7.1 dependency version and adds a smoke-test guard.

### 2. Current-patch Analyze could forget deployment suppression

When Analyze found an already-current PMM patch, it intentionally wrote a short plan with empty `Assets` and `Rows`. Preview28's deployment suppression for pure Triple/Quad alternatives was calculated from those rows. A later Deploy could therefore lose the knowledge that the unselected alternative was meant to remain in the PMM library rather than be copied back into `~mods`.

Preview29 persists `DeploymentSuppressions` in new manifests and short plans. It also reconstructs the single-conflict suppression from preview28 manifests when possible.

### 3. Old Analyze plans could survive a PMM upgrade

Plan currency was primarily source signature + mappings. If PMM was upgraded in place without changing source mods or mappings, an older plan could remain visually current even when its contract had changed.

Preview29 advances plan schema 10 -> 11 and validates schema, PMMCore identity, engine profile, source signature and mappings hash.

### 4. Deploy trusted filenames more than identities

Preview28 used remembered filenames to delete disabled/deleted/suppressed source PAKs and force-copied active files. A different third-party PAK with the same filename could therefore be removed or overwritten.

Preview29 records/deploys SHA-256 identities. Unknown same-name files block Deploy with their current and expected/desired hash instead of being changed silently.

### 5. Deploy could leave a partial game-folder update on a copy failure

Preview28 removed old managed files and then copied desired files. Failure after removal could leave `~mods` only partly synchronized.

Preview29 creates an operation plan, shows a preview, stages desired bytes inside the same volume, verifies every staged SHA-256, backs up existing touched managed files, commits with short moves, verifies committed hashes, and records deployment state only after byte verification. Caught commit failures trigger rollback. If rollback itself is incomplete, PMM preserves recovery data and says so explicitly.

This is not yet a promise of automatic recovery after process kill, OS crash or power loss; that is recorded as a follow-up hardening item.

## Save workflow assessment

The existing restore flow is conservative in two important ways: it stops Palworld and creates a fresh safety backup before deleting/replacing current world contents. Since the current user test says the feature works, preview29 intentionally does not rewrite it.

The next safe improvement is transactional restore: extract/validate to staging first, then swap, with automatic restoration of the safety copy on failure. Save parsing should remain read-only unless a separate proven need appears.

## Preview29 design decision

The most important decision is what preview29 does **not** do: PMMCore 0.7.1, mappings and the runtime-successful adapter algorithms stay unchanged. The change surface is plan/deployment lifecycle, version contracts, regression guards, documentation and UI deployment preview.

That separation makes a preview29 regression diagnostically useful: if the same compatibility overlay behavior breaks, investigate orchestration/deployment before reopening the merge algorithms.

## Remaining risks before public beta

1. The candidate has not been executed in Windows PowerShell/WPF in this Linux review environment.
2. The same runtime fixture must be repeated once on preview29.
3. Interrupted-process/OS/power-loss deployment recovery is not automatic yet, although the journal/backups are preserved.
4. Save restore should eventually adopt the same stage/validate/commit/rollback model.
5. The project needs a headless Windows regression harness so routing/output/state tests are repeatable without clicking through WPF.
6. Adapter support should expand only from captured real `Unsupported` cases, not from a marketing goal of being universal.

## Recommended release sequence

1. Treat preview28's successful fixture as the new runtime baseline.
2. Validate preview29 with exactly the same set and choice first.
3. Re-Analyze without Force and Deploy again; verify the unselected MultiJump alternative stays suppressed.
4. Remerge to the other MultiJump value and repeat the runtime check.
5. Exercise identity collision protection in a disposable `~mods` test.
6. Capture the resulting plan, manifest, logs and PAK hashes as the preview29 release-candidate evidence set.
7. Build a headless regression harness before adding another adapter capability.

The long-term product advantage should be trust: PMM merges what it can prove, asks only for real overlapping values, explains what it cannot prove, and never sacrifices unrelated mod changes merely to make Analyze look successful.
