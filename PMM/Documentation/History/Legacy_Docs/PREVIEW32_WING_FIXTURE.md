# Preview32 Fly + Wing fixture

## Inputs

`FlyMode_P.pak`

SHA-256: `8c9d74c5fbc220e4e0cbfef7952a73db53ff130bd7770761caa81e4e4e7bf080`

`WingPackNoWingCells_VisibleOnlyWhileFlying_P.pak`

SHA-256: `d3cc879ff2747cdfaf7544054fe5d6ce9ee5af083b6f6d0d6bd10efc464a3914`

Shared WingPack families:

- `Pal/Content/Pal/Blueprint/Equipment/Glider/BP_WingGlider.uasset`
- `Pal/Content/Pal/UI/HUD/InGame/WBP_JetPackGauge.uasset` (Fly/Wing identical in captured fixture)

## BP_WingGlider hashes

| Provider | .uasset bytes | .uasset SHA-256 | .uexp bytes | .uexp SHA-256 |
|---|---:|---|---:|---|
| Vanilla | 11004 | `76a1ce81d7b7b657ed2129e0e26d53d00d0c1fd1b58b4d5751b29d47b4a98186` | 8656 | `74cc6887b926494e6901f70371d7ff0b638347d69130310a13cfd6fcddad05ab` |
| Fly | 11031 | `1346783ddc0d2857c415938b1953432ff042b0090c7ee489b4cd8f33c1d9204e` | 8655 | `0938c864e139b71c8b28033fd19d63b3f9554a0c9196851abe2f0cedfbdaa470` |
| Wing | 11334 | `de326bac49d9aa0681e9c949329915612219b8ca446130576f5ee9230e959ea3` | 8808 | `46a12bf10a63f8fdcad3f1e2a2bc269671841e69410b4fad06a2bc521e0fa6a4` |

## Structural observation

The captured Vanilla-relative executable diff has:

- Fly: 12 `.uexp` hunks;
- Wing: 17 `.uexp` hunks;
- all 12 Fly hunks are exact members of Wing's hunk set at the same Vanilla
  coordinates and byte values.

Package metadata also has a containment relationship:

- Fly adds `bCanFlyWithoutFuel` plus generated bookkeeping;
- Wing preserves that insertion as a prefix and adds more NameMap/import data;
- normalized export metadata matches Vanilla after only generated
  SerialSize/SerialOffset fields are ignored;
- export serial chain and dependency sections remain coherent.

String evidence unique/additional in Wing includes `GetMainMesh`,
`SetActorHiddenInGame`, `SetHiddenInGame`, `SetVisibility`,
`EqualEqual_ByteByte` and `Not_PreBool`.

This evidence is consistent with the user's reported intent (shared no-resource
flight behavior plus additional flight-only wing visibility), but that gameplay
interpretation is **not** the safety proof. The safety proof is exact structural
containment.

## Expected routing

`BP_WingGlider` -> `ContainedSupersetAuto`, base provider Wing.

Expected output family hashes are exactly Wing's hashes above because the adapter
preserves the real anchor unchanged.

`WBP_JetPackGauge` -> `Identical` for the captured Fly/Wing pair.

## Regression interaction with other Fly collisions

The new adapter operates only on the shared `BP_WingGlider` family. Fly remains
free to participate in the same global plan with:

- `BP_PlayerBase` -> existing RelocatableDelta / MultiJump behavior;
- `DA_StaticItemDataAsset` -> existing StaticItem adapter with Food/Stack/Early
  Aquatic;
- any other independently proven shared families.

Build still produces one global PMM overlay.

## Validation status

- real fixture byte study: PASS;
- Python mirror positive gate: PASS;
- negative mutation gates: PASS;
- synthetic three-provider plumbing: PASS;
- Windows PMMCore 0.8.0 compile/run: pending user machine;
- Palworld runtime: pending user test.

## Runtime update recorded in preview33

The user tested the manual global `zzzz_merge_P.pak` on 2026-08-16 using Wing's
real cooked `BP_WingGlider` as the contained-superset anchor. The wing mesh was
visible during Fly/glider flight and the other tested merged behaviors remained
functional. For the captured hashes above, Fly+Wing is therefore runtime-proven.
