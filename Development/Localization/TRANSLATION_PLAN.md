## Romanian, Thai and Indonesian published for user testing — 2026-09-19

Română (`ro`), ไทย (`th`) and Bahasa Indonesia (`id`) now each cover **1,291/1,291 canonical English entries** and are enabled on `v1.5.0.0-PMM-translated` for user testing. Romanian preserves the recovered catalog byte-for-byte; Thai and Indonesian use the jointly validated catalogs. All three have 109 parameterized entries and the joint structural validator reported zero errors.

The registry now contains **30 registered locales, 19 enabled**. Romanian is inserted after Português (Brasil) and before Deutsch; Thai and Indonesian remain in their existing Asian positions. English remains first/default, native labels remain unchanged, and the previously enabled catalogs retain their relative order and metadata.

Runtime/visual QA, Windows PowerShell 5.1/WPF execution and native-speaker acceptance are still pending. Existing dynamic English counters, the legacy Library.UI selector path, Arabic mixed prose/path bidi handling and virtualized technical-cell checks remain separate.

Remaining approved translations: `vi -> uk -> cs -> ga` (Tiếng Việt -> Українська -> Čeština -> Gaeilge). Do not regenerate `ro`, `th` or `id` unless a specific QA defect is reported.

## Dutch localization complete; Irish next — 2026-09-18

Nederlands (`nl`) now covers **1,291/1,291 canonical English entries** and is enabled for user testing on `v1.5.0.0-PMM-translated`. Publication parent: `f231136769289a9dc56a71bed68fac11cc78833a`. All fifteen previously enabled catalogs, including Turkish and Polish, are unchanged.

Dutch blob: `f5609d59648da08956cf40c0a083e5aa21ad08ab`; SHA-256 `42eb98c97506de551f30c57566cc0cd789b0fd8b09493b7b8ccf36f63dbe2bc5`; 142,275 bytes, UTF-8/LF. Canonical English remains blob `2fa3c4712619cc5f811ce2251cef3daf5b0e2024`. The uploaded Dutch blob exactly matches the locally validated catalog. Local structural checks passed strict JSON/duplicates, metadata, exact case-sensitive keys/order, nonempty values, complete placeholders/formats, braces, numbers, edge whitespace, literal PowerShell escapes, selected technical tokens, extensions/dialog filters, units, color syntax, ~mods, Unicode controls and NFC. There are **109 parameterized entries**, **37 intentional whole-value invariants**, and zero remaining structural errors. See `DUTCH_HANDOFF.md` and `Progress/nl.json` for the glossary, invariant list and documented token rules.

The registry is now `8cf947332960f320ca3f39628b38b1dc2f089f4e`: **29 registered locales, 16 enabled**. Only Dutch enabled/status differs from the Turkish/Polish checkpoint. The quasi-continental selector order, all native labels, locale metadata, English first/default, Polish immediately after German, Dutch immediately after Polish and adjacent Chinese variants are preserved. Romanian is not added. Irish remains a disabled template in its European position.

**Next requested translation: Gaeilge (`ga`, Irish).** Dutch user runtime/visual QA and native-speaker review are pending. The request to continue did not include a new Turkish or Polish runtime confirmation, so their pending QA remains pending. Do not restart completed catalogs or follow older next-language pointers below.

No PMM/WPF execution, Windows PowerShell 5.1 test, full source-code localization audit or native-speaker acceptance was performed here. Existing dynamic English counters, the old Library.UI selector path, Arabic mixed prose/path handling and virtualized technical-cell checks remain separate. Catalog completeness is not release acceptance.

Publication is one ordinary fast-forward development commit with `[skip ci]`; no history rewriting, temporary transfer commits, PR, main update, release, tag, workflow dispatch, runtime-code change or binary change. Both shared ledgers are updated, with the complete earlier history retained below. This top checkpoint supersedes all earlier active/current headings, counts, QA states and next-language pointers only where explicitly stated.

## Turkish and Polish published; Italian user-confirmed; Dutch next — 2026-09-18

This checkpoint publishes the previously prepared Turkish and Polish catalogs together on `v1.5.0.0-PMM-translated`, without retranslating either language. The publication parent is `7b0209836ddcf8027c604bad9ea5c9e9ee0da9d2`. Both `tr` (Türkçe) and `pl` (Polski) are now enabled with `status: complete`, fallback `en`, direction `ltr`, and no separate XAML.

