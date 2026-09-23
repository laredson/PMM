# NF01 FINDINGS - exact baseline and single-EXE migration design

Status: **SUBSTANTIALLY COMPLETE / LOCAL-CLONE CONFIRMATION GATE OPEN**
Branch: `v1.5.0.2`
Starting HEAD inspected: `4d14627ce111aa416491f1fa278473354e70550d`
Date: 2026-09-23

NF01 is an evidence/design phase. No PMM runtime behavior was changed by this block.

## 1. Execution-environment limitation

The required local-first workflow was attempted first.

Command attempted:

`git clone --branch v1.5.0.2 --single-branch https://github.com/laredson/PMM.git`

The execution container could not resolve `github.com` and clone failed before authentication:

`Could not resolve host: github.com`

Therefore this NF01 pass used the authenticated GitHub repository connector against the exact branch tree/HEAD instead of pretending a local clone existed.

Consequences:
- tree/file/route/source comparisons below are real branch evidence;
- important launch/Bypass contracts were directly inspected;
- binary sizes are from the current Git tree;
- binary SHA-256 values are from the current package `SHA256SUMS.txt`;
- a byte-for-byte local SHA recomputation and exhaustive local grep are **not claimed** in this session.

The next local-capable session must run the short NF01-L confirmation checklist before NF02A edits.

---

## 2. PMM-owned executable identity

Current Git tree:

| Executable | Size | Git blob SHA | package SHA-256 |
| --- | ---: | --- | --- |
| `PMM/PMM.exe` | 2,744,832 | `1e6e1932f7e02a068a5ed154a2d00f3a41ddf138` | `a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c` |
| `PMM/Engine/PMMRuntime.exe` | 6,506,496 | `aa170ae00aad1509a1e45d60a410a946da7119e0` | `b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f` |
| `PMM/Engine/PMMFixLab.exe` | 2,790,912 | `e2a7c8269215f5f02db1408429ddee58fc445b52` | `8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe` |

Important: Git blob SHA is not SHA-256.

The SHA-256 values above are the values declared by the current package integrity inventory. NF01-L must recompute them locally from bytes before calling the binary identity gate fully closed.

### Source status

**PMM.exe / Host**
- distributed source status in manifest: reconstructed C2B integrated for user trial; Windows acceptance pending;
- latest reliability source: `Development/Reliability/NativeCandidates/Host/`;
- old snapshot: `Development/Source/Host/`;
- the old snapshot is not equivalent to the latest candidate tree.

**PMMRuntime.exe**
- latest reliability source: `Development/Reliability/NativeCandidates/Runtime/`;
- old snapshot: `Development/Source/Runtime/`;
- source trees materially diverge.

**PMMFixLab.exe**
- distributed executable remains the original/reference binary;
- exact source parity/reproducible source is not established;
- reconstruction/research is under `Development/Reliability/NativeCandidates/FixLab/`;
- do not merge/delete this executable in NF02.

---

## 3. Source divergence: old snapshots are not canonical

### Host

`Development/Source/Host/` contains only the old `main.go` path for the core Host source.

The latest Reliability candidate adds/changes:
- `main.go` - changed;
- `bridge_windows.go` - candidate-only;
- `splash_state.go` - candidate-only;
- `splash_state_test.go` - candidate-only;
- `splash_windows.go` - candidate-only;
- `progress_only_test.go` - candidate-only;
- `tools/hostmeta.go` - candidate-only.

Therefore compiling/testing only `Development/Source/Host` does not validate the latest reconstructed Host behavior.

### Runtime

Old Runtime snapshot: 18 Go files.
Latest Reliability Runtime candidate: 28 Go files.

Eight same-path files are byte-identical by Git blob:
- `archive.go`;
- `knowledge.go`;
- `manifest.go`;
- `native_shell_model.go`;
- `native_shell_other.go`;
- `notify_other.go`;
- `notify_windows.go`;
- `runtime_test.go`.

Ten old same-path files have diverged:
- `deps.go`;
- `doctor.go`;
- `game.go`;
- `main.go`;
- `native_shell_windows.go`;
- `nativeui.go`;
- `process.go`;
- `process_other.go`;
- `process_windows.go`;
- `util.go`.

Ten candidate-only files add newer contracts:
- `bridge.go`;
- `bridge_other.go`;
- `bridge_test.go`;
- `bridge_windows.go`;
- `inventory_contract_test.go`;
- `process_args.go`;
- `process_contract_test.go`;
- `tools/runtime_meta.go`;
- `ui_plan.go`;
- `ui_plan_test.go`.

### Conclusion

The current CI/repository validation that compiles `Development/Source/Host` and `Development/Source/Runtime` cannot be treated as validation of the latest C2B source lineage.

