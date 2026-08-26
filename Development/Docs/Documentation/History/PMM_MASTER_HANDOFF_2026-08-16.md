# PalModMerger (PMM) — Master Technical Handoff

**Handoff date:** 2026-08-16  
**Current implementation:** `PalModMerger v1-preview28`  
**Current PMMCore:** `0.7.1`  
**Primary goal:** let a Palworld player import a set of PAK mods, click **Analyze**, resolve only genuine same-parameter disagreements, build a compatibility overlay that preserves every other compatible change, and then explicitly **Deploy** the desired source mods + overlay to Palworld.

---

## 0. START HERE — instructions for the next ChatGPT session

Do **not** restart this project from the old “deserialize everything / rewrite UAsset” idea.

The project has already established a safer architecture:

1. preserve real cooked assets whenever possible;
2. compare each provider against Vanilla/current state;
3. merge disjoint changes automatically;
4. create a user decision only when two or more providers request different values for the **same proven property/byte**;
5. after resolving that one value, still merge every other independent change in the same file;
6. treat `Unsupported` as a blocker, never as “pick a whole mod winner”;
7. AssetReader/UAssetAPI is read-only; production writers patch copied cooked bytes and validate preconditions;
8. Import, Build and Deploy are separate lifecycle stages.

The current files to inspect first are:

- `artifacts/current/PalModMerger-v1-preview28.zip`
- `artifacts/test_inputs/MultiJumpTriple_P.pak`
- `artifacts/test_inputs/MultiJumpQuad_P.pak`
- `artifacts/test_inputs/EarlyAquaticConstructionKit_P.pak`
- `artifacts/captured_workspaces/PMM_preview27_test_workspace.zip`
- `artifacts/golden/3modmerge_sources_and_manual_golden.zip`

The **next validation target** for preview28 is not another Core-only test. It is the actual application flow:

```text
Import/active mods
  -> Analyze
  -> expected: Shared 4 / auto 3 / true-conflict decisions 1 / unsupported 0
  -> resolve MultiJump Triple vs Quad at the conflicting value
  -> Build local overlay
  -> Deploy
  -> Palworld runtime test
```

If preview28 does not route that fixture as above, treat it as a regression and debug from the supplied real PAKs/fixtures. Do not invent a new architecture first.

---

# 1. Product definition

PMM is **not** a load-order selector and not a whole-file winner tool.

Its intended mental model is:

```text
Vanilla + N source mods
        |
        v
for every shared cooked asset:
  preserve the union of compatible changes
        |
        +--> independent changes -> automatic merge
        |
        +--> same property + same value -> automatic deduplication
        |
        +--> same property + different values -> TRUE CONFLICT row
        |       choices: provider / provider / Vanilla / Custom when safe
        |
        +--> unprovable structural composition -> Unsupported (Build blocked)
        v
local compatibility overlay
        |
        v
explicit Deploy synchronizes Palworld ~mods
```

A whole mod or whole asset should **not** become the conflict unit merely because two mods touch the same `.uasset`.

Example: if MultiJump changes `JumpMaxCount` and Fly changes different data inside `BP_PlayerBase`, the user may choose the desired MultiJump value, but Fly’s other changes must remain in the final asset.

---

# 2. Non-negotiable merge semantics

## 2.1 Smallest proven conflict unit

A conflict row represents the smallest identity the active adapter can prove safely:

- semantic row/property;
- or, when semantics are unavailable but structure is proven, a stable byte/structural field.

Only providers that disagree on that exact identity are competitors.

## 2.2 Correct behavior for duplicate / quasi-duplicate mods

Exact duplicates:

- no gameplay conflict;
- deploy one copy if desired;
- preserve all library copies.

Quasi-duplicates that differ only in one proven parameter, e.g. MultiJump Triple vs Quad:

- create one true-conflict row for that parameter;
- selecting Triple/Quad chooses that value only;
- Vanilla/Custom may suppress both pure alternative PAKs from deployment if the chosen value is encoded in the overlay;
- library copies remain available for future Remerge/Rebuild.