| Locale | Canonical entries | Parameterized entries | Intentional invariant values | User runtime/visual QA |
|---|---:|---:|---:|---|
| Türkçe (`tr`) | 1,291 / 1,291 | 109 | 21 | Pending |
| Polski (`pl`) | 1,291 / 1,291 | 109 | 23 | Pending |

Exact catalog identities: Turkish `a91f23d0efc9b1fd53570b2f94f1078c6fec0487` (142,665 bytes; SHA-256 `06d9235a5f6b59c9e2901c76d8ea438f317c34cd4ee72898584ef9de87a5142e`), Polish `0485e18aa3ac5b10a83b408f7b140b3d17f7c564` (143,271 bytes; SHA-256 `b00efd82dbbcacb3b36e32c310b1879d958f8775eda5ee907703be93cc3b9164`). The prepared package checksums and both local structural validators were rerun before publication and passed with zero errors. The exact catalog objects were also retrieved through the GitHub connector before attaching them to the publication tree. Canonical English remains `2fa3c4712619cc5f811ce2251cef3daf5b0e2024`.

The user's earlier feedback, "italiano probado. ok.", is recorded in Italian progress and its handoff as user-confirmed runtime feedback. It does not imply native-speaker review, Turkish/Polish acceptance, or resolution of generic runtime defects.

The registry is `5045c649730ae8cd50864285ecc6da5948008c46`: **29 registered locales, 15 enabled**. Only the enabled/status fields of `tr` and `pl` differ from the Italian checkpoint. English remains first/default; all native labels, fallbacks, directions, XAML fields and the quasi-continental visual order are preserved. Polish follows German, Dutch retains the following reserved position, the Chinese variants remain adjacent, and Turkish precedes Arabic. No Romanian locale is added.

**Next translation execution queue: Nederlands (`nl`) -> Gaeilge (`ga`).** Do not translate Turkish or Polish again from scratch. Read `TURKISH_HANDOFF.md`, `POLISH_HANDOFF.md` and the corresponding `Progress` files. After pulling this publication, do not also apply the earlier local patches.

Publication is one normal fast-forward development commit with `[skip ci]`. No force-push, temporary transfer commits, PR, release, tag, main update, workflow dispatch, runtime-code change or binary change is part of this task. The other thirteen enabled catalogs are unchanged. No PMM/WPF, Windows PowerShell 5.1, full source-code localization audit or native-speaker review was run. Existing dynamic counters, the old Library.UI selector path, Arabic mixed prose/path handling and virtualized technical-cell QA remain separate.

## Historical checkpoints

Everything below preserves the earlier ledger. Its older statements labelled current, pending publication, next language, or enabled counts describe those earlier snapshots and do not override the publication checkpoint above.

## Italian localization complete; Japanese user-confirmed; visual grouping clarified — 2026-09-18

Italiano covers **1,291/1,291 canonical English keys** and is enabled for user testing. The user confirmed "comprobado el japones funciona." Japanese is now user-confirmed; its catalog and the other eleven previously enabled catalogs are unchanged. Italian user runtime/visual QA remains pending.

Italian blob: `622c9ff286037bb9c4d878cc9bcee06daff41879`; SHA-256 `98ceb5bfe7b4dec705a9485b16b4f4477a19135765a25b9a80e1aac205c27932`; 145,035 bytes. Local structural checks passed with **109 parameterized entries**, **26 intentional whole-value invariants**, and zero remaining errors. Source and target reconstructions match their Git blobs byte for byte. Details and the single documented Steam grammatical-elision exception are in `ITALIAN_HANDOFF.md` and `Progress/it.json`. No PMM/WPF runtime, Windows PowerShell 5.1, full source-code localization audit or native-speaker acceptance was performed here.

**Next execution queue: `tr -> pl -> nl -> ga` (Türkçe -> Polski -> Nederlands -> Gaeilge).** This queue is separate from the selector order and the historical market estimates below.

The user clarified a quasi-continental **visual grouping**, not a strict geographic taxonomy or commercial ranking. English remains first and `default: en`; the flat selector order is now:

`en -> es -> fr -> it -> pt-BR -> de -> pl -> nl -> ga -> cs -> uk -> ru -> ja -> zh-CN -> zh-TW -> ko -> hi -> bn -> ur -> mr -> te -> th -> id -> vi -> tr -> ar -> arz -> pcm -> ha`

