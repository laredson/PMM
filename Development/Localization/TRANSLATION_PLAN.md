# PMM v1.5.0.0 translation plan

Branch: `v1.5.0.0-PMM-translated`
Base: validated `main` commit `70d106e871099e4936dc5f81eef3e4ea15529d93`

This file is the close translation-work ledger for PMM 1.5. Update it whenever a language template is started, completed, validated, activated, or otherwise changed.

## Policy

- English (`en`) is the canonical source catalog.
- Spanish (`es`) and Simplified Chinese (`zh-CN`) are already translated and active.
- New language files are staged first as independent templates with `fallback: en`, `templateStatus: pending`, `templateSource: en.json`, and an empty `strings` object.
- Pending templates are deliberately **not** added to `languages.json`; this prevents the PMM language selector from advertising an untranslated language that would only fall back to English.
- When a language is translated, populate its catalog from the canonical English keys, preserve placeholders and invariant technical terms, remove/replace the template marker as appropriate, register it in `languages.json`, then run the localization, PowerShell 5.1, and WPF checks before marking it complete.
- `rtl` languages must be registered with right-to-left direction when activated.
- Language names in selectors always remain in their own native form.

## Target order

The project fixes English, Spanish, and Simplified Chinese as positions 1–3. The remaining order follows a total-speaker-oriented world ranking for the largest languages; exact rankings vary slightly by source/year and by whether closely related varieties are counted separately.

| Order | Code | Native name | English name / target | Direction | State |
|---:|---|---|---|---|---|
| 1 | `en` | English | English | ltr | complete + active |
| 2 | `es` | Español | Spanish | ltr | complete + active |
| 3 | `zh-CN` | 简体中文 | Chinese (Simplified / Mandarin UI) | ltr | complete + active |
| 4 | `hi` | हिन्दी | Hindi | ltr | template pending |
| 5 | `ar` | العربية | Modern Standard Arabic | rtl | template pending |
| 6 | `fr` | Français | French | ltr | template pending |
| 7 | `bn` | বাংলা | Bengali | ltr | template pending |
| 8 | `pt-BR` | Português (Brasil) | Portuguese (Brazil) | ltr | template pending |
| 9 | `id` | Bahasa Indonesia | Indonesian | ltr | template pending |
| 10 | `ur` | اردو | Urdu | rtl | template pending |
| 11 | `ru` | Русский | Russian | ltr | template pending |
| 12 | `de` | Deutsch | German | ltr | template pending |
| 13 | `ja` | 日本語 | Japanese | ltr | template pending |
| 14 | `pcm` | Naijá | Nigerian Pidgin | ltr | template pending |
| 15 | `arz` | العربية المصرية | Egyptian Arabic | rtl | template pending |
| 16 | `mr` | मराठी | Marathi | ltr | template pending |
| 17 | `vi` | Tiếng Việt | Vietnamese | ltr | template pending |
| 18 | `te` | తెలుగు | Telugu | ltr | template pending |
| 19 | `ha` | Hausa | Hausa | ltr | template pending |
| 20 | `tr` | Türkçe | Turkish | ltr | template pending |

## Per-language completion checklist

1. Expand the template against the current `en.json` key set.
2. Translate all user-facing values; never alter canonical English keys.
3. Preserve placeholders such as `{0}` and technical identifiers that are intentionally invariant.
4. Register the completed language in `languages.json` in the order above.
5. Set `direction` correctly (`rtl` for `ar`, `ur`, and `arz`; `ltr` for the other targets in this plan).
6. Run `Development/Localization/Test-Localization.ps1 -Language <code>`.
7. Run `python Development/Localization/audit_localization.py`.
8. Run the Windows PowerShell 5.1 localization regression before release.
9. Visually inspect the principal WPF screens for truncation, dynamic English residue, and layout problems.
10. Update this ledger with completion/validation notes and the relevant commit.

## Work log

### 2026-09-16 — v1.5 translation scaffolding

- Created branch `v1.5.0.0-PMM-translated` from the validated v1.3.4.1-era `main` state.
- Preserved the completed `en`, `es`, and `zh-CN` catalogs unchanged.
- Added 17 independent pending catalog templates for positions 4–20.
- Kept pending templates out of the runtime language registry until each one is actually translated and validated.
- No release, tag, CI workflow, or product binary was created or changed in this step.
