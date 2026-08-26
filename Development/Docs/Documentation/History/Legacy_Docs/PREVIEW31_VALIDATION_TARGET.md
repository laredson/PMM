# Preview31 validation target

Preview31 is intentionally UI-focused. PMMCore stays at 0.7.1 and the adapter
algorithms/mappings remain unchanged from preview30.

## Functional regression gate

Use the known stress fixture with FlyMode, FoodNeverSpoils, Stack,
EarlyAquaticConstructionKit, MultiJumpTriple and MultiJumpQuad plus the existing
source library. Analyze must remain:

`Shared 4 | merged automatically 3 | true-conflict decisions 1 | unsupported 0 | identical 0`

The only decision remains Triple vs Quad in BP_PlayerBase; Fly remains an
independent compatible provider in that same asset.

## UI acceptance

- Analysis Plan displays five counters and one row per shared asset.
- Each row identifies the asset, merge result, adapter and participating mods.
- Selecting a row exposes its full path/reason details.
- The library/workspace, analysis/conflict, and conflict-list/detail boundaries are draggable.
- Main window size and the three primary splitter positions persist after restart.
- Reset workspace layout restores defaults.
- The library can be filtered without changing enable/disable/delete semantics.
- Strategy selector is absent.
- Close/force-close options appear with the deployment controls.
- Build / Deploy / Remerge / Rebuild / Restore remain on one line at normal window sizes.

## Runtime gate

After the UI checks, resolve Triple, Build and Deploy. Confirm the already-proven
behaviors still work in Palworld. No runtime claim for preview31 should be made
until this pass is completed on Windows/Palworld.
