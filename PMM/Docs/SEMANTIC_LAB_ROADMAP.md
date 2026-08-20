# PMM Semantic Lab roadmap

## v0.1 in preview32

Evidence only:

- printable symbol diff against Vanilla;
- effect-class hints;
- exact known-fixture context;
- heuristic, non-selectable change-capsule candidates.

It never authorizes Build.

## v0.2 target: Kismet extraction

Use the existing read-only UAssetAPI integration to export FunctionExport raw
Kismet bytecode into a stable PMM representation. Preserve original offsets for
traceability but normalize package-index/name-map noise.

## v0.3 target: PMM Blueprint IR

Represent functions as instructions/basic blocks with:

- calls;
- variable/property reads and writes;
- constants;
- branches/jumps;
- object/class/import references;
- side effects;
- dependencies.

## v0.4 target: semantic three-way diff

Compare Vanilla -> provider changes by function/block/effect rather than by file
offset. Group independent changes and identify structurally equivalent edits.

## v0.5 target: dependency-closed Change Capsules

A selectable capsule must include every required NameMap/import/export/reference
and every control-flow dependency. Until closure is proven, it remains an
explanatory hint only.

## v0.6 target: effect/symbolic traces

Where supported, evaluate branches abstractly and report effects such as:

- visibility change;
- resource/fuel state change;
- movement/glide state read;
- mesh selection;
- scalar property assignment.

Unknown native calls remain explicit opaque effects rather than guessed behavior.

## Safety invariant

Author comments, mod descriptions and AI interpretation can explain likely
intent and help a reviewer. They never convert an unproven transformation into a
safe production merge. The writer still needs a structural/dependency proof or
an explicitly accepted exact-case manual cooked solution.
