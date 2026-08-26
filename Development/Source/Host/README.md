# PMM Host (PMMH) — v1.2.1

`PMM.exe` is the small native supervisor and normal user entry point for Palworld Manager Merger.
It resolves routes from `PMM/Engine/Runner/routes.json`, launches Runtime/script operations, records session
evidence, and creates an emergency diagnostic handoff when supervised startup/runtime fails.

For 1.2.1 the Host is linked with the Windows GUI subsystem (`-H=windowsgui`). Console-subsystem
children are launched with `CREATE_NO_WINDOW`, so normal double-click startup does not allocate or
flash a CMD/PowerShell console. The PMM icon is embedded into the executable during `BUILD_HOST.cmd`.

The Host does not disable or bypass Windows application-control policy.
