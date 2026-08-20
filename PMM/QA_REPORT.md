# PMM v1.1 CLEAN RC1 — QA status

Build: `PMM-v1.1-CLEAN-RC1`

This is a release candidate, not yet the final public ZIP.

## Source lineage

Baseline: the user-proven v1.1 working tree (`Palworld-Manager-Merger-v1.1(3)` / working-base snapshot).

Selectively ported:
- effective-order saved-patch reuse from PatchReuse RC1;
- background Game Reference worker/progress from Background RC3;
- StrictMode-safe bundled runtime verification initialization;
- portable .NET 8.0.30 payload and bounded repair-download timeouts from RC7;
- new background Analyze/Build worker using the same child-process + atomic-JSON progress pattern.

Explicitly excluded:
- Developer Console;
- Mod Edit;
- MegaMerge.

## Package contracts

- PMMCore: 0.9.0
- merge-plan schema: 14
- build-manifest schema: 8
- .NET Runtime: exact 8.0.30, bundled
- repak: bundled and SHA-256 pinned
- mappings: bundled and SHA-256 pinned
- AssetReader/PMMCore managed runtime files: SHA-256 pinned
- Oodle: not redistributed
- end-user compilation/NuGet restore: not used
- user PAKs/saves/logs/generated builds/local Game Reference: must not ship

## Required runtime validation before publication

See `Documentation/V1_1_CLEAN_RC1_TEST_PLAN.md`.

The candidate is publishable only after those Windows/Palworld checks pass. A static check cannot prove gameplay behavior or Windows WPF/process integration.

## Static verification completed

The reconstructed tree passed the following non-runtime checks before packaging:

- all three WPF XAML files parse as XML and expose the same control-name contract;
- all JSON and GitHub YAML files parse;
- the release manifest disables MegaMerge and does not advertise Console/Mod Edit;
- no runtime PowerShell implementation of MegaMerge, Developer Console, or Mod Edit remains;
- bundled .NET runtime inventory matches its pinned inventory exactly;
- PMMCore, AssetReader, repak and mappings hashes match the pinned release values;
- package state directories contain no user PAKs, saves, logs, builds, local Game Reference, caches or debug symbols;
- Analyze/Build and Game Reference use separate child-process workers with atomic JSON progress/result files;
- concurrent Game Reference and Analyze/Build workers are rejected to avoid reading/writing Game Reference simultaneously.

`SmokeTest.ps1` is included and must still be executed on the target Windows system. This build has not been claimed as runtime-passed until the user completes the RC1 test plan.

