# PMM native source status

## Canonical active source

For v1.5.0.2 NF02A onward, the canonical Host+Runtime convergence source is:

`Development/Source/PMM/`

It contains:
- unified PMM entrypoint;
- internal Host;
- internal Runtime;
- internal Supervision;
- internal UIBridge;
- offline candidate build tooling and tests.

Status: **candidate source canonical; distributed binary replacement pending build + Windows acceptance**.

## Historical snapshots

The following remain for provenance/reference and must not be treated as the active unified source:

- `Development/Source/Host/`
- `Development/Source/Runtime/`

Those snapshots predate later C2B Reliability reconstruction work.

## Pre-consolidation Reliability candidates

These are retained as exact migration evidence:

- `Development/Reliability/NativeCandidates/Host/`
- `Development/Reliability/NativeCandidates/Runtime/`
- `Development/Reliability/NativeCandidates/Supervision/`
- `Development/Reliability/NativeCandidates/UIBridge/`

Do not edit both the pre-consolidation candidates and `Development/Source/PMM/` for the same new change.

## FixLab

FixLab is not part of NF02A convergence.

Distributed `PMM/Engine/PMMFixLab.exe` remains authoritative until the later FixLab parity gate permits replacement.
