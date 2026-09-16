# PMM shared implementation state

## v1.5.0.0 translation branch — 2026-09-16

Branch `v1.5.0.0-PMM-translated` starts from validated `main` commit `70d106e871099e4936dc5f81eef3e4ea15529d93`. This branch is the working line for the next PMM localization release; the discarded historical 1.4 line is not reused.

### Current translation state

The user correctly identified a repository-state inconsistency: the branch already contained many locale JSON files, but `PMM/Resources/Localization/languages.json` still listed only the three completed languages. That made the branch look like it had only English, Spanish and Simplified Chinese from the application's point of view.

This has been corrected. `languages.json` is now the complete locale inventory for v1.5. Every planned locale is recorded there with `enabled` and `status`. Only completed locales are enabled, so the runtime selector still exposes exactly the three already-finished native labels: `English`, `Español`, `简体中文`. Pending/in-progress/reserve languages are visible and traceable in Git but remain unavailable to users until validation is complete.

The localization runtime now filters disabled language definitions during normal resolution and selector construction. This preserves the existing UI behavior while allowing the branch itself to represent all translation work accurately.

The backlog is prioritized by estimated **Palworld audience**, not world population alone. The detailed evidence model, ordered locale queue and intervention log live in `Development/Localization/TRANSLATION_PLAN.md`.

Hindi (`hi`) and Modern Standard Arabic (`ar`) are translation pair 1 even though their normal Palworld-market priority is later. Both have real translated content committed on this branch and remain `in-progress` / `enabled: false`. Arabic is the first full RTL validation target. Do not mark either complete until every canonical English key is translated, placeholder checks pass, PowerShell 5.1/WPF validation passes, and Arabic receives a visual RTL review. After this pair, resume with `pt-BR` + `ko`.

### Live language switching

The user asked to prioritize live language switching in this intervention instead of spending the prompt on the next translation pair. Inspection confirmed that Hindi and Arabic were started previously but are **not complete**; they therefore remain disabled rather than being exposed prematurely.

The localization runtime now supports reversible in-session switching for every enabled locale. `Invoke-PMMLocalizeVisualTree` keeps a weak per-object canonical-English baseline for static text, content, headers, tooltips, DataGrid headers and normal data-bound `Label` values. It can therefore move between localized values and restore English without attempting to translate one translated string into another. A reverse-catalog path recovers canonical English from windows that were originally loaded from localized XAML, and refuses ambiguous reverse mappings instead of guessing.

`Register-PMMLiveLanguageSwitch` attaches one additional handler to the existing Settings **Apply language** button during the final normal window localization sweep. The pre-existing Settings handler remains responsible for saving the selected locale. The live handler then retranslates the current visual tree, updates LTR/RTL `FlowDirection`, runs `Refresh-UI` so formatted/dynamic state text is regenerated in the new locale, and performs a second sweep for newly materialized controls. There is no global WPF `Loaded` hook.

`Development/Localization/Test-PowerShell51.ps1` now includes reversible live-switch probes (`English -> target -> English -> target`) plus direction validation. The code remains designed for Windows PowerShell 5.1. This intervention did not run that Windows-only regression inside the current execution environment, so the user's local PMM test is still required before calling the live-switch behavior runtime-proven.

No new language was enabled here. The next translation intervention remains: finish and validate Hindi + Modern Standard Arabic, enable both for user testing, then continue with Brazilian Portuguese + Korean.

### v1.5 runtime identity correction

A user screenshot on the correct `v1.5.0.0-PMM-translated` checkout still showed `PMM - Palworld Manager Merger v1.3.4.1`. The checkout itself was not the problem. `Modules/Bootstrap/Start-PalModMerger.ps1` reads `Resources/Metadata/VERSION.txt` when it creates the WPF title, and that metadata file was still inherited unchanged from the 1.3.4.1 release.

The branch runtime identity is now explicitly `1.5.0.0`: `Resources/Metadata/VERSION.txt` is `1.5.0.0` and `Resources/Metadata/BUILD_ID.txt` is `PMM-v1.5.0.0-localization-dev`. This is development metadata only. No v1.5 release/tag/main merge was created, and the old 1.3.4.1 release manifest/hash inventory remains release provenance until the eventual 1.5 package is generated.

GitHub Desktop switching/fetching a branch changes the checked-out repository files; it does not itself rebuild or replace `PMM.exe`. The editable PMM UI does read the checked-out `VERSION.txt` at startup, however, so after pulling this intervention and restarting PMM from the repository checkout the window title should show `v1.5.0.0`. If it still shows 1.3.4.1 after that, the executable was launched from a different PMM folder/copy and that path must be identified before further code changes.

Every future translation intervention must update both `Development/Localization/TRANSLATION_PLAN.md` and this state record in the same branch. No v1.5 release, tag, main merge or native executable change has been made yet.

---

# Historical PMM 1.3.3 shared implementation state

