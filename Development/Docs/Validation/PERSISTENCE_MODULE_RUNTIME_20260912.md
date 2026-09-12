# Persistence and module runtime validation — 2026-09-12

Implemented in editable PowerShell; packaged native files were preserved.

## Persistence and deployment
- Shared Write-PMMJsonAtomic validates JSON, flushes to a unique same-directory temporary file, serializes writers with a named mutex, then replaces the destination atomically while preserving .bak.
- Read-PMMJsonFile -RecoverBackup explicitly repairs corrupt JSON from a valid backup and preserves corrupt bytes. Schema validation and one-version-at-a-time migrations share this contract.
- Configuration, library priority/validation/removal records and deployment state use the shared writer.
- V2 deployment journals retain original/output hashes and verified backups, checkpoint preparation, commit, verification, state publication, rollback and completion, and retain complete file records after rollback failure.
- Startup recovery validates the selected installation and all paths. Traversal, reparse points, another game root, externally changed bytes and damaged backups block recovery and subsequent deployment. Recovery does not modify a running selected game.
- Only terminal completed/rolled-back/aborted folders are eligible for retention pruning.
- Legacy V1 Prepared journals with complete backup data can migrate and roll back. Historical RollbackIncomplete records that already discarded metadata remain blocked for manual recovery.

## Module runtime
- modules.json declares identity, version, contract, dependencies, capabilities, host profile, stage and reload policy.
- Extension paths are dot-sourced once in the caller's scope; legacy compatibility wrappers remain initialized by existing entry points.
- Operations hold generation/hash snapshots. Pure-function changes are parsed, staged, queued while busy, and activated when idle. Source-directory resource bindings survive reload.
- Parse errors, duplicate function ownership, top-level state/events, cycles, unsupported contracts and changes after staging preserve active definitions.
- UI initialization and compiled components require restart. Host, Runtime, FixLab, repak, PMMCore and AssetReader fingerprints are checked before reload.
- Development/Source/SOURCE_STATUS.md still documents unmatched Host/Runtime source. This work does not claim reproducible native binaries.

## Executed validation
Windows PowerShell 5.1:
- module_runtime_regression.ps1: graph ordering, extension-only load, generation pinning, deferred activation, malformed source, contract/cycle/event rejection, stale stage, old-definition preservation, source paths and native restart.
- persistence_recovery_regression.ps1: replacement/backup, schema guard, corrupt JSON recovery, empty arrays, migration, nine forced child-process termination checkpoints, idempotent rollback, committed-state preservation and unmanaged-file preservation.
- Failure fixtures: external edits, corrupt backup, game/state path escape, malformed journal and wrong installation; each blocks, preserves evidence and recovers after correcting the injected failure.
- The real manifest parses and orders successfully.

All deployment tests use fake game/workspace directories under Development/TestResults. No actual game files were deployed, removed or restored. Process-crash tests do not simulate physical power loss, faulty storage hardware or prove in-game compatibility.

## Integration validation
- architecture_contract_regression.ps1 passes for the real graph and worker/MCP lease pairs.
- wpf_xaml_runtime_regression.ps1 materializes all three XAML variants.
- full_bootstrap_smoke.ps1 loads complete isolated copies in English and Spanish, traverses Play/Create and seven pages, and closes offscreen windows normally.
- mcp_bridge_regression.ps1 passes 36 protocol and capability assertions after direct-call leases; synchronous edit/build/artifact operations share the worker gate.
- Foreground deployment and startup recovery also serialize through the common background-operation gate; deployment persists its module snapshot.
