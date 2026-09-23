# PMM v1.5.0.1 bugfix runtime shim

This directory contains the temporary Windows acceptance launcher used by the `v1.5.0.1-bugfix` branch.

## Purpose

The published v1.5.0.1 Runtime executes `ensureDependencies(...)` from its `start` route before dispatching the WPF UI. That path can repair, delete or download operational dependencies before the main window exists. The historical startup incident is not reproducible, so this branch does not claim that behavior was the sole root cause; it removes that concrete pre-UI failure class for testing.

The shim keeps the exact published v1.5.0.1 Runtime as:

`PMM/Engine/PMMRuntimeLegacy.exe`

and replaces the branch-only test `PMM/Engine/PMMRuntime.exe` with a small native launcher.

Behavior:

- `PMMRuntime.exe start` -> `PMMRuntimeLegacy.exe ui`
- every other Runtime command -> delegated unchanged
- child stdout/stderr handles are inherited
- the child is created with `CREATE_NO_WINDOW`
- the branch PowerShell bootstrap contains the companion hotfix that defers dependency checks until after `ContentRendered` and disables automatic startup repair

This allows the exact original Runtime binary to remain available while bypassing only its old pre-UI `start` dependency-repair route.

## Identity

- Test shim SHA-256: `d3101f0050d99a37b2f4424fe2e7ce26e7e0ba0f4bb44116096216605bbba907`
- Original v1.5.0.1 Runtime Git blob: `aa170ae00aad1509a1e45d60a410a946da7119e0`
- Source hotfix parent commit: `8f0aab5c9f98ab0f345df19b04d7a03484d3fcdf`

## Release gate

This shim is for Windows acceptance of the startup fix. It is not the intended final public Runtime architecture.

After real Windows startup acceptance, replace the shim + legacy pair with the fully rebuilt Runtime from `Development/Source/Runtime`, update release metadata/checksums, and only then create the bugfix release.

No GitHub Actions or CI are required for this development branch.
