# PMM Dutch localization - complete catalog; user QA pending

Date: 2026-09-18
Branch: `v1.5.0.0-PMM-translated`
Source checkpoint: `f231136769289a9dc56a71bed68fac11cc78833a`
Locale: `nl` / `Nederlands`
Next requested translation: **Irish (`ga`, Gaeilge)**

## State and provenance

Dutch covers **1,291/1,291 canonical English keys** with `enabled: true`, `status: complete`, fallback `en`, direction `ltr`, and no separate XAML. It occupies its existing selector position immediately after Polski. All fifteen previously enabled catalogs, including the newly published Turkish and Polish, are unchanged.

Canonical English blob: `2fa3c4712619cc5f811ce2251cef3daf5b0e2024` (132,005 bytes).
Dutch blob: `f5609d59648da08956cf40c0a083e5aa21ad08ab` (142,275 bytes, UTF-8/LF).
Dutch SHA-256: `42eb98c97506de551f30c57566cc0cd789b0fd8b09493b7b8ccf36f63dbe2bc5`.
Registry blob: `8cf947332960f320ca3f39628b38b1dc2f089f4e`.

The locally available canonical English file was checked against the current GitHub source blob and matched byte for byte. The uploaded Dutch blob exactly matches the locally constructed and validated catalog. No language was enabled merely on the basis of line counts.

## Checks actually executed

A local Python structural pass checked strict JSON/duplicate rejection, metadata, exact case-sensitive keys and order, nonempty values, complete placeholder and format multisets, brace counts, numeric literals, edge whitespace, literal PowerShell escapes, selected technical-token multisets, extensions, file-dialog filters, units, color syntax, `~mods`, Unicode controls, replacement characters and NFC normalization. All checks passed. There are **109 parameterized entries**, **37 intentional whole-value invariants**, zero missing or extra keys and zero structural errors.

The invariant list is recorded in `Progress/nl.json`. It includes product names and native language labels, as well as valid shared Dutch technical vocabulary such as Adapter, Asset, Filter, Interface, Mod, Parameter, Status, Transport, Type and Workflow. These are not unfinished entries.

Token rules are explicit: PAKs/ZIPs become PAK/ZIP; generic Vanilla, Knowledge and cooked prose is translated. Normal is translated when it is an ordinary adjective in three documented source keys, but retained as the Gura recipe identifier. The generic wording session id becomes sessie-ID. Consent, destructive-operation warnings, rollback failures, paid API opt-in and inactive/untrusted candidate warnings are preserved. `UNPROVEN` remains visible as `ONBEWEZEN (UNPROVEN)`.

Registry comparison against blob `5045c649730ae8cd50864285ecc6da5948008c46` confirms that only Dutch enabled/status changes. Names, locale codes, fallback, direction, XAML entries and list order are otherwise identical. There are **29 registered locales and 16 enabled**. English remains first/default.

These are catalog and registry checks, not a PMM execution test. No PMM/WPF, Windows PowerShell 5.1, full source-code localization audit or native-speaker acceptance was performed. No GitHub Actions or remote tests were dispatched. User runtime/visual review is pending.

## Glossary

| Source concept | Dutch |
|---|---|
| Analyze | Analyseren |
| Build | Bouwen; build for an artifact |
| Deploy | Implementeren |
| Undeploy | Implementatie verwijderen |
| Merge | Samenvoegen / samenvoeging |
| Repair | Herstellen / herstel |
| Apply Fix | Herstel toepassen |
| Case | Casus |
| Asset / shared assets | Asset / gedeelde assets |
| Game Reference | Spelreferentie |
| Compatibility overlay | Compatibiliteitslaag |
| Mappings | Mappings |
| Handoff | Overdrachtspakket |
| Evidence | Bewijs |
| Settings | Instellingen |
| Backup / save restore | Back-up / opgeslagen spel herstellen |
| Light theme | Licht |

## Ordering and scope

The user's quasi-continental visual order is unchanged: English first, Romance languages, remaining European languages, Asian languages, the Turkey/Middle-East group and remaining reserve languages. The relevant European sequence remains **Deutsch -> Polski -> Nederlands -> Gaeilge**. Irish remains a disabled template until translated; both Chinese variants remain adjacent. Romanian is still only a possible future addition and is not added here.

After Dutch, the user-directed execution queue is **Gaeilge**. Do not substitute the older market-priority table for this queue. No new Turkish or Polish runtime confirmation was supplied with this request; their pending QA is not silently marked accepted.

## User test and continuation

Pull `v1.5.0.0-PMM-translated`, launch PMM from that checkout, choose `Nederlands`, apply/save the language and restart PMM. Review principal screens, Mods & Merge, Fix Lab, Mod Creation, AI & Help, Settings/installations, World Save, dialogs and long tooltips for clipping or awkward wording. In particular, review longer Dutch compound labels such as compatibility and merge controls.

Previously tracked dynamic English counters, the old Library.UI selector assignment, Arabic mixed prose/path bidi handling and virtualized technical cells remain separate runtime QA items. Dutch catalog completeness does not resolve these code paths. Retain restart-based switching and do not alter runtime code or other catalogs during this language checkpoint.

Publication uses one ordinary fast-forward commit with `[skip ci]`, without PR, main changes, tags, releases, temporary transfer commits or force-push. Both shared ledgers are updated. Existing history, binaries, game files and all other language catalogs are preserved.
