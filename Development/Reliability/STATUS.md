# Current status - PMM v1.5.0.2

## Identity

Branch: `v1.5.0.2`

Package:
- VERSION: `1.5.0.2`
- BUILD_ID: `PMM-v1.5.0.2-development-baseline`
- stableCandidate: false

Canonical handoff:
`Development/Handoff/CURRENT_HANDOFF.md`

## Preserved baseline

- I03 localization: 30 registered / 23 enabled / 7 reserve;
- I04 Nexus Updates;
- Host C2B distributed;
- Runtime C2B distributed;
- original PMMFixLab + 04A-6E research;
- Workspace, Mods & Merge, Deep Analysis, AIIO, deploy/rollback/recovery.

## NF01

Durable evidence:
- `NF01_FINDINGS.md`
- `NF01_EVIDENCE.json`

State:
**SUBSTANTIALLY COMPLETE / LOCAL-CLONE CONFIRMATION GATE OPEN**

Completed:
- PMM-owned executable size/blob/package-hash identity;
- Host routes/commands;
- Runtime command matrix;
- Runtime generic process contract;
- startup repair/network path;
- primary worker operation set;
- progress/result/journal/lock contracts;
- dedicated process families;
- directly verified Bypass paths;
- FixLab native requirements/build contract;
- old-source vs NativeCandidate divergence;
- migration matrix;
- exact NF02A architecture/tests/rollback design;
- process/UI consensus document restored.

Environment limitation:
the execution container could not resolve github.com, so a true local clone/index/grep and byte-level SHA recomputation could not be run here.

## NF02A design decision

Create canonical `Development/Source/PMM/` with Host and Runtime as separate internal roles in one binary.

Preserve isolation:

`PMM.exe -> PMM.exe runtime start`

Do **not** merge Runtime into the Host process merely to reduce file count.

PMMRuntime.exe remains in the package until Windows acceptance of the replacement.

FixLab remains separate through NF02.

## Known later work

- NF03: startup status-only + explicit repair; remove Bypass by feature.
- NF04: migrate primary processing broker/workers to explicit same-EXE worker modes.
- NF04F: FixLab only after parity.
- NF05: conventional reproducible PE resources/build.
- P01-P04: cure product workflows.

## Roadmap

- NF00: CLOSED
- PRE-NF01: CLOSED
- NF01: **LOCAL CONFIRMATION PENDING**
- NF02A: READY AFTER NF01-L
- NF03+: PENDING

Continue with `NEXT_SESSION.md`.
