# Palworld Manager Merger (PMM)

**Current stable repository baseline: PMM 1.2.1 Guided Flow (without Fix Lab).**

PMM is a Palworld mod manager and compatibility merger. The application preserves source mods and, when necessary, builds a compatibility overlay instead of blindly combining every mod into a single MegaMerge.

## Repository layout

The repository root is intentionally small:

- `PMM/` — the complete portable application. This is the only folder packaged for normal users.
- `Development/` — source, tests, build/validation tools, engineering documentation and AI handoff material.
- `.github/` — GitHub Actions, issue/PR templates and community/security files.
- `.gitignore` / `.gitattributes` — repository behavior.
- `LICENSE` — project license.

### Development layout

- `Development/Source/` — Host, Runtime, PMMCore, AssetReader and icon-helper source inherited from the 1.2.1 restructured repository baseline.
- `Development/Scripts/` — build, CKL and validation tooling.
- `Development/Tests/` — repository smoke tests.
- `Development/Docs/` — architecture, protocol, validation, history and publishing documentation.
- `Development/AI/` — continuation handoffs for developers and AI agents.

For development or AI continuation, read **`Development/AI/CURRENT_STATE.md` first**, then `Development/AI/AI_CONTINUE_HERE.md`.

## Start PMM

Download the release ZIP, extract it, and run:

`PMM.exe`

The release ZIP is built from the **contents of `PMM/` only**. `Development/`, `.github/`, Git metadata and repository documentation are not part of the user package.

## Branch model

- `main` — stable/releasable code only.
- `dev/<version-or-feature>` — active development.
- `release/<version>` — optional release-candidate stabilization.
- tags such as `v1.2.1` — exact public releases.

The next feature line is intended to be **PMM 1.3 / Fix Lab** and should be developed on a separate branch from this stable 1.2.1 baseline.

## Important source note

`PMM/` in this repository is the user-confirmed working **Guided Flow** application and is the authority for the 1.2.1 release baseline. The native source snapshot originally came from the earlier 1.2.1 restructured repository package. The Guided Flow native `PMM.exe` / `PMMRuntime.exe` binaries are newer than that source snapshot, so do **not** rebuild and overwrite those two binaries from `Development/Source/` until the native source is reconciled. PowerShell/WPF application logic inside `PMM/Modules/` remains directly editable.

Created by **laredson**.