NF02A should establish a new canonical unified source tree instead of copying one old tree over another.

---

## 4. Host contract today

Latest Host candidate responsibilities:
- default operation: `start`;
- owns startup splash;
- creates a Host session under Workspace;
- captures security status;
- loads `Engine/Runner/routes.json`;
- supervises one child process;
- captures stdout/stderr to bounded logs;
- keeps child startup/exit evidence;
- performs UI HWND/splash foreground handoff for the direct Runtime start route;
- writes `PMM_HOST_SESSION_V1`;
- creates emergency `PMM_AI_HANDOFF_EMERGENCY_V1` on failures.

Host-owned direct commands:
- `doctor [--json]`;
- `security status [--json]`;
- `handoff create [--reason ...]`.

For normal routed operations, Host uses `routes.json`.

### Current route table

| Host operation | Current child |
| --- | --- |
| `start` | `PMMRuntime.exe start` |
| `runtime-self-test` | `PMMRuntime.exe self-test` |
| `runtime-doctor` | `PMMRuntime.exe doctor` |
| `runtime-security` | `PMMRuntime.exe security` |
| `runtime-native-ui` | `PMMRuntime.exe ui-native` |

If an operation is not a known native route, Host can fall back to:
`powershell -NoProfile -ExecutionPolicy Bypass -File Engine/Runner/PMM-Runner.ps1 <operation>`.

That fallback is deliberately retained for NF03 analysis; NF02A should not silently remove an extension path before a replacement contract exists.

---

## 5. Runtime contract today

Current Runtime commands from latest candidate source:

- `version`;
- `doctor`;
- `security`;
- `knowledge validate`;
- `game detect`;
- `dependencies status`;
- `dependencies ensure [--if-needed] [--refresh-mappings]`;
- `hash sha256 <file>`;
- `archive extract <zip> <dir>`;
- `archive create <zip> <dir>`;
- `process run [--timeout-sec N] [--cwd DIR] -- <executable> [args]`;
- `start`;
- `ui`;
- `ui-native`;
- `self-test`.

### Process contract

`process run` remains generic:
- executable is supplied by caller;
- optional cwd;
- default timeout 5 minutes;
- max timeout 86,400 seconds;
- result schema `PMM_RUNTIME_PROCESS_V1`.

This stays intact through NF02 for compatibility. Narrowing/allowlisting belongs to NF04 after callsites are mapped.

### UI routing

Latest Runtime UI plan:
- forced native OR no PowerShell OR language mode != FullLanguage -> native shell;
- otherwise -> legacy PowerShell/WPF.

The current legacy WPF arguments explicitly include:
`-STA -NoProfile -ExecutionPolicy Bypass -File ...`.

NF02 should preserve UI behavior. NF03 owns policy cleanup.

---

## 6. Startup network/repair path

Current Runtime `start` calls dependency ensure before launching UI.

`ensureDependencies` is local-only when dependencies are healthy, but on missing/invalid state it can:
- download pinned repak release;
- download Palworld mappings;
- download pinned Microsoft .NET Runtime archive;
- repair managed payload from verified nearby package material.

Network code uses bounded HTTP clients/timeouts and verification, but normal startup still crosses into repair behavior when damaged.

Conclusion:
- this is a real pre-UI failure class;
- it is **not proof** that it caused the historical startup incident;
- NF03 should change normal `start` to inspect/status only and require explicit repair.

---

## 7. Product worker/process architecture today

### Main background broker

`Modules/Operations/OperationWorker.ps1` accepts this fixed operation set:

- Analyze
- Build
- AIHandoff
- AIIOPrepare
- AIIOPendingData
- AIIOImportResponse
- AIIOUseCandidate
- AIIOModBuild
- AIIOArtifactRefresh
- FixLabBuild
- MappingsImport
- DeepAnalysis
- DeepCase
- DeepSource
- UpdateCheck
- UpdateApply
- UpdateRestore
- Recovery

The WPF UI launches this broker in a fresh Windows PowerShell child.

### Broker state/safety contract

Progress:
- `PMM_BACKGROUND_OPERATION_PROGRESS_V2`.

Result:
- `PMM_BACKGROUND_OPERATION_RESULT_V2`.

Serialization:
- installation-local exclusive file lock `Cache/PMM.background-operation.lock`;
- Recovery is the explicit exception.

Journal:
- append-only `PMM_OPERATION_EVENT_V1`;
- events START/STEP/END/FAIL/ROLLBACK/ABANDON/RECOVERY_REQUIRED;
- named mutex protects journal writes.

Module runtime:
- `PMM_MODULE_SNAPSHOT_V1`;
- operation lease keeps currently loaded module generation alive until the job ends.

