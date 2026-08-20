# Palworld Manager Merger preview34 RC4 validation target

RC4 fixes only the RC3 SmokeTest regex regression. The actual RC3 enable/disable hotfix remains unchanged.

## Root cause

RC3 added this source check:

```powershell
if($library -match '\\(\\(if\b'){ ... }
```

The pattern is over-escaped for .NET Regex. It matches a literal backslash and then opens an unmatched group, causing `No hay suficientes )` before the UI starts.

RC4 uses:

```powershell
if($library -match '\(\(\s*if\b'){ ... }
```

## Acceptance

- Start.cmd reaches the UI with SmokeTest passing.
- Fresh install / no Analyze / no patches: Import a source PAK and uncheck it.
- The PAK moves to `Mods/_Disabled` with no `if is not recognized` error.
- Re-enable the same PAK.
- `No compatibility patch` can Deploy source mods only without Analyze.
- Existing saved-patch selection remains functional.

No merge-engine runtime retest is required beyond a short startup smoke test because PMMCore and production adapters are unchanged.