Romance locales follow English; other European locales remain above Asia. Polish and Dutch keep their reserved positions immediately after German. Japanese begins the Asian block, the two Chinese variants remain adjacent, and South Asian locales follow East Asian locales. Turkish and Arabic locales form the subsequent Turkey/Middle-East visual block. The remaining African reserve locales follow. These are pragmatic display groups, not exclusive linguistic/geographic classifications. Portuguese keeps the actual `pt-BR` locale and `Português (Brasil)` label. Disabled locales stay hidden in their reserved positions. **Romanian was mentioned only as a possibility; it is not registered, enabled or translated.**

There are **29 registered locales, 13 enabled**. This checkpoint changes only the Italian catalog, registry ordering/Italian activation and continuity records. It does not change runtime code, binaries, language-switch behavior, main, tags, releases or workflows. Publish as a normal fast-forward development commit with `[skip ci]`; do not rewrite history.

## Historical checkpoint — Japanese localization complete; user-defined queue and selector order updated — 2026-09-18

> The Italian checkpoint above supersedes this snapshot's Japanese QA status, next-language pointer and selector ordering. Japanese completion evidence remains historical evidence.

日本語 now covers **1,291/1,291 canonical English keys** on `v1.5.0.0-PMM-translated` and is enabled for user testing. Japanese blob: `0523fa7a906e7b7a13e24217c1b5142efb8feff5`; SHA-256 `2444aedd657e925cfde04436b5d02671b67651f490456627ca6f6ec0b4fa252c`; 159,854 bytes. Structural checks passed with 109 parameterized entries, 26 intentional invariants and zero recorded structural errors. Runtime/visual and native-speaker QA remain pending.

The user-defined translation execution queue is now:
`ja -> it -> tr -> pl -> nl -> ga`
(**日本語 -> Italiano -> Türkçe -> Polski -> Nederlands -> Gaeilge**).
Japanese is complete, so **Italiano is next**.

The selector/product order is deliberately separate from the Palworld market-evidence ranking. Leading order:
`en -> es -> pt-BR -> it -> fr -> de -> pl -> nl -> ja -> zh-CN -> zh-TW -> ko -> ru -> tr ...`.
Thus Polish and Dutch are reserved immediately after German, while Simplified and Traditional Chinese remain adjacent. Disabled locales do not appear until complete. Irish has been registered as `ga` / `Gaeilge` with a disabled template.

No runtime code, binaries, main, releases, tags or workflows are changed by this localization checkpoint.

## Historical checkpoint — Traditional Chinese localization published — 2026-09-18

繁體中文 now covers all **1,291 canonical English keys** on `v1.5.0.0-PMM-translated` and is enabled for user testing. This publication uses the exact prepared catalog validated against canonical English; Simplified Chinese and the ten previously enabled catalogs are unchanged.

Traditional Chinese blob: `1360cf6ae05998cb8170aac47b9714972a70fa86`; SHA-256 `8abfe1603399d60d9d20be961c45237a9b6dc77a9c771016443abb73e9904b56`; 131,024 bytes. Structural checks passed with 109 parameterized entries, 21 intentional invariants, zero missing keys, zero empty values and zero structural errors. Native language names remain literal, including `简体中文`.

The temporary transfer-only commits were replaced by this clean publication checkpoint. No PR, tag, release, main update, runtime code, binary or workflow was added. PMM/WPF runtime QA, Windows PowerShell 5.1 and native-speaker review remain pending. Existing dynamic-runtime and Arabic bidi QA issues remain separate.

Next step: user runtime/visual QA of Traditional Chinese. Next translation: **Japanese (`ja`, 日本語)**. German QA remains pending.

## Historical published checkpoint — German; French user confirmation recorded — 2026-09-18

Deutsch covers all 1,291 canonical English keys on `v1.5.0.0-PMM-translated` and is enabled for user testing. The user confirmed French and explicitly authorized publishing the previously prepared German package. The nine previously active catalogs are unchanged.
The German catalog was reused byte for byte from the local delivery, not retranslated. Its structural validation was rerun before publication: exact keys/order, nonempty values, placeholders, numbers, whitespace, selected technical tokens, file-dialog patterns and Unicode controls passed. There are 109 parameterized entries, 31 intentional invariants and zero remaining entries.
The uploaded German Git blob `98bc5289926786476201a8bcbc82846c87576305` matches the validated local bytes. Detailed evidence, glossary and limits are in `GERMAN_HANDOFF.md` and `Progress/de.json`.
No GitHub Actions, full repository audit, Windows PowerShell 5.1 or WPF visual/runtime test was run for this checkpoint. Language switching remains restart-based; existing runtime QA issues remain separately tracked.
Next step: user runtime/visual QA of German. Next translation: **Traditional Chinese (`zh-TW`, 繁體中文)**. Do not restart completed languages from scratch.

