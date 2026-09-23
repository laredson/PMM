# NF02B pre-inventory - direct PMMRuntime consumers

Status: **PRE-INVENTORY COMPLETE FOR DISTRIBUTED POWERSHELL / MIGRATION NOT STARTED**
Branch HEAD scanned: `5425c8d5e7b324341cf9323ff6565941d241fbd3`
Date: 2026-09-23

This inventory was created because NF02A Windows acceptance could not execute in
the current Linux container. It advances NF02B analysis only; no distributed
PMM behavior was changed.

## Scan coverage

The exact branch Git tree was enumerated through the authenticated repository
connector.

Every distributed `.ps1` / `.psm1` file under `PMM/` was read and searched:

- files scanned: **132**
- files containing the token `PMMRuntime`: **18**
- active files that directly execute the Runtime binary: **13**
- direct Runtime native invocation sites: **18**
- central path helper files: **1**
- native snapshot/inventory files: **1**
- nominal capability references with no Runtime executable launch: **3**

This is exhaustive for distributed PowerShell at this HEAD. NF02B still requires
the normal exact local grep before deletion because JSON/config/native source and
future branch deltas must also be included in the final zero-caller proof.

## Active direct consumers

| File | Runtime command(s) | Invocation sites | Notes |
| --- | --- | ---: | --- |
| `Engine/Runner/Operations/start.ps1` | `dependencies ensure --if-needed`, `ui` | 2 | legacy script fallback startup |
| `Engine/Runner/Operations/validate.ps1` | `self-test` | 1 | legacy validation route |
| `Modules/AIIO/AIIO.PendingDataService.ps1` | `archive create` | 1 | incremental handoff ZIP |
| `Modules/AIIO/AIIO.ps1` | `archive create` | 1 | main AIIO handoff ZIP |
| `Modules/AIIO/AIIO.ResponseService.ps1` | `archive create` | 2 | candidate validation + incremental ZIP |
| `Modules/AIIO/AIIO.SessionService.ps1` | `archive create` | 1 | AIIO session package |
| `Modules/Bootstrap/Setup-Dependencies.ps1` | `dependencies ensure` | 1 | public dependency wrapper |
| `Modules/CKL/KnowledgeContributionService.ps1` | `archive create` | 1 | knowledge contribution ZIP |
| `Modules/FixLab/FixLabService.ps1` | `archive extract`, `archive create` | 2 | source ZIP + handoff ZIP |
| `Modules/Library/LibraryService.ps1` | `archive extract` | 1 | cancelable mod ZIP import |
| `Modules/Merge/MergeEngine.ps1` | `archive extract` | 1 | returned solution import |
| `Modules/Saves/SaveService.ps1` | `archive create`, `archive extract` | 2 | world backup/restore |
| `Modules/Theme/ThemeEditorService.ps1` | `archive create` | 2 | theme pack + AI request |

### Command totals

- `archive create`: **10**
- `archive extract`: **4**
- `dependencies ensure`: **2**
- `ui`: **1**
- `self-test`: **1**

Total: **18** direct native invocations.

## Central helper / inventory

### `Modules/Shared/Paths.ps1`

Current:

```powershell
function Get-PMMRuntimePath { Join-PMMPath 'Engine' 'PMMRuntime.exe' }
```

This is the central migration point used by most feature callsites.

After accepted unified PMM.exe integration, NF02B should preserve the helper name
for compatibility but return the application executable:

```text
<AppRoot>/PMM.exe
```

Each native invocation must then include an explicit leading `runtime` argument.

Example:

```text
before: PMMRuntime.exe archive create ...
after:  PMM.exe runtime archive create ...
```

This preserves native stdout/stderr and `$LASTEXITCODE` semantics with minimal
surface change.

### `Modules/Operations/ModuleRuntime.ps1`

`Get-PMMNativeModuleSnapshot` currently inventories:

```text
PMM.exe
Engine/PMMRuntime.exe
Engine/PMMFixLab.exe
...
```

Do not remove the PMMRuntime snapshot member during NF02B. Remove it in NF02C
when the legacy executable is actually deleted.

## Nominal references, not executable consumers

These contain Runtime terminology but do not launch PMMRuntime.exe:

- `Modules/Analysis/MCP.Analysis.ps1` -> `pmm_runtime_capabilities`;
- `Modules/Analysis/Repair.Service.ps1` -> `Get-PMMRuntimeCapabilities`;
- `Modules/Presentation/DeepAnalysis.UI.ps1` -> capability function consumer.

The conceptual Runtime role remains valid after single-EXE convergence, so these
names do not need to change merely to remove the physical Runtime EXE.

## Non-PowerShell package references already known

NF02A/NF02C must also update or classify:
- `Engine/Runner/routes.json`;
- `Resources/Metadata/runtime-contract.json`;
- `Resources/Metadata/RELEASE_MANIFEST.json`;
- `Resources/Metadata/SHA256SUMS.txt`;
- canonical Host compatibility logic that recognizes old
  `Engine/PMMRuntime.exe` routes.

The compatibility recognition may remain for one transition release if desired;
the distributed route table itself should use `PMM.exe runtime ...`.

## Recommended NF02B migration order

Only after NF02A Windows acceptance and first PMM.exe package integration:

1. `Paths.ps1` runtime path -> `PMM.exe`.
2. Archive callsites:
   - add leading `runtime` argument;
   - preserve output capture, exit codes and cancellation.
3. `Setup-Dependencies.ps1`:
   - target root PMM.exe;
   - invoke `runtime dependencies ensure ...`.
4. Runner legacy `start.ps1` / `validate.ps1`:
   - target root PMM.exe;
   - prefix Runtime commands.
5. Re-run feature regressions for:
   - AIIO packaging;
   - CKL contribution package;
   - FixLab ZIP input/handoff;
   - Library ZIP import/cancel;
   - manual solution ZIP import;
   - save backup/restore;
   - theme export/AI request;
   - dependency wrapper;
   - legacy runner validation.
6. Exact local repository grep.
7. Require zero active direct distributed callers to
   `Engine/PMMRuntime.exe`.
8. NF02C removes the executable and snapshot/checksum/manifest entry.

## Important gate

Do **not** apply the migration in this pre-inventory commit.

The currently distributed PMM.exe does not yet provide the accepted
`runtime` role. Migrating these callers before NF02A integration would break
features on the current package.
