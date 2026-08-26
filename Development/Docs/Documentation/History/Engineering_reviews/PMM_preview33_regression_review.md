# PalModMerger preview33 - regression / acceptance review

Date: 2026-08-16

## Why preview33 exists

Preview32 proved the new Fly + Wing route at Analyze time but the WPF Build wrapper
failed before entering `Build-PMMMerge` because one PowerShell expression could become
a scalar and `.Count` was then accessed under strict member behavior. Separately, the
manual global overlay using Wing's real cooked `BP_WingGlider` was tested successfully
in Palworld, promoting the captured `ContainedDeltaSuperset-v1` relation to a runtime
milestone.

Preview33 is therefore deliberately narrow:

1. fix the Build wrapper failure;
2. preserve the now runtime-proven Fly + Wing adapter byte-for-byte;
3. lock the real MultiJump Double / Triple / Quad N-provider shape into the functional
   PMMCore self-test and knowledge/fixture metadata.

## Build wrapper correction

Preview32:

```powershell
$experimental=if($plan){@(...)}else{@()}
if($experimental.Count -gt 0) { ... }
```

Preview33 forces the complete producer to an object array and uses `Length`:

```powershell
[object[]]$experimental=@(
  if($plan -and $null -ne $plan.Assets){
    $plan.Assets | Where-Object{[string]$_.Mode -eq 'ManualSolutionExperimental'}
  }
)
[int]$experimentalCount=$experimental.Length
```

No merge adapter changes are involved in this fix.

## PMMCore 0.8.1 N-provider self-test

The CLI self-test creates a synthetic three-provider same-layout cluster with requested
values Double=2, Triple=3 and Quad=4. The gate requires:

- one and only one value-level conflict;
- all three requested values to be present in the same conflict;
- Vanilla and Custom support for the proven one-value variant cluster;
- resolving to Triple produces 3;
- Custom=5 encodes 5.

Successful setup prints both:

```text
PMMCORE_SELFTEST_OK 0.8.1
PMMCORE_SELFTEST_NPROVIDER_OK Double=2 Triple=3 Quad=4 Custom=5
```

## Real MultiJump fixture

Offline inspection of the supplied PAKs:

- Double PAK: `73bd0efb4f08ec20996111ace6ae9674cbb787da38ea78ba8d39bf736df449d9`
- Triple PAK: `5a35b07ff3509bbed245eefb5ca0bf2dda8537738d5759026661871ff152e604`
- Quad PAK: `04ff4ef1eb636c217507d2b18f0cef03f8bdb46fc18a2eedcb70e92af4c620cc`
- all `BP_PlayerBase.uasset`: 24,627 bytes, SHA-256
  `f45c4ef94522998fe747bc97df8fd3630e60207d32643a2e99e41c748bea10c0`;
- all `.uexp`: 15,546 bytes;
- exactly one zero-based byte differs: offset 1125;
- requested byte values: Double=2, Triple=3, Quad=4.

`RelocatableDelta-v2` already uses a provider dictionary for anchor variants and the WPF
resolver builds columns dynamically from the competitor list. Preview33 does not add a
provider-count/name special case.

## Critical files deliberately unchanged from preview32

Byte-identical SHA-256 comparison passed for:

- `ContainedDeltaSupersetAdapter.cs`
- `RelocatableDeltaAdapter.cs`
- `BinaryRangeMergeAdapter.cs`
- `SupersetAnchorAdapter.cs`
- `StaticItemDataAssetAdapter.cs`
- `DataTableMergeAdapter.cs`
- `Core/LibraryService.ps1`
- `Core/SaveService.ps1`
- `Mappings/Mappings.usmap`

This keeps the successful Fly/Wing and established deployment/save behavior isolated
from the preview33 regression fix.

## Static QA

Automated offline QA: **43 checks, 0 failures**. Package checksum manifest: **81/81
files verified** after extracting the final ZIP. ZIP integrity test passed.

This environment cannot execute Windows PowerShell/WPF, compile the bundled Windows
.NET toolchain, or launch Palworld; those remain acceptance gates.

## Expected acceptance run

With Double + Triple + Quad + Fly + Wing and the established source set:

```text
Shared 6 | Auto merged 4 | Decisions 1 | Unsupported 0 | Experimental 0 | Identical 1
```

The sole decision must be the one MultiJump value. Selecting 2, 3 or 4 must preserve
Fly's independent `BP_PlayerBase` changes. `BP_WingGlider` must remain an automatic
contained-superset merge and `WBP_JetPackGauge` must remain Identical.
