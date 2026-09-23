# Plan v1.5.0.2 - execution index

The authoritative detailed plan is now:

`Development/Reliability/V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md`

This file is retained as a short index so older links do not become misleading.

## Direction adopted 2026-09-23

PMM 1.5.0.2 will:

1. preserve the open/module-oriented architecture;
2. converge PMM-owned native executables toward one `PMM.exe`;
3. keep heavy work isolated in separate processes by launching the same executable in worker modes;
4. leave Modules/Resources/CKL and other useful project surfaces externally inspectable/editable;
5. keep external third-party executables external;
6. harden startup/process/dependency behavior after establishing the unified core;
7. use a conventional reproducible PE build;
8. then repair/finish the current product features;
9. finally validate the actual release candidate with Windows/scanner/Nexus evidence.

## Active phase

**NF00 CLOSED - planning/architecture contract committed.**

**NF01 NEXT - exact baseline + executable/worker contract inventory.**

NF01 is inspection/evidence, not a speculative rewrite.

## Execution order

- NF01: exact baseline and migration matrix.
- NF02: Host + Runtime -> one PMM.exe; preserve isolated process model.
- NF03: startup offline, explicit Repair, remove inherited ExecutionPolicy Bypass.
- NF04: migrate stable worker/safety boundary to PMM.exe worker modes.
- NF04F: merge FixLab only after parity/Windows acceptance.
- NF05: conventional reproducible PMM.exe build/resources/version.
- P01: make Updates behave as intended.
- P02: verify/fix compatibility patch workflow.
- P03: verify/fix old-mod restoration/FixLab.
- P04: verify AI-created mod workflow using PMM as capability/tool plane.
- NF06: full functional regression/package preflight.
- NF07: current-artifact Defender/authorized VirusTotal/Nexus validation.
- NF08: optional SignPath/Authenticode later; not a 1.5.0.2 release blocker.

## AI mod-creation rule

The AI, not an unfinished internal PMM editor, is responsible for creating the requested mod.

PMM provides bounded tools, game/reference evidence, staging, build, validation, deployment/recovery and permitted game-test/observation capabilities so the AI can carry out the user's intent safely.

Do not make a full internal editor a prerequisite for 1.5.0.2.

## Historical startup incident

`Incidents/STARTUP_PRE_UI_2026-09.md` remains OPEN / NOT REPRODUCED / CAUSE UNKNOWN.

It is a regression watchpoint, not the active next task. If architecture/hardening work removes its underlying condition, good; if it remains/reappears with evidence, investigate it then.

## Security intent

Reduce legitimate false positives through conventional, auditable behavior.

Do not:
- disable antivirus;
- request exclusions;
- hide behavior from scanners;
- silently restore quarantined files;
- mutate builds repeatedly for the purpose of evading detection.
