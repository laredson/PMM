# PMM 1.3.3 analysis and AI routing validation

Base: branch 1.3.2, commit 3e57247f823317c85ceb71a4272b0a813f1f34fc. Implementation branch: 1.3.3. Validation started 2026-09-12.

## Accepted program behavior

The original six-tab WPF interface and 1.3.2 repairs remain. 216 Bootstrap functions were separated into presentation/workflow files. The module catalog, operation leases, compatible idle reload, deployment recovery, knowledge and observation services were selectively recovered from 1.4.0-ReUI. Engine executables and DLLs are unchanged.

Deep analysis has immutable snapshots, explicit reader/index/reverse-reference coverage, filtered evidence, JSON/HTML exports, selected-finding cases, update provenance and exact-variant successor checks. Updates are staged and the proposed source set is analyzed with the previous patch excluded pending rebuild. Candidate builds preserve the active patch selection and previous builds. Failed jobs, distinct candidates and reproducible local procedures remain inspectable.

AI requests specify model, effort and standard speed. The default is Luna/low. Recorded reasoning escalation requires the user ceiling; Repair uses Terra/medium and Complex uses Sol/high. Free/conservative, paid, API-opt-in and manual-chat paths are distinct. Model/effort acknowledgements are checked before inference; unavailable models do not fall back to Astra. Quota checks use reported data and preserve unknown status. Manual chat does not claim automatic delivery or zero usage.

## Executed checks

Counts below are per suite; some suites invoke the same 30-assertion base fixture, so they must not be added as unique assertions.

| Suite | Result |
| --- | --- |
| v133_analysis_regression.ps1 | 30 assertions: false positives, opaque data, reverse references, ambiguity, variants, snapshots, case identity, cancellation and limits |
| v133_evidence_regression.ps1 | 12 additional assertions: canonical identities, serialized import chains, actual ZIP content proof, tampering and stale authorization |
| v133_workers_regression.ps1 | 15 additional checks: real PS5.1 analysis/case/recovery processes, persistent MCP merge failure/retry, real repak ZIP stage, original preservation, proposed set and known-procedure invalidation |
| v133_candidate_regression.ps1 | 6 additional checks: real packing with a synthetic merger, candidate-only publication, no selection/rotation, output confinement and replay refusal |
| v133_ai_policy_regression.ps1 | 23 offline checks; a separate bounded real Luna probe also passed |
| v133_agent_routing_protocol.ps1 | 7 additional protocol checks: explicit routing, cost block, same-thread continuation and no repeated completed turn |
| v133_ui_regression.ps1 | 16 actual WPF checks per English/Spanish: deep panel, actions, filtering, policy dialog, case/source dialog dispatch and failed-worker lease release |
| cases_v4_regression.ps1 | 44 existing case/migration assertions |
| v132_bootstrap_regression.ps1 | 20 existing bootstrap checks per language |
| mcp_bridge_regression.ps1 | 36 assertions; 44 declared bounded tools |
| mcp_transport_regression.ps1 | 15 existing exchange assertions |
| module_runtime_regression.ps1 | Dependency order, pinned busy generation, compatible reload and native/restart guards |
| persistence_recovery_regression.ps1 | Nine forced-termination checkpoints plus changed external files, corrupt backups, path/installation guards, locks and candidate activation |
| v132_reference_recovery_regression.ps1 | 15 extraction/reference checks |
| v132_mappings_regression.ps1 | 8 checks |
| v132_datatable_guards_regression.ps1 | 14 rejection checks |
| v132_reader_regression.ps1 | 36 comparisons over 32 actual cooked families; shipped/baseline/source parity |
| workspaces_dependencies_regression.ps1 | Existing dependency and workspace boundaries passed; no installer executed |

