# PMM v1.5.0.0 translation plan

Branch: `v1.5.0.0-PMM-translated`
Base: validated `main` commit `70d106e871099e4936dc5f81eef3e4ea15529d93`

This file is the close translation-work ledger for PMM 1.5. Update it whenever a language template is created, started, completed, validated, activated, reordered, or otherwise changed.

## Policy

- English (`en`) is the canonical source catalog.
- Spanish (`es`) and Simplified Chinese (`zh-CN`) are already translated and active.
- `languages.json` is the **complete inventory** of this branch. Planned languages must appear there even while unfinished.
- Every unfinished locale is registered with `enabled: false`; therefore it is visible in repository state but does not appear in the PMM language selector.
- Registry `status` values are `complete`, `in-progress`, `template`, or `reserve`.
- Every planned locale also has its own independent JSON catalog under `PMM/Resources/Localization/`.
- When a language is finished, populate every canonical English key, preserve placeholders and invariant technical terms, validate it, then change its registry entry to `enabled: true` / `status: complete`.
- `rtl` languages must be registered with right-to-left direction.
- Language names in selectors always remain in their own native form.
- Translation work is now scoped conservatively: one language stage per intervention. A fresh 1,291-string locale should normally be reviewed in chunks of roughly 300-400 strings, followed by a separate completion/activation pass. A locale that already has a complete draft may use one intervention for finalization and activation.
- Language changes require restarting PMM. The experimental live-switch path was reverted because it increased startup cost and produced incorrect/slow in-session refreshes.
- The branch development identity is `1.5.0.0`. `PMM/Resources/Metadata/VERSION.txt` is the runtime UI version source; changing Git branches alone does not rewrite this file or rebuild an executable.

## Priority model: Palworld audience first, global language reach as tie-break

The queue is not a pure ranking by world population. PMM is a Palworld tool, so the primary signal is estimated Palworld demand by market/language. Total worldwide speakers are used when two Palworld signals are close.

Public data has an important limitation: there is no authoritative complete country-by-country Palworld player table. Therefore this is a **localization-priority estimate**, not a claim that every country percentage is known exactly.

Evidence used for the 2026-09-16 priority refresh:

- Alinea Analytics reports the United States and China as Palworld's two largest Steam markets at roughly 27% of unit sales each.
- Steam review-language distribution is used as a direct Palworld-language proxy after those two markets.
- PCGamesData's Palworld player-region language estimate is used as a second Palworld-specific signal: English ~40%, Simplified Chinese ~24.1%, Brazilian Portuguese ~6.3%, Korean ~6.2%, Russian ~5.5%, French ~3.6%, German ~2.8%, Spanish ~2.8%.
- General gaming-population estimates are used only as a secondary market-potential signal where Palworld-specific public data is sparse.
- Worldwide total-speaker estimates are used as the tie-break when two Palworld markets are relatively close.

English-speaking countries cannot be separated reliably from one another by the Steam language proxy, and Spanish reviews combine Spain and Latin-American markets. Treat those as language-market groups rather than fabricated country percentages.

## Estimated Palworld market order