## 2.3 Unsupported is not a user “winner” decision

If PMM cannot prove a safe composition, it must return `Unsupported` and block Build. It must never convert an infrastructure error or unsupported structure into “choose Mod A or Mod B”.

---

# 3. Library / Analyze / Build / Deploy lifecycle

Preview28 establishes this state model:

```text
PMM library (Mods/)                       Palworld (~mods)
       |                                         ^
       | Analyze                                 |
       v                                         | DEPLOY only
Data/merge-plan.json                             |
       |                                         |
       | Build                                   |
       v                                         |
Builds/Current/compatibility overlay ------------+
```

## 3.1 Import

Import copies source PAKs into PMM’s library only. It does not alter Palworld.

## 3.2 Disable / backup

Moves a source mod to `Mods/_Disabled`. The game folder remains unchanged until Deploy.

## 3.3 Delete from library

Removes the local source and records a pending managed removal. The game folder remains unchanged until Deploy.

## 3.4 Analyze

Builds a deterministic plan from active source hashes + mappings. Successful Analyze stays visibly current (green/full) until active inputs or mappings change.

## 3.5 Build

Creates the compatibility overlay under `Builds/Current`. Build does **not** deploy to Palworld.

## 3.6 Deploy

Deploy is the only normal boundary that changes `Pal/Content/Paks/~mods`.

It synchronizes:

- active managed source PAKs;
- current PMM overlay;
- managed disabled/deleted removals;
- old PMM overlays.

It does not blindly delete unrelated third-party PAKs PMM has never managed.

## 3.7 PMM patch lifecycle

PMM outputs are managed artifacts, never source providers.

- current local output: `Builds/Current`;
- archived outputs: `Builds/Previous`;
- deployed copy: Palworld `~mods`;
- manifest records source hashes, mappings, modes, decisions and output hash.

A PMM overlay found in the game folder may be backed up/recovered locally, but it must never re-enter the merge graph as another source mod.

---

# 4. Current architecture — preview28

Dependency profile from preview28:

- portable .NET host/SDK: **8.0.424**;
- PMMCore: **0.7.1**;
- UAssetAPI: **1.1.0**;
- Newtonsoft.Json: **13.0.3**;
- ZstdSharp.Port: **0.8.1**;
- `repak`: bundled/pinned by setup;
- mappings SHA is persisted in Analyze/manifest.

Production boundary:

- `Tools/AssetReader`: read-only Unreal semantic inspection;
- `Tools/PMMCore/src/PMM.Core`: byte/semantic merge logic;
- `Core/*.ps1`: PAK extraction, library state, Analyze/Build/Deploy orchestration;
- `UI/*.xaml` + `Start-PalModMerger.ps1`: WPF shell.

`UAsset.Write()` is not part of the production merge path.

---

# 5. Adapter stack in preview28

## 5.1 BinaryRangeMerge-v2

For providers that share the current cooked layout/topology and corresponding sizes.

Each provider is interpreted as `Vanilla -> provider` byte deltas.

- disjoint changes merge;
- same requested byte value deduplicates;
- same byte with different requested values becomes `BinaryConflict`.

## 5.2 StaticItemDataAssetAdapter/v0.4.0

Target: `DA_StaticItemDataAsset`.

This adapter exists because Fly/Food may be cooked from an older layout while Stack/current Vanilla use the newer layout.

Pipeline:

1. current-layout providers establish a cooked base;
2. stale providers sharing one stale baseline are inspected semantically;
3. common old-version drift is separated from provider intent;
4. supported semantic leaves are mapped to current rows;
5. only fixed-size proven bytes are patched in the current cooked base;
6. explicit behavior rules may extend a proven stale behavior to newly added current rows.

Current supported fixed-size property classes:

- Float32 / `FloatPropertyData`;
- Int32 / `IntPropertyData`;
- supported fixed-size SoftObject top-level paths already represented in the current NameMap.

## 5.3 SupersetAnchor-v1

