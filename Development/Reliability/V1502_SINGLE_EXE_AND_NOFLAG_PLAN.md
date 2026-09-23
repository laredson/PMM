# PMM v1.5.0.2 - Single-EXE Core, Open Architecture and Nexus Readiness

Status: **AUTHORITATIVE EXECUTION PLAN**
Branch: `v1.5.0.2`
Plan adopted: 2026-09-23
Bootstrap base: `2586b4c3999ccc094344bc65710d6559f4858871`
Planning commit parent: `9c6d98b5460a095904f318303c7164d960680d90`

This document supersedes the previous ordering in `V1502_PLAN.md` where the startup incident was the next active development target.

The startup incident remains recorded evidence, but it is **not an active blocker** unless it becomes reproducible or remains after the architecture/hardening work.

---

## 1. Product objective for 1.5.0.2

PMM 1.5.0.2 is intended to become the first clean baseline on which the project can continue growing.

The release is not intended to add the future large-scope ideas such as a complete integrated Unreal editor, full server-management platform, Steam Workshop integration, every mod provider or a public CKL service.

The release must instead make the capabilities that already define PMM useful and dependable:

1. update installed mods through supported providers, with Nexus as the first real integration;
2. analyze conflicts and create compatibility patches;
3. restore/repair old mods through Fix Lab when PMM has sufficient evidence/capability;
4. support AI-directed mod creation;
5. preserve the complete I03 localization work and I04 Nexus update work;
6. provide safe deployment, rollback and Workspace persistence;
7. package and behave conventionally enough for a normal Nexus Mods distribution path;
8. leave a maintainable architecture that can evolve without repeatedly adding new PMM executables.

"Nexus readiness" means legitimate, inspectable engineering intended to reduce false positives. It does **not** mean hiding behavior from scanners, disabling protection, requesting exclusions or mutating binaries until a detector is evaded.

---

## 2. Clarification: AI-created mods

PMM does **not** currently have a complete internal mod editor, and 1.5.0.2 must not invent one as a prerequisite.

For the current product concept:

- the **user** defines the desired mod and its behavior;
- the **AI** is the primary authoring/reasoning agent for creating the new mod solution;
- **PMM is the capability plane used by the AI**.

PMM should expose controlled, inspectable capabilities such as:

- read/query game and Game Reference evidence;
- inspect assets and mappings;
- stage candidates;
- invoke allowed build/tool operations;
- validate outputs;
- deploy a candidate transactionally when authorized;
- launch/observe permitted game tests;
- collect results and return evidence to the same AI workflow;
- preserve project/session state in Workspace.

Therefore, future work in this line must **not** interpret "mod creation" as "build a full internal graphical editor first".

The target is:

`User intent -> AI reasoning/creation -> PMM tools/evidence/build/test -> AI iteration -> user-approved result`

PMM remains the authority for filesystem safety, tool boundaries, staging, validation, deployment and recovery. Returned/generated AI content is never trusted merely because an AI produced it.

---

## 3. Architectural principle

### 3.1 One PMM-owned executable, not one process

The target is to converge the PMM-owned native executables into one binary:

`PMM.exe`

That single binary can run in several isolated Windows processes:

```text
PMM.exe                         # interactive application / supervisor
PMM.exe --worker analyze ...
PMM.exe --worker build ...
PMM.exe --worker update ...
PMM.exe --worker fixlab ...
PMM.exe --worker reference ...
```

A worker crash must not crash the UI merely because both processes come from the same executable file.

Each worker must have:
- an explicit operation;
- bounded input;
- explicit working/staging paths;
- timeout/cancellation where appropriate;
- stdout/stderr or structured diagnostics;
- defined exit codes;
- no implicit commit to live state before successful validation;
- transactional handoff for operations that mutate managed data.

This keeps the isolation benefits of the present multiprocess architecture while reducing the number of PMM-owned binaries.

### 3.2 "Single EXE" does not mean "compile everything into the EXE"

PMM intentionally remains open and easy to modify.

The release may continue to expose:

```text
PMM.exe
Modules/
Resources/
CKL/
Tools/
Documentation/
Workspace/
```

as appropriate.

