# PMM v1.2 RC1 validation target

Build: `PMM-v1.2-RC1`

## Purpose

RC1 is the clean continuation baseline produced from the maintainer-tested v1.2 Alpha 3 tree.
It keeps the proven FIX4/Ribunny merge implementation and the native PMM Host + PMMRuntime
startup architecture unchanged except for release-candidate identity/packaging.

Normal startup is:

```text
Start.cmd
  -> PMM.exe (PMMH supervisor)
  -> Runner/routes.json
  -> PMMRuntime.exe start
```

PMMHost and PMMRuntime do not require PowerShell FullLanguage. On FullLanguage systems,
PMMRuntime currently opens the proven WPF/Core workspace. On ConstrainedLanguage systems,
it opens the native Win32 shell instead.

## Required validation before calling this final v1.2

1. `PMMRuntime.exe self-test` reports `PMMRUNTIME_SELFTEST_OK 1.2.0-rc1`.
2. `PMM.exe runtime-self-test` reaches Runtime through the native route.
3. `PMMRuntime.exe ui-native` opens the native shell.
4. `Start.cmd` opens the complete current PMM workspace on the maintainer's normal test PC.
5. Re-run the known Ribunny decision regression: `Luny` OR `Ribunny + Shine`.
6. Confirm Host session evidence records `CHILD START kind=native name=PMMRuntime.exe`.
7. Integrate and validate Fix Lab only after preserving the above baseline.

## Important release gate

RC1 is a **clean integration/release candidate baseline**, not yet a truthful final answer to the
reported ConstrainedLanguage user if that user needs Analyze/Build/Deploy. The native startup,
dependency layer and diagnostic shell are FullLanguage-independent, but the complete Mods & Merge
workspace still uses the legacy PowerShell/WPF/Core path on FullLanguage systems.

Before publishing v1.2 specifically as the FullLanguage fix, migrate the remaining end-user
Analyze/Build/Deploy/Saves workflow behind PMMRuntime (or prove each remaining script CLM-safe).
PMM must not weaken or bypass Windows application-control policy.

## GitHub validation for the v1.2 architecture

The v1.1 `SmokeTest.ps1` remains in the tree as historical/FIX4 regression tooling, but it is no
longer the GitHub Actions entrypoint because it asserts that dependency implementation details still
live inside `Setup-Dependencies.ps1`. In v1.2 that script is intentionally only a CLM-safe wrapper
around `PMMRuntime.exe`.

The repository/CI entrypoint is now `Validation/Validate-v1.2.ps1`. GitHub Actions additionally
compile-tests the Go Host/Runtime source, runs `PMMRuntime.exe self-test`, and verifies the native
`PMM.exe -> PMMRuntime.exe` route. The workflow runs on `main`, `release/**`, pull requests and manual
dispatches.
