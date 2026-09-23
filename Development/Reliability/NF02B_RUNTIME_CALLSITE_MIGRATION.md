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


---

## Concrete pre-inventory at v1.5.0.2

See:
- `NF02B_PREINVENTORY.md`
- `NF02B_PREINVENTORY.json`

The exact branch tree at commit `5425c8d5e7b324341cf9323ff6565941d241fbd3`
was used to read all 132 distributed `.ps1/.psm1` files under `PMM/`.

Found:
- 13 active direct Runtime consumer files;
- 18 native invocation sites;
- 10 `archive create`;
- 4 `archive extract`;
- 2 `dependencies ensure`;
- 1 `ui`;
- 1 `self-test`;
- one central `Get-PMMRuntimePath` helper;
- one native snapshot entry;
- three nominal Runtime-capability references with no executable launch.

### Preferred migration pattern

After NF02A PMM.exe passes Windows acceptance and is integrated:

1. change `Get-PMMRuntimePath` to return root `PMM.exe`;
2. add explicit leading `runtime` to every native Runtime argument list;
3. preserve direct native invocation semantics rather than wrapping everything in
   a new PowerShell abstraction.

Example:

```text
before:
  & $runtime archive create ...

after:
  & $runtime runtime archive create ...
```

For `Invoke-PMMCancelableExternalProcess`:

```text
before Arguments:
  archive extract ...

after Arguments:
  runtime archive extract ...
```

This preserves existing output, exit-code, timeout and cancellation behavior.

Runner fallback scripts and `Setup-Dependencies.ps1` do not rely on the shared
helper, so migrate them explicitly to root `PMM.exe runtime ...`.

Do not apply these edits before NF02A integration because the currently
distributed PMM.exe does not yet own the accepted Runtime role.

---

## Guarded migration tooling

Prepared tool:

`Development/Tools/nf02b_migrate.py`

It is dry-run by default and encodes the current pre-inventory contract:
- exactly 18 Runtime command migrations;
- 14 edited PowerShell files including the shared path helper;
- explicit Runner and dependency-wrapper handling;
- Library cancelable extraction keeps the same external-process helper and only
  prefixes its argument array with `runtime`;
- file BOM choice is preserved.

`--apply` is intentionally gated. It requires:
1. the exact accepted NF02A candidate SHA-256;
2. `PMM/PMM.exe` to match that hash;
3. the five native Host routes already to be `PMM.exe runtime ...`;
4. `PMMRuntime.exe` still to exist as the NF02B rollback/legacy safety net;
5. all inventoried source contracts and counts still to match.

Validation performed while preparing the tool:
- transformation simulation against the exact remote `v1.5.0.2` files: 18/18;
- zero active physical `Engine/PMMRuntime.exe` paths in the transformed target set;
- zero unprefixed direct Runtime invocations in that transformed target set;
- Python syntax: PASS;
- synthetic dry-run + gated apply fixture: PASS, 18 migrations / 14 changed files;
- exact local-repository execution: still pending because this environment cannot
  resolve github.com.

This tooling does not authorize skipping NF02A Windows acceptance and does not
remove PMMRuntime.exe.
