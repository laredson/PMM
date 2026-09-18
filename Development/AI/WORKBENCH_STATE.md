## Active checkpoint — Russian complete; Korean user-accepted — 2026-09-18

Work ONLY in `laredson/PMM`, branch `v1.5.0.0-PMM-translated`. The user reports Korean works perfectly, as do the previously added languages, and requested the next queued language in one prompt where feasible. Russian is now complete: **1,291/1,291 canonical keys**, `enabled: true` / `status: complete`, native label `Русский`, fallback `en`, direction `ltr`. The seven previously active catalogs are unchanged.

Source checkpoint: `d9442cff26b8ac84a1f85fe0db023baf2d6c89f8`. English blob: `2fa3c4712619cc5f811ce2251cef3daf5b0e2024`, reconstructed locally with byte-identical content. Russian uploaded blob: `ffa3bfb80ef2aa4ae3268b0c557e3a38bb4b1b18`, identical to the checked local UTF-8 file. Local structural validation passed JSON/duplicates, exact keys/order, metadata, nonempty values, full placeholders, numeric literals, whitespace, selected technical tokens, file-dialog patterns and Unicode controls. There are 109 parameterized strings and 18 intentional invariant values.

Read `Development/Localization/RUSSIAN_HANDOFF.md` and `Development/Localization/Progress/ru.json` for glossary, exact hashes, scope and executed-check details. Russian still needs the user's Windows runtime/visual review; this was not a PowerShell 5.1, WPF, native-speaker or full source-code localization audit. Existing runtime QA issues are not closed by catalog completeness or by the user's general positive report on older languages.

**Next translation: French (`fr`, Français).** Do not follow the historical Korean part-1 cursor below and do not retranslate Korean, Portuguese or Russian from scratch. Preserve restart-based language changes, native names, Arabic RTL/LTR code, runtime/native binaries, main, releases, tags, workflows and game files. Development commits use `[skip ci]`; no GitHub Actions were dispatched. Update both translation ledgers in every future checkpoint.

## Korean localization completed and published — 2026-09-18

한국어 now covers all 1,291 canonical English keys on `v1.5.0.0-PMM-translated` and is enabled. The user subsequently reported it works perfectly.
Part 1 (645 entries) was preserved; part 2 added the remaining 646 entries.
Validation was deliberately bounded to one structural pass: JSON/key parity, non-empty values and placeholder preservation. No GitHub Actions, full repository audit or WPF visual/runtime test was run for that checkpoint.
Language switching remains restart-based. Portuguese remains user-validated; Arabic RTL behavior and its separately tracked UI exceptions are unchanged.
Korean user runtime feedback is accepted; do not retranslate Korean from scratch unless QA reports a specific issue.

# PMM shared implementation state

## Historical checkpoint — Korean part 1 of 2 — 2026-09-18

> Superseded by Korean completion and the active Russian checkpoint above. The following cursor and disabled status describe that earlier snapshot only.

Work ONLY in `laredson/PMM`, branch `v1.5.0.0-PMM-translated`. The user has confirmed that Portuguese works perfectly and asked to split the next language into two bounded prompts with enough context to resume in another chat.

**Korean part 1 is saved: 645 of the baseline 1,291 entries**, from `(not detected)` through `Load draft`. Continue with `Loading Fix Lab module...`; 646 baseline entries remain. The catalog is `PMM/Resources/Localization/ko.json`, `translationStatus: in-progress`; registry `ko` is `status: in-progress` / `enabled: false`. The existing six active languages are unchanged.

**Next chat: read `Development/Localization/KOREAN_HANDOFF.md` first.** It contains the exact source revision, glossary, continuation procedure, validation code, known defects and scope boundaries. Machine-readable progress is in `Development/Localization/Progress/ko.json`. Recompute missing keys against the current English catalog; do not replace the first half or use a stale line number if the source changed.

The partial Korean catalog passed local Python JSON/duplicate/nonempty, full-placeholder, numeric, selected technical-token, trailing-space and Unicode-control checks. Its uploaded Git blob `e239428f7eab5b6ff954dbebfb50e3b198308cc9` matches the locally checked bytes. The English range was read sequentially; the full repository audit, PowerShell 5.1 and WPF runtime tests have NOT run for Korean. Do not enable or claim complete until the remaining block and completion checks are done.

This intervention changes catalogs/progress/documentation only. Keep restart-based language changes, Arabic RTL/LTR code, main, releases, workflows, game files and the existing active catalogs unchanged. Push with `[skip ci]`; update both ledgers and the Korean handoff/progress file in each subsequent checkpoint.

