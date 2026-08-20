# Palworld Manager Merger v1.1 — Clean Release Candidate 1

Build identity: `PMM-v1.1-CLEAN-RC1`

This candidate is intentionally rebuilt from the user-proven v1.1 working baseline. Later experimental branches were treated as donors only when a change was isolated and useful.

## Release model

PMM keeps every original source mod and generates only the compatibility patch needed to reconcile supported conflicts.

**MegaMerge is retired and is not part of this release.**

## Included

- Import existing PAK mods into PMM's portable library.
- Import active game `~mods`.
- Enable/disable and remove library mods without treating PMM outputs as source mods.
- Persistent low-to-high mod priority with buttons, direct numeric insertion, and drag/drop.
- Analyze shared cooked assets against Vanilla.
- Automatic safe adapters for compatible changes.
- Value/property-level conflict decisions instead of whole-file winner fallback.
- Build a managed PMM compatibility patch.
- Transactional Deploy and restore/remove PMM overlays.
- Saved compatibility patches and manager-only Deploy.
- Patch reuse that ignores harmless full-list reordering when it does not change an actual priority-resolved conflict winner.
- Save backup/restore tools.
- Local Vanilla Game Reference.
- AI_HANDOFF for Unsupported cases.
- Import/validate experimental AI/manual cooked solutions.
- Export a tested `PMM_KNOWLEDGE_CONTRIBUTION_V1` after an explicit in-game PASS.
- Exact runtime-proven Knowledge recipes already present in v1.1.
- Bundled pinned repak, mappings, PMMCore, AssetReader, and portable .NET Runtime 8.0.30.
- Background worker processes for Analyze, Build, and Game Reference so long-running work does not run on the WPF UI thread.

## Removed from the public v1.1 line

The following experimental work is deliberately excluded:

- Developer Console / raw CMD / PowerShell shell.
- Mod Edit workspace.
- retired MegaMerge mode.

They are not hidden tabs; their public UI/runtime paths are not included in this candidate.

## Offline-first startup

A healthy installation verifies the bundled dependencies locally. Network repair is attempted only if a required redistributable is missing or invalid. End-user startup does not compile PMM and does not run NuGet restore.

## Community knowledge in v1.1

v1.1 does **not** automatically upload or download Knowledge.

Users can already:

1. generate exact AI_HANDOFF packages for Unsupported cases;
2. import AI/manual solutions;
3. test them in Palworld;
4. export a tested Knowledge contribution ZIP;
5. share the ZIP manually for independent validation.

The future Stable/Experimental Knowledge channels, evidence aggregation, anonymous submission intake, and application updater are documented under `Documentation/Protocols/` but are not active network features in v1.1.

## Validation status

Static/package validation is performed before this candidate is handed off. Final public release status requires the Windows/Palworld smoke test in `Documentation/V1_1_CLEAN_RC1_TEST_PLAN.md`.
