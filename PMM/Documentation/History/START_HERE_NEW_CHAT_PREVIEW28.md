# Prompt to continue PalModMerger in a new chat

We are continuing development of **PalModMerger (PMM)**, a Windows Palworld PAK compatibility merger.

Read `PMM_MASTER_HANDOFF.md` first and inspect `artifacts/current/PalModMerger-v1-preview28.zip` before proposing changes.

Important contract:

- preserve the union of compatible changes from Vanilla + N mods;
- conflicts are resolved at the smallest proven parameter/byte/property, never by picking a whole mod merely because two mods touch the same file;
- after resolving a same-parameter conflict, all independent same-file changes from other mods must still be merged;
- `Unsupported` blocks Build; it must never silently become a whole-file winner fallback;
- UAssetAPI/AssetReader is read-only; production merge writers patch copied cooked bytes;
- Import changes the PMM library only;
- Build creates a local overlay only;
- Deploy is the only normal operation that synchronizes Palworld `~mods`;
- PMM-generated overlays are managed outputs, never source providers.

Current implementation: **preview28 / PMMCore 0.7.1**.

The next real validation fixture uses:

- FlyMode + FoodNeverSpoils + Stack;
- EarlyAquaticConstructionKit;
- MultiJumpTriple;
- MultiJumpQuad;
- existing captured conflict pairs.

Expected Analyze result for the captured fixture:

`Shared 4 | merged automatically 3 | true-conflict decisions 1 | unsupported 0 | identical 0`

The one decision must be MultiJump Triple vs Quad for their one differing structural value in `BP_PlayerBase`. Fly is not a competing whole-mod choice; its independent edits must remain merged. Early Aquatic’s previous blocker was `Rows[WaterBuildKit].Rank` IntProperty 2 -> 1; preview28 adds Int32 transfer.

Known runtime-proven reference: the manual Fly+Stack+NoSpoil PAK and the preview24 application overlay. The golden StaticItem `.uexp` hash is `8f2ab2933c85bde0e8c9d74b39e466f9ad1c3b41c042106f7ffc624dea624bf8`.

Do not restart from the old StructuredRewrite/UAsset.Write architecture. Continue from preview28. If preview28’s real Analyze/Build/Deploy test fails, reproduce/debug the failing adapter using the supplied real PAKs and captured workspace, then patch the current architecture.
