# PMM 1.3.2 shared implementation state

Baseline: `c849942a42e8c8a58d7cc2840017bcf4afaf42b6`. Branch: `1.3.2`. Updated 2026-09-12.

## Implemented

- Persistent case service V4 over the compatible V3 envelope: stable origin/conflict identity, immutable revisions, atomic batch visibility/recovery, legacy IDs, revision-bound ZIP/MCP work and input rehash.
- Existing UI assistance entrypoints open cases (Unsupported, Fix Lab, diagnostics, mod creation, themes, Help). Analyze preserves the user objective and extra families/source modes. No automatic handoff or AI dispatch.
- Fixed the `$Item`/`$item` PowerShell collision causing the `Providers` exception.
- Local mapping import/reset, shared active mapping path and explicit partial reader diagnostics. Mapping104 is selected locally, not redistributed. Reader 0.3 changed only after shipped/baseline/source parity; dependencies and PMMCore/Host/Runtime are unchanged.
- Preventive long-path exact extraction plus verified atomic Game Reference publication/recovery. Gura reporter confirmed 1.3.1 works; RC30 report is not a proven 1.3.1 regression.
- Exact FasterMounts/RushRoar historical-baseline recovery and current-layout transfer. Preserves all 1.0.4 fields/passives and the current cooked header. Plan schema 19 rejects older plans and generic anchors that omit current rows/properties.
- Large native output is retained in EngineReports without a main-log write per property.

## Validated

44 case assertions; 20 real bootstrap/WPF handler assertions per language; 15 reference/recovery assertions; 8 mappings assertions; 14 DataTable rejection assertions; unchanged exact 10/1 semantic conflict policy; 11,000-line native output retention; reader parity (36 comparisons / 32 cooked families), source csproj build; MCP bridge 36 and exchange 15 assertions; actual MCP scalar edit/build/readback with revision/value/tamper rejection. WPF XAML, workspace/dependency and MCP reference fixtures passed. All 84 modules parse in PS5.1; clean application layout SmokeTest and 552 checksums pass. The local forced analysis fell from 8m34s to 3m21s after preserving large reports separately.

Staged DataTable build verified 753 rows / 68,523 properties, 10,539 intended changes, all 103 true IsUncapturable flags and current passive values. Header unchanged except proven size bookkeeping. Actual Analyze with Mapping104/schema19: 7 shared, 5 automatic, 1 unsupported, 1 identical. Runtime not verified. Full evidence and reproduction are in [validation](../Docs/Validation/PMM_1_3_2_REPAIR_VALIDATION.md).

## Pending / limitations

- EasyBreeding + NoCollision remains Unsupported. Current BreedFarm has 29 exports vs old mods' 28, new VisualEffect/default/dependency data, and partial decoding (missing BP_InteractableBox_C schema). A safe current-layout Blueprint transfer/candidate is still required. Do not enable the historical whole-family output.
- Persistent BreedFarm case: `AICASE-20260912-202028-a27cf054`. Actual ZIP handoff created locally with exact families, not sent. Faster/Rush case `AICASE-20260912-202029-ea4c2ad7` records NoLongerBlocked; this is not runtime approval.
- No full merge for the blocked source set, no deployment, no game launch tests. User owns crash isolation and reports vanilla starts. Version-related mod incompatibility remains plausible; exact crash cause is unproven.
- Desktop visual inspection unavailable; application evidence is isolated WPF/bootstrap runtime testing. Restart PMM to load the changed modules/reader.
- No public release. Do not ship local Mapping104, Workspace, TestResults or external mod/game bytes.

## Preserved work and next action

The separate 1.4.0-ReUI branch remains parked. Preserve pre-existing untracked MCP research/validation notes, InventoryProbe, SuperInventory, Development/Tools and caches. Do not blanket-add untracked files.

Next development action: investigate the BreedFarm case using current schema/reference evidence and prove a transfer that preserves all 29 exports and opaque bytes; validate the user's independently reported crash findings separately. Before releasing, complete game/runtime checks through the user and the normal clean-payload release gate.
