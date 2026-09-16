# PMM shared implementation state

## v1.5.0.0 translation branch — 2026-09-16

Branch `v1.5.0.0-PMM-translated` starts from validated `main` commit `70d106e871099e4936dc5f81eef3e4ea15529d93`. This branch is now the working line for the next PMM localization release; the discarded historical 1.4 line is not reused.

This intervention prepares the translation backlog only. Existing English (`en`), Spanish (`es`) and Simplified Chinese (`zh-CN`) catalogs remain unchanged and active. Seventeen additional independent catalog templates were staged for Hindi, Modern Standard Arabic, French, Bengali, Brazilian Portuguese, Indonesian, Urdu, Russian, German, Japanese, Nigerian Pidgin, Egyptian Arabic, Marathi, Vietnamese, Telugu, Hausa and Turkish. Pending templates fall back to English and are intentionally not registered in `languages.json` until each translation is complete and validated, so untranslated languages do not appear as false choices in the UI.

The authoritative per-language order, state and future intervention log is `Development/Localization/TRANSLATION_PLAN.md`. Update that ledger whenever a language is started/completed/validated/activated. No release or tag is created by this scaffolding step, and no native executable is changed.

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