The real local DataTable regression preserves 753 rows, 68,523 properties and all 103 current true IsUncapturable values while transferring the 10,539 intended changes. The cooked header differs only in proven size bookkeeping. FasterMounts/RushRoar therefore retains the 1.3.2 repair. EasyBreeding/NoCollision remains explicitly unsupported with current 29-export Blueprint data versus older 28-export sources and missing schema coverage.

An isolated deep scan copied EasyBreeding, NoCollision, FasterMounts and RushRoar into Development/TestResults. It indexed 77,040 resources, inspected 59 families and read 59 export maps and three complete DataTables. It retained 31 partial-reader findings, 17 structural-removal suspicions, two unknown mount priorities, a deployment difference and a missing prepared-reference limitation. No static finding claimed a reproduced crash. The fixture had no prepared reverse-dependency corpus; reverse-reference rules were exercised separately. Record: Development/TestResults/deep133-local-validation.json.

## Persistent conversation evidence

Real App Server stdio probes verified authentication, thread creation, resume after process closure, streamed progress, interruption and preserved history. A real case/session-scoped pmm_repair_get call was verified from the recorded mcpToolCall event, not from an agent's textual claim. Records: Development/TestResults/Agent133-Protocol and agent133-scoped-validation.json.

After the user's cost correction, a single bounded request explicitly used gpt-5.6-luna / low / default. The server acknowledged all three settings and returned PMM_LUNA_OK. Record: Development/TestResults/ai133-routing-validation.json. Other routing/escalation tests use protocol fixtures without paid inference.

Opening the original probe conversation in the desktop was verified. Subsequent control through a separate stdio server failed with “already has an active writer”. The installed Windows CLI also reports that app-server daemon lifecycle is supported only on Unix; its control proxy endpoint was unavailable. PMM pauses with the original conversation ID. It does not create a replacement conversation or equate opening a link with confirmed control.

## Acceptance boundaries

**Full automatic repair/game testing is not accepted.** Remaining requirements are a supported shared Windows conversation control channel, supervised-world adapter acceptance, isolated saves/configuration/cloud synchronization, and actual temporary game test/restoration acceptance. Runtime controls remain disabled. Existing durable deployment recovery passed filesystem/process-termination fixtures; that does not prove an isolated Palworld test cycle.

No Palworld launch or live installed-mod changes were performed. The user's independent game tests remain separate.

Live Nexus/GitHub download entitlement, provider limits and applying an author update to a real user's modlist were not accepted end to end. Resolver/provenance fixtures and local staged-container/proposed-set tests passed. Source identity can remain unknown; structured requirements may require manual review. Multi-PAK variants and unverified extraction formats pause.

Whole-game archive SHA256 is not computed; game archive metadata and extracted family hashes are recorded. Semantic scope is cooked PAK resources and available prepared reference data. External UE4SS/loaders and resources outside the configured Paks/~mods tree require adapters. Reader/budget gaps remain visible. Session disk limits cover session storage; shared reader caches and report storage require separate workspace capacity management.

Imported recipes remain contextual unless current exact-input proof succeeds. Static procedures are not published as game-proven fixes. Remote publication has no configured receiver.

The preview package contains public program files only, no Workspace, Mapping104, third-party mods, game assets, account credentials or test artifacts. Clean-package checksums, native dependency status and SmokeTest are recorded beside the ZIP.

References: [App Server protocol](https://learn.chatgpt.com/docs/app-server), [usage and plans](https://learn.chatgpt.com/docs/pricing), [Luna](https://developers.openai.com/api/docs/models/gpt-5.6-luna). Availability is checked against the installed runtime rather than inferred from marketing plan names.

## Clean payload result

The final preview contains 590 ZIP members (589 checksummed public files plus the checksum inventory). Windows PowerShell 5.1.19041.4648 parsed all 117 module scripts, every one of the 47 catalog entries was included, and the clean application SmokeTest passed. Native dependency status was ready. Exact final ZIP SHA256 and size are recorded in Development/Releases/PMM-1.3.3-deep-analysis-preview.zip.sha256 and the adjacent validation JSON; no Workspace is included.
