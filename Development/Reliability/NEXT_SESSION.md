# NEXT SESSION - PMM v1.5.0.2

## Read first

1. `START_HERE_NEW_PROJECT.md`
2. `Development/Reliability/V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md`
3. `Development/Reliability/STATUS.md`
4. `Development/Reliability/V1502_STATE.json`
5. relevant prior FINDINGS/CHECKS only as historical evidence.

## Active block: NF01

**Exact baseline + executable/worker contract inventory**

Do not start by fixing the unreproduced startup incident.

Do not start by rewriting all PowerShell.

Do not delete PMMRuntime.exe or PMMFixLab.exe during NF01.

### Objective

Prepare the exact, reversible migration from the current multi-PMM-executable arrangement toward one PMM-owned executable while preserving the open module architecture and every existing user-facing capability.

### Required NF01 outputs

Create/update reliability evidence that contains:

1. exact checked-out branch HEAD;
2. SHA-256/size/source status for:
   - PMM.exe;
   - PMMRuntime.exe;
   - PMMFixLab.exe;
3. current Host route/command matrix;
4. current Runtime subcommand matrix;
5. current FixLab commands actually consumed by PMM;
6. every PMM background-worker launch site grouped by feature;
7. every current `ExecutionPolicy Bypass` launch site grouped by feature;
8. startup network/repair-capable paths;
9. current progress/result/locking schemas used between UI and workers;
10. a migration table:
   `current entrypoint -> proposed PMM.exe role/subcommand -> files/callers -> acceptance gate`;
11. an NF02A file-level implementation proposal for merging Host + Runtime first;
12. explicit rollback path.

Reuse prior Reliability evidence where valid; verify against the actual branch rather than copying old claims.

### Architectural constraints

Target:

```text
PMM.exe
PMM.exe --worker <known-operation>
Modules/
Resources/
CKL/
Tools/
Documentation/
Workspace/
```

This means one **PMM-owned binary**, not one process.

Workers remain separate OS processes, so a worker crash must not terminate the UI.

Do not embed all Modules/Resources/CKL into the EXE. Ordinary module/data development should remain possible without recompiling PMM.exe.

External executables such as repak/.NET are not migration targets merely because they are executable files.

### AI mod-creation constraint

Do not design a full internal editor as part of this migration.

The AI is the primary creator of a user-requested mod. PMM exposes bounded evidence/tool/build/test/deploy capabilities that the AI can use safely.

### NF01 exit gate

NF01 is complete when a reviewer can answer, from repository evidence:

- exactly what PMM.exe, Runtime and FixLab each do today;
- which parts can move into one executable without changing product behavior;
- what the smallest NF02A code change is;
- how to test it;
- how to roll it back;
- which behaviors remain deliberately external/open.

### GitHub

Development commit/push only after owner authorization for the implementation block.
Use `[skip ci]`.
No Actions/CI, PR, tag or release during development unless explicitly requested.
