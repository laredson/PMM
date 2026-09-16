# PMM v1.5.0.0 translation plan

Branch: `v1.5.0.0-PMM-translated`
Base: validated `main` commit `70d106e871099e4936dc5f81eef3e4ea15529d93`

This file is the close translation-work ledger for PMM 1.5. Update it whenever a language template is started, completed, validated, activated, or otherwise changed.

## Policy

- English (`en`) is the canonical source catalog.
- Spanish (`es`) and Simplified Chinese (`zh-CN`) are already translated and active.
- New language files are staged first as independent templates with `fallback: en`, `templateStatus: pending`, `templateSource: en.json`, and an empty `strings` object.
- Pending templates are deliberately **not** added to `languages.json`; this prevents the PMM language selector from advertising an untranslated language that would only fall back to English.
- When a language is translated, populate its catalog from the canonical English keys, preserve placeholders and invariant technical terms, remove the template marker, register it in `languages.json`, then run the localization, PowerShell 5.1, and WPF checks before marking it complete.
- `rtl` languages must be registered with right-to-left direction when activated.
- Language names in selectors always remain in their own native form.
- Translation work is normally done in pairs so terminology and visual review remain manageable.

## Priority model: Palworld audience first, global language reach as tie-break

The queue is no longer a pure ranking by world population. PMM is a Palworld tool, so the primary signal is estimated Palworld demand by market/language. Total worldwide speakers are used when two Palworld signals are close.

Public data has an important limitation: there is no authoritative complete country-by-country Palworld player table. Therefore this is a **localization-priority estimate**, not a claim that every country percentage is known exactly.

Evidence used for the 2026-09-16 priority refresh:

- Alinea Analytics reports the United States and China as Palworld's two largest Steam markets at roughly 27% of unit sales each.
- The current Steam review-language distribution is used as a direct Palworld-language proxy after those two markets. It is especially strong for Korean, Brazilian Portuguese, German, French, Russian, Spanish, Traditional Chinese, Japanese, Turkish, Polish, Italian, Thai, Dutch, Vietnamese and Czech.
- PCGamesData's current Palworld player-region language estimate is used as a second Palworld-specific signal: English ~40%, Simplified Chinese ~24.1%, Brazilian Portuguese ~6.3%, Korean ~6.2%, Russian ~5.5%, French ~3.6%, German ~2.8%, Spanish ~2.8%.
- General gaming-population estimates are used only as a secondary market-potential signal where Palworld-specific public data is sparse.
- Worldwide total-speaker estimates (Ethnologue-style totals) are used as the tie-break when two Palworld markets are relatively close. This is why Brazilian Portuguese is placed just ahead of Korean despite both being exceptionally strong Palworld targets.

English-speaking countries cannot be separated reliably from one another by the Steam language proxy, and Spanish reviews combine Spain and Latin-American markets. Treat those as language-market groups rather than fabricated country percentages.

## Estimated Palworld market order

This is the working market picture for localization decisions, from strongest evidence downward. Countries sharing a language are grouped where public Palworld data does not split them reliably.

| Priority | Country / market | Main PMM locale | Evidence interpretation |
|---:|---|---|---|
| 1 | United States (+ other English markets) | `en` | US itself ~27% of Steam units; English is also the largest review/player-region language |
| 2 | China | `zh-CN` | China itself ~27% of Steam units; Simplified Chinese is the second-largest review/player-region language |
| 3 | Brazil | `pt-BR` | ~6.3% player-region language proxy; very strong Steam review volume |
| 4 | South Korea | `ko` | ~6.2% player-region language proxy; exceptionally strong Steam review volume |
| 5 | Russia / Russian-speaking market | `ru` | ~5.5% player-region language proxy; strong review volume |
| 6 | France / Francophone market | `fr` | ~3.6% player-region proxy; strong reviews; large worldwide language reach breaks close comparisons |
| 7 | Germany / German-speaking market | `de` | ~2.8% region proxy; very strong review volume |
| 8 | Spain + Spanish-speaking Latin America | `es` | ~2.8% region proxy plus Spain/LatAm review groups; already complete |
| 9 | Taiwan / Traditional-Chinese market | `zh-TW` | large Traditional Chinese Palworld review group |
| 10 | Japan | `ja` | dedicated Japanese review group and major gaming market |
| 11 | Turkey | `tr` | strong Palworld review group plus large gaming population |
| 12 | Poland | `pl` | clear Palworld review demand |
| 13 | Italy | `it` | clear Palworld review demand |
| 14 | Thailand | `th` | clear Palworld review demand and large gaming population |
| 15 | Indonesia | `id` | huge gaming population and very large worldwide language; direct Palworld country split is sparse |
| 16 | Vietnam | `vi` | visible Palworld reviews plus large gaming population |
| 17 | Netherlands | `nl` | visible Palworld review demand |
| 18 | Ukraine | `uk` | visible Palworld review demand; partially overlaps Russian/English usage |
| 19 | Czechia | `cs` | visible Palworld review demand |
| 20 | India / Hindi market | `hi` | enormous worldwide/gaming reach; Palworld-specific public country evidence is weaker |
| 21 | Arabic-speaking markets | `ar` | enormous worldwide reach; useful first RTL validation; Palworld-specific public country evidence is fragmented |

## PMM locale target queue

The first three existing locales remain fixed at the top of the product because they are already complete. The normal **post-baseline market queue** is `pt-BR -> ko -> ru -> fr -> de -> zh-TW -> ja -> tr -> pl -> it -> th -> id -> vi -> nl -> uk -> cs -> hi -> ar`.