PowerShell modules, localization JSON, XAML/resources, CKL data, recipes and documentation should remain external where editability, transparency or community development benefits from that.

Do **not** turn the current repository/package into a self-extracting opaque blob merely to claim that there is only one file.

Do **not** embed scripts and then unpack/execute them from temporary directories as an anti-scanner strategy.

### 3.3 Scope of executable unification

Unify **PMM-owned executables only**.

Current PMM-owned candidates include:
- `PMM/PMM.exe`;
- `PMM/Engine/PMMRuntime.exe`;
- `PMM/Engine/PMMFixLab.exe` when the reconstructed FixLab implementation has enough proven parity to replace the distributed original.

External tools/runtimes are not targets merely because they are executable files. For example:
- `repak.exe`;
- Microsoft .NET runtime files;
- third-party managed/native dependencies.

These remain external and retain their own provenance/signatures/licenses. Do not absorb or re-sign them solely for cosmetic "one exe" packaging.

---

## 4. Why this architecture is being chosen

The purpose is not to establish a new programming paradigm. PMM is also a learning project, and this architecture should make its evolution understandable.

A small stable executable can own:
- process startup/supervision;
- worker dispatch;
- bounded IPC;
- integrity checks;
- filesystem safety primitives;
- dependency status/explicit repair entry points;
- native operations that genuinely benefit from being compiled;
- stable CLI contracts.

Most feature development can remain in open modules and data.

The success condition is not that the executable never changes again. The success condition is that new PMM features normally extend stable contracts rather than requiring another independent PMM executable or another ad-hoc startup layer.

---

## 5. Current-state findings that must guide the migration

These findings are based on the current `v1.5.0.2` baseline inherited from I04.

### 5.1 Current normal startup is not fully PowerShell-free

Current routing starts natively:

`PMM.exe -> PMMRuntime.exe start`

However the Runtime normally selects the PowerShell/WPF UI when Windows PowerShell is available in FullLanguage mode.

Current candidate source:
- `Development/Reliability/NativeCandidates/Runtime/nativeui.go`
- `Development/Reliability/NativeCandidates/Runtime/ui_plan.go`

The legacy WPF launch currently includes:

`-STA -NoProfile -ExecutionPolicy Bypass -File Start-PalModMerger.ps1`

Therefore it is incorrect to treat the normal user path as fully free of PowerShell policy arguments merely because Host -> Runtime is native.

### 5.2 Startup can currently perform repair/network behavior before UI

`Development/Reliability/NativeCandidates/Runtime/main.go` calls dependency preparation during `start`.

`deps.go` can, depending on state, repair/download:
- repak;
- mappings;
- bundled .NET runtime;
- managed payload from verified nearby releases.

A healthy package already skips network after verification, but a damaged/missing dependency can turn normal startup into a repair path before the main UI appears.

For 1.5.0.2, startup status checking and repair must be separated.

### 5.3 PowerShell Bypass is not limited to one historical path

Known current examples include:
- normal legacy WPF UI arguments;
- dependency worker;
- repair worker;
- MCP/App Server case bridge;
- observation snapshot worker;
- Game Reference worker paths;
- Nexus `nxm://` handler registration command;
- Host fallback script routing.

Do not perform a blind global text replacement. Each invocation has a contract that must be understood and tested.

The objective is to remove Bypass where a supported normal invocation is sufficient and to fail clearly when system policy disallows a required script. PMM must not weaken global policy.

### 5.4 Background operations remain heavily PowerShell-based

`PMM/Modules/Operations/OperationWorker.ps1` currently brokers many operations including Analyze, Build, AIIO, FixLab and Updates.

This is not automatically a defect. The project does **not** require rewriting all PowerShell.

The target is to move the stable process/safety boundary into `PMM.exe`, then decide operation-by-operation what should remain open PowerShell logic versus what should become a compiled worker mode.

### 5.5 Native Runtime still exposes a generic process capability

The reconstructed Runtime contains a `process run` model that accepts an executable and arguments with bounds/timeouts.

For the final public runtime, prefer named PMM operations or a strict allowlisted tool contract over a general-purpose execution surface wherever practical.

Do not remove legitimate tool execution needed by PMM; narrow and document it.

