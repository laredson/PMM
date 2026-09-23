# NEXT SESSION - PMM v1.5.0.2

## Active block: NF01-L -> NF02A

NF01 architecture/inventory work is substantially complete.

First perform a short local confirmation gate; if it matches the committed evidence, close NF01 and continue directly into NF02A in the same prompt if context allows.

## NF01-L local confirmation

On a network-capable local clone:

1. fetch + checkout `v1.5.0.2`;
2. fast-forward only;
3. verify clean tree and starting HEAD;
4. run:
   `python Development/Tools/build_repo_index.py`;
5. recompute SHA-256:
   - PMM/PMM.exe
   - PMM/Engine/PMMRuntime.exe
   - PMM/Engine/PMMFixLab.exe
6. compare them with `NF01_EVIDENCE.json`;
7. exhaustive local search for:
   - `ExecutionPolicy` + `Bypass`;
   - `Start-Process`;
   - `ProcessStartInfo`;
   - `exec.Command`;
   - references to PMMRuntime.exe / PMMFixLab.exe / OperationWorker;
8. compare with `NF01_FINDINGS.md`.

If no new critical boundary appears:
- mark NF01 CLOSED;
- begin NF02A immediately.

If additional process paths appear:
- add them to NF01 evidence;
- only change the NF02 plan if they alter the migration boundary.

## NF02A

Follow the exact design in `NF01_FINDINGS.md`.

Create canonical source:

```text
Development/Source/PMM/
  go.mod
  cmd/pmm/main.go
  internal/host/
  internal/runtime/
  internal/supervision/
  internal/uibridge/
```

Behavior:
- default PMM invocation = Host;
- `PMM.exe runtime <command>` = Runtime role;
- Host launches the same executable as a **separate child process** for Runtime routes.

Build a candidate outside the package.

Do not yet:
- overwrite PMM/PMM.exe;
- remove PMMRuntime.exe;
- remove Bypass;
- change dependency-repair semantics;
- migrate OperationWorker;
- merge FixLab;
- change Updates behavior.

Run all applicable Go/static tests locally and prepare Windows acceptance instructions.

## One-prompt rule

Advance NF01-L + NF02A as far as safely possible in one prompt.

One coherent development commit, `[skip ci]`, with findings/tests/handoff/status/next updates.

No Actions/remote CI during development.
