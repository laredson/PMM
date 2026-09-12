# PMM 1.3.2 repair validation

Date: 2026-09-12. Branch: `1.3.2`. Baseline: `c849942a42e8c8a58d7cc2840017bcf4afaf42b6`.

## Scope and user steering

Repair the existing 1.3.1 workspaces. The separate `1.4.0-ReUI` redesign remains parked. Cases replace immediate AI handoff creation at assistance entrypoints; ZIP/MCP/client are choices within the same case. No public release or game deployment is part of this validation.

The user owns game launch/mod isolation and explicitly requested no game testing. No successful game launch or runtime validation occurred in this repair. An earlier launch attempt before that instruction returned no running game and supplies no evidence. The user subsequently reported that Gura works in 1.3.1 and that the game starts without mods. The original Gura report was from RC30; it does not establish a 1.3.1 regression. Long-path/recovery changes are preventive hardening.

## Findings and implemented behavior

- The handoff `Providers` exception was a PowerShell case-insensitive variable collision: `$item = Get-Item` replaced the `$Item` plan parameter. Renamed the file variable, and exercised the actual Vanilla/provider extraction branch.
- Completed Analyze registers one persistent case per unsupported asset/provider set. Repeated analysis keeps identity and immutable evidence revisions; case goals, additional sources, selected source modes and history survive refresh. Old case/session/review IDs remain linked. Interrupted case publication stays invisible until committed and can be recovered idempotently.
- Fix Lab, diagnostics, mod creation, themes and Help open cases. Opening a case creates no ZIP and sends nothing to an AI service. Explicit ZIP/MCP exchanges bind the evidence revision and revalidate inputs before work. Imported work orders cannot execute themselves or approve a merge.
- Settings imports a local `.usmap` into an immutable hash-addressed store. All affected readers and transports use that selection. Invalid import leaves the previous selection intact; reset recovers malformed selection state. The bundled mapping remains unchanged.
- Reference extraction handles long Windows paths independently of registry policy. It verifies every selected output, retains a previous complete reference until atomic metadata publication, and recovers interrupted swaps. Reference freshness and semantic readability are reported separately.
- AssetReader 0.3 reports swallowed decoder errors and `Partial` readability instead of treating opaque exports as successful semantic decoding. It remains read-only. PMMCore, Host, Runtime and reader dependencies are unchanged.
- Large native reports are retained in `Workspace/Logs/EngineReports`, with a summary in the main log. All native output remains available to callers and diagnostics. This avoids a cross-process log write per property. Two successive full forced analyses of the same library took 8m34s before this change and 3m21s afterward, with the same 5/1/1 result; this is a local observation, not a general benchmark.

## Palworld 1.0.4 evidence

Local Steam build: `25094871`. Current `Pal-Windows.pak` size: 43,649,125,878 bytes; mtime UTC: `2026-09-07T03:22:50.9842083Z`.

