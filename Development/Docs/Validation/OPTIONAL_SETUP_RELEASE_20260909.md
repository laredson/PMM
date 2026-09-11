# Optional setup branch and private recovery — 2026-09-09

## Deliverables

- Branch: codex/optional-modding-setup, based on the existing working tree at f7d826e. Existing optional adapter, MCP, workspace and installer work is preserved with its tests. Main is not a publication target.
- Private personal archive: PMM-setup-backup, Release setup-2026-09-09.
- Archive: PMM-offline-2021.1.11.zip, 1,171,774,003 bytes, 24 original downloaded package files plus the inventory.
- Archive SHA-256: 9302c31a2cf9a46bea99c0aab3b2254c77423060e1316ed7711950c94d4536b8.
- Original package bytes: 1,171,762,255. Original vendor metadata is retained; its old download locations are not imported into PMM settings.
- Public package: PMM-1.3.1-MCP-0.5.0-BASE-20260909-133040.zip, 52,158,019 bytes, 520 members, SHA-256 ffdcec0990e8e9256d70f0dfc1769417adffdd73c9eddb8bb4bc074747fbde3e.
- Spanish and English tutorials are included in the public package and accessible through the shared themed dialog in Mod Creation → Tools.

## Validation performed

- Created the private repository and checked its privacy before uploading each asset. GitHub stored ZIP, SHA-256 sidecar and JSON inventory.
- Downloaded all three assets through authenticated GitHub access into an isolated directory. Their hashes match the uploaded originals.
- Ran Restore-OfflineBackup.ps1 against that downloaded ZIP: verified every entry before copying, restored all 24 files and reran restoration with zero copied files and 24 reused files.
- PMM recognized the restored Audiokinetic offline launcher with a valid Audiokinetic signature and the restored Unreal.5.0.tar.xz location. No installer was executed.
- Read the actual installed environment: UE 5.1.1 compatible, no missing prerequisites, pinned kit ZIP hash valid. The adapter remains disabled; editor/project verification is separate.
- offline_restore_regression.py: verify-only creates no destination, correct restoration, repeat reuse, archive/file hash failures, conflicting destination preservation, traversal, case collisions, invalid schema and extra ZIP entry rejection.
- setup_tutorial_ui_regression.ps1: real WPF dialog rendering, language selection, complete content, scrolling and close in both languages; screenshot reviewed.
- Existing wwise_offline_regression.ps1, dependency_locations_regression.ps1 and workspaces_dependencies_regression.ps1 passed (both UI languages for workspace checks).
- PowerShell module parsing passed. Native manifest encoding test passed: UTF-8 without BOM, BOM fixture rejected, SHA-256 matches.
- Public tree audit found no private/runtime/game payloads or credential-like tokens. All 519 packaged checksum entries are tracked and valid. Existing local research notes and Workspace were not staged.
- Public package validation verified all 520 ZIP members and the native dependency runtime. Workspace and optional vendor payloads are excluded.
- Actual PMM startup succeeded; the window responds, the existing color theme loads, and the runtime reports local dependency verification without network setup.

## Limits

This proves backup download, integrity, restoration and PMM discovery, not a fresh Wwise installation on another machine. Original installers may still require their official interactive steps. No public redistribution permission for the complete Wwise SDK is asserted.

UE project compilation, cooking, candidate behavior and the extra-100-inventory-slots mod remain NOT_VERIFIED. The optional tools are not required for every mod.
