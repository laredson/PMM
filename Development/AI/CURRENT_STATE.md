# PMM — CURRENT STATE

**Read this file first when continuing development.**

## Stable baseline

- Product: **Palworld Manager Merger (PMM)**
- Creator: **laredson**
- Stable line prepared here: **v1.2.1**
- Application baseline: **Guided Flow**
- Fix Lab: **not included in this stable branch**
- Runtime status: the user confirmed the Guided Flow build works correctly in normal use.

Known QoL differences in this older stable baseline include a completion confirmation after merge and buttons that do not yet contain the later inline progress bars. Those are not treated as functional blockers for v1.2.1.

## Repository policy

`PMM/` is the distributable application. Everything else is repository/development material.

Do not ship `Development/`, `.github/`, `.git*`, tests, source trees or maintainer handoffs in the normal user ZIP.

## Next product line

Fix Lab is considered a sufficiently large feature to begin **PMM 1.3** rather than continuing to call it 1.2.1.

Recommended branch:

`dev/1.3-fixlab`

The 1.3 branch should start from this stable 1.2.1 baseline, then import the latest working Fix Lab line and continue with the agreed Workshop / Repair / Deploy Fix / AUTO-routing work.

## Native source caveat

The `Development/Source/` tree comes from the earlier **PMM v1.2.1 RESTRUCTURED_REPOSITORY** snapshot. The `PMM/` folder comes from the later **GUIDED_FLOW_TEST** build confirmed working by the user.

The Guided Flow `PMM.exe` and `PMM/Engine/PMMRuntime.exe` are newer than the native Host/Runtime source snapshot. Therefore:

1. Treat the binaries in `PMM/` as the release authority for v1.2.1.
2. Do not rebuild/replace those two binaries from `Development/Source/` until the corresponding native source changes are recovered or reconciled.
3. The editable PowerShell/WPF code under `PMM/Modules/` and `PMM/Resources/` is part of the working Guided Flow build and can be compared/modified normally.
4. A future source-reconciliation commit should remove this caveat once source and binaries correspond again.

## Repository path migration

The old restructured repository used root folders named `src/`, `scripts/`, `tests/` and `docs/`. They are now intentionally grouped under `Development/`:

- old `src/...` -> `Development/Source/...`
- old `scripts/...` -> `Development/Scripts/...`
- old `tests/...` -> `Development/Tests/...`
- old `docs/Development/...` -> `Development/AI/...`
- other old `docs/...` -> `Development/Docs/...`

The packaged 1.2.1 release manifest contains some informational `repository ...` strings from the pre-cleanup layout. They do not affect the portable application's runtime paths. The PMM folder itself has intentionally been kept byte-for-byte identical to the confirmed Guided Flow build.

## Git workflow

- `main`: only stable/releasable states.
- Develop Fix Lab on `dev/1.3-fixlab`.
- Commit small coherent changes.
- Validate before merging to `main`.
- Tag the exact public release (`v1.2.1`, later `v1.3.0`).
- Never commit `PMM/Workspace/`, user mods, Game Reference data, saves, logs, Gura assets or other third-party PAK/UCAS/UTOC files.