Used when one structurally larger provider already contains every byte requested by smaller current-layout providers. The anchor is accepted unchanged only after that inclusion is proven.

Reference fixture: `IncreasedPlayerStatCaps1000Free + FreeEnhancePlayerAbility`.

## 5.4 DataTableScalarTransfer-v2

Uses the largest DataTable provider as cooked anchor. Read-only semantic maps identify row/property/type/value/disk offset. Supported secondary scalar changes are transferred with byte preconditions. Same-property disagreements become true conflicts. Unsupported structural secondary changes remain Unsupported.

## 5.5 RelocatableDelta-v2

For relatively small variable-size `.uasset + .uexp` families.

1. choose largest provider as structural anchor;
2. identify providers with the same anchor topology/size and identical `.uasset` metadata as anchor variants;
3. differences between those variants can become value/byte true conflicts;
4. apply the selected variant value;
5. transplant other providers’ disjoint Vanilla-relative hunks through the anchor alignment;
6. compose proven `.uasset` relocation arithmetic.

Reference fixtures:

- EasyBreeding + NoCollisionFarms (`BP_BuildObject_BreedFarm`);
- MultiJump Triple/Quad + Fly (`BP_PlayerBase`) in preview28.

---

# 6. The golden reference — Fly + Stack + NoSpoil

This is the most important proven case in the project.

## 6.1 Manual runtime-working PAK

File:

`FlyMode_Stack999999999_ZeroWeight_NoSpoil_P.pak`

SHA-256:

`42a055bc5dba79ca16366038e970a9ec21a27fec3d447577112faa7e20e16916`

It is included inside:

`artifacts/golden/3modmerge_sources_and_manual_golden.zip`

The same ZIP contains the source Fly/Food/Stack PAKs used as references.

## 6.2 What the manual merge actually did

It was **not** a generic full-asset reserialization.

Conceptually:

```text
Stack current-layout cooked DA_StaticItemDataAsset
  + Fly Glider_Old actor/class intent
  + NoSpoil corruption-factor intent
  = merged current-layout DA_StaticItemDataAsset
```

Fly’s Blueprint/UI files were preserved rather than reserialized.

The known-good final `DA_StaticItemDataAsset.uexp` hash is:

`8f2ab2933c85bde0e8c9d74b39e466f9ad1c3b41c042106f7ffc624dea624bf8`

## 6.3 120 vs 123 NoSpoil detail

The old Food provider expressed 120 observed `CorruptionFactor -> 0` changes, while the current table contained 123 applicable positive spoil rows. The manual golden extended the intended NoSpoil behavior to those current rows.

This distinction drove the split between:

- source-faithful semantic intent;
- explicit behavior-rule extension.

## 6.4 First C# golden gate

`PMMCore-v0.3.2` passed the C# golden reproduction on Windows:

- inferred intents: 121;
- ambiguities: 0;
- shape observations: 0;
- observed Food no-spoil intents: 120;
- current positive corruption rows: 123;
- source-faithful `.uexp`: `8b90581bdd67549a8e9e1a74db2941b6de37ae94ab9fb9776f1e881b3890c7e8`;
- behavior-rule/golden `.uexp`: `8f2ab2933c85bde0e8c9d74b39e466f9ad1c3b41c042106f7ffc624dea624bf8`;
- result: `C# GOLDEN REPRODUCTION: PASS`.

The corresponding archived core is included as `artifacts/golden/PMMCore-v0.3.2.7z`.

---

# 7. Runtime-confirmed application milestone — preview24

The user confirmed that the preview24-generated overlay allowed Palworld to start and **Fly + Food + Stack all worked**.

The captured generated overlay is:

`zzzzzzzzzz_PMM_Merge_20260815_230359_P.pak`

SHA-256:

`7330e1aee0c5e4f904b697d5071b9532b0f956225d6de61cdc2b788474743e33`

Size: 1,280,030 bytes.

Its manifest recorded three reconciled families:

1. `BP_BuildObject_BreedFarm` — `RelocatableAuto`;
2. `DA_StaticItemDataAsset` — `StaticItemAuto`;
3. `DT_PlayerStatusRankMasterDataTable` — `SupersetAuto`.

The larger size relative to the original three-mod manual golden is expected because this overlay contains the other two reconciled conflict families as well.

Important deployment design conclusion reached afterward: keep source mods in PMM’s library, and normally keep active source PAKs deployed beside the compatibility overlay so Remerge/Rebuild remains reproducible. PMM may suppress exact duplicates or unselected pure alternatives from the game folder, but it does not discard their library copies.

---

# 8. Current preview28 test fixtures

## 8.1 MultiJump Triple vs Quad

Uploaded files:

- `MultiJumpTriple_P.pak` SHA-256 `5a35b07ff3509bbed245eefb5ca0bf2dda8537738d5759026661871ff152e604`
- `MultiJumpQuad_P.pak` SHA-256 `04ff4ef1eb636c217507d2b18f0cef03f8bdb46fc18a2eedcb70e92af4c620cc`

Their `BP_PlayerBase.uasset` files are identical:

`f45c4ef94522998fe747bc97df8fd3630e60207d32643a2e99e41c748bea10c0`

Both `.uexp` files are 15,546 bytes and differ at one byte only:

- conflict offset: 1125;
- Triple: `3`;
- Quad: `4`.

Correct product behavior:

- one true-conflict row for that value;
- choices: Vanilla / Triple / Quad / Custom (where safely encodable);
- Fly is **not** a competing whole-mod choice;
- Fly’s independent `BP_PlayerBase` changes remain merged after choosing 3/4/etc.

Expected merged hashes captured in preview28 validation:

### Choose Triple + Fly

- `.uasset`: `f45c4ef94522998fe747bc97df8fd3630e60207d32643a2e99e41c748bea10c0`
- `.uexp`: `3375ff19e9e81225f3821c98651714f20f1258398e82c71196c131034ecaf5ea`

### Choose Quad + Fly

- `.uasset`: `f45c4ef94522998fe747bc97df8fd3630e60207d32643a2e99e41c748bea10c0`
- `.uexp`: `02a5bce36d7bc98b67a287985e376fd03176582d0d6dd3850650396587daefc6`

### Choose Vanilla

- `.uasset`: `0bc56b07d7014acbc81ca296105a225538788dae3c22b049b775412d48be9e67`
- `.uexp`: `463642a3e2d4dc77e00e03e0823ff81ae95dcb035c32b99be5ba597197ae2992`

### Custom 5

- `.uasset`: `f45c4ef94522998fe747bc97df8fd3630e60207d32643a2e99e41c748bea10c0`
- `.uexp`: `0823ebfd5da8965e3c3cbbac5e3607ddd5f218f1f9a6fdb9d80023ddec0bc6a7`

## 8.2 Early Aquatic Construction Kit

Uploaded PAK SHA-256:

`4f682b17bb04e49042e8fc99be9f4ae64546e562c33545b7a7df628e774a3b1a`

Preview27’s StaticItem adapter rejected exactly one semantic leaf:

```text
Rows[WaterBuildKit].Rank
Property type: IntPropertyData
current: 2
desired: 1
```

Preview28 adds generic Int32 fixed-size transfer.

Expected combined current-layout StaticItem `.uexp`:

`c1720969e6fac5fbf1a818ece1522a41fcb42bddac74348d8b4bc99781bb2254`

The first 124 patches still reproduce the previously runtime-confirmed Fly+Food+Stack golden; the Early Aquatic Rank edit adds the next supported patch.

## 8.3 Expected Analyze result for the captured preview28 development fixture

```text
Shared: 4
merged automatically: 3
true-conflict decisions: 1
unsupported: 0
identical: 0
```

The one decision must be Triple vs Quad inside `BP_PlayerBase`.

**Status:** preview28 documents/static-fixture-validates this expectation. In the material supplied at handoff time, this full preview28 path has not yet been confirmed by a fresh user runtime test after Build/Deploy. Do not report it as runtime-proven until that test is completed.