Branch 1.3.3 starts exactly at 1.3.2 commit 3e57247f823317c85ceb71a4272b0a813f1f34fc. Current implementation: deep-analysis preview with account-aware AI routing. No public release/push requested.

## Preserved baseline

The 1.3.2 case V4 repairs, Providers collision fix, current mappings selection, long-path/reference recovery, reader 0.3 and exact historical-delta/current-layout DataTable transfer remain. Native binaries are unchanged. FasterMounts/RushRoar preserves 753 rows / 68,523 properties and all 103 current true IsUncapturable flags. See the 1.3.2 validation record for its exact cooked-data proof.

EasyBreeding/NoCollision remains Unsupported: current 29 exports versus old 28 and missing Blueprint schema. Do not reactivate the historical whole-family replacement. The Gura RC30 reporter confirmed 1.3.1 works; that is not a proven 1.3.1 regression.

Existing real cases: BreedFarm AICASE-20260912-202028-a27cf054 and Faster/Rush AICASE-20260912-202029-ea4c2ad7. Preserve their identifiers and history. Mapping104 remains local in Workspace and must not be redistributed.

## Added

- Deep analysis above Analysis plan, immutable snapshots/findings, explicit coverage, JSON/HTML, selected/new/linked cases and staged update analysis.
- Exact origin and variant handling for Nexus/GitHub; original source and selected patch preserved. New candidate-only merge output avoids changing case inputs.
- Selective 1.4.0-ReUI service/presentation/workflow separation, module catalog, idle-compatible reload, durable recovery, candidate/observation history. Original six-tab UI retained.
- Persistent App Server case conversations, scoped MCP repair sessions and durable idempotent jobs; failed attempts and local reproducible procedures retained.
- Routine AI uses Luna / low / standard explicitly. Optional authorized escalation to Terra/medium and Sol/high, detected account access, quota/model checks, API billing opt-in and manual-chat export. Model/effort acknowledgement is checked before starting a request. No silent fallback to Astra/fast. Deterministic work stays in PMM.
- UI model policy, cases and origins use sender-bound state instead of module closures that lose access to script-scoped services in PS5.1.

## Validation and boundaries

See Development/Docs/Validation/PMM_1_3_3_ANALYSIS_VALIDATION.md for executed suites, real local scan and protocol evidence. The AI-policy probe now explicitly verifies Luna/low/default; broader routing tests are offline protocol fixtures.

Full automation is not accepted. A conversation opened in the Windows desktop can retain its active writer; this installed runtime lacks the shared daemon-control adapter. Retain the same ID and pause. Game launch/world/isolation controls remain blocked until the adapter proves save/configuration/sync isolation and actual restore behavior. No Palworld launch or installed-mod modification during development.

Nexus/GitHub live downloads and update activation have not been accepted end to end. Staging/reanalysis and exact variant tests pass. Reader coverage remains partial for opaque Blueprint payloads. Static structural success is not runtime or feature-preservation proof.

The 1.4.0-ReUI branch remains preserved separately. Do not blanket-add pre-existing untracked MCP notes, InventoryProbe, SuperInventory, Development/Tools or caches. Keep Workspace, TestResults and ExternalFiles out of the public package.

Next acceptance work: supported shared Windows conversation control, supervised world/restore adapter validation expressly authorized by the user, and reader capability for the BreedFarm case. Do not launch Palworld or change the user's installed mods under the existing development authorization.

## 1.3.3 case entry hotfix

The user runs C:/Modding/palworld/1.3.3333/PMM. This copy is patched in place with a sibling backup PMM-backup-case-entry-20260912-191252. Its active UI was not closed; restart is required. The AUAT case AICASE-20260913-004810-a5411828 now includes the exact AutoUnlockAllTechnology_V1_P.pak reference at step 4. AUAT itself has not yet been rebuilt or runtime-tested.

Resolved: missing library context menu, old hardcoded window title, missing desktop Codex discovery outside task PATH, invisible case agent errors/responses, duplicated sessions on retry and ineffective case cancellation. New cases default to GPTD but do not send until requested. Existing seven paused AUAT sessions are preserved. Current behavior, validation and package receipt: Development/Docs/Validation/PMM_1_3_3_CASE_ENTRY_VALIDATION.md.

Maintain Luna low/standard routing and the no-Palworld/no-live-game-mod-change development instruction. The live connection regression queried metadata only; no inference started in this hotfix verification.

### Case entry hotfix 2: actual library row contract

The first menu regression was insufficient: it supplied synthetic rows with Path, while the production Refresh-UI omitted Path/Hash. The user's follow-up caught this. Both active and disabled display rows now preserve source Path and full Hash. Revised tests use the real library scan, disable operation and Refresh-UI, and reproduce the defect before passing 26 assertions per EN/ES after the fix. Preserve this production-row coverage; do not reintroduce hand-built display rows in the context-menu test.