# PMM v1.5.0.0 translation plan

Branch: `v1.5.0.0-PMM-translated`
Base: validated `main` commit `70d106e871099e4936dc5f81eef3e4ea15529d93`

This file is the close translation-work ledger for PMM 1.5. Update it whenever a language template is created, started, completed, validated, activated, reordered, or otherwise changed.

## Current checkpoint — 2026-09-18

Italian is complete at the catalog level: **1,291/1,291 entries**, enabled with native label `Italiano`, fallback `en`, direction `ltr`, no separate XAML. The source checkpoint is `a11985b8608f00f64282af4817de71cfa5dad84f`; canonical English blob remains `2fa3c4712619cc5f811ce2251cef3daf5b0e2024`. `Progress/it.json` records the executed local structural checks. Japanese is user-confirmed; Italian user runtime/visual QA is pending. French, Korean and Portuguese remain user-confirmed; Russian has positive preliminary feedback. No additional German or Traditional Chinese confirmation is inferred. Turkish is next in the user-directed execution queue. The current quasi-continental selector order is defined in the top checkpoint and `languages.json`.

## Policy

- English (`en`) is the canonical source catalog and remains first/default in the selector.
- Spanish (`es`) and Simplified Chinese (`zh-CN`) are already translated and active.
- `languages.json` is the **complete inventory** of this branch. Planned languages must appear there even while unfinished.
- Every unfinished locale is registered with `enabled: false`; therefore it is visible in repository state but does not appear in the PMM language selector.
- Registry `status` values are `complete`, `in-progress`, `template`, or `reserve`.
- Every planned locale also has its own independent JSON catalog under `PMM/Resources/Localization/`.
- When a language is finished, populate every canonical English key, preserve placeholders and invariant technical terms, validate it, then change its registry entry to `enabled: true` / `status: complete`.
- `complete` is catalog readiness for development testing, not automatic release acceptance. Record which checks actually ran; matching line counts alone are not a machine-run key/placeholder audit.
- `rtl` languages must be registered with right-to-left direction.
- Language names in selectors always remain in their own native form. Display order follows the user's visual grouping, independently of translation execution priority and historical market estimates.
- Scope is one language or bounded stage per intervention. Korean was completed in two stages; the user subsequently requested a complete next language in one prompt where feasible. Keep a recoverable catalog, exact counts/cursor, glossary and validation status. Never mark unfinished work complete to meet a prompt quota.
- Language changes require restarting PMM. The experimental live-switch path was reverted because it increased startup cost and produced incorrect/slow in-session refreshes.
- The branch development identity is `1.5.0.0`. `PMM/Resources/Metadata/VERSION.txt` is the runtime UI version source; changing Git branches alone does not rewrite this file or rebuild an executable.

## Historical priority model: Palworld audience first, global language reach as tie-break

> Retained from the 2026-09-16 planning record; these estimates were not re-researched in the Italian checkpoint. They no longer determine selector order or override the user's execution queue.

The queue is not a pure ranking by world population. PMM is a Palworld tool, so the primary signal is estimated Palworld demand by market/language. Total worldwide speakers are used when two Palworld signals are close.

Public data has an important limitation: there is no authoritative complete country-by-country Palworld player table. Therefore this is a **localization-priority estimate**, not a claim that every country percentage is known exactly.

Evidence used for the 2026-09-16 priority refresh:

- Alinea Analytics reports the United States and China as Palworld's two largest Steam markets at roughly 27% of unit sales each.
- Steam review-language distribution is used as a direct Palworld-language proxy after those two markets.
- PCGamesData's Palworld player-region language estimate is used as a second Palworld-specific signal: English ~40%, Simplified Chinese ~24.1%, Brazilian Portuguese ~6.3%, Korean ~6.2%, Russian ~5.5%, French ~3.6%, German ~2.8%, Spanish ~2.8%.
- General gaming-population estimates are used only as a secondary market-potential signal where Palworld-specific public data is sparse.
- Worldwide total-speaker estimates are used as the tie-break when two Palworld markets are relatively close.

