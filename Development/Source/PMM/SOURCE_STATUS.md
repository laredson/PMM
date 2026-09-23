# Canonical source status

## Current

`Development/Source/PMM/` is the canonical **NF02A unified candidate source**.

It is not yet the distributed release source because Windows acceptance is pending.

## Historical/reference trees

- `Development/Source/Host/`: older snapshot.
- `Development/Source/Runtime/`: older snapshot.
- `Development/Reliability/NativeCandidates/Host/`: latest pre-consolidation Host candidate.
- `Development/Reliability/NativeCandidates/Runtime/`: latest pre-consolidation Runtime candidate.
- `Development/Reliability/NativeCandidates/Supervision/`: pre-consolidation shared package.
- `Development/Reliability/NativeCandidates/UIBridge/`: pre-consolidation shared package.

Do not edit both old and new trees in parallel.

During NF02A onward, changes intended for the unified Host/Runtime candidate belong under `Development/Source/PMM/`.

The old trees remain evidence until the unified candidate passes Windows acceptance and the package integration is complete.


## NF02 integration preparation

The canonical source no longer treats `Engine/PMMRuntime.exe` as a required
doctor dependency. The Host still recognizes legacy Runtime route entries during
migration, but final staged routes use `PMM.exe runtime ...`.

The source requires an exact-clone rebuild and Windows acceptance after this
integration-preparation delta.
