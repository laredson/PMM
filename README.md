# Palworld Manager Merger (PMM)

**Current release candidate: PMM 1.3.0 RC20.**

Palworld Manager Merger is a local Palworld mod manager, compatibility analyzer/overlay builder and legacy-mod repair platform. It preserves normal source mods and creates a compatibility overlay only for shared assets that actually require reconciliation.

## Repository layout

- `PMM/` — complete portable application. Release ZIPs are built from this folder only.
- `Development/` — engineering source, tests, architecture and AI/developer handoffs.
- `.github/` — GitHub workflows/community files.
- `.gitignore` / `.gitattributes` — repository policy.
- `LICENSE` — MIT project license.

## Start PMM

Extract the release ZIP and run `PMM.exe`.

The normal guided workflow is:

`Detect (if needed) -> Import -> Fix Lab when required -> Analyze -> Build Merge -> Deploy -> Play optional`

PMM 1.3.0 includes Fix Lab for supported exact legacy cases, a portable current Game Reference, background processing, AUTO/ColorFlow guidance, backups/restores, Night/Light/custom themes and event sound profiles.

## 1.3.0 engineering notes

The `1.3.0final` branch is the canonical 1.3.0 stabilization branch. The runnable `PMM/` tree is authoritative for the release candidate. RC20 is based directly on the user-tested RC19 and adds final header/detection/settings UX, terminal Ready-to-play guidance and conservative persistent caches to make repeat Analyze passes lighter.

Future AIIO / **AI & Help** work should begin with `Development/AI/AIIO_1_3_0_HANDOFF.md` and reuse the existing `Modules/AIIO`, CKL, Game Reference and Fix Lab services rather than replacing them.

Runtime-created `PMM/Workspace/` is local state and must never be committed or shipped in a clean public package.

Created by **laredson**.
