# PMM Runtime (PMMRT) — v1.2.1

`PMM/Engine/PMMRuntime.exe` owns native startup/dependency capabilities and is launched by PMMH for normal use.
It does not change, disable or bypass Windows application-control policy.

`start` verifies dependencies natively and dispatches UI. On FullLanguage machines PMMRT opens the
proven WPF interface for compatibility; if FullLanguage is unavailable it opens the native Win32 shell.
PowerShell and helper processes launched by Runtime use `CREATE_NO_WINDOW`, preventing console flashes
while keeping the real GUI visible.

The application icon is embedded in PMMRuntime.exe and used by the native Win32 fallback shell.
`PMMRuntime.exe ui-native` forces that shell for testing.
