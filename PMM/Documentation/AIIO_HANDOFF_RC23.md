# AIIO continuation handoff — PMM 1.3.0 RC23

> Historical RC23 delta. Continue from `AIIO_HANDOFF_RC24.md`, which preserves the singleton guard and adds the responsive UI/Fix Lab deployment-ownership boundary.

Use `AIIO_HANDOFF_RC22.md` for the complete AIIO, merge-safety, UI and workflow contract. RC23 changes only one implementation boundary discovered by the user's first real RC22 Build.

Continuation baseline:

- version: **1.3.0 RC23**;
- build ID: `PMM-v1.3.0-RC23-POWERSHELL-SINGLETON-GUARD`;
- code authority: the complete RC23 `PMM/` tree supplied in the Git-root-ready package;
- product authority: `PMM_AIIO_MASTER_HANDOFF_2026-08-29.md` in the separate continuity package.

## RC23 delta that must be preserved

Windows PowerShell 5.1 pipeline-unrolls arrays emitted by conditional branches. A one-element result therefore becomes its contained `PSCustomObject`, while an empty result can become `$null`. Under StrictMode, collection code that assumes `.Count` exists can fail even though the merge/build succeeded.

For every zero/one/many collection used by patch compatibility or reuse:

1. initialize the variable as `@()`;
2. assign `@(...)` inside the conditional branch;
3. do not replace this with `$items=if(...){@(...)}else{@()}` when `.Count`, indexing or collection semantics follow.

The captured RC22 PAK itself is valid. Its worker completed normally and its schema-9 manifest records six patched assets, seven shared proofs and one known recipe. The exception occurred only during the final library/UI refresh. RC23 must continue to recognize that existing Workspace build without forcing another Build.

## Unchanged authority

- RC22 effective-conflict-set reuse and its engine/mappings/Vanilla/provider/hash/order/decision/recipe/output-evidence gates remain unchanged.
- Unique non-conflicting PAK changes may skip Build, but Deploy must still synchronize active sources.
- Semiauto schema-3 migration and sound controls remain unchanged.
- AIIO still packages only explicit current Unsupported cases, never whole source PAKs, and must preserve exact provenance, budgets, cancellation, worker supervision and rollback.
- The visible planned module remains **AI & Help**; AIIO remains its internal engine and **Apply Fix** remains the visible repair action.
- Packaged native and managed binaries remain the unchanged RC21 authority. Do not rebuild them from the incomplete development snapshot without explicit source-parity work.

Final continuation still depends on Windows/WPF and real Palworld acceptance described in `RC23_RELEASE_CANDIDATE.md`.
