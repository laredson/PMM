# Palworld Manager Merger v1.1 — final validation target

v1.1 is intentionally a focused release over the runtime-proven v1.0 baseline.

## What changed

1. The DataTable semantic map now preserves duplicate Unreal row names using occurrence-qualified internal identities instead of aborting the entire table.
2. A new exact `KnownRecipeAuto` route can reuse a provider cooked family only when a production recipe matches the exact asset, mappings, Vanilla family, full provider hash set and every provider family hash.
3. The first production recipe is AI_HANDOFF case `73bb3d0635170dad4cb3f7a8`: RushRoar Leather Drop v2 + FasterMounts on `DT_PalMonsterParameter_Common`.
4. Persistent low-to-high merge priority is part of Build identity (merge-plan schema 14 / build-manifest schema 8). The library can be reordered by drag/drop, direct numeric insertion, or one-step buttons.
5. Language and conflict-decision ComboBoxes use one explicit sizing/typography contract.

The manual AI solution for this exact case is already runtime-proven. It was byte-for-byte identical to the FasterMounts cooked family. The test below validates that v1.1 can reproduce that proven result automatically, without importing the manual solution.

## Offline-first package test

Use the final public `Palworld-Manager-Merger-v1.1.zip`, extracted to a fresh folder.

1. Extract the generated `dist\Palworld-Manager-Merger-v1.1.zip` into a new folder.
2. Confirm the clean package contains no `Tools\dotnet\sdk`, stale `dotnet-host.txt`, Oodle DLL, source PAK, generated merge, save backup or prior runtime state. The exact .NET Runtime 8.0.30 may be reused from the machine or installed portably by Setup when needed.
3. Run `Start.cmd`. If an exact .NET Runtime 8.0.30 is already available, startup should require no runtime download. Otherwise Setup may download the pinned Microsoft win-x64 runtime once, verify SHA-512, install it portably, and continue. The status line must report `.NET 8.0.30 OK`, `PMMCore OK` and `AssetReader OK`.
4. Close/reopen PMM and confirm the same no-network startup path.
5. Optional repair proof: after Setup has installed the portable runtime, deliberately remove or corrupt `Tools\dotnet\8.0.30\dotnet.exe`, then run `Start.cmd` with Internet available. Setup should recover the pinned runtime archive, verify SHA-512, restore a working exact runtime, and pass self-tests. Restore/re-extract the clean package afterward.

Oodle is intentionally not part of this startup test. A later Analyze may cause pinned repak to obtain Oodle on demand when the inspected PAK requires it.

## Required test

Use the exact provider versions from the contribution:

- RushRoar Leather Drop v2 PAK SHA-256: `b663b49a2a0825b01c45bfd223b2114e7dfc30bf108d8250aa89f6d82ee4a266`
- FasterMounts4xAllWorkSuitabilitiesLevel10 PAK SHA-256: `f91dd7ae1aa0d5ef1399d9185cee74a4ce06d907cfaf4c936489dbdf67b21e64`
- mappings SHA-256: `604550ba90faab1e394c2789f38eeff625493d3729c2d7f6a6058bfedb90a67b`

Do **not** import/use the old manual experimental solution for this test.

1. Start v1.1 and allow dependency setup/self-tests to complete.
2. Import/use the same active source library containing RushRoar v2 + FasterMounts and the established regression stack.
3. Run **Analyze**.
4. `DT_PalMonsterParameter_Common.uasset` must show:
   - Result: **Auto merged**
   - Adapter: **Runtime-proven recipe**
   - Unsupported: **0 for this asset**
5. Build a new compatibility patch.
6. Deploy it.
7. In Palworld verify RushRoar Leather Drop v2 behavior and FasterMounts/work-suitability behavior.
8. Smoke-check the established Fly + Wing + selected finite MultiJump + Stack/ZeroWeight + FoodNeverSpoils + Early Aquatic stack.


## Priority / UI test

Before publishing, perform this Windows UI pass:

1. Pick a mod that is not already first/last. Type `1` in **Order** and leave the field or press Enter. It must become #1 and every mod previously above it must shift down by one.
2. Type a number larger than the current library size. The mod must become the last item; intervening mods shift up and the displayed order remains exactly `1..N` with no duplicates/gaps.
3. Drag a row onto the upper half of another row and verify it inserts immediately before; repeat onto the lower half and verify it inserts immediately after. With a long list, dragging at the top/bottom edge should auto-scroll.
4. After an actual reorder, the previous Analyze must be treated as stale for a new Build. Re-run Analyze and verify an overlapping conflict defaults to the later/lower-listed provider unless a manual decision exists.
5. Confirm **English/Español**, bulk/source decision ComboBoxes and per-row conflict-decision ComboBoxes have consistent text size, control height, padding and vertical centering.
6. Run the one-step **Earlier / lower priority** and **Later / higher priority** buttons once to confirm they still use the same persisted order.

## Expected safety behavior

The production recipe must **not** match if any pinned input changes: provider PAK hash, provider cooked family, Vanilla cooked family or mappings. In that situation PMM must fall back to ordinary adapters/Unsupported rather than guessing.

## Publish decision

If the automatic recipe path passes the runtime test above, v1.1 can be published. The exact manual solution is already runtime-proven; this final gate proves the new automatic integration path and regression safety.
