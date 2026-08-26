# PMM v1.2.1 validation target

Build: `PMM-v1.2.1`

## Purpose

v1.2.1 is the stable release of the QA2-tested 1.2 branch. It preserves the proven merge behavior,
AIIO disk-safety redesign, and native PMM Host + PMMRuntime startup architecture while adding the
final desktop-application polish: direct `PMM.exe` startup, no transient console window, and the PMM
application icon in Explorer/taskbar/Alt-Tab/WPF/native shell.

Normal startup is:

```text
PMM.exe
  -> Runner/routes.json
  -> PMMRuntime.exe start
  -> WPF workspace on FullLanguage systems
     OR native Runtime shell on ConstrainedLanguage systems
```

`Start.cmd` remains only as a compatibility launcher for old shortcuts/instructions.

## Required validation

1. Double-click `PMM.exe`: no CMD/PowerShell console should appear before or behind the UI.
2. The PMM icon should appear on `PMM.exe`, the WPF title bar, Alt-Tab and the taskbar.
3. `PMMRuntime.exe self-test` reports `PMMRUNTIME_SELFTEST_OK 1.2.1`.
4. `PMM.exe runtime-self-test` reaches Runtime through the native route.
5. `PMMRuntime.exe ui-native` opens the native shell and shows the PMM icon.
6. `RUN_VALIDATION.cmd` reports `PMM_V12_VALIDATION_OK`, `BUILD_ID=PMM-v1.2.1` and `VERSION=v1.2.1`.
7. Re-run the known Ribunny decision regression: `Luny` OR `Ribunny + Shine`.
8. Run the maintainer-tested Analyze -> Build -> Deploy path on the Gura pair or another known shared-asset set.
9. For a mod set with Unsupported assets, Analyze must not create any AI handoff ZIP. AIIO must create
   one explicit combined bundle only when requested, with no whole source `.pak` files.
10. Confirm Analyze/AIIO transient staging is reclaimed after success, cancellation and recoverable failure.

## Console/window contract

`PMM.exe` is linked with the Windows GUI subsystem. PMM Host and Runtime launch console-subsystem
children with `CREATE_NO_WINDOW`; this suppresses transient CMD/PowerShell windows without hiding the
actual WPF/native GUI. Diagnostic `.cmd` scripts (`RUN_VALIDATION.cmd`, `SETUP_ONCE.cmd`) intentionally
remain console tools.

## Application icon contract

`UI/PMM.ico` is a multi-resolution 16-256 px icon generated from the selected PMM artwork. The build
scripts compile fresh Go binaries and then run the dependency-free `Tools/PEIcon/inject.go` helper to
embed RT_ICON/RT_GROUP_ICON resources into both `PMM.exe` and `PMMRuntime.exe`. The WPF workspace loads
the same ICO explicitly so the PowerShell-hosted window does not inherit the PowerShell icon.

## PowerShell language-mode boundary

PMM Host and PMMRuntime startup/dependency/diagnostic capabilities do not require FullLanguage and do
not weaken or bypass Windows application-control policy. The complete existing Mods & Merge WPF/Core
workspace remains the proven PowerShell path on FullLanguage systems; ConstrainedLanguage systems use
the native Runtime shell.