English-speaking countries cannot be separated reliably from one another by the Steam language proxy, and Spanish reviews combine Spain and Latin-American markets. Treat those as language-market groups rather than fabricated country percentages.

## Estimated Palworld market order (historical planning evidence)

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

English remains first/default. The old rule fixing English, Español and 简体中文 as the first three has been superseded by the user's visual grouping; Simplified and Traditional Chinese are now adjacent in the Asian block.

Historical market-evidence queue (kept for demand analysis only):

`pt-BR -> ko -> ru -> fr -> de -> zh-TW -> ja -> tr -> pl -> it -> th -> id -> vi -> nl -> uk -> cs -> hi -> ar`

Current user-directed execution queue after completed locales:

`tr -> pl -> nl -> ga`

Hindi and Modern Standard Arabic were intentionally moved ahead of their normal market position as early v1.5 quality targets. Both are enabled for user testing. Brazilian Portuguese, Korean, French and Japanese have passed the user's reported runtime test. Russian has positive preliminary user feedback. German and Traditional Chinese are complete and published; their separately tracked QA remains pending. Italian is complete and enabled for user QA. The user's positive reports do not by themselves close the specific runtime issues listed below.

The older worldwide-speaker backlog remains as reserve templates rather than being deleted: Bengali (`bn`), Urdu (`ur`), Nigerian Pidgin (`pcm`), Egyptian Arabic (`arz`), Marathi (`mr`), Telugu (`te`) and Hausa (`ha`). Romanian is a possible future Romance-block addition, not a committed locale or part of the active execution queue.

## Current locale state

The first column preserves historical market labels; actual selector order is in `languages.json` and the current checkpoint above.

| Market order | Code | Native name | English name / target | Direction | Registry | State |
|---:|---|---|---|---|---|---|
| baseline | `en` | English | English | ltr | enabled | complete + active; default |
| baseline | `es` | Español | Spanish | ltr | enabled | complete + active |
| baseline | `zh-CN` | 简体中文 | Chinese (Simplified) | ltr | enabled | complete + active |
| 3 | `pt-BR` | Português (Brasil) | Portuguese (Brazil) | ltr | enabled | **catalog complete; user reports it works perfectly** |
| 4 | `ko` | 한국어 | Korean | ltr | enabled | **catalog complete, 1,291/1,291; user reports it works perfectly** |
| 5 | `ru` | Русский | Russian | ltr | enabled | **catalog complete, 1,291/1,291; user reports it apparently works well** |
| 6 | `fr` | Français | French | ltr | enabled | **catalog complete, 1,291/1,291; user confirmed French** |
| 7 | `de` | Deutsch | German | ltr | enabled | **catalog complete, 1,291/1,291; published; structural recheck passed; user QA pending** |
| 9 | `zh-TW` | 繁體中文 | Chinese (Traditional) | ltr | enabled | **catalog complete, 1,291/1,291; published; user QA pending** |
| product | `ja` | 日本語 | Japanese | ltr | enabled | **catalog complete, 1,291/1,291; user confirms it works** |
| 11 | `tr` | Türkçe | Turkish | ltr | disabled | **next user-directed translation target; template pending** |
| 12 | `pl` | Polski | Polish | ltr | disabled | template pending; after Turkish |
| 13 | `it` | Italiano | Italian | ltr | enabled | **catalog complete, 1,291/1,291; structural checks passed; user QA pending** |
| 14 | `th` | ไทย | Thai | ltr | disabled | template pending |
| 15 | `id` | Bahasa Indonesia | Indonesian | ltr | disabled | template pending |
| 16 | `vi` | Tiếng Việt | Vietnamese | ltr | disabled | template pending |
| 17 | `nl` | Nederlands | Dutch | ltr | disabled | template pending; after Polish |
| 18 | `uk` | Українська | Ukrainian | ltr | disabled | template pending |
| 19 | `cs` | Čeština | Czech | ltr | disabled | template pending |
| 20 | `hi` | हिन्दी | Hindi | ltr | enabled | **complete; user runtime/visual test in progress** |
| 21 | `ar` | العربية | Modern Standard Arabic | rtl | enabled | **catalog complete; RTL polishing and runtime QA in progress** |
| product | `ga` | Gaeilge | Irish | ltr | disabled | **user-requested template; translate after Nederlands** |
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

## Open runtime localization QA

