# PMM German localization - complete catalog; user QA pending

Date: 2026-09-18
Branch: `v1.5.0.0-PMM-translated`
Base commit: `d5e293b690e863501684adc2f77ef7d603222386`
Next translation: **Traditional Chinese (`zh-TW`, 繁體中文)**

## State and provenance

The user confirmed French and requested German, then explicitly authorized publishing the prepared German package to this branch. German covers all **1,291/1,291** canonical entries. The accompanying registry change enables only `de`, with native name `Deutsch`, fallback `en`, direction `ltr`, and no separate XAML. The nine existing language catalogs and runtime code are unchanged.

The German catalog was first delivered as the local `PMM_1.5.0.0_Deutsch.zip` and `PMM_German.patch`, without a remote commit. This publication reuses that exact catalog rather than retranslating it. The branch was checked again and still matched the package's base commit. Publication uses one development commit with `[skip ci]`, with no main update, PR, tag, release or workflow dispatch. The publication commit is the Git commit containing this checkpoint; do not reuse the French base commit as the German publication SHA.

The English source was reconstructed from the previously read canonical sequence and verified byte for byte against the unchanged GitHub blob `2fa3c4712619cc5f811ce2251cef3daf5b0e2024` (132,005 bytes, including CRLF). The source blob was reconfirmed through the GitHub connector before publication.

German Git-blob SHA: `98bc5289926786476201a8bcbc82846c87576305`.
German SHA-256: `6fdc63265fbf90cfd7575baef474c29837f8442075b45ff6aa4b73b3fdf053a1`.
German size: 146,725 bytes, UTF-8/LF.

## Checks actually run

The package's local Python structural validation was rerun before publication, and its reproduced catalog was byte-identical to the prepared payload. Checks passed strict JSON/duplicate rejection, metadata, exact canonical keys/order, nonempty strings, complete placeholder/format multisets, numeric literals, edge whitespace, literal PowerShell escapes, selected technical identifiers, file extensions/filter patterns, Unicode controls/replacement characters and NFC. There are **109 parameterized entries**, **31 intentional invariants** and zero structural errors. The complete report and invariant list are in `Progress/de.json`.

The unchanged values are valid German words, mode/product labels, technical identifiers and native language names, including Adapter, Filter, Hash, Mod, Mods, Parameter, Patch and Status. Keyboard labels use German Strg/Umschalt while preserving the shortcut actions. PAKs/ZIPs normalize to PAK/ZIP for technical-token checks. UNPROVEN is retained with the clarification NICHT NACHGEWIESEN.

No PMM/WPF runtime, Windows PowerShell 5.1, native-speaker acceptance or full source-code localization audit was run. Publication is not an in-game test. Existing dynamic English counters, Library.UI selector behavior, Arabic mixed prose/path scopes and virtualized technical cells remain separate QA items.

## Glossary

| Source concept | German |
|---|---|
| Case / job | Fall / Auftrag |
| Analyze | Analysieren |
| Build | Erstellen / Erstellung (Build for the resulting artifact) |
| Deploy | Bereitstellen / Bereitstellung |
| Undeploy | Aus dem Spiel entfernen |
| Delete | Löschen |
| Merge | Zusammenführung |
| Repair / recipe | Reparatur / Rezept |
| Game Reference | Spielreferenz |
| Current Game Reference | Referenz des aktuellen Spiels |
| Asset / shared assets | Ressource / gemeinsam genutzte Ressourcen |
| Mappings | Mappings |
| Compatibility overlay | Kompatibilitätsebene |
| Evidence / findings | Nachweise / Befunde |
| Handoff | Übergabepaket |
| Color scheme | Farbschema |
| AI | KI |

Instructions use informal German consistently; buttons use infinitives. Product names and external menu paths remain recognizable. Source keys, identifiers, file filters, consent and rollback semantics are preserved. Undeploy and Delete remain distinct; optional installation and paid API opt-in are not turned into automatic consent. Native language names never change with the active locale.

## Test and continue

Pull `v1.5.0.0-PMM-translated` with GitHub Desktop. The manual patch installer is no longer required for a checkout containing this commit. Open PMM from that checkout, choose `Deutsch`, apply/save the language and restart PMM. Check main screens, Fix Lab, AI/help, installations, backups, dialogs, long messages and tooltips for clipping and phrasing. Restart-based language changes are deliberately unchanged.

French user confirmation is recorded in both ledgers and the French progress/handoff documents. German user runtime/visual QA remains pending. Address German feedback by exact canonical key rather than retranslating. The next queued language is Traditional Chinese, not Japanese. Preserve existing catalogs, runtime code, binaries, Arabic RTL/LTR behavior and all separately tracked QA issues. Update both ledgers when user QA is received.