### 5.6 Native build currently post-processes PE resources

Host/Runtime build recipes currently:
1. invoke `go build`;
2. build the repository PE icon helper;
3. modify the produced PE to append `.rsrc` icon resources.

The helper is a build utility, not evidence of malicious process injection.

Nevertheless, NF05 should replace this post-link mutation with a conventional reproducible Windows resource path including:
- icon;
- application manifest;
- VERSIONINFO;
- product/file version;
- product name;
- original filename;
- creator/publisher metadata that is true for this personal open-source project.

Do not associate PMM with Wice Games Studio. PMM is the owner's personal open-source/fan-made project.

### 5.7 The old VirusTotal sample is not the current baseline

Historical recorded VT SHA-256:
`5be86567f597aefb64f1645a9b924c7de213da49206d7591b9e4f7f685fbcade`

The repository evidence associates that sample with the old `PMM.1.3.0.RC30.stable.release.zip`.

It must not be used as proof of what current 1.5.0.1/1.5.0.2 files trigger.

Any new scanner conclusions require exact current hashes and exact sample identity.

### 5.8 FixLab is special

The currently distributed FixLab executable still has weaker reconstructed-source/parity evidence than Host/Runtime.

Research/candidates through 04A-6E exist and must be preserved.

Do not delete `PMMFixLab.exe` just to achieve the single-EXE goal.

FixLab merges into `PMM.exe --worker fixlab` only after the replacement path satisfies the relevant parity/acceptance gates.

---

## 6. 1.5.0.2 execution order

The old S01-S08 plan is replaced for active execution by NF00-NF08 below.

### NF00 - Plan and contract freeze

Status: **CLOSED by this planning commit.**

Purpose:
- define 1.5.0.2 scope;
- record the target one-owned-EXE architecture;
- record the AI-created-mod responsibility model;
- preserve all inherited features as migration gates;
- make the unreproduced startup incident a watchpoint instead of the active next task.

No product bytes change in NF00.

### NF01 - Exact baseline and executable-contract inventory

Purpose: create a local, reviewable before-state before architecture changes.

Required work:
1. verify the exact branch HEAD and clean local checkout;
2. inventory current PMM-owned binaries and exact SHA-256 values;
3. inventory PMM entry points and commands:
   - Host routes;
   - Runtime subcommands;
   - FixLab commands/contracts;
   - background worker launches;
4. inventory PowerShell process launches and classify them by feature;
5. inventory network-capable startup/repair paths;
6. inventory current process/worker result and progress schemas;
7. map which UI actions depend on each worker/command;
8. preserve I03/I04 and package identity evidence;
9. produce an explicit migration matrix:
   `old executable/entrypoint -> future PMM.exe role -> compatibility gate`.

NF01 should reuse existing reliability evidence instead of repeating completed historical research.

NF01 is primarily inspection/evidence. Do not mutate product behavior merely to satisfy the inventory.

Exit gate:
- every PMM-owned executable role to be migrated is accounted for;
- there is a concrete first Host+Runtime integration step;
- no required user-facing feature is orphaned.

### NF02 - Merge Host and Runtime into one PMM.exe

Purpose: remove the permanent `PMM.exe -> PMMRuntime.exe` two-binary boundary while preserving process isolation for work.

Preferred migration shape:
- one source/build target produces `PMM.exe`;
- existing Runtime subcommands become subcommands/modes of PMM.exe;
- normal start no longer launches a second PMM-owned runtime binary;
- worker processes, when needed, launch another instance of the same PMM.exe.

Preserve or replace with equivalent contracts:
- startup splash;
- host session/log identity;
- security status;
- doctor/self-test;
- dependency status;
- UI launch;
- child supervision;
- foreground/UI handoff;
- emergency diagnostic evidence;
- cancellation/process-family behavior.

Do not remove `PMMRuntime.exe` from the package until Windows acceptance proves the combined executable covers the required route.

Use an integration candidate first. Keep rollback possible.

Exit gate:
- normal startup works with the combined executable;
- doctor/security/dependency commands work;
- one worker-mode smoke contract works in a separate process;
- UI survives a deliberately failing worker fixture;
- old Runtime is no longer required by accepted routes before it is removed;
- all checks clearly distinguish static/tool tests from real Windows acceptance.

