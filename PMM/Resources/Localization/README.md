# PMM localization

PMM uses a catalog-driven localization layer. English is the canonical source; every visible UI string is inventoried and every language is a data file. Application code must not add language-specific branches.

## Files

- `languages.json`: registry (`code`, native/English names, fallback, `ltr`/`rtl`, optional XAML file).
- `en.json`: canonical English keys/source text.
- `<BCP-47>.json`: one catalog per language, using the same English keys.
- `MainWindow.en.xaml`: canonical static WPF layout. A locale may provide `MainWindow.<code>.xaml`; otherwise PMM translates the English XAML from the catalog at runtime.
- `Modules/Shared/Localization.ps1`: generic lookup, fallback, XAML translation, visual-tree translation and live translation for dynamically created controls.
- `Development/Localization/audit_localization.py`: discovers visible strings in XAML and PowerShell and fails when catalogs/wiring drift.
- `Development/Localization/Test-Localization.ps1`: validates key completeness, placeholders, residue and critical strings.

## Add any language

1. Run `Development/Localization/New-Language.ps1 -Code de -NativeName Deutsch -EnglishName German` (use any BCP-47 code such as `ja`, `pt-BR`, `ar`, `zh-TW`).
2. Translate every empty value in `PMM/Resources/Localization/<code>.json`; never change the English keys.
3. Add/register the language in `languages.json` (the scaffold prints the exact entry). Set `direction` to `rtl` for Arabic/Hebrew-style layouts.
4. Run `Development/Localization/Test-Localization.ps1 -Language <code>` and `python Development/Localization/audit_localization.py`.
5. If a new UI label is added in PowerShell, use `L 'English' 'Spanish'` or `Get-PMMLocalizedText 'English'`. Embedded/static XAML may remain canonical English: the runtime/catalog layer translates it. Controls created dynamically are covered by `Register-PMMLiveLocalization`, but new strings still must be present in the catalog and audit.

Product names, file formats, paths, IDs, hashes and placeholders such as `{0}` are kept invariant unless grammar requires surrounding translation. The audit treats a small documented set of those values as intentionally language-neutral.