---

# 9. Captured preview27 failures that preview28 is intended to fix

The supplied `PMM_preview27_test_workspace.zip` contains two captured preview27 runs.

One run with one MultiJump variant routed:

- `BP_PlayerBase` -> `RelocatableAuto`;
- BreedFarm -> `RelocatableAuto`;
- StaticItem -> `Unsupported` because of Early Aquatic IntProperty;
- PlayerStatus DataTable -> `SupersetAuto`.

A later run with both Triple and Quad routed:

- `BP_PlayerBase` -> `Unsupported` (`secondary .uasset changes size`);
- BreedFarm -> `RelocatableAuto`;
- StaticItem -> `Unsupported` (Early Aquatic IntProperty);
- PlayerStatus DataTable -> `SupersetAuto`.

Preview28’s two main changes are therefore directly motivated by real captured failures:

1. `IntPropertyData` support for Early Aquatic;
2. anchor-variant true conflicts in RelocatableDelta for Triple vs Quad.

---

# 10. Development chronology and lessons

## Pre-app manual merge

The manual Fly + Stack + NoSpoil PAK worked on the first practical attempt because it preserved a real cooked base and applied only validated localized edits. This remains the architectural north star.

## Preview14

Early automatic-merger approach. Still fundamentally aimed at broad structured reconstruction. Useful only as historical context.

## Preview15

Attempted to formalize `StructuredRewrite`/binary concepts, but real logs showed Analyze choosing `StructuredRewrite` and Build failing semantic round-trip on BreedFarm. First run also downloaded portable .NET and dependencies. This demonstrated that parser success + semantic equality does not make generic full cooked reserialization safe.

## Preview16

Moved away from JSON reconstruction but still mutated a full UAsset object and called `UAsset.Write()`. It also regressed to moving dependency choices (`net10.0`, floating UAssetAPI). This was the point where the project explicitly abandoned the universal writer as the core architecture.

## PMMCore v0.1 / v0.2

Separated the problem from the GUI.

- v0.1: conservative N-provider binary merge prototype;
- discovered that Fly/Food and current Stack/Vanilla can be different cooked layouts;
- v0.2: semantic-to-current-layout golden proof; Python reference reproduced the golden behavior.

## PMMCore v0.3 / v0.3.2

Ported the core idea to C#. The user executed the acceptance gate on Windows. v0.3.2 passed seven spec tests plus the real golden reproduction.

This is the first C# milestone that should be kept when reconstructing the project.

## Preview17

First reintegration into the Windows app. `ZstdSharp.dll` was missing, so the StaticItem adapter never really ran; the app incorrectly degraded an infrastructure failure into whole-asset fallback. Lesson: infrastructure errors must never become compatibility choices.

## Preview18

Dependency closure improved, but a serious semantic-cache bug remained: cache identity used only `.uasset`. Fly and Food share the same stale `.uasset` but have different `.uexp`, so one provider’s semantic JSON was reused for the other. The resulting patch was effectively Stack-only.

## Preview19

Cache identity changed to the complete cooked family (`.uasset + .uexp + .ubulk + sizes`). Added zero-patch guards. Startup then exposed stale PMMCore reuse problems.

## Preview20–23

Primarily runtime/setup contract fixes:

- exact Core version identity;
- avoid reusing stale executables;
- framework-dependent vs self-contained packaging lessons;
- ultimately run managed Core via PMM’s located portable `dotnet` host;
- replace fragile textual `--version` checks with stable metadata/health checks.

These versions are less important for merge logic than for setup history.

## Preview24

Major milestone: user confirmed the app-generated overlay made Fly + Food + Stack all work in Palworld. This is the first runtime-confirmed application milestone of the new architecture.

## Preview25

Patch awareness/metadata and persistent Analyze state ideas were introduced. Current patches should be recognized as PMM outputs rather than re-fed as source mods.

## Preview26–27