| Priority | Country / market | Main PMM locale | Evidence interpretation |
|---:|---|---|---|
| 1 | United States (+ other English markets) | `en` | US itself ~27% of Steam units; English is the largest language group |
| 2 | China | `zh-CN` | China itself ~27% of Steam units; Simplified Chinese is the second-largest language group |
| 3 | Brazil | `pt-BR` | ~6.3% player-region language proxy; very strong Steam review volume |
| 4 | South Korea | `ko` | ~6.2% player-region language proxy; exceptionally strong Steam review volume |
| 5 | Russia / Russian-speaking market | `ru` | ~5.5% player-region language proxy; strong review volume |
| 6 | France / Francophone market | `fr` | ~3.6% region proxy; strong reviews; large worldwide language reach |
| 7 | Germany / German-speaking market | `de` | ~2.8% region proxy; very strong review volume |
| 8 | Spain + Spanish-speaking Latin America | `es` | ~2.8% region proxy plus Spain/LatAm review groups; already complete |
| 9 | Taiwan / Traditional-Chinese market | `zh-TW` | large Traditional Chinese Palworld review group |
| 10 | Japan | `ja` | dedicated Japanese review group and major gaming market |
| 11 | Turkey | `tr` | strong Palworld review group plus large gaming population |
| 12 | Poland | `pl` | clear Palworld review demand |
| 13 | Italy | `it` | clear Palworld review demand |
| 14 | Thailand | `th` | clear Palworld review demand and large gaming population |
| 15 | Indonesia | `id` | huge gaming population and very large worldwide language |
| 16 | Vietnam | `vi` | visible Palworld reviews plus large gaming population |
| 17 | Netherlands | `nl` | visible Palworld review demand |
| 18 | Ukraine | `uk` | visible Palworld review demand; partial overlap with Russian/English usage |
| 19 | Czechia | `cs` | visible Palworld review demand |
| 20 | India / Hindi market | `hi` | enormous worldwide/gaming reach; weaker direct Palworld country evidence |
| 21 | Arabic-speaking markets | `ar` | enormous worldwide reach; useful first RTL validation |

## PMM locale target queue

The first three existing locales remain fixed at the top of the product because they are already complete: **English**, **Español**, **简体中文**.

Normal post-baseline market queue:

`pt-BR -> ko -> ru -> fr -> de -> zh-TW -> ja -> tr -> pl -> it -> th -> id -> vi -> nl -> uk -> cs -> hi -> ar`

Hindi and Modern Standard Arabic were intentionally moved ahead of their normal market position as early v1.5 quality targets. Both catalogs are now complete and enabled for user testing: Hindi validates Devanagari/non-Latin rendering, while Arabic is the first RTL locale. The next active translation target returns to the commercial queue with Brazilian Portuguese (`pt-BR`), followed by Korean (`ko`).

The older worldwide-speaker backlog remains as reserve templates rather than being deleted: Bengali (`bn`), Urdu (`ur`), Nigerian Pidgin (`pcm`), Egyptian Arabic (`arz`), Marathi (`mr`), Telugu (`te`) and Hausa (`ha`).

## Current locale state

| Market order | Code | Native name | English name / target | Direction | Registry | State |
|---:|---|---|---|---|---|---|
| baseline | `en` | English | English | ltr | enabled | complete + active |
| baseline | `es` | Español | Spanish | ltr | enabled | complete + active |
| baseline | `zh-CN` | 简体中文 | Chinese (Simplified) | ltr | enabled | complete + active |
| 3 | `pt-BR` | Português (Brasil) | Portuguese (Brazil) | ltr | disabled | template pending |
| 4 | `ko` | 한국어 | Korean | ltr | disabled | template pending |
| 5 | `ru` | Русский | Russian | ltr | disabled | template pending |
| 6 | `fr` | Français | French | ltr | disabled | template pending |
| 7 | `de` | Deutsch | German | ltr | disabled | template pending |
| 9 | `zh-TW` | 繁體中文 | Chinese (Traditional) | ltr | disabled | template pending |
| 10 | `ja` | 日本語 | Japanese | ltr | disabled | template pending |
| 11 | `tr` | Türkçe | Turkish | ltr | disabled | template pending |
| 12 | `pl` | Polski | Polish | ltr | disabled | template pending |
| 13 | `it` | Italiano | Italian | ltr | disabled | template pending |
| 14 | `th` | ไทย | Thai | ltr | disabled | template pending |
| 15 | `id` | Bahasa Indonesia | Indonesian | ltr | disabled | template pending |
| 16 | `vi` | Tiếng Việt | Vietnamese | ltr | disabled | template pending |
| 17 | `nl` | Nederlands | Dutch | ltr | disabled | template pending |
| 18 | `uk` | Українська | Ukrainian | ltr | disabled | template pending |
| 19 | `cs` | Čeština | Czech | ltr | disabled | template pending |
| 20 | `hi` | हिन्दी | Hindi | ltr | enabled | **complete; user runtime/visual test in progress** |
| 21 | `ar` | العربية | Modern Standard Arabic | rtl | enabled | **complete; user RTL/runtime visual test pending** |
| reserve | `bn` | বাংলা | Bengali | ltr | disabled | reserve template |
| reserve | `ur` | اردو | Urdu | rtl | disabled | reserve template |
| reserve | `pcm` | Naijá | Nigerian Pidgin | ltr | disabled | reserve template |
| reserve | `arz` | العربية المصرية | Egyptian Arabic | rtl | disabled | reserve template |
| reserve | `mr` | मराठी | Marathi | ltr | disabled | reserve template |
| reserve | `te` | తెలుగు | Telugu | ltr | disabled | reserve template |
| reserve | `ha` | Hausa | Hausa | ltr | disabled | reserve template |

