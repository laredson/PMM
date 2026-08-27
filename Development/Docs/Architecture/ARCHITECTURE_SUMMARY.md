# Architecture summary

## Product model

```text
PMM source library
      |
    Analyze
      v
Vanilla/current + N providers
      |
      +-- automatic proven composition
      +-- true value/property conflict
      +-- exact manual/AI experimental solution
      +-- unsupported blocker
      v
Build one local compatibility overlay
      |
    Deploy
      v
Palworld ~mods
```

## Core principles

1. Preserve real cooked assets whenever possible.
2. Compare every provider relative to Vanilla/current state.
3. Merge independent changes automatically.
4. Resolve disagreements at the smallest proven identity.
5. Unsupported blocks Build.
6. AssetReader/UAssetAPI is read-only in production.
7. Production writers patch copied cooked bytes or preserve a proven cooked anchor.
8. PMM outputs are managed artifacts, never source providers.
9. Import/Build and Deploy are separate lifecycle stages.
10. Knowledge/AI interpretation is evidence, not automatic write permission.

## Detailed Analyze–Merge reference

For the complete internal flow—from source PAK identity, package choices, indexing and exact extraction through every merge adapter, conflict rows, plan invalidation, Build replay, PAK construction, manifests, AIIO/manual solutions and transactional Deploy—read:

- [`ANALYZE_MERGE_INTERNALS.md`](./ANALYZE_MERGE_INTERNALS.md)

That document is version-neutral as an architectural reference, with the PMM 1.2.1 Guided Flow stable tree recorded as its verified implementation baseline. It also explains the key product invariant: PMM normally keeps the original source mods installed and creates a minimal compatibility overlay rather than one autonomous megapak containing every source asset.

## Components

- `Start-PalModMerger.ps1` + `UI/*.xaml`: Windows/WPF product shell.
- `Core/*.ps1`: library, PAK extraction, Analyze/Build/Deploy, saves, Semantic Lab orchestration.
- `Tools/PMMCore/src`: C# merge proof/writer implementation.
- `Tools/AssetReader`: read-only semantic Unreal inspection.
- `Knowledge/`: reusable fixture/evidence library.
- `Docs/`: engineering history/contracts/validation targets.

For exact adapter preconditions and historical rationale, read `ARCHITECTURE.md`, [`ANALYZE_MERGE_INTERNALS.md`](./ANALYZE_MERGE_INTERNALS.md), `DEVELOPER_GUIDE.md`, `GOLDEN_REFERENCE.md` and `HANDOFF.md` shipped with the release.
