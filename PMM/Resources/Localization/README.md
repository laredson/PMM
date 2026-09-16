# PMM localization

PMM uses one canonical English source string catalog and one JSON catalog per language. Runtime code never needs a new `if language == ...` branch.

## Add a language

1. Copy `en.json` to `<language-code>.json` (BCP-47 code such as `de`, `ja`, `pt-BR`, `ar`).
2. Set `language`, `nativeName`, `fallback`, and translate every value under `strings` while keeping the English keys unchanged.
3. Add one entry to `languages.json`. `direction` may be `ltr` or `rtl`.
4. Run `Development/Localization/Test-Localization.ps1`. Missing keys, broken placeholders and untranslated catalog values fail validation.

The English key is the stable source identifier for v1.3.4.1. `Get-PMMLocalizedText` is the generic lookup API; the existing `L English Spanish` helper remains compatible and routes every non-English/non-Spanish language through its catalog. Static XAML may have a dedicated file, but a new language can fall back to the English XAML and be localized from its catalog. Dynamically created WPF controls should use `L`/`Get-PMMLocalizedText`, or call `Invoke-PMMLocalizeVisualTree` after construction.

Do not translate product names, file formats, paths, IDs, hashes, or placeholders such as `{0}` unless the surrounding sentence requires it.
