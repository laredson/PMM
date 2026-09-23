# PMM v1.5.0.2 - development rules

Active branch: `v1.5.0.2`.

## Canonical continuation

Read:
1. `START_HERE_NEW_PROJECT.md`
2. `Development/Handoff/CURRENT_HANDOFF.md`
3. `Development/Handoff/CURRENT_STATE.json`
4. `Development/Reliability/V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md`
5. `Development/Reliability/STATUS.md`
6. `Development/Reliability/NEXT_SESSION.md`

Older handoffs remain historical evidence. Classify them through
`Development/Handoff/HISTORY_REGISTRY.json`; do not use them as current state.

## Normal working mode: local first

Normal development is performed in a local clone, not by editing isolated GitHub files one at a time.

At prompt start:
- if no clone exists, clone the repository;
- otherwise `git fetch`;
- checkout the requested branch;
- fast-forward only;
- verify the working tree is clean;
- run `python Development/Tools/build_repo_index.py --check`;
- if the index is missing/stale, run `python Development/Tools/build_repo_index.py`.

The generated `.pmm-index/` is local-only and must not be committed.

Inspect real checked-out source before changing it.

## One prompt = one coherent development commit

For an authorized development prompt:
- advance as far as reasonably possible within the prompt/context and the current acceptance gate;
- do not stop after arbitrary microsteps when more of the same block can safely be completed;
- keep the work coherent/reversible;
- run relevant local validations;
- update continuity/history/status/next in the same commit when project state changes;
- create **one coherent commit for the prompt**;
- use `[skip ci]` on development commits;
- push that commit when the prompt authorizes repository write.

Do not split one prompt into many remote commits merely to checkpoint progress.

Do not cross a gate requiring owner/manual/Windows/game/Nexus validation by declaring it passed.

## End-of-prompt report

Always report:
- starting HEAD;
- ending commit;
- completed work;
- local validations and their category;
- remaining unverified items;
- comparison against the original active plan;
- any plan change and why it is objectively better;
- exact next work.

If a clearly superior project-wide approach is discovered, update the authoritative plan/state in the same prompt and document the rationale. Never silently deviate.

## Current architecture target

One PMM-owned executable, not one process:

```text
PMM.exe
PMM.exe --worker analyze
PMM.exe --worker build
PMM.exe --worker update
PMM.exe --worker reference
PMM.exe --worker fixlab   # only after FixLab parity
```

Workers remain separate OS processes.

Keep Modules/Resources/CKL/localization/XAML/recipes/config/documentation external and editable where practical.

External third-party executables/runtimes remain external. Do not absorb them merely to claim a single EXE.

FixLab remains a separate distributed exception until the reconstructed replacement passes its parity/Windows gates.

## Product scope that must survive

- I03 localization: 30 registered, 23 enabled, 7 reserve;
- I04 Nexus Updates state/data;
- Workspace;
- Mods & Merge;
- Analyze/Build/Deploy;
- rollback/recovery;
- Deep Analysis;
- FixLab;
- AIIO and AI-directed mod creation.

AI-directed creation means:
- user defines the requested mod;
- AI performs the primary authoring/reasoning;
- PMM provides bounded evidence/tool/build/test/deploy/recovery capabilities.

A complete internal graphical editor is not required for v1.5.0.2.

## Startup incident

`Development/Reliability/Incidents/STARTUP_PRE_UI_2026-09.md`

State: OPEN / NOT REPRODUCED / CAUSE UNKNOWN / WATCHPOINT.

Do not attribute it to locale, antivirus, Workspace, race, PowerShell or another cause without evidence.

Do not start NF01 by chasing it.

## Nexus/antivirus hardening intent

Use auditable engineering:
- offline/read-only healthy startup;
- check separate from explicit repair;
- remove inherited ExecutionPolicy Bypass where supported;
- narrow process contracts;
- conventional reproducible Windows build/resources;
- exact hashes/provenance;
- vendor false-positive channels where needed.

Do not:
- disable antivirus;
- request exclusions;
- hide behavior from scanners;
- silently restore quarantined material;
- mutate binaries to evade detection;
- promise zero detections.

VirusTotal/Nexus sample uploads require explicit authorization at that later step.

## Source/evidence caution

`Development/Source/Host` and `Development/Source/Runtime` are older snapshots.

Later Reliability NativeCandidates diverge from those snapshots.

Do not overwrite distributed native binaries merely because a candidate compiles.

NF01 must inventory exact current roles/source status before NF02 establishes a consolidated canonical native source.

## Package identity/integrity

Current development package identity:
- VERSION `1.5.0.2`
- BUILD_ID `PMM-v1.5.0.2-development-baseline`

Keep VERSION, BUILD_ID, RELEASE_MANIFEST and SHA256SUMS coherent whenever package bytes/identity change.

Do not edit only a visible version label.

## GitHub policy

- read freely;
- remote writes require owner authorization for the relevant block;
- no force push;
- no PR/tag/release/Latest by initiative;
- development uses local validation, not Actions/CI, unless explicitly requested;
- main/stable/release or explicit validation may use remote automation;
- before push, confirm remote HEAD is compatible with a fast-forward update.

## Validation language

Always distinguish:
- static inspection;
- unit/tool/fixture tests;
- build/cross-build;
- real Windows execution;
- WPF/PowerShell runtime;
- Palworld runtime;
- Nexus account behavior;
- antivirus scan;
- Nexus upload.

A PASS in one category is not a PASS in another.