### NF03 - Startup offline + explicit repair + PowerShell policy cleanup

Purpose: reduce surprising startup behavior and remove inherited policy bypasses without removing valid PMM functionality.

#### NF03A startup dependency policy

Normal `PMM.exe start`:
- verifies required package state locally;
- performs no dependency download;
- performs no silent restoration/reinstallation;
- does not search nearby installations in order to mutate the package;
- reports missing/invalid required components clearly.

Repair:
- is an explicit user/authorized operation;
- uses pinned sources;
- HTTPS;
- size/time limits;
- hash/signature checks where available;
- staging;
- transactional replacement/rollback where relevant;
- never retries in a way intended to defeat a security product;
- never silently restores quarantined material.

#### NF03B PowerShell policy

For each PowerShell launch:
- remove `-ExecutionPolicy Bypass` where standard invocation is sufficient;
- do not change machine/user execution policy;
- do not silently fall back to a policy bypass;
- if policy blocks a feature, report a precise actionable error or use an already-supported native path;
- keep `CREATE_NO_WINDOW`/hidden console behavior when it only prevents CLI-window flicker for a GUI/background worker.

Start with the main WPF UI path because it is part of normal startup, then cover feature workers.

#### NF03C NXM registration

The `nxm://` handler must not register a command that depends on ExecutionPolicy Bypass if a supported equivalent is available.

Preserve:
- exact URI validation;
- expiry validation;
- current-plan/file identity checks;
- DPAPI-protected queue behavior;
- explicit opt-in registration/restoration.

Exit gate:
- healthy startup has no network/repair mutation;
- no normal startup path requires ExecutionPolicy Bypass;
- remaining Bypass occurrences, if any, are either removed or explicitly blocked from release with rationale;
- Nexus update workflows remain intact.

### NF04 - One-executable worker architecture

Purpose: make the stable execution/safety boundary live in `PMM.exe` while preserving open feature modules.

Target roles include, as appropriate:
- `PMM.exe --worker analyze`;
- `--worker build`;
- `--worker update`;
- `--worker reference`;
- `--worker recovery`;
- `--worker fixlab` only after FixLab parity allows it.

This phase does **not** require moving every algorithm out of PowerShell.

A compiled worker can supervise/load a known PMM module operation if that remains the clearest open architecture, provided:
- operation name is allowlisted;
- arguments are structured and validated;
- root/workspace boundaries are fixed;
- status/result schemas are explicit;
- no arbitrary shell command is accepted as a public PMM operation;
- worker crash/cancel leaves recoverable state;
- live mutations are transactional.

Review the current generic `process run` capability. Narrow it to explicit/allowlisted needs where possible.

OperationWorker migration should be incremental. Do not replace all operations in one untestable change.

Exit gate:
- primary long-running operations use the one-executable process model or have an explicitly documented temporary exception;
- worker failure does not terminate UI;
- no feature is lost merely to reduce process count;
- Workspace/state locking semantics remain coherent.

### NF04F - FixLab convergence gate

This is a sub-gate, not permission to force a premature replacement.

Before deleting the distributed `PMMFixLab.exe`:
- identify the exact current commands PMM relies on;
- map them to reconstructed 04A-6E capabilities;
- pass the existing reference/golden/structural gates relevant to those commands;
- perform Windows acceptance for the PMM.exe worker form;
- preserve recipe/version contracts and rollback.

If FixLab is not ready when NF04's other workers are ready, keep it external temporarily and continue. A single remaining PMM-owned executable exception is preferable to breaking old-mod repair.

### NF05 - Conventional reproducible PMM.exe build

Purpose: finish the executable architecture before product-feature curing.

Requirements:
- one canonical PMM.exe source/build recipe;
- fixed toolchain;
- deterministic/reproducible inputs as far as practical;
- standard Windows resources included through the normal build path;
- no custom post-link PE icon injector in the final canonical recipe;
- icon;
- application manifest;
- VERSIONINFO;
- consistent FileVersion/ProductVersion;
- ProductName: Palworld Manager Merger;
- creator/publisher metadata truthful to this personal open-source project;
- no Wice Games Studio attribution;
- final artifact inventory generated from final bytes.

