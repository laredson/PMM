# PMM localization

PMM uses a catalog-driven localization layer. English is the canonical source; every visible UI string is inventoried and every language is a data file. Application code must not add language-specific branches.

## Runtime compatibility rule

The shipped PMM UI currently runs on **Windows PowerShell 5.1** on supported Windows installations. Localization runtime code under `PMM/` must therefore remain Windows PowerShell 5.1 compatible. Do not use PowerShell 7-only parameters or syntax in the shipped localization path (for example `ConvertFrom-Json -AsHashtable`). `Development/Localization/Test-PowerShell51.ps1` is the regression test for this contract and must pass before publishing a localized release.

## Native language-name rule

Language selectors always show each language in its own native form, independent of the active UI language. `languages.json.nativeName` is UI metadata and must never be translated by a language catalog. For example, the current selector must always display `English`, `Español`, and `简体中文`. `Get-PMMLanguageOptions` marks these labels with `PMMLocalizeLabel = $false`; the generic visual-tree localizer respects that opt-out. Future language selectors must consume `Get-PMMLanguageOptions` rather than constructing translated language names manually.

## Files

- `languages.json`: active language registry (`code`, native/English names, fallback, `ltr`/`rtl`, optional XAML file).
- `en.json`: canonical English keys/source text.
- `<BCP-47>.json`: one catalog per language, using the same English keys when translation is complete.
- `MainWindow.en.xaml`: canonical static WPF layout. A locale may provide `MainWindow.<code>.xaml`; otherwise PMM translates the English XAML from the catalog at runtime.
- `Modules/Shared/Localization.ps1`: generic lookup, fallback, XAML translation and visual-tree translation. It must remain Windows PowerShell 5.1 compatible.
- `Development/Localization/audit_localization.py`: discovers visible strings in XAML and PowerShell and fails when catalogs/wiring drift.
- `Development/Localization/Test-Localization.ps1`: validates key completeness, placeholders, residue and critical strings.
- `Development/Localization/Test-PowerShell51.ps1`: loads a real language catalog and localized WPF window under Windows PowerShell 5.1, rejects known PowerShell 7-only runtime usage, and verifies that native language names survive localization unchanged.
- `Development/Localization/TRANSLATION_PLAN.md`: ordered v1.5 language backlog and close work ledger.

## v1.5 staged language templates

The `v1.5.0.0-PMM-translated` branch stages future language catalogs before translating them. A staged template is a valid `PMM_LANGUAGE_V1` JSON file with its target language metadata, `fallback: en`, `templateStatus: pending`, `templateSource: en.json`, and an intentionally empty `strings` object.

Pending templates are **not** registered in `languages.json`. This is deliberate: only completed languages should appear in the PMM language selector. When a template is translated, expand it against the current canonical English key set, complete the translation, validate it, and only then register it in `languages.json`.

The current ordered backlog and status of every target language are maintained in `Development/Localization/TRANSLATION_PLAN.md`.

## Add any language

1. For a new language that does not already have a staged template, run `Development/Localization/New-Language.ps1 -Code de -NativeName Deutsch -EnglishName German` (use any BCP-47 code such as `ja`, `pt-BR`, `ar`, `zh-TW`).
2. Translate every empty value in `PMM/Resources/Localization/<code>.json`; never change the English keys. For a staged v1.5 template, first populate it from the current `en.json` key set.
3. Add/register the language in `languages.json` only after its translation is complete enough for user exposure (the scaffold prints the exact entry). Set `direction` to `rtl` for Arabic/Hebrew-style layouts. `nativeName` must be the language's own name for itself, for example `Deutsch`, `Français`, `日本語`, `한국어`, `Português`, or `العربية`.
4. Run `Development/Localization/Test-Localization.ps1 -Language <code>` and `python Development/Localization/audit_localization.py`.
5. On Windows, also run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Development/Localization/Test-PowerShell51.ps1 -Language <code>` before release.
6. If a new UI label is added in PowerShell, use `L 'English' 'Spanish'` or `Get-PMMLocalizedText 'English'`. Embedded/static XAML may remain canonical English: the runtime/catalog layer translates it. Dynamically created workspaces must call `Invoke-PMMLocalizeVisualTree` after their controls are created; new strings still must be present in the catalog and audit.
7. If a data-bound label is semantic metadata that must remain invariant instead of being localized, set `PMMLocalizeLabel = $false`. Use this sparingly; normal user-facing labels should remain localizable.

Product names, file formats, paths, IDs, hashes and placeholders such as `{0}` are kept invariant unless grammar requires surrounding translation. The audit treats a small documented set of those values as intentionally language-neutral.
