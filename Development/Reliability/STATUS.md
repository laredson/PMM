# Current status - PMM v1.5.0.2

## Identity

Branch: `v1.5.0.2`

Package remains unchanged:
- VERSION: `1.5.0.2`
- BUILD_ID: `PMM-v1.5.0.2-development-baseline`
- distributed PMM.exe / PMMRuntime.exe / PMMFixLab.exe: unchanged

## NF01-L

Local clone was attempted again and failed because the execution container could not resolve `github.com`.

Therefore:
- byte-level local SHA recomputation: still pending;
- local `.pmm-index` exhaustive grep: still pending.

NF01 architectural findings remain valid and no contradiction was found.

## NF02A

State: **CANONICAL SOURCE CONSOLIDATED / BUILD + WINDOWS ACCEPTANCE PENDING**

New canonical source:
`Development/Source/PMM/`

Architecture:
`PMM.exe Host -> separate child PMM.exe runtime <command>`

Consolidated from latest Reliability candidates:
- Host;
- Runtime;
- Supervision;
- UIBridge.

Preserved:
- separate Host/Runtime OS-process boundary;
- external editable Modules/Resources/CKL/XAML;
- current PowerShell/WPF route;
- current workers;
- PMMRuntime.exe in distributed package;
- PMMFixLab.exe;
- third-party tools.

Not yet changed:
- startup repair/network policy;
- ExecutionPolicy Bypass;
- OperationWorker;
- Updates;
- FixLab engine;
- package binaries.

Candidate build:
`python Development/Source/PMM/build.py --out <outside-repo>`

The build is offline, uses Go 1.23.2, runs package tests, cross-compiles Host tests and emits `PMMUnified-candidate.exe` without touching the package.

## Roadmap

- NF00: CLOSED
- PRE-NF01: CLOSED
- NF01: evidence complete, local confirmation still pending
- NF02A source consolidation: **COMPLETE**
- NF02A compile/Windows acceptance: **NEXT**
- NF02 package integration: PENDING
- NF03+: PENDING