Do not claim that Go, stripping, section layout or any one build property causes antivirus detections without measured evidence.

A controlled A/B build can be used to decide optional linker settings, but do not iterate random binary mutations to chase scanners.

Exit gate:
- PMM.exe can be rebuilt from documented source/toolchain;
- its resources/version are inspectable through standard Windows mechanisms;
- final bytes are not subsequently mutated by the build;
- Host/Runtime unified path is accepted;
- remaining external executables are clearly third-party or documented temporary exceptions.

### PRODUCT - Cure the existing user-facing capabilities

After NF05, pause architecture expansion.

The next objective is to make the present PMM product work as intended.

Recommended order:

#### P01 - Updates

The current I04 implementation is preserved but is not considered product-complete merely because its static regressions passed.

Define and verify the intended user behavior before changes, including:
- discovery/identity of installed mod origin;
- Nexus account modes;
- free-account `nxm://` confirmation;
- update chain/variant handling;
- download;
- candidate analysis;
- compatibility checks;
- game-running deferral;
- atomic apply;
- rollback/archive;
- batch behavior;
- UI states/messages;
- failure recovery.

Real Nexus account behavior and Palworld runtime remain gates.

#### P02 - Compatibility patches

Verify the existing Analyze -> Resolve -> Build -> Deploy path can:
- identify actual conflicts;
- preserve non-conflicting mods;
- create only the compatibility output needed;
- reuse valid prior patches safely;
- invalidate stale evidence;
- deploy/rollback transactionally.

#### P03 - Old-mod restoration / Fix Lab

Complete the user flow around old/unsupported mods:
- discovery;
- evidence;
- candidate/recipe choice;
- build;
- review;
- deployment;
- backup/revert;
- exact claims about what was and was not proven.

This is also the point to finish NF04F if it was deferred.

#### P04 - AI-created mods through PMM

Do **not** build an internal general-purpose editor as a prerequisite.

Verify an AI can use PMM's bounded interfaces to:
- understand the user's requested mod;
- request/read necessary game/reference evidence;
- create/stage source or cooked candidates allowed by current capabilities;
- ask PMM to build/validate;
- use PMM to test/observe when a validated adapter permits it;
- iterate within the same project/session;
- leave an inspectable artifact/result for the user.

The AI is responsible for the creative/technical construction. PMM supplies controlled capabilities and evidence.

### NF06 - Full regression and package preflight

Only after P01-P04 are acceptable.

Required coverage:
- clean install;
- update over prior supported package;
- existing Workspace;
- first launch and subsequent launch;
- 23 enabled languages;
- zh-CN and zh-TW coverage where applicable;
- RTL language;
- theme/resource loading;
- Nexus Updates;
- Analyze/compatibility patch;
- Build/Deploy;
- rollback/recovery;
- FixLab;
- AIIO/AI-created-mod flow;
- worker failure/cancellation;
- startup offline behavior;
- dependency check vs explicit repair;
- package/version/hash coherence.

The historical pre-UI incident remains a watchpoint. Do not block the release merely because it was once reported and cannot be reproduced, but if it appears during regression, capture and fix it.

### NF07 - Current-artifact scanner/Nexus validation

After the product is functionally ready.

1. construct the actual candidate package;
2. record ZIP SHA-256;
3. record exact hashes of PMM-owned and relevant third-party binaries;
4. perform local Windows/Defender validation;
5. attribute any detection to the exact artifact where possible;
6. VirusTotal sample upload requires explicit owner authorization;
7. Nexus test upload requires explicit owner authorization;
8. record hash/date/engine/detection/result;
9. do not confuse an old RC30 VirusTotal result with the candidate.

If individual vendors produce demonstrable false positives, use their official false-positive process rather than modifying behavior solely to evade a heuristic.

### NF08 - Optional provenance/signing after the program is ready

Authenticode/SignPath is **not a release blocker for 1.5.0.2**.

PMM is a personal open-source/fan-made project, unrelated to Wice Games Studio.

If the project later benefits from code signing, evaluate SignPath Foundation after:
- executable architecture is stable;
- product features are ready;
- final release artifacts exist.

