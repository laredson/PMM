# AI_CONTINUE_HERE — Palworld Manager Merger v1.1

If the complete public PMM ZIP was uploaded to you, start here.

1. Read `Documentation/AI_DEVELOPMENT_HANDOFF.md`.
2. Read `ARCHITECTURE.md`, `DEVELOPER_GUIDE.md`, `Knowledge/README.md`, `Knowledge/production-recipes.json`, `Docs/COMMUNITY_KNOWLEDGE_WORKFLOW.md`, and `Docs/MANUAL_SOLUTION_CONTRACT.md`.
3. Inspect the relevant source before proposing changes.
4. Preserve the core contract: merge the union of compatible changes; resolve conflicts at the smallest proven unit; `Unsupported` must never silently become a whole-file winner.
5. AssetReader/UAssetAPI stays read-only in production. Writers patch/copy real cooked families under explicit proofs.
6. Never authorize a new merge from author comments, mod names or AI interpretation alone.
7. Preserve runtime-proven behavior unless a real new fixture justifies change.

**Current baseline:** Palworld Manager Merger v1.1 / PMMCore 0.9.0 / merge-plan schema 14 / UE5_1 / mappings SHA-256 `604550ba90faab1e394c2789f38eeff625493d3729c2d7f6a6058bfedb90a67b`.

**Public dependency invariant:** the final v1.1 archive includes pinned repak, mappings and prebuilt PMMCore/AssetReader. End-user setup verifies/repairs them and never compiles or restores NuGet packages. PMM requires exact .NET Runtime 8.0.30: it reuses an exact available host or downloads the pinned Microsoft win-x64 archive, verifies its SHA-512 and installs it portably. The .NET SDK 8.0.424 is developer-only. Oodle remains intentionally unbundled.

## v1.1 new invariant

PMM also has persistent low-to-high merge priority. The UI supports drag/drop, direct 1-based position entry, and one-step Earlier/Later moves. Priority resolves only true overlapping values; independent diffs remain union-merged, manual choices override priority, and structural Unsupported cases stay blocked.

`Knowledge/production-recipes.json` is the narrow bridge from a successful community `AI_HANDOFF` to automatic production behavior. A recipe may run only after exact validation of mappings, Vanilla cooked-family hashes, complete provider PAK hash set and every provider family hash. Current v1.1 recipe #1 is case `73bb3d0635170dad4cb3f7a8` (RushRoar Leather Drop v2 + FasterMounts). The public package stores hashes/proof/runtime evidence, not third-party PAKs or Palworld cooked assets.

The DataTable semantic map also supports duplicate source row IDs by occurrence (`Row#1`, `Row#2`, ...). Do not collapse duplicates.

Creator: **laredson**. PMM uses extensive GPT-assisted development plus real Windows/Palworld testing.

## v1.1 Game Reference / community contribution extension

This build also contains `Core/GameReferenceService.ps1` and
`Core/KnowledgeContributionService.ps1`.

- Game Reference is generated locally from the user's installed `Pal-Windows.pak`; do
  not ship extracted Vanilla cooked assets in a public PMM release.
- The broad extraction must remain a single bulk selective `repak unpack`, not hundreds
  of tiny PAK reopens.
- AI_HANDOFF enrichment is deterministic supporting evidence only. Read
  `references/reference-reasons.json`; never treat reference selection or Knowledge as
  production write permission.
- `PMM_KNOWLEDGE_CONTRIBUTION_V1` packages an accepted solution + exact handoff + explicit
  user runtime PASS for review. It must never self-promote into a production recipe.
- Future website/intake design is documented in
  `Docs/COMMUNITY_KNOWLEDGE_SERVER_SPEC.md`.

Read `Documentation/GAME_REFERENCE_AND_COMMUNITY_CONTRIBUTIONS.md` before changing this
subsystem.


## Clean v1.1 release line (2026-08-20)

The public release candidate is `PMM-v1.1-CLEAN-RC1`.

Important current invariants:

- original source mods remain intact;
- Build creates only a PMM compatibility patch;
- MegaMerge is retired and removed from the clean path;
- Developer Console and Mod Edit are excluded;
- effective-order saved-patch reuse is present;
- Analyze and Build run through `Core/OperationWorker.ps1`;
- Game Reference runs through `Core/GameReferenceWorker.ps1`;
- community Knowledge upload/download and self-update are **not active network features in v1.1**;
- users can manually export `PMM_KNOWLEDGE_CONTRIBUTION_V1` after a tested PASS.

Read `RELEASE_NOTES.md`, `Documentation/V1_1_CLEAN_RC1_TEST_PLAN.md`, and `Documentation/SHARING_KNOWLEDGE_MANUALLY.md` before changing release behavior.
