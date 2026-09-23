# PMM v1.5.0.2 - CURRENT HANDOFF

Status: **CANONICAL CONTINUATION DOCUMENT**
Branch: `v1.5.0.2`
Project: Palworld Manager Merger (PMM)
Ownership: personal open-source/fan-made project by `laredson`; unrelated to Wice Games Studio.
License: MIT.

This document is designed to let a new chat, Codex session, developer or AI continue PMM with no access to prior conversations.

---

## 1. Start here

The checked-out Git branch is the source of truth.

Read:
1. this file;
2. `CURRENT_STATE.json`;
3. `../Reliability/V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md`;
4. `../Reliability/STATUS.md`;
5. `../Reliability/NEXT_SESSION.md`.

Use `HISTORY_REGISTRY.json` to understand older handoffs/evidence.

Do not request the old chat or an old handoff ZIP if this repository is available.

---

## 2. Current package identity

Target/current development version:
- VERSION: `1.5.0.2`
- BUILD_ID: `PMM-v1.5.0.2-development-baseline`
- branch: `v1.5.0.2`
- stable/release candidate: **no**

The 1.5.0.2 development baseline is the complete inherited I04 package with its package metadata moved coherently to the new development version. The version move itself does not claim that NF01+ work is complete.

Inherited integrations:
- I03 localization: 30 registered languages, 23 enabled, 7 reserves;
- I04 Nexus Updates implementation;
- Host C2B distributed;
- Runtime C2B distributed;
- original distributed PMMFixLab plus retained 04A-6E reconstruction/research;
- Workspace, rollback/recovery/deployment, Deep Analysis, Mods & Merge and AIIO flows.

Package inventory integrity remains governed by `PMM/Resources/Metadata/SHA256SUMS.txt`.

---

## 3. What PMM is trying to become

PMM is intended to make Palworld modding easier across as many workflows as are practical.

Long-term possibilities include broader mod-source integration, Workshop, servers, CKL/community knowledge and deeper Unreal/modding tool integration.

Those large expansions are **not** the completion scope of 1.5.0.2.

1.5.0.2 should establish a useful stable base in which:
1. installed mods can be updated through supported providers as designed;
2. users can create compatibility patches;
3. old mods can be restored/repaired where PMM has sufficient evidence;
4. users can request new mods from an AI that uses PMM's controlled capabilities;
5. the application installs/runs reliably and can be distributed normally through Nexus;
6. the architecture is open, inspectable and easy to continue.

---

## 4. AI-created mod responsibility model

PMM does not currently need a complete internal graphical mod editor.

Current responsibility:
- user defines desired mod/behavior;
- AI is the primary authoring/reasoning agent;
- PMM is the capability and evidence plane.

PMM may provide bounded capabilities for:
- Game Reference/evidence queries;
- asset/mapping inspection;
- staging;
- allowed build/tool operations;
- validation;
- game launch/test/observation adapters;
- transactional deploy/rollback;
- durable project/session state.

AI output remains untrusted until PMM validates it. PMM controls filesystem/tool/deployment boundaries.

Target flow:

`user intent -> AI creation/reasoning -> PMM evidence/tools/build/test -> AI iteration -> user-approved result`

Do not make a complete internal editor a prerequisite for 1.5.0.2.

---

## 5. Adopted native architecture

Target: **one PMM-owned executable, not one process**.

Future shape:

```text
PMM.exe
PMM.exe --worker analyze ...
PMM.exe --worker build ...
PMM.exe --worker update ...
PMM.exe --worker reference ...
PMM.exe --worker fixlab ...   # only after FixLab parity
```

Each worker remains a separate Windows process. Worker failure must not inherently terminate the UI process.

Keep externally editable where practical:
- Modules/
- Resources/
- CKL/
- localization;
- XAML/UI resources;
- recipes/configuration;
- documentation.

Do not create an opaque self-extracting EXE simply to reduce the visible file count.

External third-party executables/runtimes (repak, Microsoft .NET, etc.) remain external and retain their own provenance. The single-EXE goal applies to PMM-owned executables.

FixLab is a special gate: do not remove the currently distributed `PMMFixLab.exe` until the reconstructed replacement has sufficient contract parity and Windows acceptance.

---

## 6. Known architecture facts at this baseline

Verified from the current branch/reliability evidence:

- Host normal routing currently launches `Engine/PMMRuntime.exe start`.
- Host still has a PowerShell fallback route using `-ExecutionPolicy Bypass`.
- Runtime normally selects the editable PowerShell/WPF UI on FullLanguage systems.
- that legacy WPF launch currently uses `-ExecutionPolicy Bypass`.
- Runtime `start` currently calls dependency ensure before UI.
- dependency ensure can repair/download components when missing/invalid.
- `Modules/Operations/OperationWorker.ps1` is the broad current background-operation broker.
- Runtime still exposes a generic bounded `process run` capability.
- current Host/Runtime candidate build recipes post-process PE files with the repository icon helper.
- the old recorded VirusTotal sample is an older RC30 artifact and cannot establish current 1.5.x detection causes.
- the unreproduced pre-UI startup incident remains open as a watchpoint, not the active next task.

Important source-state issue:
- `Development/Source/Host` and `Development/Source/Runtime` are older snapshots;
- the Reliability NativeCandidates contain later reconstructed work;
- do not assume either tree is canonical until NF01 records and NF02 consolidates the migration.
- current validation infrastructure must not be treated as proof of source parity merely because old snapshot tests pass.

---

## 7. Current execution plan

Authoritative plan:
`Development/Reliability/V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md`

Order:
- NF00: plan/architecture contract - closed.
- PRE-NF01: continuity/index/version baseline preparation - closed by the current preparation commit.
- NF01: exact current baseline and migration matrix - **NEXT**.
- NF02: merge Host + Runtime into one PMM.exe.
- NF03: startup offline/read-only + explicit repair + PowerShell policy cleanup.
- NF04: one-executable worker/process boundary.
- NF04F: FixLab convergence only after parity.
- NF05: conventional reproducible Windows PMM.exe build.
- P01: make Updates behave as intended.
- P02: compatibility-patch workflow.
- P03: old-mod restoration/FixLab.
- P04: AI-created mods through PMM capabilities.
- NF06: complete regression/preflight.
- NF07: current-artifact Defender/authorized VirusTotal/Nexus validation.
- NF08: optional provenance/signing later.

Authenticode/SignPath is **not** a 1.5.0.2 release blocker.

---

## 8. Exact next block: NF01

NF01 is inspection/evidence and a migration design, not the first product rewrite.

It must produce:
- exact local HEAD/clean-tree evidence;
- actual SHA-256/size/source status for PMM.exe, PMMRuntime.exe and PMMFixLab.exe;
- Host route/command matrix;
- Runtime subcommand matrix;
- FixLab commands actually consumed by PMM;
- exhaustive local inventory of background process/worker launch sites;
- exhaustive local inventory of `ExecutionPolicy Bypass`;
- startup network/repair-capable paths;
- progress/result/locking schemas;
- old-entrypoint -> future PMM.exe migration matrix;
- smallest reversible NF02A Host+Runtime integration proposal;
- tests/gates and rollback path.

Use the repository-local index tool as an accelerator, but verify important contracts in source.

Do not:
- start by rewriting all PowerShell;
- delete PMMRuntime/FixLab;
- claim scanner causality;
- chase the unreproduced startup incident without new evidence.

---

## 9. Development operating protocol

Normal Codex/developer behavior is local-first.

### At the beginning of a prompt

If no clone exists:
1. clone the repository locally;
2. checkout the requested branch.

If a clone already exists:
1. `git fetch`;
2. checkout `v1.5.0.2`;
3. fast-forward only;
4. verify the working tree is clean before beginning.

Then:
1. check whether `.pmm-index` matches current HEAD;
2. regenerate with `python Development/Tools/build_repo_index.py` if missing/stale;
3. read this handoff, state, plan, status and next block.

### During the prompt

- work in the local clone;
- inspect real code before changing it;
- advance as far as reasonably possible within the available context and the current acceptance gate;
- do not stop after arbitrary microsteps when more of the same authorized block can safely be completed;
- do not cross a gate requiring owner/manual/Windows/game validation by pretending it passed;
- keep changes coherent and reversible;
- test locally as appropriate;
- do not run GitHub Actions/remote CI during development unless explicitly requested.

If a clearly superior project-wide plan is discovered:
1. evaluate it against current constraints;
2. update the authoritative plan/state in the same prompt;
3. explain exactly what changed and why;
4. do not silently deviate.

### At the end of a prompt

Normal rule: **one coherent commit per prompt**.

The same commit should contain:
- implementation;
- relevant tests/evidence;
- continuity/status/history/next updates when project state changed.

Development commit message ends with `[skip ci]`.

Then push that single commit (when the prompt authorizes repository write).

Report:
- starting HEAD;
- ending commit;
- what was completed;
- local validations and their category;
- what remains unverified;
- comparison with original plan;
- any plan modification and rationale;
- exact next work.

No force push. No PR/tag/release/Latest by initiative.

---

