# PMM workbench — shared implementation state

Updated: 2026-09-12. Status: parked on branch 1.4.0-ReUI by user request; do not merge into the 1.3.1 baseline or main. Baseline commit: c849942. The redesign is preserved in branch 1.4.0-ReUI. The original 1.3.1ModCreator baseline remains c849942 on codex/optional-modding-setup. No new public release or native rebuild. Current authority: [AGENTS](../../AGENTS.md), [architecture/UI contract](../Docs/Architecture/PMM_WORKBENCH_CONTRACT.md), [user guide](../../PMM/Documentation/WORKBENCH.md).

## Implemented

1. **Cases:** shared V4 contract over the readable V3 envelope; historical AICASE/session associations retained; immutable evidence; logical provider-set dedupe; atomic Analyze batch visibility; contextual Fix/Compat/Query with multiple sources; stale response/candidate rejection; verified ZIP extraction. The old Item/item shadowing error is corrected. Reference freshness and semantic readability are explicitly separate.
2. **Persistence/deployment:** atomic JSON, backup recovery and schema migrations; durable phase records; startup recovery; full backup/path/hash validation; pending recovery blocks deployment; worker/MCP/deployment common operation gate and module version snapshots.
3. **Jugar/Crear:** unified navigation over preserved existing controls; library/repairs/saves/history; common editor for every case type; no automatic IA call or navigation from Analyze; keyboard/contextual multi-mod actions; candidates linked back to their case; retained search/selection/drafts; artwork header and unchanged ColorFlow palette; high contrast resources and reduced-motion behavior.
4. **Modules/tools:** Bootstrap reduced from approximately 6,300 to 333 lines; 39 manifest nodes; presentation/actions/workflow extracted into editable modules. Pure-function service reload stages and activates while idle; invalid source preserves the prior version. Presentation/legacy initialization and native changes require restart. Structured scalar and optional Unreal texture adapters share existing validated providers. Heavy case creation, tools, capabilities, candidate checks and knowledge scans use workers.
5. **Knowledge/observations:** failed attempts and built candidates retained; generated library copies disabled; trial activation requires current evidence/provenance, one-use local proof and explicit decision. Separate technical/observation/user/reviewer/applicability dimensions. Process observation binds the selected installation and exact committed deployment, excludes gaps/suspension, records crash coverage, groups feedback once after >=10 observed minutes. Versioned allowlisted local import/export, canonical dedupe, inert pending imports and preference storage; no receiver or uploads.

## Validated

All service/worker and WPF tests below use isolated fixtures under Development/TestResults, not real game installation writes.

Windows PowerShell 5.1:
- cases_v4_regression.ps1: 36 assertions, including zero/one/many results, changed evidence, failed publication visibility/retry, contextual cases, migration, ZIP and stale responses.
- play_create_knowledge_regression.ps1: 51 assertions, including separate truth labels, canonical contributions, private-field rejection, observation gaps/clock/UTC/crash coverage and exact deployment candidates.
- play_create_tools_regression.ps1: 15 assertions using the real isolated Tool.Worker, provider arguments/revisions, cancellation through the terminal worker state, knowledge scan, candidate rejection and source rehash during contextual creation.
- play_create_trial_regression.ps1: 10 assertions using the real library setter; bypass, proof ownership, changed sources, expiry, one-use activation and ordinary mods.
- persistence_recovery_regression.ps1: nine actual forced child-process terminations, six corruption/path/edit guards, idempotent recovery, lock/lease release and activation guard.
- module_runtime_regression.ps1 and architecture_contract_regression.ps1: generation retention, deferred activation, source/contract/native changes, malformed/cyclic/side-effect modules and single shared Auto/ColorFlow state.
- workbench_ui_regression.ps1: both languages, Query editor roundtrip, contextual multi-source case, search/drafts, actual WPF renders, compact navigation, keyboard focus and simulated 150% layout scale.
- full_bootstrap_smoke.ps1: complete isolated production startup, both languages and all workbench pages; actual WPF templates.
- workbench_actions_regression.ps1: 81 assertions. Covers complete bootstrap with real background workers (including empty-case requests), lifecycle/lease and failure handling, case identity/hashes, one-time result consumption during modal callbacks, one queued knowledge refresh, independent persistent drafts across three case editors and grouped feedback dialog timer/reentry handling.
- Existing MCP bridge (36), transport (15), exchange (15), Unreal adapter (19), WPF materialization and six earlier PowerShell regressions passed.
- Twelve earlier Python model scripts and SmokeTest passed in a clean distribution fixture with Workspace and locally downloaded optional runtime bytes excluded.
- Validate-v1.3.ps1 passed layout, parsers and the 569-file SHA inventory in clean staging. The inventory is generated by Development/Tests/update_mcp_preview_checksums.ps1; regenerate after future runtime/documentation edits. CI now includes the new regression suites; this task ran validation locally and did not trigger a remote CI run.
- All 197 tracked EXE/DLL files were compared byte-for-byte with baseline Git blobs; unchanged.

