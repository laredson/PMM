# PMM French localization - complete catalog, user QA pending

Date: 2026-09-18
Branch: `v1.5.0.0-PMM-translated`
Next translation target: **German (`de`, Deutsch)**

## Checkpoint

The user reported that Russian apparently works well and requested the next language. Record this as positive preliminary user feedback, not exhaustive runtime or linguistic acceptance. French was the next disabled template in the established queue.

French now covers **1,291/1,291 canonical keys** in `PMM/Resources/Localization/fr.json`. Registry: `enabled: true`, `status: complete`, native name `Français`, fallback `en`, direction `ltr`, no separate XAML. The eight previously active catalogs are unchanged. Language changes still require a restart.

Source commit: `7da32ce5fb043105690219d90f86ad0cf514d1bb`.
Canonical English Git blob: `2fa3c4712619cc5f811ce2251cef3daf5b0e2024` (132,005 bytes).
French Git blob: `09b29bddef3fe13d7bc0f0fdd4d7d476f1050deb` (149,134 bytes, UTF-8/LF).
French SHA-256: `de54d8d56b2bf6d488215ebcc6f401662b17af0cff475c5b04ca085330b1ad8e`.

## Checks actually executed

A local Python structural check loaded strict JSON while rejecting duplicate keys; checked metadata, exact key set and order, nonempty strings, full placeholder multisets and format specifiers, balanced remaining braces, numeric literals, leading/trailing whitespace, literal PowerShell escapes, selected technical identifiers, ~mods references, file extensions/filter patterns, Unicode controls/replacement characters and NFC normalization.

All checks passed after focused corrections. There are **109 parameterized entries**, zero missing keys and zero empty values. The reconstructed English source matched the canonical Git blob byte for byte, including CRLF; this was not merely a line-count comparison. GitHub returned a French blob SHA identical to the locally validated file.

The 31 unchanged values are intentional: product/native-language labels, technical identifiers and words also used in French, such as Interface, Installations, Mod, Mode, Options, Question, Solutions, Source and Type. Their exact list is in `Progress/fr.json`. PAKs/ZIPs are normalized to PAK/ZIP for technical-token comparison. Mo, Go and Mio localize MB, GB and MiB without altering their numeric placeholders.

No PMM/WPF runtime, Windows PowerShell 5.1, native-speaker acceptance or full repository/source-code localization audit was performed. No GitHub Actions were dispatched. Catalog readiness is not final release acceptance.

## Glossary

| English concept | French |
|---|---|
| Case / job | Dossier / tâche |
| Analyze | Analyser |
| Build | Générer / génération |
| Deploy | Déployer / déploiement |
| Undeploy | Retirer du jeu |
| Merge | Fusion |
| Repair | Réparer / réparation |
| Game Reference | Référence du jeu |
| Current Game Reference | Référence du jeu actuel |
| Asset / shared assets | Ressource / ressources partagées |
| Mappings | Correspondances |
| Compatibility patch / overlay | Correctif / couche de compatibilité |
| Evidence / findings | Preuves / constats |
| Handoff | Dossier de transfert |
| Color scheme | Palette de couleurs |
| AI | IA |

PMM, Palworld, Fix Lab, ChatGPT, Codex, MCP, paths, versions, format placeholders and code identifiers remain intact. AUTO/SemiAUTO remain recognizable mode labels. Safety/consent text, paid API opt-in, rollback failures and inactive untrusted-return warnings preserve the original behavior. UNPROVEN is displayed with the French clarification NON PROUVÉ. External application menu paths remain recognizable. No safety or runtime behavior was changed.

## User test and continuation

Pull this branch, launch PMM from that checkout, select `Français`, apply/save the language and restart PMM. Review main screens, Fix Lab, AI/help cases, installations, backups, dialogs and long messages for clipping and phrasing. Confirm that all language names stay native in the selector.

Previously tracked dynamic English counters, the old Library.UI selector assignment, Arabic mixed prose/path bidi scopes and virtualized technical cells remain separate runtime QA items. This catalog-only change neither fixes nor closes them.

Address French feedback by exact key rather than retranslating the file. Otherwise continue with **German (`de`)**, using the current English catalog and checking whether any German work already exists. Keep existing catalogs, runtime code, native binaries, main, tags, releases and workflows unchanged. Update both ledgers in the same authorized development checkpoint and use `[skip ci]`.
