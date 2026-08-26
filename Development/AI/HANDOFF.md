# Palworld Manager Merger v1.1 — AI / Developer Development Handoff

## Canonical current state

- Release: **v1.1**
- PMMCore: **0.9.0**
- merge-plan schema: **14**
- build-manifest schema: **8**
- engine profile: **UE5_1**
- mappings SHA-256: `604550ba90faab1e394c2789f38eeff625493d3729c2d7f6a6058bfedb90a67b`
- application: PowerShell/WPF; source included
- AssetReader/UAssetAPI: read-only production boundary
- generated overlays: managed outputs, never source providers
- public package: pinned repak, mappings and prebuilt managed helpers; exact .NET Runtime **8.0.30 win-x64** is reused when available or downloaded/verified and installed portably when needed
- developer-only SDK contract: **8.0.424**; end-user setup never compiles or restores NuGet packages
- final public manifest uses `packageProfile=public-standard`, `sourceTreeRequiresReleaseBuild=false`, and `standardPackageDotnetBundled=false`; Setup owns the exact-runtime install/repair fallback

## Merge contract

Preserve Vanilla + N-mod compatible changes. A shared file is not itself a conflict. Resolve only the smallest proven byte/property/parameter where providers actually disagree. `Unsupported` blocks Build. Do not restore generic `UAsset.Write()` production reserialization and do not invent whole-file winners.

Mod order is persistent low-to-high precedence. Top applies earlier; bottom applies later/higher priority. Users can reorder by drag/drop, direct 1-based insertion, or one-step buttons. Priority is only the default winner for a true overlapping value; it never replaces an entire shared asset, and an explicit manual conflict decision still overrides priority. Reordering invalidates the current Analyze/Build identity while retaining prior manual choices only as decision history.

## Runtime-proven baseline carried from v1.0

Finite MultiJump variants (Double/Triple/Quad) can participate as one N-provider jump-count decision while Fly's independent BP_PlayerBase edits remain merged. Fly + Wing is runtime-proven through `ContainedDeltaSuperset-v1`. StaticItem, BreedFarm and player-status merge fixtures remain proven. Manager-only deployment, selectable saved patches, and save backup/restore have been user-tested.

## v1.1 promoted community case

Case `73bb3d0635170dad4cb3f7a8` targeted `Pal/Content/Pal/DataTable/Character/DT_PalMonsterParameter_Common.uasset` with exact providers:

- FasterMounts4xAllWorkSuitabilitiesLevel10_P.pak — `f91dd7ae1aa0d5ef1399d9185cee74a4ce06d907cfaf4c936489dbdf67b21e64`
- RushRoarLeatherDrop_v2_P.pak — `b663b49a2a0825b01c45bfd223b2114e7dfc30bf108d8250aa89f6d82ee4a266`

v1.0/RC5 reported Unsupported because SupersetAnchor could not prove the secondary layout and the DataTable parser rejected duplicate row ID `RAID_NightLady_Dark`. The AI/manual returned solution was byte-for-byte identical to the FasterMounts family. The user imported it and confirmed the complete merge worked in Palworld.

v1.1 therefore adds two separate improvements:

1. **Duplicate-row semantic identity:** `DataTableMap` preserves duplicate row names as occurrence-qualified identities instead of throwing.
2. **Exact runtime-proven production recipes:** `Core/KnowledgeRecipeService.ps1` + `Knowledge/production-recipes.json` can automatically reuse a proven provider family, but only when exact mappings, Vanilla family, complete provider PAK set and all provider family hashes match. It never matches by filename alone.

Do not generalize this case into a rule such as "higher work-suitability number always wins". That semantic generalization has not been proven safe for arbitrary mods.

## Community growth workflow

Unsupported set -> explicit AIIO export -> ONE `AI_HANDOFF_<bundle>.zip` containing every current Unsupported case and only the exact conflicting source/Vanilla files -> AI/modder returns `PMM_MANUAL_SOLUTION_V1` per solved case -> PMM validates/imports -> user tests in Palworld -> maintainer records runtime result -> only then may an exact recipe or stronger generic adapter be added.

Public PMM releases must not embed contributed third-party PAKs or Palworld cooked assets. Preserve hashes, structural findings, sanitized solution summaries and runtime reports instead.

## Where to work

- `Core/MergeEngine.ps1` — Analyze/Build routing and review metadata
- `Core/AIIO.ps1` — explicit one-bundle AI handoff extraction/packaging
- `Core/KnowledgeRecipeService.ps1` — exact production-recipe validation
- `Core/SemanticLab.ps1` — non-authoritative evidence/Knowledge
- `Tools/PMMCore/src/PMM.Core/` — merge algorithms
- `Tools/PMMCore/src/PMM.Core/Semantic/DataTableMap.cs` — duplicate-row identity
- `Knowledge/` — behavior cases, exact fixtures and production recipes
- `Knowledge/Contributions/` — sanitized contributed runtime evidence
- `Docs/COMMUNITY_KNOWLEDGE_WORKFLOW.md` — contribution workflow

Historical pre-v1.1 notes under `Documentation/History/` are archaeology. This handoff + current source are authoritative.
