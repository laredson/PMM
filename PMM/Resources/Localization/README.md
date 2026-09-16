# PMM localization

PMM uses a catalog-driven localization layer. English is the canonical source; every visible UI string is inventoried and every language is a data file. Application code must not add language-specific branches.

## Runtime compatibility rule

The shipped PMM UI currently runs on **Windows PowerShell 5.1** on supported Windows installations. Localization runtime code under `PMM/` must therefore remain Windows PowerShell 5.1 compatible. Do not use PowerShell 7-only parameters or syntax in the shipped localization path (for example `ConvertFrom-Json -AsHashtable`). `Development/Localization/Test-PowerShell51.ps1` is the regression test for this contract and must pass before publishing a localized release.

## Files

- `languages.json`: registry (`code`, native/English names, fallback, `ltr`/`rtl`, optional XAML file).
- `en.json`: canonical English keys/source text.
- `<BCP-47>.json`: one catalog per language, using the same English keys.
- `MainWindow.en.xaml`: canonical static WPF layout. A locale may provide `MainWindow.<code>.xaml`; otherwise PMM translates the English XAML from the catalog at runtime.
- `Modules/Shared/Localization.ps1`: generic lookup, fallback, XAML translation and visual-tree translation. It must remain Windows PowerShell 5.1 compatible.
- `Development/Localization/audit_localization.py`: discovers visible strings in XAML and PowerShell and fails when catalogs/wiring drift.
- `Development/Localization/Test-Localization.ps1`: validates key completeness, placeholders, residue and critical strings.
- `Development/Localization/Test-PowerShell51.ps1`: loads a real language catalog and localized WPF window under Windows PowerShell 5.1 and rejects known PowerShell 7-only runtime usage.

## Add any language

1. Run `Development/Localization/New-Language.ps1 -Code de -NativeName Deutsch -EnglishName German` (use any BCP-47 code such as `ja`, `pt-BR`, `ar`, `zh-TW`).
2. Translate every empty value in `PMM/Resources/Localization/<code>.json`; never change the English keys.
3. Add/register the language in `languages.json` (the scaffold prints the exact entry). Set `direction` to `rtl` for Arabic/Hebrew-style layouts.
4. Run `Development/Localization/Test-Localization.ps1 -Language <code>` and `python Development/Localization/audit_localization.py`.
5. On Windows, also run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Development/Localization/Test-PowerShell51.ps1 -Language <code>` before release.
6. If a new UI label is added in PowerShell, use `L 'English' 'Spanish'` or `Get-PMMLocalizedText 'English'`. Embedded/static XAML may remain canonical English: the runtime/catalog layer translates it. Dynamically created workspaces must call `Invoke-PMMLocalizeVisualTree` after their controls are created; new strings still must be present in the catalog and audit.

Product names, file formats, paths, IDs, hashes and placeholders such as `{0}` are kept invariant unless grammar requires surrounding translation. The audit treats a small documented set of those values as intentionally language-neutral.