Result/progress files are written temp-then-move.

This is a sound contract to preserve while changing the executable boundary.

### Dedicated worker families

Separate currently verified process families include:
- Game Reference: `GameReferenceWorker.ps1`;
- repair/AI agent: `Repair.Worker.ps1`;
- observation snapshot: `Observation.SnapshotWorker.ps1`;
- Unreal/dependency installation: `Dependencies.Worker.ps1`;
- MCP reference wrapper -> Game Reference worker;
- MCP App Server -> `Start-PMMMCP.ps1`;
- NXM protocol handler registered as a PowerShell shell command.

These do not all need to become native in NF02. NF04 should decide which become explicit PMM.exe worker modes.

---

## 8. Directly verified ExecutionPolicy Bypass inventory

The following branch paths were directly inspected in NF01 and contain Bypass in process-launch behavior:

1. `Development/Reliability/NativeCandidates/Host/main.go`
   - Host script-route fallback.
2. `Development/Reliability/NativeCandidates/Runtime/ui_plan.go`
   - normal legacy WPF UI.
3. `PMM/Modules/Presentation/Operations.UI.ps1`
   - OperationWorker;
   - GameReferenceWorker.
4. `PMM/Modules/Unreal/Dependencies.Service.ps1`
   - Dependencies.Worker.
5. `PMM/Modules/Analysis/Repair.Service.ps1`
   - Repair.Worker.
6. `PMM/Modules/MCP/AppServer.Client.ps1`
   - Start-PMMMCP.
7. `PMM/Modules/Observations/Observation.Service.ps1`
   - Observation.SnapshotWorker.
8. `PMM/Modules/MCP/MCP.Reference.ps1`
   - MCP.ReferenceWorker.
9. `PMM/Modules/MCP/MCP.ReferenceWorker.ps1`
   - GameReferenceWorker.
10. `PMM/Modules/Analysis/Nexus.Client.ps1`
    - registered `nxm://` command.

This is a directly verified runtime set, but **not declared exhaustive** until NF01-L runs local grep/index over the clone.

NF03 should remove Bypass operation-by-operation while preserving normal Windows policy and clear failure reporting.

---

## 9. FixLab contract actually used by current PMM

Current UI:
- FixLab build runs through the shared `OperationWorker.ps1` as `FixLabBuild`.
- the worker calls `Invoke-PMMFixLabBuild`.

Current native recipe path resolves the engine from recipe metadata.

The distributed native FixLab engine is currently called with two concrete command contracts:

### Requirements

`PMMFixLab.exe requirements --recipe <recipe>`

Expected:
- exit code 0;
- JSON response;
- `referenceFamilies` informs bounded Game Reference hydration.

### Build

`PMMFixLab.exe build --recipe <recipe> --source-root <dir> --game-reference <dir> --output <pak> --report <json>`

Expected:
- exit code 0;
- output PAK exists;
- report exists and parses as JSON;
- report validation requires `readback=true` and `byteExact=true`;
- output hash is recorded;
- output filename must end in `_P.pak`.

Other Runner-level FixLab commands still exist for jobs/UI orchestration:
- list-jobs;
- new;
- add-related;
- analyze;
- handoff;
- build.

### NF02 implication

Do not merge FixLab into the unified binary during Host+Runtime convergence.

Its future PMM.exe worker replacement must preserve at minimum the native `requirements` and `build` behavior plus report semantics.

---

## 10. Migration matrix

| Current boundary | NF02A target | Preserve |
| --- | --- | --- |
| `PMM.exe` Host | unified `PMM.exe` Host mode | splash, session, supervision, logs, handoff |
| `PMMRuntime.exe start` | child `PMM.exe runtime start` | **separate OS process** |
| Runtime diagnostics | `PMM.exe runtime <command>` | output/exit contracts |
| `routes.json` native runtime routes | same-binary child routes | reversible route table |
| Runtime legacy WPF child | unchanged in NF02 | external/editable UI |
| Host PS runner fallback | unchanged in NF02 | extension compatibility; NF03 review |
| `OperationWorker.ps1` | unchanged in NF02 | worker/result/lock/journal contracts |
| dedicated PS workers | unchanged in NF02 | feature behavior |
| `PMMFixLab.exe` | unchanged in NF02 | requirements/build exact contract |
| third-party EXEs | unchanged external | provenance/licensing |

Key design refinement:

**Single EXE does not mean Host and Runtime must share one process.**

The unified file should preserve the current crash/isolation boundary by making the Host launch another instance of itself in Runtime mode:

`PMM.exe -> PMM.exe runtime start`

This is preferable to invoking Runtime logic in-process during normal startup.

---