- Dynamic counters (`candidate(s)`, `variant(s)`, `case backup(s)`, library/patch counts) still contain English at runtime. Catalog completeness alone does not fix interpolation paths that never call localization with a canonical key.
- Arabic mixed prose/path text in `TxtGamePathStatus` needs separate inline bidi scopes in the rendering path. Do not force the entire sentence or status/log controls to LTR merely because it contains a Latin token.
- The technical allowlist now includes actual library bindings `HashShort`, `SizeText` and `Priority`. Pure paths/IDs/versions and supported DataGrid technical cell content use LTR; column order and captions stay RTL. Virtualized/template-created cells still need Windows review.
- `Refresh-UI` in `Presentation/Library.UI.ps1` was found to retain an old English/Spanish-only selector assignment. It is not changed in this bounded recovery; verify selection persistence/refresh before release and replace it with the language resolver in a focused correction.
- Full machine-run catalog validation and Windows PowerShell/WPF validation were not executed in the 2026-09-17 recovery environment. The registry enables Portuguese for user testing, not as a release-accepted build.

## Work log

### 2026-09-18 — Japanese confirmed; Italian completed; visual grouping clarified

- Recorded the user's exact Japanese feedback: "comprobado el japones funciona." Updated Japanese progress as user-confirmed without changing the Japanese catalog or presenting old automated checks as a new runtime test.
- Continued from `a11985b8608f00f64282af4817de71cfa5dad84f`, where Italian was an empty disabled template. Completed every canonical entry and preserved exact keys/order and case distinctions.
- Italian blob `622c9ff286037bb9c4d878cc9bcee06daff41879` matches the locally checked file byte for byte; SHA-256 `98ceb5bfe7b4dec705a9485b16b4f4477a19135765a25b9a80e1aac205c27932`, 145,035 bytes. Canonical English blob remains `2fa3c4712619cc5f811ce2251cef3daf5b0e2024`.
- Local Python checks passed JSON/duplicates, metadata, keys/order, nonempty strings, full placeholders/formats, numeric literals, whitespace, literal escapes, selected technical identifiers, file extensions/dialog filters, units, color syntax, `~mods`, Unicode controls and NFC. There are 109 parameterized entries and 26 intentional invariants. A single Steam qualifier elision is documented in `Progress/it.json` and `ITALIAN_HANDOFF.md`.
- Enabled only Italian and applied the user's quasi-continental grouping. Registry blob `0bbac7221e8bd16c128758a50710e63c9b5d73e9` preserves all existing names/fallbacks/directions/XAML/statuses except Italian activation. English remains first/default, Polish/Dutch immediately after German, Irish/Russian above Asia, and the Chinese variants together. Romanian stays a possibility only.
- Next execution order is Turkish, Polish, Dutch, Irish, independent of display order. Updated both ledgers and added the Italian handoff/progress. No other catalog or runtime/native binary changed.
- No PMM/WPF runtime, Windows PowerShell 5.1, full source-code localization audit or native-speaker review ran; these remain release/user QA work. No Actions were dispatched. Use a single `[skip ci]` fast-forward development commit, with no main, PR, tag or release changes.

### 2026-09-18 — French confirmed; prepared German package published

- Recorded the user's French confirmation: "Frances confirmado. Seguimos con alemán". French catalog contents remain unchanged; confirmation is user feedback, not a new exhaustive automated audit.
- The German catalog was already complete in the local package. The user explicitly requested publication to the same branch after restoring GitHub write access. No translation was restarted.
- Rechecked the branch at `d5e293b690e863501684adc2f77ef7d603222386` and the canonical English blob `2fa3c4712619cc5f811ce2251cef3daf5b0e2024` before publication.
- Reran the package's bounded local Python validation: 1,291/1,291 exact keys, 109 parameterized entries, 31 intentional invariants, no structural errors. The reproduced file is byte-identical to the prepared payload.
- GitHub returned German blob `98bc5289926786476201a8bcbc82846c87576305`, exactly matching the local file; SHA-256 `6fdc63265fbf90cfd7575baef474c29837f8442075b45ff6aa4b73b3fdf053a1`, 146,725 bytes.
- Enabled only `de`; reversing those two registry fields exactly reproduces the current registry blob. Added the German handoff/progress records, updated both ledgers and recorded French confirmation in its handoff/progress.
- Publication is one authorized development commit with `[skip ci]`. No runtime code, binaries, other language catalogs, main, tags, releases or workflows changed. No Actions were dispatched; no Windows PowerShell 5.1, PMM/WPF or full source-code localization audit ran.
- German user QA is pending. Traditional Chinese (`zh-TW`) is next. The manual patch installer is no longer needed after pulling this commit.