## v1.5.0.0 translation branch — 2026-09-17

Branch `v1.5.0.0-PMM-translated` starts from validated `main` commit `70d106e871099e4936dc5f81eef3e4ea15529d93`. This branch is the working line for the next PMM localization release; the discarded historical 1.4 line is not reused.

### Current translation state

`PMM/Resources/Localization/languages.json` is the complete locale inventory for v1.5. Pending/template/reserve languages remain traceable in Git but are filtered from normal runtime language resolution until enabled.

The active selector now contains eight native labels, in this order: `English`, `Español`, `简体中文`, `Português (Brasil)`, `한국어`, `Русский`, `हिन्दी`, and `العربية`. The first three remain fixed. Registry `complete` means catalog ready for development/user testing, not release acceptance or proof that every runtime-generated string is localized.

Brazilian Portuguese (`pt-BR`) is committed and enabled, and the user has since reported it works perfectly. This is user runtime feedback, not a new automated audit. The interrupted write did succeed in commit `9bcc60ff96da11c39c05cdf5b97b7561f84ca879`; it must not be translated from scratch again. Recovery found unescaped embedded quotes in two catalog lines (Delete draft and Replace the installed user scheme). Commit `fcd966a8ce921574ab2eaff864295a29dd3aa6a8` corrects only those two lines. The corrected catalog blob is `8bb8888779c60fe4c22ab6d7c8ac3944077cf5e0`. The registry is enabled only after that correction. Italian has not been started or enabled.

Hindi (`hi`) is enabled. The user's first runtime screenshot shows Devanagari text and no obvious severe clipping in the visible Fix Lab screen. Generic dynamic English suffixes such as `0 candidate(s)`, `0 variant(s)` and `0 case backup(s)` remain open localization defects; catalog completion must not hide those runtime gaps.

Modern Standard Arabic (`ar`) is enabled with `direction: rtl`. The user has now supplied real RTL screenshots; mirrored panel/tab layout is retained. Partial technical-data direction support was committed in `38bd5a934488ac11a6200d3142b889ca86a82f57` during the interrupted work. This recovery narrows that support: `TxtStatus` and `TxtLog` are not forced LTR because they also carry localized sentences; `HashShort`, `SizeText` and `Priority` join the technical binding names actually used by the library. Existing paths, IDs, versions and supported DataGrid technical cells remain LTR without reversing the surrounding Arabic layout or changing the stored data. No new timer, global Loaded handler or live-language switch is added.

Arabic QA is not fully closed. Mixed prose/path text in `TxtGamePathStatus` needs proper separate inline scopes in its rendering path, not a blanket LTR override. Virtualized/template-created cells and technical text must be checked on Windows. The dynamic counters noted above also remain open.

### Recovery verification and limits — 2026-09-17

- Re-read the branch HEAD, saved Portuguese file, language inventory and localization implementation through the GitHub connector.
- Verified the exact remote diff of the Portuguese correction: only the two malformed quoted-placeholder lines changed. A local Python check of the corrected quoted-placeholder snippets parsed successfully; this was not a full-catalog test.
- Reviewed the Portuguese catalog against the supplied canonical source text. Do not treat previous claims of zero automated errors or matching line offsets as a new executed validation report.
- A complete machine-run catalog audit and Windows PowerShell 5.1/WPF tests were not executed in this recovery environment. They remain required before release, alongside the user's runtime/visual test. No GitHub Actions were started to substitute for local execution.
- Reviewed the RTL change against Microsoft's WPF bidirectional guidance: data can use its own FlowDirection while surrounding layout remains RTL. This does not constitute visual verification on Windows.
- Updated the registry, the bounded RTL allowlist and both tracking documents together. Retain Git history as the checkpoint; do not create scratch branches or temporary marker files.

The experimental live-language-switch implementation remains reverted because the user observed slow startup, slow in-session changes and incorrect refresh results. PMM uses the stable behavior: selecting a language saves it, and the complete interface adopts it after PMM is restarted.

Translation workload remains scoped to one language or recoverable stage per intervention. Korean was completed in two stages; the user subsequently requested one complete next language where feasible, and Russian is complete in this checkpoint. A complete draft can be finalized without restarting its translation. Every intervention must leave a recoverable Git checkpoint and update `Development/Localization/TRANSLATION_PLAN.md` plus this file.

The backlog is prioritized by estimated Palworld audience. The detailed model and ordered locale queue live in `Development/Localization/TRANSLATION_PLAN.md`. Portuguese and Korean have passed the user's reported runtime test. Russian is ready for user QA; French is the next translation target.

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
