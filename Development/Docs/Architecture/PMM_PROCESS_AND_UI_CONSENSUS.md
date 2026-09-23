# PMM process and UI consensus

Status: **CURRENT ARCHITECTURE CONTRACT**
Established from NF01 on 2026-09-23.

This document describes process ownership and the migration invariant. It does not claim every current implementation already matches the target.

## Core rule

PMM aims for one **PMM-owned executable file**, not one process.

Heavy/failure-sensitive work may and should use separate OS processes.

## Current architecture

```text
PMM.exe (Host)
  -> PMMRuntime.exe start
       -> PowerShell/WPF UI on ordinary FullLanguage Windows
       -> native UI fallback otherwise

WPF UI
  -> OperationWorker.ps1 child for primary heavy operations
  -> GameReferenceWorker.ps1 child
  -> other bounded feature workers

OperationWorker / services
  -> third-party tools as required
  -> PMMFixLab.exe for native FixLab recipe requirements/build
```

The UI must not execute expensive merge/build/reference/repair work on the WPF dispatcher.

## Target architecture

```text
PMM.exe (Host/supervisor)
  -> PMM.exe runtime start       # separate child process, same binary file
       -> editable external UI

UI
  -> PMM.exe --worker <known-operation>   # NF04 target
  -> explicit external third-party tools where appropriate

FixLab
  -> PMM.exe --worker fixlab only after reconstruction parity/acceptance
```

## Why self-child Runtime is preferred

Unifying Host and Runtime into one in-process startup path would reduce physical files but also remove the existing crash/isolation boundary.

The preferred NF02 design therefore compiles both roles into the same executable and has Host spawn another instance in Runtime mode.

This preserves:
- separate address spaces;
- child exit codes;
- supervision/logging;
- Host survival after Runtime child failure;
- future worker-process consistency.

## UI

UI/resources/policy remain external/editable where practical.

The one-EXE objective must not turn Modules/Resources/CKL/localization/XAML into an opaque embedded blob.

The current PowerShell/WPF route remains during NF02. ExecutionPolicy cleanup belongs to NF03.

## Concurrency

Primary Workspace-mutating processing remains serialized to one operation per installation unless a later contract explicitly proves safe concurrency.

Current broker contract:
- exclusive background-operation lock;
- operation journal;
- per-job progress/result JSON;
- module-operation lease.

## Third-party binaries

Third-party executables/runtimes remain external and keep their own provenance.

They are not targets of PMM executable unification.

## FixLab

Distributed PMMFixLab remains a separate exception until source/behavior parity and Windows acceptance are sufficient.

Its current required native contracts include:
- `requirements --recipe ...`;
- `build --recipe ... --source-root ... --game-reference ... --output ... --report ...`.

## Migration principle

Never delete an old process boundary before the replacement has:
1. static/unit contract coverage;
2. a reversible candidate build;
3. Windows acceptance for the boundary it replaces.

See:
- `Development/Reliability/NF01_FINDINGS.md`;
- `Development/Reliability/V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md`.
