# PMM Italian localization - complete catalog; user-confirmed

> User update, 2026-09-18: "italiano probado. ok." Italian has passed the user's reported runtime test. This supersedes the earlier pending user-QA wording below. It is not exhaustive native-speaker or automated acceptance, and does not close generic runtime localization issues. The Italian catalog is unchanged.

Date: 2026-09-18
Branch: `v1.5.0.0-PMM-translated`
Source checkpoint: `a11985b8608f00f64282af4817de71cfa5dad84f`
Locale: `it` / `Italiano`
Next requested translation: **Turkish (`tr`, Türkçe)**

## State and provenance

Italian covers **1,291/1,291 canonical English keys**, with `enabled: true`, `status: complete`, fallback `en`, direction `ltr`, and no separate XAML. All twelve previously enabled catalogs, including Japanese, are unchanged. The user explicitly reported: "comprobado el japones funciona." This is recorded as user-confirmed Japanese runtime feedback, not an exhaustive automated or native-speaker audit.

Canonical English blob: `2fa3c4712619cc5f811ce2251cef3daf5b0e2024` (132,005 bytes).
Italian blob: `622c9ff286037bb9c4d878cc9bcee06daff41879` (145,035 bytes, UTF-8/LF).
Italian SHA-256: `98ceb5bfe7b4dec705a9485b16b4f4477a19135765a25b9a80e1aac205c27932`.
Registry blob: `0bbac7221e8bd16c128758a50710e63c9b5d73e9`.

A local reconstruction of both source and Italian files matched the respective Git blob hashes byte for byte. The registry was reconstructed against its previous blob `a088f943d2b36abf4e0bca7d766a812f5f60bccc`; the only per-locale field changes are Italian enabled/status. Reordering preserves all names, fallbacks, directions, XAML paths and other statuses. English remains first and `default: en`. There are 29 registered locales and 13 enabled locales; no Romanian locale was created or enabled.

## Executed checks and limits

Local Python checks passed strict JSON with duplicate rejection, schema/locale metadata, exact case-sensitive key set and order, nonempty strings, complete placeholder/format multisets, remaining braces, numeric literals, leading/trailing whitespace, literal PowerShell escapes, selected protected identifiers, file extensions, file-dialog filters, units, color-format tokens, `~mods`, Unicode controls/replacement characters and NFC. There are **109 parameterized entries**, **26 intentional whole-value invariants**, and zero remaining structural errors.

The token check permits `PAKs/ZIPs` to become `PAK/ZIP`. One exact-key grammatical exception is documented: in `Select a Steam installation or Steam library. PMM will inspect steamapps and registered Steam libraries.`, Italian shares the qualifier in `un'installazione o una libreria di Steam`, reducing three occurrences of Steam to two without changing the meaning. AI becomes IA; generic Vanilla/Knowledge/cooked prose is translated, not treated as a protocol identifier. Product and actual code identifiers are preserved.

Invariant values include product/native-language names and words also valid in Italian, such as `Auto`, `Backup: {0}`, `Hash`, `Mod`, `Patch`, and `Volume:`. Their exact list is in `Progress/it.json`.

No PMM/WPF runtime, Windows PowerShell 5.1, full repository/source-code localization audit, or native-speaker acceptance was performed here. No CI or GitHub Actions was dispatched. Catalog readiness is not release acceptance.

## Glossary

| Source concept | Italian |
|---|---|
| Analyze | Analizza / analisi |
| Build | Compila / compilazione; build for a built artifact |
| Deploy | Distribuisci / distribuzione |
| Undeploy / Delete | Rimuovi dal gioco / Elimina |
| Merge | Unione |
| Repair / Apply Fix | Ripara / Applica correzione |
| Case / job | Caso / attività |
| Game Reference | Riferimento del gioco |
| Asset / shared assets | Risorsa / risorse condivise |
| Mappings | Mappature |
| Compatibility overlay | Overlay di compatibilità |
| Evidence | Prove |
| Handoff | Pacchetto di passaggio |
| Save backup / save restore | Backup del salvataggio / Ripristino del salvataggio |
| Color scheme / Light | Combinazione di colori / Chiaro |
| AI | IA |

Consent, rollback warnings, untrusted/inactive returned content, optional installations and separately billed API opt-in retain their original meaning. `UNPROVEN` is retained with the clarification `NON VERIFICATO`.

## Visual grouping, not a market ranking

The user's latest clarification separates execution priority from a quasi-continental selector layout. Keep this flat registry order; no UI headers, live switching, automatic sorting, or runtime layout changes were introduced:

- English first/default; Romance block: `es -> fr -> it -> pt-BR`.
- Remaining European block: `de -> pl -> nl -> ga -> cs -> uk -> ru`. Polish and Dutch stay immediately after German; Irish stays with Europe.
- Asian block: `ja -> zh-CN -> zh-TW -> ko -> hi -> bn -> ur -> mr -> te -> th -> id -> vi`. The two Chinese variants are adjacent; Urdu stays with South Asian languages rather than being moved solely by its script.
- Turkey/Middle-East visual block: `tr -> ar -> arz`; remaining African reserve: `pcm -> ha`.

These are pragmatic display groups, not exclusive geographic or linguistic classifications. Portuguese retains its actual locale and label `Português (Brasil)`. Romanian was only mentioned as a possibility; record it as a candidate for the Romance block pending a decision, not as a translated or registered language. Disabled locales retain their reserved positions and remain hidden.

Execution queue after Italian: **Türkçe -> Polski -> Nederlands -> Gaeilge**. Do not reorder this queue to match the selector.

## User test and continuity

Pull the translation branch, launch PMM from that checkout, choose `Italiano`, apply/save the language and restart PMM. Review major tabs, Fix Lab, AI/help, installations, saves, dialogs, tooltips and long labels. Confirm that every selector label remains native.

Previously tracked dynamic English counters, the older Library.UI selector path, Arabic mixed prose/path bidi scopes and virtualized technical-cell checks remain open separately. Japanese confirmation does not close those generic issues or imply German/Traditional Chinese acceptance. Do not retranslate completed catalogs without a specific reported defect. Keep main, tags, releases, workflows, binaries and runtime code unchanged. Publish by a normal fast-forward development commit with `[skip ci]`, not by rewriting branch history.
