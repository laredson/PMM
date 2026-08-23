# PMM 1.2 Runtime migration

## Objective

The final PMM 1.2 end-user path must not require PowerShell `FullLanguage`.
PMM does not change Windows application-control policy; functionality that needs
restricted .NET/native capabilities moves into `PMMRuntime.exe` instead.

## Layer boundary

- `PMM.exe` / PMMH: small stable supervisor, process evidence, emergency handoff.
- `PMMRuntime.exe` / PMMRT: evolvable native functionality; complete source in `Runtime/`.
- PowerShell: editable orchestration/extensions only where confirmed compatible with CLM or where used solely by maintainers.
- `Knowledge/*.json`: external PMMCKL source of truth, validated before use.
- future PMMFLKL: external source of truth for Fix Lab knowledge.
- UI/config/localization: external where practical; compiled code may own the native event/runtime layer.

## Alpha 2 migrated capabilities

- dependency verification and bounded repair;
- portable .NET runtime inventory verification;
- PMMCore/AssetReader runtime probes;
- hashing;
- safe ZIP extraction/creation;
- bounded native child-process execution with captured stdout/stderr;
- Palworld/Steam discovery;
- Knowledge JSON validation.

The public `Setup-Dependencies.ps1` is now a small PMMRT wrapper and contains no
`Add-Type`, `New-Object`, `[pscustomobject]`, generic collection construction, or WPF calls.

## Remaining final-1.2 migration surface

The current WPF UI and Core orchestration are kept unchanged as the regression oracle
as the regression oracle. They still contain FullLanguage-dependent constructs and must move to PMMRT
(or be rewritten as explicitly CLM-safe orchestration) before 1.2 final.

This separation is deliberate: first prove that introducing PMMRT does not alter FIX4
behavior; then migrate UI/Core feature groups behind the same runtime contract.
