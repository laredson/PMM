# NEXT SESSION - PMM v1.5.0.2

## Active block: NF01

**Exact baseline + executable/worker/process contract inventory**

Use a local clone and complete as much of NF01 as can be safely established in one prompt.

## Prompt-start procedure

1. fetch;
2. checkout `v1.5.0.2`;
3. fast-forward only;
4. verify clean working tree;
5. run `python Development/Tools/build_repo_index.py --check`;
6. regenerate index if stale;
7. read current handoff/state/plan.

Record starting HEAD.

## Required NF01 outputs

Using exhaustive local search plus direct source verification:

1. exact HEAD and clean-tree state;
2. actual SHA-256 and size of:
   - `PMM/PMM.exe`;
   - `PMM/Engine/PMMRuntime.exe`;
   - `PMM/Engine/PMMFixLab.exe`;
3. source-status classification for each PMM-owned EXE;
4. Host commands/routes matrix;
5. Runtime subcommand/capability matrix;
6. FixLab commands/contracts actually consumed by current PMM;
7. every background-worker/process launch site grouped by feature;
8. every `ExecutionPolicy Bypass` occurrence grouped by runtime/maintainer/test usage;
9. startup network/repair-capable paths;
10. current progress/result/locking/journal schemas between UI/workers;
11. references to `Development/Source` vs Reliability NativeCandidates and exact divergence risk;
12. old-entrypoint -> proposed PMM.exe role migration matrix;
13. exact smallest reversible NF02A Host+Runtime implementation proposal;
14. NF02A tests/gates;
15. explicit rollback path.

Create durable NF01 findings/evidence under Reliability rather than relying only on chat output.

## Important known issue to verify

Current repository infrastructure has historically tested `Development/Source/Host` and `Development/Source/Runtime`, while later Reliability NativeCandidates have diverged.

NF01 must establish which source becomes canonical before future validation/build automation is trusted as evidence for the unified executable.

Do not solve this by blindly copying one tree over the other.

## Constraints

Do not:
- rewrite all PowerShell;
- remove PMMRuntime.exe;
- remove PMMFixLab.exe;
- change user-facing feature behavior merely to complete inventory;
- attribute antivirus detections without current exact evidence;
- chase the unreproduced startup incident without new evidence.

## Prompt completion rule

Advance NF01 as far as reasonably possible in this prompt.

Normal output is one coherent commit containing:
- NF01 findings/evidence;
- any safe index/continuity corrections discovered;
- STATUS/NEXT/HANDOFF changes if state materially advances.

Use `[skip ci]`.

Do not run Actions/remote CI during development.

End report must compare actual findings with the existing plan and record any objectively superior plan modification.

## NF01 exit gate

A new reviewer must be able to answer:
- what every PMM-owned EXE does today;
- which source/evidence corresponds to it;
- every important process/worker boundary;
- which behaviors are open/module-based;
- what moves in NF02A;
- how NF02A is tested and rolled back.

Then NF02A can begin.
