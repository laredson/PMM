# PMM localization

PMM uses a catalog-driven localization layer. English is the canonical source; every visible UI string is inventoried and every language is a data file. Application code must not add language-specific branches.

## Runtime compatibility rule

The shipped PMM UI currently runs on **Windows PowerShell 5.1** on supported Windows installations. Localization runtime code under `PMM/` must therefore remain Windows PowerShell 5.1 compatible. Do not use PowerShell 7-only parameters or syntax in the shipped localization path (for example `ConvertFrom-Json -AsHashtable`). `Development/Localization/Test-PowerShell51.ps1` is the regression test for this contract and must pass before publishing a localized release.

## Native language-name rule

Language selectors always show each language in its own native form, independent of the active UI language. `languages.json.nativeName` is UI metadata and must never be translated by a language catalog. For example, the active selector currently displays `English`, `Español`, and `简体中文`. `Get-PMMLanguageOptions` marks these labels with `PMMLocalizeLabel = $false`; the generic visual-tree localizer respects that opt-out.

## Live language switching

Changing the language from Settings is applied to the running PMM window immediately; restarting PMM is not required. The selected locale is still persisted in `config.json`, so the next startup uses the same language.

The live path is deliberately explicit and does **not** use a global WPF `Loaded` hook. During the final normal localization sweep, `Register-PMMLiveLanguageSwitch` attaches one handler to the existing **Apply language** button. The normal Settings handler saves the new language first; the localization handler then:

1. retranslates the existing visual tree from its canonical English baseline,
2. applies the target LTR/RTL `FlowDirection`,
3. calls the normal `Refresh-UI` path so formatted/dynamic text is regenerated in the new language, and
4. performs a second safe sweep for controls/items materialized by that refresh.

`Invoke-PMMLocalizeVisualTree` keeps a weak per-object baseline for exact static strings and data-bound labels. This makes transitions reversible (`English -> Español -> 简体中文 -> English`) instead of trying to translate one translated string into another. If a dynamic formatted string cannot be mapped safely back to an English catalog key, the localizer leaves it alone and lets `Refresh-UI` regenerate it rather than guessing.

This works because the editable WPF/PowerShell UI and localization catalogs live outside the native host executable. `PMM.exe` supervises/launches the runtime, while the interface text and layout are supplied by the shipped XAML/PowerShell resources.

## Registry versus activation

`languages.json` is the complete language inventory for the translation branch, not just the list of finished translations. Every planned locale must have an entry there and a matching catalog file.

Each language entry has:

- `enabled`: whether the locale is exposed to the PMM runtime selector.
- `status`: `complete`, `in-progress`, `template`, or `reserve`.
- `nativeName`: the name shown in its own language.
- `direction`: `ltr` or `rtl`.
- `fallback`: normally `en` until the locale is complete.

Only entries with `enabled: true` are returned by `Get-PMMLanguageOptions` or accepted by normal runtime language resolution. This means the branch can visibly track every planned language without advertising unfinished translations to users.

## Files

- `languages.json`: complete locale inventory and activation state.
- `en.json`: canonical English keys/source text.
- `<BCP-47>.json`: one catalog per target language.
- `MainWindow.en.xaml`: canonical static WPF layout. A locale may provide `MainWindow.<code>.xaml`; otherwise PMM translates the English XAML from the catalog at runtime.
- `Modules/Shared/Localization.ps1`: generic lookup, fallback, activation filtering, XAML translation, reversible visual-tree translation and live language switching. It must remain Windows PowerShell 5.1 compatible.
- `Development/Localization/audit_localization.py`: discovers visible strings in XAML and PowerShell and fails when catalogs/wiring drift.
- `Development/Localization/Test-Localization.ps1`: validates key completeness, placeholders, residue and critical strings.
- `Development/Localization/Test-PowerShell51.ps1`: loads a real language catalog and localized WPF window under Windows PowerShell 5.1, including a reversible live-switch probe.
- `Development/Localization/TRANSLATION_PLAN.md`: ordered v1.5 backlog and intervention ledger.

## v1.5 staged language templates

The `v1.5.0.0-PMM-translated` branch stores all planned locales in both the registry and `PMM/Resources/Localization/`. Pending templates remain `enabled: false` until translation and validation are complete. Hindi and Modern Standard Arabic are currently `in-progress`; all other unfinished market targets are `template`, with lower-priority worldwide-language candidates kept as `reserve`.

When a language is completed, fill every canonical English key, preserve placeholders/invariant technical terms, run the localization and PowerShell 5.1 checks, visually review the UI, then set its registry entry to `enabled: true` and `status: complete`.

## Add any language

1. Create the catalog under `PMM/Resources/Localization/<code>.json` and add its inventory entry to `languages.json` immediately with `enabled: false`.
2. Translate all canonical English keys without changing those keys.
3. Set `direction` to `rtl` for Arabic/Hebrew-style layouts. `nativeName` must be the language's own name for itself.
4. Run `Development/Localization/Test-Localization.ps1 -Language <code>` and `python Development/Localization/audit_localization.py`.
5. On Windows, run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Development/Localization/Test-PowerShell51.ps1 -Language <code>` before release.
6. Visually review the major WPF workspaces. RTL locales require an additional navigation/order/alignment pass.
7. Only after those checks, change the registry entry to `enabled: true` / `status: complete`.
8. Update `Development/Localization/TRANSLATION_PLAN.md` and `Development/AI/WORKBENCH_STATE.md` in the same intervention.

Product names, file formats, paths, IDs, hashes and placeholders such as `{0}` are kept invariant unless grammar requires surrounding translation.
