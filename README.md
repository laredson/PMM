# Palworld Manager Merger (PMM) v1.1

Palworld Manager Merger is an open-source Palworld mod manager and PAK compatibility merger for Windows/Steam.

**Import -> Analyze -> resolve only real decisions -> Build -> Deploy -> Play.**


PMM preserves the original source mods. It does **not** combine every installed mod into one MegaMerge. Build creates only a managed compatibility patch containing the cooked assets PMM must reconcile.

Analyze, Build, and Game Reference run through background worker processes in the clean v1.1 candidate so long-running work does not own the WPF UI thread.

PMM compares shared cooked assets against the installed Vanilla game, preserves compatible changes from multiple mods, asks only when providers truly disagree on the same proven value/property, and blocks Unsupported cases instead of silently choosing a whole-file winner.

## v1.1 highlight: the AI_HANDOFF loop is now proven end-to-end

A real conflict between **RushRoar Leather Drop v2** and **FasterMounts4xAllWorkSuitabilitiesLevel10** originally produced Unsupported. PMM generated an `AI_HANDOFF` package; an AI returned a `PMM_MANUAL_SOLUTION_V1`; PMM validated/imported it; and the user confirmed the resulting full mod setup worked correctly in Palworld.

v1.1 promotes that successful contribution into PMM's first **exact runtime-proven production recipe**. The recipe does not match by filename and does not redistribute the solution cooked files: it activates only when the current mappings, Vanilla family, complete provider PAK hash set and every provider family hash exactly match the proven case. Any changed version falls back to normal analysis.

v1.1 also teaches the DataTable semantic layer to preserve duplicate Unreal row IDs by occurrence instead of rejecting the whole table. This is a general parser improvement prompted by the same real case.

## Runtime-proven baseline

The v1.0/v1.1 development stack has successfully combined/tested cases including finite MultiJump variants with FlyMode, Fly + Wing visible-while-flying/no-cell behavior, Stack/ZeroWeight, FoodNeverSpoils, Early Aquatic, EasyBreeding + NoCollisionFarmsAndExped, player-stat-cap changes, world save backup/restore, selectable saved patches and manager-only deployment. RushRoar Leather Drop v2 + FasterMounts is now additionally runtime-proven through the AI_HANDOFF/manual-solution path.

Runtime-proven means the exact tested files/versions. PMM still analyzes current bytes; it does not assume future versions are compatible.

## Dependency preparation

The public v1.1 package is offline-first and includes the pinned repak binary, mappings, prebuilt PMMCore/AssetReader, and the exact portable .NET Runtime 8.0.30. `Start.cmd` verifies those payloads before opening the UI, so a healthy installation performs no dependency download. Network repair is attempted only when a required redistributable is missing or invalid. PMM never compiles itself or restores NuGet packages on an end-user machine. Oodle is intentionally not redistributed and may be obtained later by pinned repak when a PAK requires it.

## Manager features

PMM can also be used without a compatibility patch: import existing `~mods`, enable/disable source mods, deploy source mods only, keep and select saved compatibility patches, remove managed overlays, and backup/restore worlds.

## Open source / transparency

PMM is MIT licensed. Its application logic is readable PowerShell/WPF and the C# source for PMMCore/AssetReader is included. There is no closed proprietary PMM executable hiding the merge logic. Third-party tools/runtimes keep their own licenses; see `THIRD_PARTY_NOTICES.md`.

## Continue development with an AI

If you upload this entire release ZIP to an AI, tell it to read **`AI_CONTINUE_HERE.md` first**. The package includes source, architecture, Knowledge, production-recipe rules, runtime evidence, history and the AI_HANDOFF/manual-solution contract needed to continue development without reconstructing the project from scratch.

Created by **laredson** with extensive GPT-assisted development and real Palworld runtime testing.

## v1.1 Game Reference + community learning

Settings can build a local **Vanilla Game Reference** from the user's own
`Pal-Windows.pak`. PMM uses a fast bulk extraction and indexes complete cooked families.
Unsupported `AI_HANDOFF` ZIPs can then include a bounded set of related Vanilla examples
plus focused provider context, so a completely fresh AI can reason about the subsystem
without having access to previous chats or a separate game dump.

After an imported AI/manual solution is tested successfully in Palworld, **Create tested
contribution** packages the exact case + original handoff + returned solution + PMM
validation + user-reported runtime PASS as `PMM_KNOWLEDGE_CONTRIBUTION_V1`. This is
review evidence; it never auto-promotes itself into a production merger rule.

See `Documentation/GAME_REFERENCE_AND_COMMUNITY_CONTRIBUTIONS.md`.

## Share new knowledge manually

v1.1 does not upload anything automatically. Community learning is deliberately manual for the first public release:

1. Run **Analyze**. Unsupported assets can generate an `AI_HANDOFF` ZIP.
2. Give that handoff to an AI or modder and import the returned `PMM_MANUAL_SOLUTION_V1`.
3. Build, Deploy, and test the exact result in Palworld.
4. After a successful in-game test, use **Settings -> Create tested contribution...**.
5. PMM creates a `PMM_KNOWLEDGE_CONTRIBUTION_V1` ZIP under `Data/KnowledgeContributions`.
6. Share that ZIP with the project maintainer/community for quarantine, independent validation, and possible future Knowledge promotion.

A contribution is evidence, not automatic authorization. It never edits `Knowledge/production-recipes.json` by itself.

See `Documentation/SHARING_KNOWLEDGE_MANUALLY.md`.
