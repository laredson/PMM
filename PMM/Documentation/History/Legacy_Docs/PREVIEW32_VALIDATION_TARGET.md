# Preview32 validation target

## Primary acceptance run: Wing + current Triple-only set

Use the same known-good source library that previously produced the runtime
working 41-source Triple-only overlay, then enable:

`WingPackNoWingCells_VisibleOnlyWhileFlying_P.pak`

Keep `MultiJumpTriple_P.pak` enabled and Quad disabled for the first run.

Expected Analyze summary:

```text
Shared 6 | Auto merged 5 | Decisions 0 | Unsupported 0 | Experimental 0 | Identical 1
```

Expected shared routes:

1. `BP_PlayerBase` -> `RelocatableAuto` (Fly + Triple)
2. `BP_WingGlider` -> `ContainedSupersetAuto` (Fly subsumed by Wing)
3. `WBP_JetPackGauge` -> `Identical`
4. `BP_BuildObject_BreedFarm` -> existing relocatable auto path
5. `DA_StaticItemDataAsset` -> existing StaticItem auto path
6. `DT_PlayerStatusRankMasterDataTable` -> existing Superset/DataTable proven path

Build one overlay and Deploy.

### Runtime checks

At minimum check:

- Fly still identifies/uses the intended wing/glider flight behavior;
- equipped WingPack wings appear only in the intended flying state;
- no-cell/no-resource flying behavior expected by the two mods;
- Triple jump;
- Stack / zero weight;
- NoSpoil;
- Early Aquatic;
- BreedFarm conflict-pair behavior previously used as a regression fixture;
- existing PlayerStatus/stat-cap compatibility.

If runtime succeeds, record the generated overlay SHA-256 as the first
runtime-proven ContainedDeltaSuperset fixture.

## Secondary acceptance run: Triple + Quad present

Re-enable Quad and Analyze.

Expected:

```text
Shared 6 | Auto merged 4 | Decisions 1 | Unsupported 0 | Experimental 0 | Identical 1
```

The only required decision must still be Triple vs Quad in `BP_PlayerBase`.
Wing/Fly must not become a decision.

## UI acceptance

- Analysis Plan can collapse fully.
- Resolution & Review can collapse fully.
- With a new unresolved decision it auto-opens and highlights DECISION REQUIRED.
- Build/Deploy/Restore remain visible at the bottom while either panel is open.
- source mod checkbox disables a PAK into `Mods/_Disabled` and invalidates the
  current plan;
- PMM patches remain in their separate patch panel;
- no Remerge/Rebuild buttons are present.

## Unsupported/manual path acceptance (can use a future unsupported fixture)

Analyze should create `AI_HANDOFF_<caseId>.zip`. Import of a returned solution
must reject:

- wrong caseId;
- changed/missing pinned review input;
- provider PAK no longer active or hash-changed;
- path traversal;
- unrelated asset files;
- wrong cooked sidecar topology;
- AssetReader parse failure.

A valid accepted solution must appear as `ManualSolutionExperimental`, require
explicit risk acceptance and build into the same single overlay.

## Wing 2x

When the user supplies Wing 2x, add it without changing adapter code. The real
N-provider test is successful only if one provider is proven to contain every
other provider's exact change set, or the adapter conservatively rejects it.
Do not special-case provider count or names.