## Per-language completion checklist

1. Confirm the locale already exists in `languages.json` with `enabled: false` and the correct native name/direction.
2. Expand its catalog against the current `en.json` key set.
3. Translate all user-facing values; never alter canonical English keys.
4. Preserve placeholders such as `{0}`, format specifiers such as `{0:N2}`, and intentionally invariant technical identifiers.
5. Use a consistent glossary and preserve product/technology names (`PMM`, `Palworld`, `Steam`, `PAK`, `ChatGPT`, `Codex`, `Unreal`, `Wwise`, `MCP`, etc.).
6. Run `Development/Localization/Test-Localization.ps1 -Language <code>`.
7. Run `python Development/Localization/audit_localization.py`.
8. Run the Windows PowerShell 5.1 localization regression before release.
9. Visually inspect principal WPF screens for truncation, dynamic English residue, and layout problems. RTL languages additionally require navigation/order/alignment review.
10. Change registry to `enabled: true` / `status: complete` when the catalog is complete enough for the user's runtime test; release acceptance still requires the validation and visual checks above.
11. Update this ledger and `Development/AI/WORKBENCH_STATE.md` in the same intervention.

## Work log

### 2026-09-16 — Arabic completion + first RTL user-test handoff

- Continued from the committed partial `ar.json`; the Arabic work was not restarted from zero.
- Expanded Modern Standard Arabic through the complete current canonical English sequence. The Arabic file keeps the same key order and reaches the same canonical tail as `en.json`; its one-line offset is the Arabic-only `translationStatus` metadata line. This provides a direct key-parity check against the 1,291-string source catalog.
- Preserved format placeholders and technical/product identifiers while translating PMM-facing prose. Arabic is registered with `direction: rtl` and is now `enabled: true` / `status: complete` for the user's runtime test.
- The user's Hindi screenshot showed stable Devanagari rendering and no obvious severe clipping in the visible Fix Lab screen. It also exposed dynamic English suffix residue such as `0 candidate(s)`, `0 variant(s)` and `0 case backup(s)`. Those are dynamic-format localization gaps rather than missing Hindi catalog entries and should be cleaned up generically before the final v1.5 release.
- Final release acceptance for Arabic is still pending the user's real Windows RTL/layout screenshot plus the normal PowerShell/WPF localization validation before release. No GitHub Actions were run in this development intervention.
- Next translation target returns to the market queue: Brazilian Portuguese (`pt-BR`), then Korean (`ko`).

### 2026-09-16 — scope recalibration + Hindi activation

