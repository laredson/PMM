# Golden regression reference: Fly + Stack + NoSpoil

The third-party source PAKs are not distributed with PMM. This document records the real user fixture that drove the safe architecture.

## Known-good output

`FlyMode_Stack999999999_ZeroWeight_NoSpoil_P.pak`

SHA-256: `42a055bc5dba79ca16366038e970a9ec21a27fec3d447577112faa7e20e16916`

Known-good merged `DA_StaticItemDataAsset.uexp` SHA-256:

`8f2ab2933c85bde0e8c9d74b39e466f9ad1c3b41c042106f7ffc624dea624bf8`

## What the fixture proved

- Stack's `DA_StaticItemDataAsset.uasset` matches the current Vanilla layout.
- Fly and Food share a different/stale cooked baseline.
- A raw `current Vanilla -> stale provider` byte diff therefore contains game-version drift and cannot be treated as mod intent.
- Comparing stale providers semantically isolates 121 observed intents: 120 `CorruptionFactor -> 0` edits and one glider soft-class edit.
- The no-spoil pattern is near-global (120/123 spoil-positive rows). Promoting that behavior to all current positive rows produces 123 zeroed factors.
- Applying those fixed-size semantic changes to Stack's current-layout cooked base reproduces the known-good `.uexp` byte-for-byte.

## Production invariant

There are two different automatic cases:

1. **Current-layout providers:** compute Vanilla -> provider byte deltas and merge them for N providers when overlapping bytes agree.
2. **Stale-layout providers:** do not replay their byte offsets. A specific semantic adapter must separate common stale baseline drift from provider intent and encode supported fixed-size changes onto a current-layout cooked base.

If neither proof exists, PMM marks the shared family Unsupported and blocks Build. It does not silently select a whole provider and discard the other changes.