Final evidence directories (all relative to Development/TestResults):
- SourceAware-50e3904309b045a9a5e6685426b5ac68: validation-results.txt, smoke-results.txt and model-results.txt.
- WorkbenchActions-cd6ee3e795db49ca82e6e2314819f93e: final 81-assertion integration fixture.
- Bootstrap-46d55ad32af14b76a5ce6ed56da3d370: final English/Spanish full startup fixtures.
- Workspaces-56d2532ea7534c4ea45a615e30e2e3cb: Spanish WPF Library/Cases/Knowledge screenshots and layout checks. Fixtures contain synthetic inputs and are not distributable runtime content.
## Pending / proposed — not claimed validated

- Actual Palworld gameplay/compatibility for this checkout, the 1.0.4 repair plan's mappings/semantic reader work, and real Unreal preparation/cooking with installed prerequisites. Another task's plan is not proof it ran.
- Native source/binary parity remains unresolved per Development/Source/SOURCE_STATUS.md. Preserve packaged binaries until reconciled; Go source snapshot tests cannot prove equivalent rebuilt behavior.
- No validated played/gameplay detector is shipped. Observation reports execution; installation-local crash logs do not provide complete OS crash coverage.
- Interactive human acceptance on multiple real monitors/DPI, active Windows high-contrast mode and assistive technologies; automated WPF layout/focus tests are narrower evidence.
- Physical disk/power-loss behavior is not proven by process-kill fixtures.
- General models, animation and arbitrary gameplay-authoring adapters remain unsupported. New adapters need real input/output validation before claiming availability.
- Hot reload of side-effectful legacy initialization/UI is intentionally not enabled. Restart is required; function-only domain services and visual resources have safe refresh paths.
- Promotion of newly reviewed local procedures into production Auto recipes needs a separate declarative-recipe validation/promotion stage. Existing exact-match CKL recipes remain the automatic path; local imports and review labels alone never authorize it.
- Community receiver, anonymous intake, automatic submission, anti-abuse, scheduled review and hosting are proposed later phases. Local exchange sends nothing.

## Handoff workflow

Integration is complete; no active component ownership remains from this task. Before starting another change, inspect git status and current contracts; isolate overlapping edits. Record contract decisions and test evidence here. Do not overwrite pre-existing untracked MCP_LOCAL_STATE, dated research/validation notes, InventoryProbe, SuperInventory, Development/Tools or caches: they predate this change. The user requested preserving this work in a dedicated branch, followed by returning the working checkout to the original baseline. The preservation commit belongs only to 1.4.0-ReUI. No release uploads or live game deployment were performed. Remote main was checked at 9886c4f and declares version 1.3.0; it was not changed.

Resume this redesign only when explicitly requested, from branch 1.4.0-ReUI. Next meaningful validation then: launch that branch in an isolated checkout, select the intended game installation, complete one bounded case from real evidence through an explicit candidate trial and a separately recorded Palworld session. Resolve actual native/Vanilla reader failures as their own cases; do not mark them solved from UI test results.