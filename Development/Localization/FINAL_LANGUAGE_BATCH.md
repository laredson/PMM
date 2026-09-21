# PMM final-language batch — Romanian, Thai and Indonesian

Branch: `v1.5.0.0-PMM-translated`  
Base before publication: `32cd1fc815cedddc8f114badcdd86a5e47d2c633`  
Batch date: 2026-09-19 (El Salvador)

## Published catalogs

| Locale | Native name | Entries | Parameterized | Catalog Git blob | Runtime/native QA |
|---|---|---:|---:|---|---|
| ro | Română | 1,291 | 109 | `d63dfdd217e76c9cf56cd98432857640679d84c7` | pending |
| th | ไทย | 1,291 | 109 | `ede5b79c33cf6ec033fcf3c92173fca15a12e3c4` | pending |
| id | Bahasa Indonesia | 1,291 | 109 | `ac4f3b9ab0282074aa7e1cd44d1d909f6da1db42` | pending |

Romanian is preserved byte-for-byte from the recovered catalog. Thai and Indonesian are the jointly prepared catalogs from the same batch. All three were authored against canonical English blob `2fa3c4712619cc5f811ce2251cef3daf5b0e2024`.

Structural validation passed all three catalogs together: exact 1,291-key coverage and ordering, nonempty values, placeholders/formats, braces, numbers, significant whitespace, PowerShell escapes, protected identifiers, extensions/file-dialog masks, units, Unicode/NFC, native labels, and reviewed invariant allowlists. Total: **3,873 entries, 327 parameterized entries, zero final structural errors**.

The registry now contains **30 registered locales and 19 enabled**. Romanian is inserted after Português (Brasil) and before Deutsch. Thai and Indonesian retain their existing Asian-group positions. English remains first/default and native language labels remain native.

This does not constitute PMM/WPF runtime testing, Windows PowerShell 5.1 testing, or native-speaker acceptance. Existing runtime-generated English counters, the old Library.UI selector path, Arabic mixed-direction text, and virtualized technical cells remain separate tracked issues.

Remaining approved translations: `vi -> uk -> cs -> ga` (Tiếng Việt -> Українська -> Čeština -> Gaeilge).
