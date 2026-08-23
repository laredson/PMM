# PMM v1.2 Alpha 2 validation target

Build: `PMM-v1.2-ALPHA2`

This build is an incremental runtime migration, not the final 1.2 release.

## Must remain identical in behavior

- normal `Start.cmd` opens the existing PMM UI on the known-good Windows test machine;
- Nexus #4935 package-choice still offers **Luny OR Ribunny + Shine**;
- Analyze, second Analyze after package selection, Build and Deploy keep FIX4 behavior;
- PMM source mods remain independent and only the compatibility overlay is generated;
- Host supervision/session evidence remains operational.

## New native runtime gates

Run:

```text
PMMRuntime.exe self-test
PMMRuntime.exe security
PMMRuntime.exe dependencies status
PMMRuntime.exe knowledge validate
PMMRuntime.exe game detect
```

Expected self-test marker:

`PMMRUNTIME_SELFTEST_OK 0.2.0-alpha2`

`dependencies status` should report all bundled release dependencies ready on the clean package.

## CLM scope in Alpha 2

The following startup/native responsibilities no longer require PowerShell FullLanguage:

- dependency verification/repair;
- hashing;
- ZIP operations;
- bounded child-process execution;
- game discovery;
- Knowledge JSON validation.

The existing PowerShell/WPF UI and remaining Core orchestration are deliberately retained as the regression path in Alpha 2. A constrained machine should no longer fail in the old `Setup-Dependencies.ps1` generic-list code; it will reach PMMRT and clearly report that native UI/Core migration is not complete yet.

Do not publish Alpha 2 as the completed FullLanguage fix.