Patch backup/recovery and UI lifecycle improvements; preview27 also captured the Early Aquatic and MultiJump limitations that motivated preview28.

## Preview28

Current implementation:

- PMMCore 0.7.1;
- value-level conflict contract;
- StaticItem Int32 support;
- Relocatable anchor-variant conflict model;
- Import -> Analyze -> Build -> Deploy separation;
- Disable/backup/delete library controls;
- persistent Analyze completion state;
- deployment suppression rules for exact/quasi duplicates.

---

# 11. Things that must NOT be reintroduced

1. Do not use `UAsset.Write()` as a generic production merger.
2. Do not use floating NuGet versions.
3. Do not choose the first Unreal version that merely “does not throw” and call it validated.
4. Do not key semantic caches by `.uasset` hash alone; semantic payload may live in `.uexp`.
5. Do not interpret adapter/internal exceptions as user compatibility conflicts.
6. Do not silently emit an unchanged anchor when differing providers produced zero inferred patches.
7. Do not let PMM-generated overlays become source providers.
8. Do not make Import or Build mutate Palworld; Deploy is the synchronization boundary.
9. Do not ask the user to choose a whole mod when only one parameter overlaps.
10. Do not claim arbitrary Blueprint/Kismet merging is universally solved. Unsupported structural cases are acceptable until a proven adapter exists.

---

# 12. Validation levels — use these terms precisely

## Runtime-proven

Confirmed by loading/running in Palworld.

Known milestones:

- manual Fly + Stack + NoSpoil golden;
- preview24 application overlay with Fly + Food + Stack functioning.

## Golden/fixture-proven

Output hashes or structural expectations match real captured assets, but full runtime behavior may not yet have been re-tested.

Examples:

- PMMCore v0.3.2 golden reproduction;
- Early Aquatic preview28 expected StaticItem hash;
- MultiJump Triple/Quad + Fly expected hashes;
- BreedFarm relocatable composition;
- PlayerStatus superset proof.

## Static-only

Source/package checks, not Windows/Palworld execution.

Preview28’s QA document explicitly states that the build container could not execute WPF/Palworld and that the next target is actual application validation.

Do not blur these categories in future reports.

---

# 13. Current next-step test protocol

Use preview28 and the supplied real test PAKs.

1. Start PMM normally.
2. Ensure active set contains the existing source mods plus:
   - EarlyAquaticConstructionKit;
   - MultiJumpTriple;
   - MultiJumpQuad.
3. Analyze.
4. Expected summary:

```text
Shared 4 / auto 3 / true conflict 1 / unsupported 0
```

5. Inspect the single true-conflict row:
   - competitors must be Triple vs Quad;
   - Fly must not be presented as a whole-file competitor;
   - Vanilla/Custom should be offered only if encoder safety is proven.
6. Choose Triple first.
7. Build local overlay.
8. Deploy.
9. Runtime test:
   - Fly behavior still works;
   - Triple jump works;
   - Stack/zero weight works;
   - NoSpoil works;
   - Early Aquatic behavior works;
   - previously validated unrelated conflict pairs remain functional.
10. Repeat with Quad if needed, using Remerge/change decision -> Build -> Deploy.

If Analyze produces any Unsupported, inspect the adapter’s exact reason and the real provider bytes/semantic maps. Do not fall back to whole-file winner selection.

---

# 14. Publication-oriented work after preview28 passes

Once the above runtime fixture passes, the project can shift from architecture rescue to product hardening:

- UI hierarchy and terminology cleanup;
- clearer “active / disabled / deployed / patch-current / patch-stale” states;
- patch details panel listing reconciled mods/assets;
- deployment preview/diff before changing `~mods`;
- version/update strategy for mappings/repak/PMMCore;
- bundled diagnostics export;
- restore/recovery workflow;
- user-facing explanation of Unsupported vs True Conflict;
- localization cleanup;
- signed/reproducible release packaging if desired;
- a small public fixture suite made only of distributable/synthetic data plus hashes for non-distributable mod fixtures.