### 2026-09-18 — Russian preliminary user feedback positive; French completed

- Recorded the user's exact Russian feedback: "funciona bien aparentemente". This is positive preliminary feedback, not exhaustive runtime or linguistic acceptance.
- Continued from `7da32ce5fb043105690219d90f86ad0cf514d1bb`, where French was an empty disabled template and the next queued language.
- Translated all 1,291 canonical entries and preserved exact source keys/order. The reconstructed English file matched Git blob `2fa3c4712619cc5f811ce2251cef3daf5b0e2024` byte for byte.
- Local Python checks passed strict JSON/duplicate rejection, metadata, full key parity/order, nonempty values, full placeholders/format specifiers, remaining braces, numeric literals, edge whitespace, literal escapes, selected technical identifiers, ~mods references, extensions, file-dialog patterns, Unicode controls and NFC normalization. There are 109 parameterized entries and 31 intentional invariant values, including valid French homographs.
- French Git blob `09b29bddef3fe13d7bc0f0fdd4d7d476f1050deb` matches the checked local bytes; SHA-256 `de54d8d56b2bf6d488215ebcc6f401662b17af0cff475c5b04ca085330b1ad8e`, 149,134 bytes. Added `FRENCH_HANDOFF.md` and `Progress/fr.json`.
- Enabled only French in the registry. The eight previously active language catalogs, runtime code, binaries, Arabic bidi behavior, main, releases, tags and workflows remain unchanged. No GitHub Actions were dispatched, and no PowerShell 5.1/WPF or full repository localization audit was run.
- French user QA is pending. German (`de`, Deutsch) is the next target; do not restart completed catalogs. Both ledgers are updated in the same `[skip ci]` development checkpoint.

### 2026-09-18 — Korean user QA accepted; Russian completed in one prompt

- Recorded the user's report that Korean works perfectly and the previously added languages also work. This is user feedback, not an automated or exhaustive runtime audit.
- Resumed from branch HEAD `d9442cff26b8ac84a1f85fe0db023baf2d6c89f8`. Russian was an empty disabled template and followed Korean in the approved queue.
- Translated all 1,291 canonical entries; no source key was changed. Source blob `2fa3c4712619cc5f811ce2251cef3daf5b0e2024` was reconstructed locally with byte-identical content, not just matching line counts.
- Ran bounded local Python checks for strict JSON/duplicates, metadata, exact keys/order, nonempty values, full placeholder multisets, numeric literals, whitespace, literal escapes, selected technical identifiers, extensions/dialog filters and Unicode controls. Zero errors remained; 109 entries contain parameters, 18 whole-value invariants are intentional and 1,273 values contain Cyrillic.
- Uploaded Russian blob `ffa3bfb80ef2aa4ae3268b0c557e3a38bb4b1b18` exactly matches the checked local bytes. SHA-256: `21250ee7671b8b4875527b799072043d80b27e2883820249b96af3f477bf1173`.
- Enabled only `ru` in the registry, preserving all names, ordering, existing locale settings and other catalogs. Added `RUSSIAN_HANDOFF.md` and `Progress/ru.json` with glossary, evidence, intentional invariants and validation limits.
- No localization runtime, Arabic RTL/LTR behavior, native binary, main, release, tag or workflow changed. No GitHub Actions were dispatched; no PowerShell 5.1/WPF or full source-code localization audit was run. Existing runtime QA issues remain open separately.
- Russian user runtime/visual QA is next; French (`fr`) is the next translation target. Both tracking ledgers are updated in the same development checkpoint with `[skip ci]`.

### 2026-09-18 — Portuguese user QA accepted; Korean part 1 checkpoint

- Recorded the user's report that Portuguese works perfectly. This is user-reported runtime QA, not a new machine-run audit.
- Resumed from branch HEAD `ef68aeef85b5160948030a0eb358b932ed68a82f`; the Korean catalog at that point was an empty template. No saved Korean translation was overwritten.
- Completed the first 645 baseline keys through `Load draft` in `PMM/Resources/Localization/ko.json`, with 11 intentional invariants and 62 parameterized strings. Source blob: `2fa3c4712619cc5f811ce2251cef3daf5b0e2024`.
- Executed local Python checks for strict JSON/duplicate keys, nonempty values, full placeholder multisets, numeric literals, selected technical tokens, trailing spaces and unexpected Unicode controls. No errors remained. Uploaded catalog blob `e239428f7eab5b6ff954dbebfb50e3b198308cc9` exactly matches the locally validated bytes.
- Source range was read sequentially through GitHub; a full repository/source-parity machine audit and PowerShell/WPF tests were not run. Korean remains `in-progress` and disabled.
- Added `KOREAN_HANDOFF.md` with glossary, source identity, procedures, validation limits and preserved product constraints; added `Progress/ko.json` with exact counts, hashes and the next key. The remaining 646 entries begin at `Loading Fix Lab module...`.
- Updated both ledgers and the registry in the same checkpoint. No active language catalog, runtime code, main, release, tag, PR or workflow changed; no GitHub Actions were run.

