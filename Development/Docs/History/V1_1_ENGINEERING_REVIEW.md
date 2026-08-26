# Palworld Manager Merger v1.1 — engineering review

**Date:** 2026-08-18  
**Application:** Palworld Manager Merger v1.1  
**PMMCore:** 0.9.0  
**Merge-plan schema:** 14

## Why v1.1 exists

RushRoar Leather Drop v2 and FasterMounts shared `DT_PalMonsterParameter_Common`. v1.0 correctly returned Unsupported because the existing superset proof could not prove the changed layout and the semantic DataTable map aborted on a duplicate Unreal row name (`RAID_NightLady_Dark`).

PMM's AI_HANDOFF workflow produced case `73bb3d0635170dad4cb3f7a8`. An external AI returned a `PMM_MANUAL_SOLUTION_V1`; PMM validated/imported it and the user confirmed the full setup works in Palworld. The returned cooked family is byte-for-byte identical to FasterMounts for this asset.

This is the first real case where the community/AI workflow completed the intended loop and fed a solution back into PMM.

## v1.1 changes

### 1. Duplicate-row DataTable identity

`DataTableMap` no longer rejects the entire semantic map solely because two serialized rows expose the same source row ID. Duplicate groups are preserved in source order using internal keys such as `Row#1`, `Row#2`, while unique rows keep their existing key. No duplicate row is silently collapsed.

### 2. Exact runtime-proven production recipes

`Knowledge/production-recipes.json` is a narrow production bridge, separate from ordinary explanatory Knowledge.

A recipe may authorize Build only when PMM revalidates:

- exact target asset;
- `UE5_1` engine profile;
- exact mappings SHA-256;
- exact complete provider PAK hash set for the shared asset;
- exact Vanilla cooked-family topology, size and hashes;
- exact cooked-family topology, size and hashes for every provider;
- runtime-proven recipe status;
- exact output-provider family hashes.

The recipe service contains no special-case provider filenames. Names are evidence/display metadata only; authorization is hash/family based.

The first recipe reuses the FasterMounts provider family for the exact RushRoar v2 + FasterMounts fixture. It does **not** encode a general rule such as “10 wins over 1.” A changed mod/game version does not match the recipe.

### 3. Build revalidation

Analyze records `KnownRecipeAuto`. Build reruns the complete recipe match against newly extracted Vanilla/providers before copying the output provider family. A stale or changed recipe cannot be built from an old plan.

### 4. Priority ordering and UI hardening

The source library stores one deterministic low-to-high order. A user can now drag/drop rows or type the final 1-based position directly. Numeric moves are insertion operations: existing rows shift around the moved mod, out-of-range values clamp to the first/last slot, and the stored sequence remains dense `1..N`. Reordering invalidates the current Analyze/Build order identity but does not discard explicit manual conflict choices.

Language and decision ComboBoxes now use explicit shared height/font/padding/centering. The language selector is data-backed instead of nesting `ComboBoxItem` controls as selected content.

## Frozen merge boundary

The runtime-proven merge algorithms remain unchanged in the priority-UX candidate. `Tools/PMMCore` is byte-for-byte identical to the preceding RC, as are the merge-oriented Core services other than `Core/LibraryService.ps1`. `Mappings.usmap` is unchanged.

`Core/LibraryService.ps1` is intentionally **not** frozen in this candidate: it owns persistent mod ordering and now exposes absolute insertion (`Set-PMMModPriorityPosition`) in addition to the one-step move API. That change is orchestration/state management around the proven merge engine, not a new cooked-asset adapter.

## Redistribution/privacy

The public v1.1 package does not contain the contributed third-party PAKs, Vanilla cooked assets or returned cooked solution. It stores hashes, structural conclusions, recipe metadata and runtime-result summaries only.

For provenance, Knowledge records SHA-256 of the original AI_HANDOFF and AI_SOLUTION archives.


## RC4 release-package hygiene hardening

RC3 exposed a packaging-process defect rather than a runtime merge defect: the candidate ZIP had been compressed from a used test working directory. Runtime state (`Mods/`, `Builds/`, save backups, `Data/Review`, logs and local configuration) was therefore present in the archive even though the curated checksum list did not include most of it.

RC4 adds an allowlist-based release builder plus a dedicated release-package validator. A public package is rejected if it contains user/source PAKs, generated PMM merges, saves, runtime Data state, logs, a machine-specific `dotnet-host.txt`, source-tree `bin/obj` build leftovers, or `oo2core_9_win64.dll`. The normal standard package still includes the redistributable/pinned repak binary, mappings, PMMCore runtime and AssetReader runtime.

Dependency startup is also stricter: the bundled repak must match the pinned SHA-256 instead of merely existing. PMMCore keeps its exact assembly-version + self-test gate, AssetReader keeps its dependency self-test, and an already-present local Oodle DLL is accepted only at the known repak 0.2.3 hash; otherwise it is removed so repak can reacquire the expected runtime on demand.

## RC5 offline-first launch packaging

The v1.1 public dependency flow uses the exact Microsoft .NET Runtime 8.0.30 win-x64. Setup first reuses an exact compatible host when available; otherwise it downloads the pinned Microsoft runtime archive, verifies the official SHA-512, installs it portably under `Tools/dotnet/8.0.30`, and then runs PMMCore/AssetReader self-tests. The public package never requires the .NET SDK and never compiles PMM on the end-user machine.

`Setup-Dependencies.ps1` is now a verifier/repair layer for end users rather than a compiler. It never runs `dotnet publish` or NuGet restore. PMMCore and AssetReader are shipped prebuilt, pinned by release-manifest hashes and exercised by their existing self-tests. A public package will not silently bypass a damaged bundled runtime just because the machine has a compatible system runtime: it must validate or repair its own portable runtime first.

The release validator executes the bundled `dotnet.exe`, PMMCore self-test and AssetReader dependency self-test before creating the final ZIP, and rejects SDK payloads, missing/untracked runtime files, an unfinalized release-source manifest, or any of the runtime/user-state artifacts already blocked by RC4. A healthy public-package `Start.cmd` therefore performs no web request. Oodle remains intentionally outside the archive and may be acquired by pinned repak only when actually needed.

## Test status

- manual AI solution: **runtime PASS**
- exact solution output == FasterMounts provider family: **verified**
- current container-side priority-UX static checks: **157 PASS / 0 FAIL** before final checksum packaging
- v1.1 automatic `KnownRecipeAuto` integration: **awaiting final Windows/Palworld test**
