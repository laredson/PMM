# PMM 1.3.4 validation — 2026-09-16

Branch: v1.3.4, based on 1.3.3 commit 8542d33. No main merge or latest release.

## Desktop

The obsolete OpenAI.ChatGPT-Desktop package and the current unified OpenAI.Codex package coexist. The old launcher ignored its destination and opened the obsolete package. Activation now targets the unique running compatible signed package by package family. A Windows Runtime activation of the existing AUAT conversation returned true; this proves protocol activation, not message delivery or account identity.

The installed route schema exposes chat, work and codex. New requests explicitly default to chat and draft. Mode discovery is metadata-only; unknown schemas fail closed. This is a compatibility adapter for the installed Desktop, not a promise of a permanent public protocol API. No inference was used for discovery or connection tests.

Automatic send and anonymous profiles remain unavailable. Chat is not advertised as unlimited or free; local tools and account limits depend on Desktop. PMM does not silently switch to Work. Old internal conversations remain accessible without starting another model turn. Per-project MCP configuration points to the selected PMM root and preserves conflicting user configuration. The request verifies installationRoot before claiming a case.

Validation:
- v134_desktop_regression.ps1 -ProbeInstalled: 14 assertions passed.
- v133_case_entry_regression.ps1: 33 assertions passed in each of English and Spanish under Windows PowerShell 5.1.
- WPF fixture rendered and visually inspected: destination/mode/draft controls and Folders panel visible.
- Includes setup dialog, repeated dispatch without duplicate chat, unsupported-send rejection and new-case defaults.
- Computer-use runtime failed to initialize; live desktop UI and game-world observations are not claimed.

## AUAT v1.1

Exact donor SHA256: b6af99dfd1d597b9a04458c884aacb5d09f8c3f30ca77f819d67d9a87e183f40.

The old mod uses the 1.0.3 Blueprint layout. Mapping104 decodes the current Blueprint completely; the old mapping cannot decode its CDO. The build transfers DefaultUnlockTechnology onto the current asset and preserves WazaSelectPowerOverrideMap plus all other current data. The 588 technology names must exactly match the current unlock table.

Recipe fixlab-auat-v1-to-v1-1-pw104 pins donor, both mappings and all four current family files. Wrong source, mappings, table contents or target identities are rejected. All exports must decode; lossless serialization, semantic preservation and PAK extraction/readback must pass.

v134_auat_regression.ps1: five end-to-end checks passed, including recognition, build, output registration, runtime-unproven distinction and wrong-donor rejection. Output SHA256: 0d743e39d67974705ad61bceb5cb351fd11eee410fc97823b69134454cfe47d8.

Only the AssetTools assembly was rebuilt; other native tools remain unchanged. The shipped recipe rebuilds from the user's local donor and current game. Game packages/extracted assets and user cases are excluded from the PMM release ZIP and Git.

Runtime functionality remains pending a supervised world test. Structural success is not proof of gameplay behavior, future game compatibility, or complete automatic repair acceptance.

## Package and installation

Public files are checksum-inventoried. Clean package validation runs SmokeTest, PS5.1 parsing, module catalog and all compressed member hashes, and rejects a shipped Workspace. Machine-local receipts are under Development/TestResults and are excluded from the public ZIP.

Installed public-file changes are backed up and compared against the previous inventory before update. Workspace mods, cases and preferences are preserved. AUAT deployment is restricted to the single authorized donor in ~mods; it must not deploy the active 49-mod PMM library.

Additional acceptance checks: clean-package SmokeTest PASS; 120 PS5.1 module parses, 48 catalog entries and 594 public file hashes verified. Installation update preserved 230 existing case/mod/state files. AUAT was rebuilt in the installed Fix Lab and applied through Deploy-PMMFixLabBuiltOutput; ~mods contains only its exact v1.1 hash, with original backups retained. The first launch reached a Steam empty-arguments confirmation reported by the user, so no world/gameplay acceptance is claimed.
The follow-up fix routes a verified Steam installation through steam://rungameid/1623730 without ArgumentList. Four mocked launch checks passed. A non-PowerShell-parent MCP regression reproduced missing Get-FileHash autoload; explicitly importing the system utility module fixed the handshake. Four isolated protocol checks passed, plus a direct read of the actual installed case. These checks start no AI requests.
