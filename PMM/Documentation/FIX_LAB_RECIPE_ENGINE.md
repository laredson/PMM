# Fix Lab native recipe engine

PMM 1.3 repairs supported legacy mods locally. Production Fix Lab must never solve a case by downloading or silently copying a previously repaired third-party PAK.

## Inputs

```text
exact legacy source PAK
        +
Current Game Reference from the user's installed Palworld
        +
small reviewed recipe + transformation payload
        ->
PMMFixLab.exe
        ->
PAK v11 + build report + independent readback validation
```

The original source is snapshotted and expanded only inside the job Workshop. `Workspace/FixLab/Workshop` and job work folders are temporary construction space, not a repository of finished mods.

## Case 001 V2

Engine version: `0.2.0-variant-recipes`  
Recipe schema: `PMM_FIXLAB_VARIANT_RECIPE_V2`  
Transformation format: `PMMDLT1`

Five executable recipes are included for Gawr Gura v5. Each exact v5 Normal or FullReplacement source independently generates all five outputs.

The V2 pipeline is:

```text
source + Current Game Reference
 -> deterministic core reconstruction R1 in memory
 -> recipe operations (remove/copy/transform)
 -> bounded PMMDLT1 COPY/LITERAL execution
 -> PAK v11 writer
 -> independent readback
 -> byte-exact per-entry verification
 -> required/forbidden path validation
 -> Built output registration
```

The compact payload contains transformation knowledge, not complete repaired PAKs. Every referenced input file and payload is identified by SHA-256 before an operation executes.

## Game Reference evolution

Recipes declare the current families they require. PMM can extend Current Game Reference on demand from the user's `Pal-Windows.pak`. Extracted reference identities should be retained by game/mappings identity until the user deletes them, because historical/current comparisons are valuable evidence for later AIIO investigation.

If a required current base changed and the recipe cannot prove the transformation, the engine must stop with a base mismatch report. It must not force an output merely because a previous game version worked.

## Validation meaning

A matching historical PAK SHA-256 is a strong regression result for the exact captured inputs, not a product rule. Future builds may legitimately differ in package ordering, compression, current game bytes, or reconstructed data. Required validation is layered:

1. recipe/source/reference identity checks;
2. transformation bounds and expected cooked-file checks;
3. PAK v11 readback and entry verification;
4. family/topology/negative-constraint checks;
5. in-game runtime acceptance.

## Processing model

Long Fix Lab Repair work runs in `OperationWorker.ps1`, outside the WPF dispatcher. Progress and completion are exchanged through atomic JSON files. The UI remains available for navigation, resizing and cancellation while the worker owns the single mutating processing slot.

## Future cases and AIIO

A future AI or developer should:

1. preserve the failing source by exact hash;
2. collect the game version it targeted when known;
3. compare old and current package/provider topology;
4. express the smallest falsifiable repair hypothesis;
5. add generic engine primitives where possible;
6. encode case-specific paths/parameters/constraints in a compact recipe;
7. validate offline and then in-game;
8. promote only the proven evidence to stable CKL.

When an automatic attempt fails, PMM should preserve the source extraction, requested reference families, reports, missing-family/base-mismatch information and recipe attempt for a later AIIO handoff. AIIO can request additional historical/current families without requiring the user to rebuild everything from zero.
## Repair PAK mount priority

Fix Lab repair outputs that override existing Palworld cooked paths must use the Unreal patch filename suffix `_P.pak`. The recipe engine validates the reconstructed bytes independently, but deployment naming is also part of runtime correctness: without patch priority, a byte-correct repair can lose to the vanilla `Pal-Windows.pak` provider at mount time.

Case 001 therefore emits all five generated variants with `_P.pak`, and Apply Fix refuses a repair output that does not carry that suffix. Output hashes refer to PAK contents and may remain identical when only the external filename changes.
