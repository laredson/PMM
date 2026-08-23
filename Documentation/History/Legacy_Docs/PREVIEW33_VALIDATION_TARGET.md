# Preview33 validation target

## Primary run: Double + Triple + Quad + Fly + Wing

Enable the known source set plus:

- `MultiJumpDouble_P.pak`
- `MultiJumpTriple_P.pak`
- `MultiJumpQuad_P.pak`
- `FlyMode_P.pak`
- `WingPackNoWingCells_VisibleOnlyWhileFlying_P.pak`

Expected Analyze:

```text
Shared 6 | Auto merged 4 | Decisions 1 | Unsupported 0 | Experimental 0 | Identical 1
```

Expected routes:

1. `BP_PlayerBase` -> `RelocatableConflict`: Double/Triple/Quad compete only for the
   single structural value; Fly remains compatible and is still merged.
2. `BP_WingGlider` -> `ContainedSupersetAuto`: Wing contains the proven Fly delta.
3. `WBP_JetPackGauge` -> `Identical`.
4. `BP_BuildObject_BreedFarm` -> existing relocatable auto route.
5. `DA_StaticItemDataAsset` -> existing StaticItem auto route.
6. `DT_PlayerStatusRankMasterDataTable` -> existing superset/DataTable route.

### Decision behavior

The row should expose Double=2, Triple=3 and Quad=4. Vanilla and Custom may be offered
because the captured variant cluster has exactly one conflicting value. Select one of
2/3/4 for the acceptance run.

### Build regression

Build must no longer fail before `Build-PMMMerge` with the preview32 PowerShell error:
`No se encuentra la propiedad 'Count' en este objeto.`

### Runtime

After Build -> Deploy verify:

- selected number of jumps;
- Fly begins after the selected jump behavior;
- Wing mesh is visible during Fly/glider flight as in the manual runtime-proven overlay;
- no-cell/no-resource flight behavior;
- Stack/zero weight;
- NoSpoil;
- Early Aquatic;
- existing BreedFarm and PlayerStatus regression behaviors.
