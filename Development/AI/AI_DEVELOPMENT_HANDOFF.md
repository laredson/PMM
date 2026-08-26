# Palworld Manager Merger v1.1.1 — AI / Developer Development Handoff

## Canonical current state

- Release: **v1.1.1**
- PMMCore: **0.9.0**
- merge-plan schema: **14**
- build-manifest schema: **8**
- engine profile: **UE5_1**
- mappings SHA-256: `604550ba90faab1e394c2789f38eeff625493d3729c2d7f6a6058bfedb90a67b`
- application: PowerShell/WPF; source included
- AssetReader/UAssetAPI: read-only production boundary
- generated overlays: managed outputs, never source providers

### v1.1.1 maintenance delta

v1.1.1 keeps the `Core/PakService.ps1::Get-PakEntry` hardening: redirected binary stdout and stderr are consumed concurrently, exact extraction is bounded to 180 seconds, a timed-out repak process is terminated, and partial output is deleted. It also replaces the old unbounded/rotating logging approach with one append-only Smart Log at `Logs\PalModMerger.log`: every physical line is timestamped, process sessions are explicit, exact consecutive repeats are coalesced with total count + first/last timestamps and periodic checkpoints, distinct child-process diagnostics are preserved, successful `repak list` noise is suppressed, and fast `repak get` success lines are omitted while START/slow/failure/timeout diagnostics remain.

Do **not** infer any Fix Lab implementation from this release. Fix Lab remains future work and no merge/conflict authorization behavior was changed for v1.1.1.

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

Unsupported set -> explicit AIIO export -> ONE `AI_HANDOFF_<bundle>.zip` with exact conflicting source/Vanilla files -> AI/modder returns `PMM_MANUAL_SOLUTION_V1` per solved case -> PMM validates/imports -> user tests in Palworld -> maintainer records runtime result -> only then may an exact recipe or stronger generic adapter be added.

Public PMM releases must not embed contributed third-party PAKs or Palworld cooked assets. Preserve hashes, structural findings, sanitized solution summaries and runtime reports instead.

## Where to work

- `Core/MergeEngine.ps1` — Analyze/Build routing and review metadata
- `Core/AIIO.ps1` — explicit one-bundle handoff extraction/packaging
- `Core/KnowledgeRecipeService.ps1` — exact production-recipe validation
- `Core/SemanticLab.ps1` — non-authoritative evidence/Knowledge
- `Tools/PMMCore/src/PMM.Core/` — merge algorithms
- `Tools/PMMCore/src/PMM.Core/Semantic/DataTableMap.cs` — duplicate-row identity
- `Knowledge/` — behavior cases, exact fixtures and production recipes
- `Knowledge/Contributions/` — sanitized contributed runtime evidence
- `Docs/COMMUNITY_KNOWLEDGE_WORKFLOW.md` — contribution workflow

Historical pre-v1.1 notes under `Documentation/History/` are archaeology. This handoff + current source are authoritative.

## Local Game Reference and fresh-session handoffs (v1.1)

PMM can now build a local indexed Vanilla research cache from `Pal-Windows.pak`. The
scope/version/provenance contract is in `Core/GameReferenceService.ps1` and
`Documentation/GAME_REFERENCE_AND_COMMUNITY_CONTRIBUTIONS.md`. The initial production
scope intentionally uses exact directory roots plus a tiny exact leaf allow-list. Do not
reintroduce the old `ranch` substring selector; it matched unrelated `branch` assets.

AIIO is now the only normal handoff packager. Analyze never packages handoffs. AIIO
re-extracts each exact conflicting provider/Vanilla file on explicit user request and
builds one bundle for the complete current Unsupported set; whole source PAKs are never
included. The receiver is explicitly assumed to have zero previous chat context.

`Core/KnowledgeContributionService.ps1` exports
`PMM_KNOWLEDGE_CONTRIBUTION_V1` after explicit user confirmation of a runtime PASS. This
is intake evidence only. Exact production recipes still require maintainer validation,
strict fixture hashes/mappings and the existing production recipe contract.