Do not buy or provision a commercial certificate as an assumed project requirement.

---

## 7. Migration invariants

Every NF/P phase must preserve these unless an explicit scoped change says otherwise:

### Localization
- 30 registered languages;
- 23 enabled languages;
- 7 reserves;
- language names displayed natively;
- RTL/LTR behavior;
- persisted choice;
- no English/Spanish-only regression.

### Updates
- I04 data/state must not be discarded simply because Updates is later repaired;
- provider identity records and archives remain migratable;
- credentials remain protected and excluded from source/package.

### Workspace
- user state remains under Workspace;
- architecture migration must not silently delete or reset Workspace;
- schemas must be versioned/migrated deliberately if changed.

### Safety/recovery
- live game/mod mutations remain transactional;
- backups/archives are not silently discarded;
- crash/cancel paths preserve enough evidence to recover;
- child processes do not outlive PMM unintentionally.

### Open development
- Modules/Resources/CKL remain inspectable and editable where practical;
- single executable does not imply obfuscation;
- community/developer extension should not require recompiling PMM.exe for ordinary data/module changes.

### External tools
- preserve third-party provenance;
- never present third-party binaries as PMM-signed/owned;
- update pins deliberately.

---

## 8. Development discipline for Codex

### Before each implementation block
1. read this file;
2. read `STATUS.md` and `NEXT_SESSION.md`;
3. confirm branch `v1.5.0.2`;
4. inspect current code rather than assuming an old handoff is still accurate;
5. define the smallest reversible change.

### During development
- prefer incremental migrations;
- do not copy an older PMM tree over the branch;
- do not delete the old path until replacement acceptance exists;
- keep evidence of what was actually tested;
- do not label static parsing/unit tests as Windows runtime proof;
- avoid unrelated cleanup in architecture commits.

### GitHub policy
- development writes require owner authorization for the requested block;
- development commit/push is silent with `[skip ci]`;
- no Actions/CI during development unless explicitly requested;
- no PR/tag/release/Latest change by initiative;
- no force push;
- local functional acceptance by the owner remains the normal development gate.

---

## 9. Immediate next action for Codex

Start with **NF01**.

Do not begin by debugging the historical pre-UI incident.

Do not begin by rewriting all PowerShell.

Do not begin by deleting PMMRuntime/FixLab.

Deliver an exact migration inventory and the smallest concrete Host+Runtime unification candidate plan, based on the checked-out `v1.5.0.2` code.

NF01 should end with:
- current PMM-owned executable hashes;
- current command/route matrix;
- worker/process launch matrix;
- Bypass/network/startup-repair inventory;
- old -> new single-EXE migration matrix;
- exact files proposed for NF02A;
- tests/gates for NF02A;
- no unsupported claims about scanner causality.

Then NF02A can implement the first reversible combined-executable candidate.


---

## 10. Decision-context transcript

The architectural/product discussion that led to this plan is preserved at:

`Development/Reliability/V1502_DECISION_TRANSCRIPT_2026-09-23.md`

It is historical context, not a competing specification. Use it to understand the owner's intent and the alternatives considered; use this plan for implementation requirements.


---

## 11. Local-first prompt execution protocol

Normal implementation work uses a local clone.

At prompt start:
1. clone if necessary, otherwise fetch;
2. checkout `v1.5.0.2`;
3. fast-forward only;
4. require a clean working tree;
5. check/regenerate `.pmm-index` with `Development/Tools/build_repo_index.py`;
6. read canonical handoff/state/status/next.

During a prompt:
- advance as far as reasonably possible inside the current authorized block and acceptance gate;
- do not create artificial micro-session boundaries;
- do not fake a manual/Windows/game/Nexus gate;
- keep changes coherent and reversible;
- validate locally.

Normal completion:
- one coherent development commit per prompt;
- include code + evidence + continuity updates that belong to that work;
- commit message ends `[skip ci]`;
- push when authorized;
- report start/end HEAD, work, validation category, remaining uncertainty, comparison with the plan and exact next step.

If evidence shows a clearly superior project-wide plan, update this plan/state in that same prompt and record the rationale. Do not silently diverge.

The canonical handoff definition and precedence rules live in `Development/Handoff/README.md`.
