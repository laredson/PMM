# Current status - PMM v1.5.0.2

## Identity

Branch: `v1.5.0.2`

Distributed package remains unchanged:
- VERSION: `1.5.0.2`
- BUILD_ID: `PMM-v1.5.0.2-development-baseline`
- PMM.exe: unchanged
- PMMRuntime.exe: unchanged
- PMMFixLab.exe: unchanged

## This prompt

Requested:
- exact NF01-L local confirmation;
- exact NF02A V2 build;
- Windows staging/diagnostics;
- integrate PMM.exe only if all gates pass;
- begin NF02B after that.

Actual environment:
- `git clone`: FAIL before auth, `Could not resolve host: github.com`;
- Windows runtime/Wine: unavailable.

Therefore:
- NF01-L exact checkout confirmation: NOT EXECUTABLE HERE;
- NF02A exact-clone build: NOT EXECUTABLE HERE;
- NF02A Windows diagnostics/manual gate: NOT EXECUTABLE HERE;
- PMM.exe package integration: **CORRECTLY NOT PERFORMED**.

No `PMM/` product file is changed by this prompt.

## NF02B pre-inventory advanced safely

Even though migration is gated on NF02A acceptance, the distributed PowerShell
surface was exhaustively inventoried through the exact Git branch tree.

Coverage:
- 132 distributed `.ps1/.psm1` files scanned;
- 18 files contained Runtime terminology;
- 13 files are active direct PMMRuntime consumers;
- 18 direct native invocations.

Command totals:
- archive create: 10
- archive extract: 4
- dependencies ensure: 2
- ui: 1
- self-test: 1

Key consumers include:
- legacy Runner start/validate;
- AIIO;
- dependency bootstrap;
- CKL contribution;
- FixLab;
- Library ZIP import;
- Merge solution import;
- save backup/restore;
- theme export/AI handoff.

Central helper:
`Modules/Shared/Paths.ps1 -> Get-PMMRuntimePath`.

Evidence:
- `NF02B_PREINVENTORY.md`
- `NF02B_PREINVENTORY.json`

## NF02 plan

- NF02A: unified PMM.exe exact build + Windows acceptance.
- NF02A first integration: replace PMM.exe + final routes, retain PMMRuntime.exe.
- NF02B: migrate the 18 direct invocations and any exact-local additional hits.
- NF02C: only then delete PMMRuntime.exe and clean metadata/checksums/snapshots.

## Roadmap

- NF00: CLOSED
- PRE-NF01: CLOSED
- NF01 evidence: COMPLETE
- NF01-L exact local confirmation: BLOCKED BY THIS ENVIRONMENT
- NF02A canonical source/integration prep: COMPLETE
- NF02A exact-clone build: NEXT IN NETWORK-CAPABLE LOCAL ENV
- NF02A Windows acceptance: NEXT ON WINDOWS
- NF02A package integration: BLOCKED UNTIL WINDOWS PASS
- NF02B pre-inventory: **COMPLETE FOR DISTRIBUTED POWERSHELL**
- NF02B migration tooling: PREPARED + VALIDATED; APPLY BLOCKED UNTIL NF02A INTEGRATION
- NF02C Runtime deletion: BLOCKED UNTIL NF02B
- NF03+: PENDING

## NF02B guarded migration tooling

Prepared `Development/Tools/nf02b_migrate.py` without changing any distributed
`PMM/` product file.

Validation:
- exact remote transformation simulation: 18/18 known command migrations;
- post-transform target-set check: 0 active physical PMMRuntime paths and 0
  unprefixed direct Runtime invocations;
- Python syntax: PASS;
- synthetic dry-run/apply fixture: PASS (18 migrations, 14 changed files);
- PMMRuntime retained by design.

Apply is locked behind the accepted PMM.exe SHA-256 and the already-integrated
five `PMM.exe runtime ...` Host routes.
