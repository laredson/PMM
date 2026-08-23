# Palworld Manager Merger preview34 RC4 hotfix review

RC4 is a source-validation hotfix over RC3.

## Observed Windows failure

`SmokeTest.ps1` failed before the WPF application opened:

`analizando "\\(\\(if\b" - No hay suficientes ).`

The RC3 regression check used an over-escaped .NET regular expression:

```powershell
if($library -match '\\(\\(if\b'){ ... }
```

In .NET Regex, `\\` matches a literal backslash, leaving the following `(` as an unmatched group opener.

## RC4 fix

```powershell
if($library -match '\(\(\s*if\b'){ ... }
```

This correctly detects an ordinary-parentheses `((if...` construction while remaining valid .NET Regex.

## Frozen functionality

The following are byte-for-byte identical to RC3:

- `Tools/PMMCore/` (PMMCore 0.8.1 and all production adapters)
- `Mappings/`
- `Core/LibraryService.ps1`
- `Core/MergeEngine.ps1`
- `Core/PakService.ps1`
- `Core/SaveService.ps1`
- `Core/Common.ps1`

`Setup-Dependencies.ps1` changes only RC3 -> RC4 display text.

## Independent static verification

- corrected regex compiles in an independent regex parser;
- old over-escaped pattern is absent;
- all three XAML files parse as XML;
- all JSON files parse;
- SHA256SUMS contains 109 files and verifies 109/109;
- ZIP integrity test passes.

## Windows acceptance target

1. Start RC4 normally; SmokeTest must complete and the UI must open.
2. Fresh library, no Analyze and no compatibility patches: Import a PAK and immediately uncheck it.
3. The PAK must move to `Mods/_Disabled` without an `if is not recognized` error.
4. Re-check the mod and confirm it returns to active.
5. Select `No compatibility patch` and Deploy source mods only.
6. Optionally select an existing saved compatibility patch and Deploy it again.
