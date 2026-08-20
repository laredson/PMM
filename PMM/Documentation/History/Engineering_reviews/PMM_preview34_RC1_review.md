# PalModMerger preview34 RC1 engineering review

**Date:** 2026-08-16  
**Application:** v1-preview34-RC1  
**PMMCore:** 0.8.1  
**Plan schema:** 12

## Release intent

RC34 is a product-hardening release candidate around the runtime-proven preview33
merge engine. It deliberately does **not** broaden automatic merge permission.
The complete `Tools/PMMCore` tree, `Mappings.usmap`, and `Core/SaveService.ps1`
are byte-identical to preview33.

The runtime baseline entering this RC includes:

- simultaneous MultiJump Double / Triple / Quad represented as one value-level
  decision, with the selected jump variant working in-game;
- independent Fly changes retained in the same `BP_PlayerBase` composition;
- Fly + Wing `ContainedDeltaSuperset-v1` working in-game, including visible wing
  mesh while flying;
- Stack/ZeroWeight, FoodNeverSpoils, Early Aquatic and the established
  BreedFarm/PlayerStatus compatibility families continuing to work in the same
  tested stack; and
- `RushoarBoneToLeather_P.pak` working in the Ranch alongside the full test set.

## Saved compatibility patch library

Preview33 archived old overlays but exposed essentially only the current one in
the UI. RC34 treats the local overlay history as an explicit managed collection.

`Get-PMMManagedPatches` now represents:

- the deployed PMM overlay;
- `Builds/Current`; and
- `Builds/Previous`.

Entries are de-duplicated by generated patch filename. The UI displays every
saved patch and uses one radio group so exactly one compatible overlay is chosen
for Deploy.

### Two identities are intentionally separate

`Test-PMMPatchSourceSetCompatible` answers whether a previously built output may
be intentionally deployed against the current inputs. It requires:

1. a readable manifest;
2. a valid current output SHA-256 matching `manifest.OutputHash`;
3. the exact active source `Name:Hash` signature; and
4. the exact current mappings SHA-256 when the manifest records it.

It intentionally **does not** require the saved patch's `DecisionSignature` to
equal the conflict choice currently displayed by Analyze. This is what makes an
older Double/Triple/Quad build a legitimate rollback variant for the same exact
input set.

`Test-PMMPatchCurrent` remains the stronger identity used to determine whether a
patch already represents the currently displayed Analyze decisions.

### Deployment suppressions follow the selected patch

Rollback would be unsafe if PMM selected an old overlay but deployed source PAK
alternatives according to a newer conflict choice. RC34 therefore derives
suppressed alternatives from the selected patch manifest's persisted
`DeploymentSuppressions`. A migration bridge reconstructs the same proven
pure-alternative logic for older manifests that contain Assets + Decisions but
predate the persisted field.

Exact duplicate source hashes are still deterministically reduced at Deploy.

### Promotion after Deploy

After the transactional game-folder commit succeeds, the selected overlay is
promoted to `Builds/Current` and the previous Current overlay is moved to
`Builds/Previous`. If local promotion/bookkeeping itself fails, Deploy is not
falsely reported as a failed game-folder transaction; the error is logged.

The transaction safety introduced earlier remains unchanged: stage first,
SHA-verify, back up every touched managed target, commit, verify again, and try a
rollback on caught failure. Unknown same-name PAKs are not overwritten/deleted.

## Patch UI

The patch panel remains independently resizable and persistent. Its compact
columns are:

- `Use` / `Usar`: single radio selection;
- `Patch`;
- `Decision`: stored conflict choice summary such as
  `MultiJumpDouble_P.pak`, `MultiJumpTriple_P.pak`, or
  `MultiJumpQuad_P.pak`; and
- `Status`: Current / Deployed / Archived and source-set state.

Patches from other source signatures/mappings remain visible as history but have
a disabled radio button. This avoids manual folder surgery while preserving a
clear safety boundary.

Build still follows the decisions currently shown by Analyze. Deploy may use a
selected saved rollback variant from the same exact source set. This distinction
also allows a known saved variant to be redeployed while a new conflict decision
is temporarily unresolved, without pretending that the unresolved decision was
solved.

## Knowledge Library

RC34 promotes the existing `Knowledge/` directory into an explicit product
feature, visible from Settings. It carries:

- generic behavior-symbol hints;
- known behavior lessons; and
- exact fixture evidence with separate structural/runtime status.

New runtime evidence recorded for the RC line includes the MultiJump N-provider
test and Rushoar Bone->Leather; Fly+Wing was already promoted to runtime-proven.

The safety contract is unchanged: Knowledge may explain, classify, suggest a
review path or provide regression evidence. It cannot authorize a production
write merely because a mod name/hash/pattern resembles a known case.

## Community AI / modder handoff

Unsupported assets already generated `AI_HANDOFF_<caseId>.zip`. RC34 enriches
that single ready-to-send file with:

- exact case manifest and Vanilla/provider cooked families;
- involved original source PAKs;
- PMMCore report and Semantic Lab evidence;
- a snapshot of `Knowledge/`;
- `context/global-context.json` containing sanitized active source hashes,
  mappings/core/profile and the current shared-asset plan;
- `COMMUNITY_KNOWLEDGE_WORKFLOW.md`;
- the strict `PMM_MANUAL_SOLUTION_V1` return template; and
- `contribution/RUNTIME_RESULT_TEMPLATE.md`.

The handoff is intentionally self-contained so a user can send one ZIP to an AI
or modder. The returned cooked solution still must pass PMM's exact-case hash,
path, topology and AssetReader checks and remains `UNPROVEN` until an in-game
runtime test.

For knowledge contributions, preserve three artifacts together: the original
handoff ZIP, returned solution ZIP, and completed runtime-result file. A future
PMM release should generalize the structural lesson into a safe adapter or
knowledge rule rather than create a filename allow-list.

## Static QA performed in this environment

PASS:

- all JSON parses;
- all three XAML files parse as XML;
- all 77 WPF control names referenced by the controller exist in EN/ES XAML;
- PowerShell files pass a delimiter/string/comment structural scanner;
- no suspicious non-scope `$variable:` interpolation pattern remains;
- PMMCore tree is byte-identical to preview33;
- `Mappings.usmap` is byte-identical to preview33;
- `SaveService.ps1` is byte-identical to preview33;
- merge schema/core/adapter-mode contract markers remain present;
- saved-patch source/mapping/output-hash gates are present;
- selected-manifest deployment suppressions are used;
- patch decision labels/radio state are present in both localized XAMLs;
- Knowledge remains evidence-only;
- latest runtime-proven fixtures are recorded; and
- duplicate Remerge/Rebuild actions remain absent.

## Limits of this review

This Linux environment cannot execute the official PowerShell parser,
Windows-targeted portable .NET runtime, WPF, transactional Windows Deploy or
Palworld. Those are not claimed as passed here.

The recommended RC acceptance gate is intentionally small: build two or more
2x/3x/4x variants for the same exact active source set, switch between them using
the radio selector + Deploy without rebuilding, verify the expected jump choice
and the already proven Fly+Wing/other behaviors, then change one source mod and
confirm old-set patches become non-selectable.

If that passes, RC34 is a strong v1.0 baseline. The merge engine should then be
frozen for the initial release and compatibility growth should continue through
new fixtures, Knowledge contributions and separately proven adapters.
