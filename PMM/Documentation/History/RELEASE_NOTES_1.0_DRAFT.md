# Palworld Manager Merger 1.0 — Release notes draft

## What 1.0 represents

1.0 is the first public baseline where PMM's architecture has moved beyond proof-of-concept merging into a tested product workflow:

- reproducible source library;
- Analyze -> Build -> Deploy lifecycle;
- value-level True Conflicts;
- multiple conservative production adapters;
- transactional managed deployment;
- saved compatibility patch library/rollback variants;
- world save backup/restore;
- English/Spanish UI;
- Knowledge Library;
- AI/modder handoff for unsupported cases.

## Runtime baseline entering 1.0

The current regression stack includes simultaneous MultiJump Double/Triple/Quad as one choice, Fly, Wing, Stack/ZeroWeight, FoodNeverSpoils, Early Aquatic and the established BreedFarm/PlayerStatus merges. The selected jump variant and the combined Fly/Wing behavior have been tested in Palworld. RushRoar Leather Drop also works alongside the active stack as a unique source PAK.

## Final RC gate still pending in this draft

Before changing the label to final v1.0, complete RC34's saved-patch selector test:

- build at least two 2x/3x/4x variants;
- deploy an older same-source patch via radio selection without Build;
- confirm in-game behavior;
- change the active source set and confirm old-set patches become non-selectable.

If that passes, no merge-engine changes are recommended between RC34 and 1.0.
