# Palworld Manager Merger v1.2 RC1

## Included

- Native `PMM.exe` supervisor/host with stdout/stderr/session evidence and emergency AI handoff creation.
- Native `PMMRuntime.exe` capability layer with dependency verification, process execution, hashing,
  archive handling, Palworld discovery, Knowledge validation and native Win32 fallback UI.
- PowerShell-free normal startup route: `PMM.exe -> Runner/routes.json -> PMMRuntime.exe start`.
- Complete open source for both executables and rebuild scripts.
- External editable Compatibility Knowledge Library (`Knowledge/*.json`).
- Proven v1.1.1 FIX4 merge baseline, including the Ribunny package choice:
  `Luny` OR `Ribunny + Shine`.
- Repak timeout, Smart Log, HeaderPath hardening and the existing schema-15 merge-plan behavior.

## Release gate still open

This RC is intentionally honest about the ConstrainedLanguage migration boundary. Startup,
dependency preparation, supervision and the native fallback UI no longer require FullLanguage,
but the complete existing Analyze/Build/Deploy/Saves workspace still runs through the proven
PowerShell/WPF/Core path on FullLanguage systems. Do not advertise RC1 as the complete CLM fix until
those remaining end-user operations are migrated behind PMMRuntime or independently proven CLM-safe.

Fix Lab is not included in this baseline; it is intended to be integrated from the separate Fix Lab
handoff after preserving this candidate's regression behavior.