### 2026-09-17 — recover Portuguese publication and bound RTL exceptions

- Confirmed the previously interrupted Portuguese write really reached GitHub in `9bcc60ff96da11c39c05cdf5b97b7561f84ca879`. Reused that committed translation; no restart from zero and no second language added.
- Found two malformed embedded-quote lines and fixed them in `fcd966a8ce921574ab2eaff864295a29dd3aa6a8`. The remote diff contains only those two fixes. Corrected catalog blob: `8bb8888779c60fe4c22ab6d7c8ac3944077cf5e0`.
- A local Python check confirmed the two corrected quoted-placeholder snippets parse and preserve `{0}`. This was a snippet check, not a full-catalog audit. Earlier statements that automated checks passed must not be reused as evidence of a new run.
- Enabled `Português (Brasil)` while preserving `English`, `Español`, `简体中文` as the first three native labels. Arabic and Hindi remain enabled; all other templates remain disabled.
- Recovered the partial LTR work from `38bd5a934488ac11a6200d3142b889ca86a82f57`. Narrowed the exception list by excluding status/log sentences and adding actual technical library binding names. No RTL layout reversal, stored-data mutation, global event handler, timer or live language switching was introduced.
- Updated both tracking documents with the work performed and the remaining runtime checks. No release, tag, PR, main update or GitHub Actions run was requested or created in this recovery.

### 2026-09-16 — Arabic completion + first RTL user-test handoff

- Continued from the committed partial `ar.json`; the Arabic work was not restarted from zero.
- Expanded Modern Standard Arabic through the complete current canonical English sequence. The Arabic file keeps the same key order and reaches the same canonical tail as `en.json`; its one-line offset is the Arabic-only `translationStatus` metadata line. This was a visual sequence comparison, not an executed machine key-parity audit.
- Preserved format placeholders and technical/product identifiers while translating PMM-facing prose. Arabic is registered with `direction: rtl` and is now `enabled: true` / `status: complete` for the user's runtime test.
- The user's Hindi screenshot showed stable Devanagari text and no obvious severe clipping in the visible Fix Lab screen. It also exposed dynamic English suffix residue such as `0 candidate(s)`, `0 variant(s)` and `0 case backup(s)`. Those are dynamic-format localization gaps rather than missing Hindi catalog entries and should be cleaned up generically before the final v1.5 release.
- Final release acceptance for Arabic is still pending the user's real Windows RTL/layout screenshot plus the normal PowerShell/WPF localization validation before release. No GitHub Actions were run in this development intervention.
- Next translation target returned to the market queue: Brazilian Portuguese (`pt-BR`), then Korean (`ko`).

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
- Added pending market templates that were missing from the original speaker-based scaffold: Korean (`ko`), Traditional Chinese (`zh-TW`), Polish (`pl`), Italian (`it`), Thai (`th`), Ukrainian (`uk`) and Dutch (`nl`) and Czech (`cs`).
- Preserved the previous high-speaker templates as a reserve backlog instead of deleting them.
- Started Hindi (`hi`) + Modern Standard Arabic (`ar`) as early quality targets to validate Devanagari/non-Latin rendering and RTL behavior.
- After Hindi and Arabic, the market queue resumes with Brazilian Portuguese (`pt-BR`) and Korean (`ko`), now handled one language/stage at a time rather than two complete locales in one prompt.

### 2026-09-16 — v1.5 translation scaffolding

- Created branch `v1.5.0.0-PMM-translated` from the validated v1.3.4.1-era `main` state.
- Preserved the completed `en`, `es`, and `zh-CN` catalogs unchanged.
- Added independent pending catalog templates for the original worldwide-speaker list.
- No release, tag, main merge or native executable was created or changed in this translation scaffolding.