## 10. GitHub / test policy

GitHub is freely readable.

Remote writes require owner authorization for the relevant block. A prompt that explicitly asks to implement and upload that block is authorization for that block.

Development:
- local tests;
- no automatic Actions/CI;
- no remote test workflow by default;
- `[skip ci]` on development commits.

Release/main/explicit validation may use automated validation.

Always distinguish:
- static inspection;
- unit/tool/fixture tests;
- cross-build;
- real Windows execution;
- WPF/PowerShell runtime acceptance;
- real Palworld runtime;
- real Nexus account;
- antivirus scan;
- Nexus upload.

One category does not prove another.

---

## 11. Security/distribution intent

The goal is legitimate reduction of false positives and conventional distribution.

Allowed direction:
- simpler/observable startup;
- offline normal startup;
- explicit repair;
- standard process contracts;
- conventional PE resources/build;
- provenance/hashes;
- vendor false-positive submissions if required.

Do not:
- disable antivirus;
- request exclusions;
- hide behavior from scanners;
- restore quarantined files automatically;
- mutate binaries to evade a detector;
- promise zero detections.

VirusTotal or Nexus sample upload requires explicit authorization when that step is reached.

---

## 12. Historical evidence and continuity

Use `HISTORY_REGISTRY.json` for classification.

Important current-line records:
- `../Reliability/V1502_HISTORY.md`
- `../Reliability/HISTORY_INDEX.md`
- `../Reliability/V1502_DECISION_TRANSCRIPT_2026-09-23.md`
- `../Reliability/Incidents/STARTUP_PRE_UI_2026-09.md`

Older 1.5.0.1 and AIIO/localization handoffs remain historical evidence. They are not the current continuation entrypoint.

Do not delete or rewrite historical FINDINGS/CHECKS to make them match a newer conclusion.

---

## 13. Package preservation invariants

Until an explicit scoped change says otherwise preserve:
- 30 registered / 23 enabled / 7 reserve localization set;
- native language names and RTL/LTR handling;
- I04 Nexus update state/data compatibility;
- Workspace user state;
- deployment/rollback/recovery;
- Mods & Merge;
- Deep Analysis;
- AIIO current data/contracts;
- external-tool provenance;
- exact historical evidence.

A cleaner architecture is not success if it silently loses product behavior.


---

## 14. NF01 result

NF01 durable findings:
- `Development/Reliability/NF01_FINDINGS.md`
- `Development/Reliability/NF01_EVIDENCE.json`

NF01 is substantially complete, with one local confirmation gate remaining because the session environment could not resolve GitHub for a local clone.

The important design result is now fixed:

`PMM.exe Host -> separate child PMM.exe runtime start`

The single-executable goal does **not** remove the Host/Runtime process isolation boundary.

A new canonical source tree will be created under `Development/Source/PMM/` in NF02A from the latest Reliability candidate lineage. The older Host/Runtime source snapshots remain historical/reference material.

See `Development/Reliability/NEXT_SESSION.md` for NF01-L and NF02A.


---

## 15. NF02A source consolidation

NF02A now has a canonical unified source tree:

`Development/Source/PMM/`

It contains Host + Runtime + Supervision + UIBridge in one Go module.

Process architecture remains:

`PMM.exe Host -> separate child PMM.exe runtime <command>`

The distributed package has **not** been changed. PMMRuntime.exe and PMMFixLab.exe remain present.

Build and Windows acceptance are still required before package integration.

The execution environment again could not clone GitHub due DNS failure, so NF01-L local hash/index confirmation is still pending. This does not invalidate the source consolidation; it remains a required local gate before release integration.

Next:
`Development/Reliability/NEXT_SESSION.md`


---

## 16. NF02A compile validation

NF02A's unified source has now been cross-compiled successfully from a connector-backed local reconstruction.

Evidence:
`Development/Reliability/NF02A_BUILD_EVIDENCE.json`

Confirmed:
- unified dispatcher compiles/tests;
- Runtime/Supervision/UIBridge compile;
- Host cross-compiles for Windows;
- Runtime cross-compiles for Windows;
- full `cmd/pmm` produces a Windows GUI x86-64 executable;
- separate Host -> same-binary Runtime child architecture compiles.

No actual canonical-source compilation error was found.

The generated reconstruction EXE is evidence only and is not packaged/distributed.

The environment still cannot make an exact Git clone, so NF01-L byte/hash/index confirmation and an exact-checkout run of all migrated tests remain open.

The project is now operationally at the **NF02A Windows acceptance gate**, preceded by one short exact-clone confirmation/build when a network-capable local environment is available.
