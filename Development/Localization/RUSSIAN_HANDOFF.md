# PMM Russian localization — completed catalog, user QA pending

Date: 2026-09-18  
Branch: `v1.5.0.0-PMM-translated`  
Next translation target: **French (`fr`, Français)**

## Checkpoint

The user confirmed Korean works perfectly and asked to continue the existing queue, preferably completing one language in this prompt. Russian is the next queued language and is now complete at the catalog level: **1,291/1,291 canonical keys**, registered as `enabled: true` / `status: complete`, native label `Русский`, fallback `en`, direction `ltr`, no separate XAML.

The source is `en.json` at commit `d9442cff26b8ac84a1f85fe0db023baf2d6c89f8`, Git blob `2fa3c4712619cc5f811ce2251cef3daf5b0e2024`. The sequentially reconstructed local English file matches that remote blob byte for byte, including CRLF. The uploaded Russian blob matches the locally checked UTF-8/LF file exactly: `ffa3bfb80ef2aa4ae3268b0c557e3a38bb4b1b18`.

Russian SHA-256: `21250ee7671b8b4875527b799072043d80b27e2883820249b96af3f477bf1173`. Size: 196,759 bytes.

## Validation actually executed

A local Python structural pass checked strict JSON/duplicate keys, schema/locale metadata, exact key set and order, nonempty values, full placeholder multisets including format specifiers, numeric literals, leading/trailing spaces, literal escapes, selected technical-token multisets, archive/file extensions, file-dialog filters, unexpected Unicode controls and Cyrillic presence. No errors remained.

There are 109 parameterized strings and 18 intentional whole-value invariants; the other 1,273 entries contain Cyrillic. PAKs/ZIPs are normalized to the invariant PAK/ZIP tokens for token comparison. The visible standalone labels LOCAL FAIL/PARTIAL/PASS are translated; those status identifiers are retained inside explanatory text. These are documented contextual rules, not unrestricted token exceptions. Machine-readable results and the exact invariant list are in `Progress/ru.json`.

This is not a PMM runtime or native-speaker acceptance claim. `Test-Localization.ps1`, the full source-code localization auditor, Windows PowerShell 5.1 and WPF visual/runtime tests were not run for this checkpoint. No GitHub Actions were dispatched. The existing release-validation checklist still applies.

## Glossary and translation choices

| Source concept | Russian |
|---|---|
| Mod | Мод |
| Case / job | Задача / задание |
| Analyze | Анализировать |
| Build | Сборка / собрать |
| Deploy | Развёртывание / развернуть |
| Undeploy | Снять с развёртывания |
| Repair | Исправление / исправить |
| Game Reference | Эталон игры |
| Current Game Reference | Эталон текущей версии игры |
| Asset / shared assets | Ресурс / общие ресурсы |
| Mappings | Сопоставления |
| Compatibility overlay | Слой совместимости |
| Evidence | Подтверждающие данные |
| Handoff | Пакет передачи |
| AI | ИИ |
| AUTO / SemiAUTO | АВТО / ПолуАВТО |

PMM, Palworld, Fix Lab, product names, paths/extensions, code identifiers, protocol names and technical report identifiers remain invariant where required. External application menu paths remain recognizable. English source keys are unchanged, including case-only distinctions and quoted-placeholder keys. Confirmations, rollback failures, untrusted/inactive returned files, consent, paid API opt-in and UNPROVEN warnings retain their original meaning; nothing was weakened or turned into an approval.

## User QA and continuation

Pull this branch, open PMM from that checkout, choose `Русский`, save/apply the language, and restart PMM. Check Mods & Merge, Fix Lab, Mod Creation, AI & Help, Settings/Installations, backups, dialogs and long status/tooltips for clipping and natural phrasing. Confirm that the selector still shows every language in its native form. Do not revive live language switching to avoid the restart.

Previously tracked dynamic English counters, the old Library.UI selector assignment, Arabic mixed prose/path scopes and virtualized technical cells remain separate runtime QA issues. This catalog-only intervention neither fixes nor closes them. The user's positive feedback on older languages is recorded without treating it as proof that those specific paths were exhaustively retested.

Do not retranslate Korean, Portuguese or Russian from scratch. Address any reported Russian issue by exact source key. Otherwise continue with French against the current canonical key set. Keep other language catalogs, localization runtime, binaries, main, releases, tags and workflows unchanged. Update both ledgers with every subsequent checkpoint and use `[skip ci]` for authorized development commits.
