# PMM Runtime (PMMRT) — v1.2 RC1

`PMMRuntime.exe` is the evolvable native capability/application layer for Palworld Manager Merger.

It exists so user-facing PMM functionality can work without relying on PowerShell FullLanguage. It does **not** change, disable or bypass Windows application-control policy.

RC1 owns the normal startup path after PMMH:

```text
PMM.exe -> PMMRuntime.exe start
```

`start` verifies dependencies natively and dispatches UI. On normal FullLanguage development/test machines PMMRT temporarily opens the proven WPF interface for regression compatibility. If FullLanguage is unavailable, PMMRT opens its native Win32 shell instead. `PMMRuntime.exe ui-native` forces that shell for testing.

## Native capabilities

- normal start dispatch;
- dependency verification/repair;
- SHA-256/SHA-512 hashing;
- safe ZIP extraction/creation;
- bounded process execution with stdout/stderr capture and timeout;
- portable .NET runtime / PMMCore / AssetReader verification;
- Palworld/Steam discovery;
- external Knowledge JSON validation;
- native Win32 UI shell;
- PowerShell language-mode diagnostics only (PMMRT does not require FullLanguage).

`Knowledge/*.json`, `UI/native-shell.json`, mappings and other mutable project data remain external.

## Source and build

All PMMRT source is in this folder and currently uses the Go standard library only.

On Windows with Go 1.23+:

```bat
Runtime\BUILD_RUNTIME.cmd
```

Public releases ship the already compiled `PMMRuntime.exe`; end users do not need Go.
