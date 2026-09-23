# Current status - PMM v1.5.0.2

## Identity

Branch: `v1.5.0.2`

Package:
- VERSION: `1.5.0.2`
- BUILD_ID: `PMM-v1.5.0.2-development-baseline`
- stableCandidate: false

The package identity has now been moved atomically from inherited 1.5.0.1/I04 metadata to the 1.5.0.2 development baseline. This is a development-baseline identity change, not completion of NF01+.

Canonical handoff:
`Development/Handoff/CURRENT_HANDOFF.md`

## Inherited baseline preserved

- I03 localization: 30 registered / 23 enabled / 7 reserve;
- I04 Nexus Updates;
- Host C2B distributed;
- Runtime C2B distributed;
- PMMFixLab original distributed + 04A-6E research/candidates;
- Workspace;
- Mods & Merge;
- deployment/rollback/recovery;
- Deep Analysis;
- AIIO.

## Architecture target

One PMM-owned executable with separate-process worker modes.

External third-party executables remain external.

Modules/Resources/CKL and other useful development surfaces stay open/editable.

FixLab does not merge until parity/Windows acceptance permits it.

## PRE-NF01 preparation

Completed:
- canonical `Development/Handoff/` continuity layer;
- machine-readable history classification;
- local repository-index generator;
- local-first Codex/developer workflow;
- one coherent commit per prompt rule;
- maximize progress within current gate rule;
- explicit end-of-prompt comparison against plan;
- package identity moved to 1.5.0.2 development baseline;
- generated index output excluded from Git.

## Known architecture facts

- Host normal start routes to PMMRuntime.
- normal WPF/other worker paths still contain ExecutionPolicy Bypass.
- Runtime start can repair/download missing/invalid dependencies before UI.
- OperationWorker.ps1 remains broad.
- generic Runtime process-run capability exists.
- Host/Runtime candidate builds still post-process PE resources.
- Development/Source Host/Runtime snapshots diverge from later NativeCandidates.
- old VT RC30 result is not a current 1.5.x baseline.
- pre-UI incident remains OPEN / NOT REPRODUCED / UNKNOWN / WATCHPOINT.

## Roadmap

- NF00: CLOSED
- PRE-NF01 continuity/index/version baseline: **CLOSED**
- NF01 baseline + migration matrix: **NEXT**
- NF02 Host+Runtime single-EXE: PENDING
- NF03 startup/dependency/PowerShell hardening: PENDING
- NF04 workers single-EXE: PENDING
- NF04F FixLab convergence: PENDING
- NF05 conventional reproducible PE build: PENDING
- P01 Updates: PENDING
- P02 compatibility patch: PENDING
- P03 FixLab restoration: PENDING
- P04 AI-created mods via PMM: PENDING
- NF06 full regression: PENDING
- NF07 scanner/Nexus candidate validation: PENDING
- NF08 signing/provenance: OPTIONAL/LATER

Continue with `NEXT_SESSION.md`.
