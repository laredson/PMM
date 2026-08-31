# Runtime-proven compatibility evidence

**Evidence date:** 2026-08-17  
**Meaning:** the listed behaviors were observed working in Palworld for the captured/tested mod versions. This is stronger than a static/hash fixture but is not a blanket guarantee for future updates.

## Current combined test stack

The release line has runtime evidence for a combined compatibility overlay in which the following shared families coexist:

### BP_PlayerBase

Providers:

- FlyMode
- MultiJumpDouble
- MultiJumpTriple
- MultiJumpQuad

Observed rule:

- Double / Triple / Quad appear as one N-provider jump-count decision.
- The selected value works in-game.
- Fly's independent same-file changes remain functional after the selected jumps.

Adapter: `RelocatableDelta-v2`.

### BP_WingGlider

Providers:

- FlyMode
- WingPackNoWingCells_VisibleOnlyWhileFlying

Observed behavior:

- the real Wing cooked asset structurally contains the Fly changes required by this family;
- wing mesh is visible during Fly/glider flight in-game;
- the rest of the established merged stack remained functional.

Adapter: `ContainedDeltaSuperset-v1`.

### DA_StaticItemDataAsset

Providers include:

- FlyMode
- FoodNeverSpoils
- StackSize999999999ZeroWeight
- EarlyAquaticConstructionKit

Observed behavior includes Fly-related item intent, no-spoil behavior, stack/zero-weight behavior and Early Aquatic behavior continuing in the combined runtime stack.

Adapter: `StaticItemDataAssetAdapter/v0.4.0`.

### BP_BuildObject_BreedFarm

Providers:

- EasyBreeding
- NoCollisionFarmsAndExped

The relocatable composition was included in runtime-working application overlays.

### DT_PlayerStatusRankMasterDataTable

Providers:

- FreeEnhancePlayerAbility
- IncreasedPlayerStatCaps1000Free

The proven superset family was included in runtime-working overlays.

### RushRoar Leather Drop v1

The first standalone PAK replaced the Ranch Bone output with Leather and did not need to enter the shared-asset overlay in the captured library. The user confirmed the Leather drop works while the complete active test stack remains functional.

### RushRoar Leather Drop v2 + FasterMounts — AI_HANDOFF case

Providers:

- RushRoar Leather Drop v2
- FasterMounts4xAllWorkSuitabilitiesLevel10

The shared `DT_PalMonsterParameter_Common` family was Unsupported in v1.0 because the old DataTable semantic map rejected duplicate row ID `RAID_NightLady_Dark`. PMM generated AI_HANDOFF case `73bb3d0635170dad4cb3f7a8`. The returned manual solution reused the exact FasterMounts cooked family for that asset; PMM validated/imported it, and the user confirmed the resulting complete merged setup works in Palworld.

The manual/AI solution is therefore runtime-proven for the pinned hashes. v1.1 promoted those exact hashes to a production recipe.

RC26 also records the narrow semantic reason already established by that evidence. RushRoar changes `Rows[Boar].WorkSuitability_MonsterFarm` from 0 to 1, enabling ranch work. FasterMounts sets that same field to 10 as part of the full suitability block, so its value preserves RushRoar's enablement requirement. RushRoar's separate `BP_Boar` and spawn-action assets remain deployed as normal source content.

The RC26 semantic fallback is not a generic numeric policy. It is eligible only after the current DataTable adapter reports the exact asset/path, the exact two competing providers and canonical values 10/1. It selects FasterMounts only for that field and rebuilds from the current cooked families. Any changed path, provider set or value tuple remains a normal decision. Windows/in-game acceptance of the RC26 implementation is still required before publication.

## Why exact versions matter

PMM knowledge stores exact hashes where available. If a mod or Palworld update changes a provider, old cooked-output evidence becomes historical evidence. New bytes must still pass current Analyze/proof rules. A separately declared semantic rule may survive a byte/hash change only when its exact current path/provider/value contract is independently reproduced by the normal adapter; it never authorizes unrelated changes.
