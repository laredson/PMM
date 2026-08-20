# Palworld Manager Merger preview34 RC3 engineering review

## Scope

RC3 is a surgical hotfix over RC2 for one Windows PowerShell 5.1 runtime regression in the source-mod checkbox workflow.

Observed acceptance failure in RC2:

- fresh PMM installation;
- Import source PAK(s);
- before Analyze and before any merge exists, uncheck a source mod;
- UI reported: `if is not recognized as the name of a cmdlet...`.

## Root cause

`Core/LibraryService.ps1` logged the enable/disable action with an `if` statement wrapped in ordinary parentheses:

```powershell
Write-PMMLog ((if($Enabled){'Enabled'}else{'Disabled/backed up'})+" source mod: $Name")
```

Windows PowerShell 5.1 can evaluate that form as a command invocation in this context. The failure happens after the checkbox calls the library toggle path and is unrelated to Analyze, PMMCore or compatibility-patch state.

## Fix

RC3 computes the label first with a normal PowerShell conditional statement:

```powershell
$actionLabel=if($Enabled){'Enabled'}else{'Disabled/backed up'}
Write-PMMLog ("$actionLabel source mod: $Name")
```

The smoke test now rejects the exact problematic `((if` form in LibraryService and requires the new action-label pattern.

## Frozen runtime-proven components

Compared with RC2, the following remain byte-for-byte identical:

- `Tools/PMMCore` (PMMCore 0.8.1 and every merge adapter)
- `Mappings/Mappings.usmap`
- `Core/SaveService.ps1`
- `Core/PakService.ps1`
- `Tools/AssetReader`

`Start-PalModMerger.ps1` is functionally identical apart from RC2 -> RC3 branding text.

## Static QA

32 checks passed, 0 failed. See `Docs/PREVIEW34_RC3_STATIC_QA.txt` in the package.

## Required Windows acceptance test

1. Start from a fresh RC3 folder.
2. Import a PAK.
3. Immediately uncheck it, without Analyze and without any saved merge.
4. It must move to `Mods/_Disabled` with no error.
5. Re-check it; it must return to the active library.
6. Select `No compatibility patch` and Deploy; source-mod-only synchronization should work.

A full gameplay merge regression is not required for this hotfix because the merge core/adapters are unchanged.