- Recalibrated translation scope after repeated stream/tool timeouts. Two full 1,291-string languages in one intervention was too aggressive for quality and recoverability.
- New default unit: roughly 300-400 fresh/reviewed strings per prompt, or one finalization/activation pass when a complete draft already exists. Do not claim multiple languages complete merely because template files exist.
- Preserved the earlier revert of live language switching. PMM again saves the selected language and applies it after restart; no live localization handler is active.
- Promoted the complete Hindi draft into the canonical `hi.json`. Its key order reaches the same canonical tail as `en.json` with the expected one-line metadata offset, and reviewed samples preserve placeholders/format specifiers and product identifiers.
- Enabled `हिन्दी` in `languages.json` with `status: complete`, making it available for the user's runtime/visual test. This is not a claim of final release acceptance; the user's visual review and release validation remain required.
- Arabic remained `in-progress` at that checkpoint and subsequent work continued from the existing `ar.json` instead of starting over.
- Removed temporary recovery/checkpoint files and the temporary Hindi draft filename from the branch; Git history still preserves those checkpoints.
- No release, tag, main merge or GitHub Actions run was created.

### 2026-09-16 — v1.5 runtime identity correction

- User screenshot proved that the branch was checked out correctly while the PMM title still reported `v1.3.4.1`.
- Root cause: `Modules/Bootstrap/Start-PalModMerger.ps1` builds the window title from `Resources/Metadata/VERSION.txt`, and that file had never been advanced from the 1.3.4.1 release baseline.
- Updated `Resources/Metadata/VERSION.txt` to `1.5.0.0` and `Resources/Metadata/BUILD_ID.txt` to `PMM-v1.5.0.0-localization-dev` on this branch only.
- No release/tag/main merge was created. The existing 1.3.4.1 release manifest/hash inventory remains release provenance and will be regenerated when 1.5 is actually packaged.
- The language selector still intentionally exposes only completed languages; unfinished locales remain registered but disabled until their translations reach user-test quality.
- GitHub Desktop branch switching changes the checked-out source files. It does not by itself rebuild/replace a binary; the current editable UI nevertheless reads `VERSION.txt` at startup, so after fetching/pulling this commit and restarting PMM from this checkout the title should report `v1.5.0.0`.

### 2026-09-16 — registry/progress synchronization correction

- User correctly identified that `languages.json` still contained only the three completed locales, even though additional catalog files had already been committed to this branch.
- Corrected the architecture so `languages.json` now inventories **all planned v1.5 locales** and records `enabled` plus `status` for each.
- Preserved the first three active entries exactly as `English`, `Español`, and `简体中文`.
- Added runtime filtering so unfinished entries remain visible in Git/repository state but cannot appear in the PMM selector or be resolved as normal active UI languages.
- Hindi and Arabic were registered as `in-progress` and disabled at that stage; subsequent work now records both as complete/enabled for user testing.
- Updated localization documentation and the shared workbench state in the same intervention.

### 2026-09-16 — Palworld-market priority refresh + first translation pair

- Replaced the original pure total-speaker order with a Palworld-market-first priority model; worldwide speakers now break close ties.
- Added pending market templates that were missing from the original speaker-based scaffold: Korean (`ko`), Traditional Chinese (`zh-TW`), Polish (`pl`), Italian (`it`), Thai (`th`), Ukrainian (`uk`), Dutch (`nl`) and Czech (`cs`).
- Preserved the previous high-speaker templates as a reserve backlog instead of deleting them.
- Started Hindi (`hi`) + Modern Standard Arabic (`ar`) as early quality targets to validate Devanagari/non-Latin rendering and RTL behavior.
- After Hindi and Arabic, the market queue resumes with Brazilian Portuguese (`pt-BR`) and Korean (`ko`), now handled one language/stage at a time rather than two complete locales in one prompt.

### 2026-09-16 — v1.5 translation scaffolding

- Created branch `v1.5.0.0-PMM-translated` from the validated v1.3.4.1-era `main` state.
- Preserved the completed `en`, `es`, and `zh-CN` catalogs unchanged.
- Added independent pending catalog templates for the original worldwide-speaker list.
- No release, tag, main merge or native executable was created or changed in this translation scaffolding.
