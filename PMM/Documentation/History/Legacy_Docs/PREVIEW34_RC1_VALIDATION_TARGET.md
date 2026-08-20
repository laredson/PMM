# Preview34 RC1 validation target

## Purpose

RC34 is the release-candidate pass around the runtime-proven preview33 merger.
The merge algorithms are intentionally frozen. This validation is therefore
about saved-patch rollback, deployment identity, UI state, and the public
Knowledge / AI-handoff workflow.

## Baseline fixture

Use the same active library that already passed runtime testing with:

- MultiJumpDouble_P.pak
- MultiJumpTriple_P.pak
- MultiJumpQuad_P.pak
- FlyMode_P.pak
- WingPackNoWingCells_VisibleOnlyWhileFlying_P.pak
- FoodNeverSpoils_P.pak
- StackSize999999999ZeroWeight_P.pak
- EarlyAquaticConstructionKit_P.pak
- the established BreedFarm / PlayerStatus providers
- RushoarBoneToLeather_P.pak may remain enabled; in the captured library it is a
  unique source asset and does not add another shared family.

Expected shared-asset summary:

```text
Shared 6 | Auto merged 4 | Decisions 1 | Unsupported 0 | Experimental 0 | Identical 1
```

The sole decision remains the MultiJump 2 / 3 / 4 value in `BP_PlayerBase`.
Fly remains an independent same-file provider. `BP_WingGlider` remains a safe
contained-code-superset composition.

## Saved-patch selector test

1. Choose Double and Build.
2. Change the decision to Triple and Build again without deleting the Double
   build.
3. Optionally repeat with Quad.
4. In **Compatibility patches**, verify that all variants are listed.
5. The patches built from the exact current source hashes + current mappings
   should have enabled radio buttons. Patches from other source sets should be
   visible but disabled.
6. Select the older Double patch and press Deploy. Do not Build again.
7. Verify in Palworld that Double is active and the already proven Fly+Wing,
   Stack/Weight, NoSpoil, Early Aquatic and other regression behaviors still
   work.
8. Return to PMM. The deployed Double patch should now be Current/Deployed and
   the previous Current should be archived.
9. Select Triple or Quad and Deploy it back. Verify that variant in-game.

This proves that rollback is a first-class manifest-backed operation, not a
manual file-copy/load-order trick.

## Source-set safety test

1. Disable one active source mod (or add another source PAK).
2. Analyze the changed set.
3. Previous patches from the old set must remain visible for history but their
   radio buttons must be disabled.
4. Deploy must never use one of those patches against the changed source set.

Compatibility identity is based on exact source hashes plus mappings. The
currently displayed true-conflict decision is deliberately *not* part of
source-set compatibility, because previous decisions from the same exact input
set are valid rollback variants.

## Knowledge / community handoff test

For any genuinely Unsupported shared asset:

1. PMM should prepare the review case and `AI_HANDOFF_<caseId>.zip`.
2. **HAND TO AI / MODDER** should locate that ready-to-send ZIP.
3. The ZIP should contain exact case inputs, involved source PAKs, semantic
   evidence, Knowledge snapshot, `context/global-context.json`, the manual
   solution template and `COMMUNITY_KNOWLEDGE_WORKFLOW.md`.
4. A returned `PMM_MANUAL_SOLUTION_V1` remains experimental until runtime tested.

Knowledge may explain or rank evidence but must never authorize an unsafe
production write on its own.

## v1.0 release decision

If the saved-patch selector/deploy test and the source-set safety test pass on
Windows, RC34 is a suitable code baseline for v1.0. The recommended v1.0 policy
is to freeze the proven merge adapters and grow compatibility afterward through
new real fixtures, community handoffs, Knowledge updates and additional proven
adapters.