Do not broaden adapter support merely to claim “universal”. Prefer explicit safe coverage and honest Unsupported states.

---

# 15. Artifact map in this handoff bundle

## Current

`artifacts/current/PalModMerger-v1-preview28.zip`

- latest implementation;
- contains PMMCore 0.7.1 source;
- contains README, architecture, developer guide, handoff, QA and preview28 fixture validation metadata.

## Golden / reconstruction inputs

`artifacts/golden/3modmerge_sources_and_manual_golden.zip`

- Fly source;
- Food source;
- Stack source;
- manual runtime-working Fly+Stack+NoSpoil PAK.

`artifacts/golden/PMMCore-v0.3.2.7z`

- first C# Core milestone that passed the real golden gate on Windows.

`artifacts/golden/PMM_Fixture_20260815-163254.zip`

- captured Vanilla/provider cooked families used to derive the architecture.

`artifacts/golden/PMM_SemanticOffsets_20260815-172050.zip`

- semantic exports used in the golden investigation.

## Runtime application milestone

`artifacts/milestones/PalModMerger-v1-preview24.7z`

- application build from the point where the user confirmed Fly/Food/Stack worked.

`artifacts/milestones/zzzzzzzzzz_PMM_Merge_20260815_230359_P.pak`

- captured preview24 overlay, SHA `7330e1...`.

## Historical architecture pivots

`artifacts/milestones/PalModMerger-v1-preview14.zip`  
`artifacts/milestones/PalModMerger-v1-preview15.zip`  
`artifacts/milestones/PalModMerger-v1-preview16.zip`  
`artifacts/milestones/PalModMerger-v1-preview17.7z`  
`artifacts/milestones/PalModMerger-v1-preview18.7z`  
`artifacts/milestones/PalModMerger-v1-preview19.7z`

These are for archaeology/regression tracing. Do not resume development from them instead of preview28.

## Current stress-test inputs

`artifacts/test_inputs/EarlyAquaticConstructionKit_P.pak`  
`artifacts/test_inputs/MultiJumpTriple_P.pak`  
`artifacts/test_inputs/MultiJumpQuad_P.pak`

## Captured workspace

`artifacts/captured_workspaces/PMM_preview27_test_workspace.zip`

Contains the preview27 workspace, source mod library, logs, semantic caches, last-scan/merge-plan data and the previously generated overlay. Useful for reproducing the failures preview28 is meant to fix.

---

# 16. Essential hashes

```text
Current preview28 ZIP
9fa1fd9e10cd21ca61bfac8fa153e999f45d1f1e6bb985eb1163500da19324e5

Manual runtime golden PAK
42a055bc5dba79ca16366038e970a9ec21a27fec3d447577112faa7e20e16916

Runtime-confirmed preview24 overlay
7330e1aee0c5e4f904b697d5071b9532b0f956225d6de61cdc2b788474743e33

Golden StaticItem .uexp
8f2ab2933c85bde0e8c9d74b39e466f9ad1c3b41c042106f7ffc624dea624bf8

Preview28 EarlyAquatic expected StaticItem .uexp
c1720969e6fac5fbf1a818ece1522a41fcb42bddac74348d8b4bc99781bb2254

MultiJumpTriple PAK
5a35b07ff3509bbed245eefb5ca0bf2dda8537738d5759026661871ff152e604

MultiJumpQuad PAK
04ff4ef1eb636c217507d2b18f0cef03f8bdb46fc18a2eedcb70e92af4c620cc

EarlyAquaticConstructionKit PAK
4f682b17bb04e49042e8fc99be9f4ae64546e562c33545b7a7df628e774a3b1a
```

See `CHECKSUMS.sha256` for the handoff bundle’s complete file checksum list.

---

# 17. Suggested first message in a new chat

Use the text in `START_HERE_NEW_CHAT.md` and upload the whole continuation bundle (or at minimum preview28 + the three stress-test PAKs + this handoff document).

The next assistant should inspect the actual preview28 code and supplied fixtures before changing anything.