The previous mapping, SHA-256 `604550ba90faab1e394c2789f38eeff625493d3729c2d7f6a6058bfedb90a67b`, cannot decode schema index 90 of `PalCharacterParameterDatabaseRow`. The locally supplied Mapping104, SHA-256 `369a9413f3ea9faa7cd409f57cb70a02feb56ad865a306a9a141cf6cdc969153`, reads all 753 current rows and 91 properties per row. Mapping bytes are not included in this branch/release payload. Obtain the mapping from its [author's file page](https://www.nexusmods.com/palworld/mods/2854?tab=files), extract the `.usmap`, and import it in Settings.

### Faster Mounts + RushRoar

The original mod PAK hashes are unchanged. Current Vanilla contains the new `IsUncapturable` field and changed passive-skill values. Selecting the old FasterMounts cooked anchor would omit game changes even if the DataTable reader succeeds. The new generic guard rejects an anchor missing current rows or properties. Plan schema 19 invalidates earlier plans.

The narrow current-layout rule requires exact mapping, current Vanilla, complete provider PAK and family hashes. It reconstructs historical Vanilla from the exact RushRoar family and verifies both original historical family hashes already pinned in CKL. Only genuine historical mod deltas are projected onto current data. Zero-masked i32/f32 fields are materialized losslessly where needed, with exact framing/header checks and readback of every unchanged value before the native scalar adapter runs. The original current cooked bytes and all 91 fields are retained except proven scalar deltas and generated size/mask bookkeeping. No whole-asset UAsset.Write is used.

A staged build and independent value verification passed: 753 rows, 68,523 properties checked, 10,539 intended changes, all 103 true `IsUncapturable` flags preserved. The existing exact Boar ranch 10/1 dominance rule still resolves only that declared conflict. New game passives are preserved where neither mod changed the historical property. The output header matches current Vanilla outside the two proven size fields. Runtime on 1.0.4 remains unverified.

Unversioned encoding reference: [UAssetAPI FUnversionedHeader](https://github.com/atenfyr/UAssetAPI/blob/master/UAssetAPI/Unversioned/FUnversionedHeader.cs) and [FFragment](https://github.com/atenfyr/UAssetAPI/blob/master/UAssetAPI/Unversioned/FFragment.cs).

### EasyBreeding + NoCollision

Still **Unsupported**. Current BreedFarm has 29 exports; both old mods have 28. The current family adds `VisualEffect` and related import/dependency/default-object data. Current uasset is 8,642 bytes; EasyBreeding 8,405; NoCollision 8,379. Two exports remain opaque because the available mappings lack `BP_InteractableBox_C` schema. The old relocatable/superset proof cannot establish preservation of this changed topology.

This is a current-game layout difference, not evidence that 1.3.1 removed the historical merge rule. The evidence/diagnostic is stored in persistent case `AICASE-20260912-202028-a27cf054`; a real case-worker handoff with exact current/provider family parts was successfully created locally. It was not sent. Faster/Rush case `AICASE-20260912-202029-ea4c2ad7` records that it is no longer blocked without claiming gameplay validation.

A full merge of this source set remains blocked by BreedFarm. No full merge/deployment or crash-cause claim is made. To support it automatically, a current-layout Blueprint transfer must prove all references, opaque bytes and intended EasyBreeding/NoCollision changes, or an exact externally supplied candidate must pass the case validation workflow.

## Validation evidence

| Layer | Check | Result |
|---|---|---|
| PS5.1 fixtures | `cases_v4_regression.ps1` | 44 assertions: identity, revisions, interrupted publication, legacy linkage, stale work orders, source rehash, goal/reference preservation and ZIP sources |
| WPF application fixture | `v132_bootstrap_regression.ps1 -Language en/es` | 20 assertions per language; actual bootstrap button handlers, external process boundary forbidden |
| WPF runtime | `wpf_xaml_runtime_regression.ps1` | Materialization passed; no desktop visual inspection claim |
| Reference fixtures | `v132_reference_recovery_regression.ps1` | 15 assertions; legacy MAX_PATH policy, traversal/topology and publication recovery |
| Mapping fixtures | `v132_mappings_regression.ps1` | 8 assertions; immutable local selection, invalid import and reset recovery |
| Core policy fixture | `rc26_semantic_compatibility_regression.ps1` | Exact 10/1 conflict accepted; altered field/values/provider set rejected; schema 19 |
| Layout fixtures | `v132_datatable_guards_regression.ps1` | 14 assertions; PAK/family/mapping/Vanilla pins, row occurrence and property preservation, header rejection |
| Native diagnostic fixture | `v132_core_output_regression.ps1` | 11,000 unique lines and failure status retained, one main-log write, deduplicated repeat, short output preserved |
| Reader source parity | `v132_reader_regression.ps1` | 36 comparisons over 32 local cooked families; baseline, shipped and rebuilt reader JSON/DataTable parity |
| Native source build | `dotnet build` with `BundledReferenceDir` | .NET 8 csproj build passed, zero warnings/errors, output isolated under TestResults |
| MCP fixtures | `mcp_bridge_regression.ps1`, `mcp_exchange_regression.ps1` | 36 + 15 assertions; scope, file hashes, revisions and stale completion |
| MCP real cooked fixture | `mcp_edit_regression.ps1` | Scalar candidate build and PAK readback; missing/stale revisions, stale values and tampered output rejected |
| Existing integration fixtures | workspace/dependencies and MCP reference | Passed with the new mapping/case services |
| Local staged cooked output | `v132_datatable_local_regression.ps1`, `v132_datatable_values.py` | Full table values and header preservation passed |
| Clean payload fixture | SmokeTest, inventory and SHA-256 | 553 application files / 552 checksum entries; Workspace excluded |
| Static PS5.1 | All module scripts | 84 parsed successfully |
| Local application worker | Analyze, schema 19, Mapping104 | 7 shared assets: 5 auto, 1 unsupported, 1 identical; no decisions |
| Game runtime | launch, loading saves, behavior/crash checks | Not performed; user handles these |

Raw fixtures, mappings, extracted families, ZIPs and logs live only in ignored `Development/TestResults` or local `PMM/Workspace`. They must never be staged, committed or packaged. The packaged reader SHA-256 is `15b226b1dad2e32fded53d2ea52fbf7b038dba3d977ed2908a41424f43633be8`.

## Reproduction and limits

Use Windows PowerShell 5.1 for the `.ps1` fixtures. Local DataTable/reader tests require the user's exact mod PAKs, current extracted reference and selected Mapping104; isolated case/mapping/guard tests do not. Build the reader against the shipped dependency DLLs, never silently substitute newer dependencies. Tests materialize WPF inside isolated roots; native desktop inspection was unavailable. Restart PMM after applying this branch so loaded modules and the reader match the new sources.
