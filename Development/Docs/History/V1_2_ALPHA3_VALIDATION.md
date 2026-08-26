# PMM v1.2 Alpha 3 validation target

Build: `PMM-v1.2-ALPHA3`

## Purpose

Alpha 3 removes PowerShell from the **normal startup chain**. `PMM.exe start` reads the external `Runner/routes.json` route table and starts `PMMRuntime.exe start` directly. PMMRuntime verifies dependencies and then chooses the UI path.

On a normal FullLanguage machine the proven PowerShell/WPF interface is still launched so the existing FIX4/Ribunny workflow can be regression-tested unchanged.

On a ConstrainedLanguage machine PMMRuntime no longer tries to start the WPF PowerShell UI. It opens the new native Win32 shell implemented by `Runtime/native_shell_windows.go` and configured by `UI/native-shell.json`. This proves PMM can reach a real UI without PowerShell FullLanguage.

## Required checks

1. `PMMRuntime.exe self-test` -> `PMMRUNTIME_SELFTEST_OK 0.3.0-alpha3`.
2. `PMM.exe runtime-self-test` reaches PMMRuntime through a native Host route.
3. `PMMRuntime.exe ui-native` opens the native shell even on a FullLanguage development machine.
4. `Start.cmd` on a normal machine still opens the current full PMM interface.
5. Ribunny package choice still behaves exactly as in FIX4/Alpha 1/Alpha 2.
6. Host session log for `start` should say `CHILD START kind=native name=PMMRuntime.exe`.
7. Native shell shows dependency, Knowledge, game-detection and PowerShell LanguageMode status.

## Scope boundary

Alpha 3 is **not** the completed CLM release. Analyze/Build/Deploy and the full management workspace are still implemented by the legacy PowerShell UI/Core on FullLanguage systems. The next migration stage moves those user operations behind PMMRuntime so the native shell can become the full interface.

No Windows policy is disabled, changed or bypassed.
