# Palworld Manager Merger v1.1 — Release Notes


### Release packaging and dependency hygiene

- Public release staging is now allowlist-based instead of zipping a used working directory.
- User/source PAKs, generated merges, save backups, review extracts, runtime config/state, logs, machine-specific .NET host markers and Oodle are blocked from the public ZIP.
- Bundled repak is now checked against its pinned SHA-256 before startup can treat dependencies as healthy.
- The public archive ships repak, mappings and prebuilt PMMCore/AssetReader. Startup verifies them locally. If .NET Runtime 8.0.30 is not already available, Setup downloads the pinned Microsoft win-x64 archive once, verifies its SHA-512 and installs it portably inside PMM.
- End-user setup never runs `dotnet publish`, NuGet restore, or any compilation step. The .NET SDK 8.0.424 remains a developer-only contract and is not shipped.
- Network access is reserved for verified repair of redistributable upstream payloads if a bundled copy is damaged/missing. Oodle is still not redistributed by PMM; pinned repak may obtain its expected Oodle runtime on demand when a PAK requires it.

## Game Reference + fresh-session AI_HANDOFF

PMM can build a local reusable Vanilla Game Reference from the user's installed `Pal-Windows.pak`. The production selector uses exact roots/names and a fast bulk extraction instead of reopening the large PAK per asset. On the supplied 2026-08-17 research capture the corrected scope selects 7,134 cooked files / 3,565 families / about 66.8 MiB raw; these counts are not hard-coded and may change with Palworld.

When Game Reference is current, Unsupported AI_HANDOFF packages add a bounded `references/` neighborhood: related Vanilla cooked families, provider entry indexes and a small non-conflict provider neighborhood for focused mods. `reference-reasons.json` explains why each Vanilla family was selected. The receiving AI is instructed to assume zero previous chat/project context.

The first relation rule covers Ranch/SpawnItem context and exists only to select explanatory references. Game Reference/Knowledge never grants merge/write permission.

## Tested Knowledge contribution package

After an imported AI/manual solution has been validated by PMM and the user has tested that exact solution successfully in Palworld, Settings can create one `PMM_KNOWLEDGE_CONTRIBUTION_<caseId>.zip`. It contains the exact case, original handoff when available, preserved returned solution, PMM validation and explicit user-reported runtime PASS.

The contribution is evidence for maintainer/community review and cannot auto-promote itself into a production recipe. A future community intake service should quarantine/validate submissions and publish sanitized approved Knowledge packs rather than redistributing source PAKs or extracted Vanilla assets.


## Main change: successful AI_HANDOFF promoted into the app

The RushRoar Leather Drop v2 + FasterMounts conflict became the first PMM Unsupported case to complete the full community workflow: HANDOFF generated -> AI solution returned -> PMM validation/import -> in-game PASS. v1.1 promotes that exact proven solution into a production recipe.

### Exact runtime-proven recipe

For case `73bb3d0635170dad4cb3f7a8`, PMM can now automatically reuse the proven FasterMounts `DT_PalMonsterParameter_Common` cooked family when—and only when—the exact mappings, Vanilla asset family, complete two-provider PAK hash set and provider-family hashes match the runtime-tested fixture. No cooked solution is bundled. A changed mod/game version falls back to the normal adapter chain.

### Duplicate DataTable row support

`DataTableMap` no longer aborts simply because Unreal exposes duplicate row IDs. Duplicate names are preserved by deterministic occurrence-qualified identities (`Row#1`, `Row#2`, ...). This fixes the parser limitation that originally blocked semantic inspection of `RAID_NightLady_Dark` and can help future unrelated DataTable conflicts.

### Core / plan

- PMMCore: **0.9.0**
- merge-plan schema: **14**
- build-manifest schema: **8**
- previous v1.0 merge adapters and runtime-proven behavior remain unchanged
- saved v1.0 patches remain managed artifacts; new Analyze plans are regenerated under the v1.1/Core 0.9.0 contract

### Knowledge/community

- new `Knowledge/production-recipes.json`
- sanitized contribution evidence for case `73bb3d0635170dad4cb3f7a8`
- Knowledge UI reports production recipe count
- AI/developer handoff updated so the entire public ZIP remains a self-contained continuation package

## Validation target before publishing

With FasterMounts4xAllWorkSuitabilitiesLevel10 and RushRoar Leather Drop v2 active together, Analyze should report the shared `DT_PalMonsterParameter_Common` as **Auto merged / Runtime-proven recipe**, with no Unsupported for that asset. Build -> Deploy should produce the same working behavior as the previously tested manual experimental solution. Re-test the existing Fly/Wing/MultiJump/StaticItem stack as a smoke regression.


## Priority-order UI polish

Source mods can now be reordered by drag/drop or direct numeric position entry. PMM uses insertion semantics and normalizes the list to `1..N`. Language and decision ComboBoxes also use explicit consistent sizing/typography.
