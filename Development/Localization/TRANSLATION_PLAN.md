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
- Translation work is normally done in pairs so terminology and visual review remain manageable.
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

Hindi and Modern Standard Arabic are intentionally being completed before their normal market position as the first v1.5 quality pair. Hindi exercises Devanagari/non-Latin rendering; Arabic is the first complete RTL locale and validates the generic right-to-left layout path. After that pair, work resumes at the start of the market queue with Brazilian Portuguese + Korean.

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
| 20 | `hi` | हिन्दी | Hindi | ltr | disabled | **translation pair 1: in progress** |
| 21 | `ar` | العربية | Modern Standard Arabic | rtl | disabled | **translation pair 1: in progress / RTL validation** |
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
10. Change registry to `enabled: true` / `status: complete` only after validation.
11. Update this ledger and `Development/AI/WORKBENCH_STATE.md` in the same intervention.

## Work log

### 2026-09-16 — v1.5 runtime identity correction

- User screenshot proved that the branch was checked out correctly while the PMM title still reported `v1.3.4.1`.
- Root cause: `Modules/Bootstrap/Start-PalModMerger.ps1` builds the window title from `Resources/Metadata/VERSION.txt`, and that file had never been advanced from the 1.3.4.1 release baseline.
- Updated `Resources/Metadata/VERSION.txt` to `1.5.0.0` and `Resources/Metadata/BUILD_ID.txt` to `PMM-v1.5.0.0-localization-dev` on this branch only.
- No release/tag/main merge was created. The existing 1.3.4.1 release manifest/hash inventory remains release provenance and will be regenerated when 1.5 is actually packaged.
- The language selector still intentionally exposes only `English`, `Español`, `简体中文`; all unfinished locales remain registered but disabled until their translations pass validation.
- GitHub Desktop branch switching changes the checked-out source files. It does not by itself rebuild/replace a binary; the current editable UI nevertheless reads `VERSION.txt` at startup, so after fetching/pulling this commit and restarting PMM from this checkout the title should report `v1.5.0.0`.

### 2026-09-16 — registry/progress synchronization correction

- User correctly identified that `languages.json` still contained only the three completed locales, even though additional catalog files had already been committed to this branch.
- Corrected the architecture so `languages.json` now inventories **all planned v1.5 locales** and records `enabled` plus `status` for each.
- Preserved the first three active entries exactly as `English`, `Español`, and `简体中文`.
- Added runtime filtering so unfinished entries remain visible in Git/repository state but cannot appear in the PMM selector or be resolved as normal active UI languages.
- Hindi and Arabic remain `in-progress` and disabled; their current translated work is stored directly in `hi.json` and `ar.json` on this branch.
- Updated localization documentation and the shared workbench state in the same intervention.

### 2026-09-16 — Palworld-market priority refresh + first translation pair

- Replaced the original pure total-speaker order with a Palworld-market-first priority model; worldwide speakers now break close ties.
- Added pending market templates that were missing from the original speaker-based scaffold: Korean (`ko`), Traditional Chinese (`zh-TW`), Polish (`pl`), Italian (`it`), Thai (`th`), Ukrainian (`uk`), Dutch (`nl`) and Czech (`cs`).
- Preserved the previous high-speaker templates as a reserve backlog instead of deleting them.
- Started Hindi (`hi`) + Modern Standard Arabic (`ar`) as the first quality-controlled pair to validate Devanagari/non-Latin rendering and RTL behavior.
- After this pair, the next planned pair is Brazilian Portuguese (`pt-BR`) + Korean (`ko`).

### 2026-09-16 — v1.5 translation scaffolding

- Created branch `v1.5.0.0-PMM-translated` from the validated v1.3.4.1-era `main` state.
- Preserved the completed `en`, `es`, and `zh-CN` catalogs unchanged.
- Added independent pending catalog templates for the original worldwide-speaker list.
- No release, tag, main merge or native executable was created or changed in this translation scaffolding.
