# PMM v1.5.0.1 startup bugfix

Branch: v1.5.0.1-bugfix
Base: release/tag v1.5.0.1 at 2586b4c3999ccc094344bc65710d6559f4858871

## Scope

Independent hotfix for the unreproduced startup failure observed after splash/loading and before the main WPF UI. This branch does not merge or depend on v1.5.0.2 development.

## Change

Normal startup is now offline/read-only with respect to operational dependencies:

- PMMRuntime.exe start no longer calls dependency repair/download before UI dispatch.
- Runtime performs only a local, non-executing startup inspection and continues to UI in degraded mode.
- PowerShell dependency self-tests are deferred until ContentRendered.
- PowerShell startup checks no longer call Setup-Dependencies.ps1.
- Missing/invalid operational dependencies no longer trigger the old blocking pre-UI information popup.
- Explicit repair remains available through Settings > Prepare / repair dependencies.
- Additional startup stage markers identify failures before ShowDialog().

## Validation added

- Go regression: startup dependency inspection leaves invalid/missing files untouched and does not create Workspace state.
- PowerShell regression: normal Runtime start cannot call ensureDependencies; dependency repair is not invoked before ContentRendered; the explicit Settings repair entrypoint remains present.

## Release gate

Status after source patch: WINDOWS BUILD / REAL STARTUP ACCEPTANCE PENDING.

Do not publish the hotfix release until the rebuilt Runtime/package is exercised on Windows, including:

1. healthy package startup;
2. no-network startup;
3. missing/corrupt repak;
4. missing/corrupt mappings;
5. missing portable .NET runtime;
6. fresh Workspace;
7. second startup;
8. zh-CN UI startup;
9. explicit Settings dependency repair still succeeds.

The unreproduced historical incident remains cause-unknown unless new evidence identifies its exact trigger. This hotfix removes a concrete pre-UI failure class without claiming that it was the sole historical cause.