## 11. NF02A canonical source layout

Rather than promote either stale snapshot or candidate directory wholesale, create a new canonical source module:

```text
Development/Source/PMM/
  go.mod
  cmd/pmm/main.go
  internal/host/
  internal/runtime/
  internal/supervision/
  internal/uibridge/
```

Inputs:
- latest Reliability Host candidate;
- latest Reliability Runtime candidate;
- Supervision;
- UIBridge.

Old `Development/Source/Host`, `Development/Source/Runtime` and Reliability candidates remain historical/reference material until NF02 acceptance.

### Dispatch model

`cmd/pmm/main.go`:
- when invoked as `PMM.exe runtime ...`, dispatch directly to Runtime package;
- otherwise dispatch Host behavior.

Host native route plan:
- use `os.Executable()`;
- child arguments become `runtime start`, `runtime self-test`, etc.;
- keep child supervision exactly as a separate process.

This avoids source-name collisions and preserves process isolation.

---

## 12. Exact NF02A implementation scope

NF02A should:
1. create the canonical unified Go module;
2. port current candidate Host/Runtime/Supervision/UIBridge without changing feature semantics;
3. add compatibility tests for CLI dispatch/route argument construction;
4. build `PMMUnified-candidate.exe` **outside the package**;
5. do not overwrite `PMM/PMM.exe`;
6. do not remove `PMMRuntime.exe`;
7. compare candidate metadata/behavior statically;
8. prepare Windows acceptance instructions.

Do not in NF02A:
- remove Bypass;
- change dependency startup policy;
- narrow `process run`;
- migrate OperationWorker;
- merge FixLab;
- change Updates behavior.

Those later scopes remain NF03/NF04/P01.

---

## 13. NF02A acceptance gates

Static/tool gates:
- Go tests for unified dispatch;
- Host route tests;
- Runtime command/parser tests;
- Supervision/UIBridge tests;
- no network/toolchain auto-download in build;
- build output outside checkout/package;
- canonical source inventory recorded.

Windows acceptance before integration:
- `PMMUnified-candidate.exe doctor --json`;
- `security status --json`;
- `runtime self-test`;
- `runtime doctor`;
- `runtime security`;
- normal `start`;
- splash -> WPF foreground handoff;
- close UI normally;
- force a child Runtime failure and confirm Host survives/records it;
- compare Workspace Host session/log behavior;
- no unexpected console window.

Only after Windows acceptance should the package replace `PMM.exe` and switch native routes to self-child Runtime mode.

---

## 14. Rollback

NF02A candidate work is reversible by design:
- build candidate outside package;
- retain current PMM.exe;
- retain PMMRuntime.exe;
- retain current routes.json;
- retain old source/candidate trees.

Integration rollback, if later needed:
- restore previous `PMM.exe`;
- restore previous `routes.json`;
- restore VERSION/BUILD_ID/manifest/checksums for the prior package commit;
- PMMRuntime.exe remains available until accepted replacement proves it is no longer required.

No force push/history rewrite is needed.

---

## 15. Repository issues discovered by NF01

1. **Validation-source drift**  
   Existing validation/CI compiles older `Development/Source/Host` and `Development/Source/Runtime`, not the latest Reliability candidates. Do not treat that as unified-source validation.

2. **Missing architecture consensus target**  
   RELEASE_MANIFEST points to `Development/Docs/Architecture/PMM_PROCESS_AND_UI_CONSENSUS.md`. NF01 creates that file so the reference becomes real and records current/target process ownership.

3. **FixLab manifest source wording is misleading**  
   Manifest points to `Development/Source/FixLabEngine/`, which is not the current reconstructed research location and must not imply exact source recovery. Correct this during the next package-manifest cleanup (NF02/NF05) with explicit `source not recovered + researchRoot` semantics.

4. **Old release-validation tooling is version-stale**  
   Existing RUN_VALIDATION/CI still includes 1.3-era naming and Bypass. Replace only after unified canonical source exists so validation is not moved twice.

---

## 16. NF01 completion assessment

Completed with branch evidence:
- PMM-owned binary tree identities/sizes;
- package SHA pins;
- Host route/command matrix;
- Runtime command/capability matrix;
- current FixLab native contracts;
- primary broker operation list;
- progress/result/journal/locking contracts;
- source divergence matrix;
- startup network/repair path;
- directly verified Bypass launch families;
- old -> new migration matrix;
- exact NF02A source/process design;
- acceptance and rollback design.

Open confirmation only:
- recompute the three executable SHA-256 values from local bytes;
- run repository index/grep locally and compare Bypass/process inventory with this report.

If NF01-L finds no missing critical process boundary, NF01 becomes CLOSED and NF02A starts immediately.