Hindi and Modern Standard Arabic are intentionally being completed **before** their market-queue position as the first v1.5 translation pair. Hindi exercises a major non-Latin script and very large language market; Arabic is the first complete `rtl` locale and therefore validates the generic right-to-left layout path. After that validation pair, work resumes at the start of the Palworld market queue with Brazilian Portuguese + Korean.

The older worldwide-speaker backlog is kept as reserve templates rather than deleted: Bengali (`bn`), Urdu (`ur`), Nigerian Pidgin (`pcm`), Egyptian Arabic (`arz`), Marathi (`mr`), Telugu (`te`) and Hausa (`ha`). They can be promoted later if usage/community demand justifies it. Modern Standard Arabic remains the primary Arabic UI locale; Egyptian Arabic is not a substitute for it.

## Current locale state

| Market order | Code | Native name | English name / target | Direction | State |
|---:|---|---|---|---|---|
| baseline | `en` | English | English | ltr | complete + active |
| baseline | `es` | Español | Spanish | ltr | complete + active |
| baseline | `zh-CN` | 简体中文 | Chinese (Simplified) | ltr | complete + active |
| 3 | `pt-BR` | Português (Brasil) | Portuguese (Brazil) | ltr | template pending |
| 4 | `ko` | 한국어 | Korean | ltr | template pending |
| 5 | `ru` | Русский | Russian | ltr | template pending |
| 6 | `fr` | Français | French | ltr | template pending |
| 7 | `de` | Deutsch | German | ltr | template pending |
| 9 | `zh-TW` | 繁體中文 | Chinese (Traditional) | ltr | template pending |
| 10 | `ja` | 日本語 | Japanese | ltr | template pending |
| 11 | `tr` | Türkçe | Turkish | ltr | template pending |
| 12 | `pl` | Polski | Polish | ltr | template pending |
| 13 | `it` | Italiano | Italian | ltr | template pending |
| 14 | `th` | ไทย | Thai | ltr | template pending |
| 15 | `id` | Bahasa Indonesia | Indonesian | ltr | template pending |
| 16 | `vi` | Tiếng Việt | Vietnamese | ltr | template pending |
| 17 | `nl` | Nederlands | Dutch | ltr | template pending |
| 18 | `uk` | Українська | Ukrainian | ltr | template pending |
| 19 | `cs` | Čeština | Czech | ltr | template pending |
| 20 | `hi` | हिन्दी | Hindi | ltr | **translation pair 1: in progress** |
| 21 | `ar` | العربية | Modern Standard Arabic | rtl | **translation pair 1: in progress / RTL validation** |
| reserve | `bn` | বাংলা | Bengali | ltr | reserve template |
| reserve | `ur` | اردو | Urdu | rtl | reserve template |
| reserve | `pcm` | Naijá | Nigerian Pidgin | ltr | reserve template |
| reserve | `arz` | العربية المصرية | Egyptian Arabic | rtl | reserve template |
| reserve | `mr` | मराठी | Marathi | ltr | reserve template |
| reserve | `te` | తెలుగు | Telugu | ltr | reserve template |
| reserve | `ha` | Hausa | Hausa | ltr | reserve template |

## Per-language completion checklist

1. Expand the template against the current `en.json` key set.
2. Translate all user-facing values; never alter canonical English keys.
3. Preserve placeholders such as `{0}`, format specifiers such as `{0:N2}`, and technical identifiers that are intentionally invariant.
4. Use a consistent glossary for PMM concepts and preserve proper product/technology names (`PMM`, `Palworld`, `Steam`, `PAK`, `ChatGPT`, `Codex`, `Unreal`, `Wwise`, `MCP`, etc.).
5. Register the completed language in `languages.json` at its product order.
6. Set `direction` correctly (`rtl` for `ar`; `ltr` for `hi` and the other current market targets).
7. Run `Development/Localization/Test-Localization.ps1 -Language <code>`.
8. Run `python Development/Localization/audit_localization.py`.
9. Run the Windows PowerShell 5.1 localization regression before release.
10. Visually inspect the principal WPF screens for truncation, dynamic English residue, and layout problems. RTL languages additionally require navigation/order/alignment review.
11. Update this ledger with completion/validation notes and the relevant commit.

## Work log

### 2026-09-16 — Palworld-market priority refresh + first translation pair

- Replaced the original pure total-speaker order with a Palworld-market-first priority model; worldwide speakers now break close ties.
- Kept public-data uncertainty explicit: US/China have direct approximate Palworld Steam shares, while later markets use Palworld language-region/review proxies rather than invented country percentages.
- Added pending market templates that were missing from the original speaker-based scaffold: Korean (`ko`), Traditional Chinese (`zh-TW`), Polish (`pl`), Italian (`it`), Thai (`th`), Ukrainian (`uk`), Dutch (`nl`) and Czech (`cs`).
- Preserved the previous high-speaker templates as a reserve backlog instead of deleting them.
- Started Hindi (`hi`) + Modern Standard Arabic (`ar`) as the first quality-controlled pair despite their later market priority, specifically to validate Devanagari/non-Latin rendering and the complete RTL path.
- After this pair, the next planned pair is Brazilian Portuguese (`pt-BR`) + Korean (`ko`).

### 2026-09-16 — v1.5 translation scaffolding

- Created branch `v1.5.0.0-PMM-translated` from the validated v1.3.4.1-era `main` state.
- Preserved the completed `en`, `es`, and `zh-CN` catalogs unchanged.
- Added 17 independent pending catalog templates from the original worldwide-speaker list.
- Kept pending templates out of the runtime language registry until each one is actually translated and validated.
- No release, tag, CI workflow, or product binary was created or changed in this step.
