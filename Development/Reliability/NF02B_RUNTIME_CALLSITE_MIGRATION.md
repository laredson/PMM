# NF02B - PMMRuntime direct-call migration

Status: **REQUIRED BEFORE PMMRuntime.exe DELETION**

NF02A unifies Host and Runtime implementation into one PMM.exe and proves the
same executable can run the Runtime role in a separate OS process.

That is not, by itself, proof that the distributed PMMRuntime.exe can be deleted.

## Why

Some editable/external PMM modules historically call PMMRuntime.exe directly
(for example dependency/repair helper paths). Those callers bypass Host
`routes.json`.

Deleting PMMRuntime.exe before migrating every direct caller would turn a
successful startup migration into feature regressions.

## Target contract

Every PMM-owned native Runtime invocation becomes:

```text
PMM.exe runtime <command> [arguments]
```

The process remains a separate child where appropriate.

Third-party executables remain external and are not part of this migration.

## NF02B gate

From an exact local clone:

1. exhaustive repository search for:
   - `PMMRuntime.exe`
   - legacy Runtime path construction;
   - process launches whose executable resolves to PMMRuntime;
2. classify every hit:
   - active runtime callsite;
   - route/config;
   - doctor/inventory;
   - build/history/evidence only;
3. migrate active callsites to the unified contract;
4. preserve exit-code/stdout/stderr/timeout/cancellation behavior;
5. test startup, dependency status/repair, UI, MCP/AI helpers and any caller found;
6. repeat search and require **zero active distributed callsites** to PMMRuntime.exe;
7. only then remove `PMM/Engine/PMMRuntime.exe` and its checksum/manifest inventory entry.

## Compatibility

The unified Host may temporarily recognize old `routes.json` entries that name
`Engine/PMMRuntime.exe`. This is a migration compatibility path, not the final
distributed route format.

Final native routes should name `PMM.exe` and prefix Runtime arguments with
`runtime`.

## Rollback

Until NF02B closes, keep PMMRuntime.exe in the package. It is a rollback/legacy
caller safety net, even when NF02A staging routes no longer use it.
