# PMM Community Knowledge Workflow

Palworld Manager Merger deliberately separates **understanding** from **permission to write**.

The bundled `Knowledge/` directory can help Semantic Lab recognize known providers,
explain likely behavior, recall runtime-proven fixtures and suggest reusable merge
lessons. It does not whitelist a filename and it never bypasses the byte/structure
preconditions of a production adapter.

## When Analyze reports Unsupported

Select the blocked asset and use **HAND TO AI / MODDER**. PMM creates a self-contained
`AI_HANDOFF_<caseId>.zip` that can be shared without manually collecting files.

The handoff contains:

- `case.json` with the exact target asset and pinned Vanilla/provider hashes;
- the relevant Vanilla cooked family when available;
- the exact cooked family from every involved provider;
- the involved original source PAKs;
- PMMCore structural reports and Semantic Lab evidence when available;
- `context/global-context.json` with PMM/Core/mappings identity, active source hashes
  and the other shared assets in the current plan;
- a snapshot of the bundled `Knowledge/` directory;
- `solution-template.json` and a `return-template/` directory describing the strict
  `PMM_MANUAL_SOLUTION_V1` response contract.

Creator descriptions, comments and user observations may be added to `CONTEXT_NOTES.md`.
They are useful evidence for explaining intent, but are never treated as proof that a
binary composition is safe.

## What an AI or modder returns

Return one ZIP with:

```text
solution.json
cooked/<asset-leaf>.uasset
cooked/<asset-leaf>.uexp
cooked/<asset-leaf>.ubulk   # only when required
```

`solution.json` must retain the exact `caseId` and target asset from the handoff.
PMM rejects path traversal, stale case hashes, wrong asset families, incomplete sidecars
and outputs that fail its read-only asset probe.

A structurally accepted solution remains **experimental** until it is tested in Palworld.
PMM never claims gameplay correctness merely because an AI produced a plausible result.

## Contributing a successful case back to PMM

Keep these together:

1. the original `AI_HANDOFF_<caseId>.zip`;
2. the returned solution ZIP;
3. the PMM version used;
4. a short runtime report: what behavior was expected, what was tested, and what worked
   or failed.

A maintainer can then turn the evidence into one or more of:

- an exact regression fixture in `Knowledge/known-fixtures.json`;
- a broader explanatory lesson in `Knowledge/known-behaviors.json`;
- a generic behavior-symbol/effect hint;
- a new production adapter or a stronger precondition for an existing adapter.

The goal is to learn reusable structural rules. Avoid rules of the form
`if mod name == X then accept`. Known names/hashes help explain and reproduce a case;
the current bytes still have to satisfy the generic safety proof.

## Runtime evidence bundle

Each PMM v1.1 AI handoff also contains `contribution/RUNTIME_RESULT_TEMPLATE.md`.
Keep the original `AI_HANDOFF_<caseId>.zip` unchanged. After testing a returned
solution in Palworld, fill a copy of that template and share three artifacts
with the PMM maintainer: the original handoff ZIP, the returned solution ZIP,
and the completed runtime result. A PASS upgrades confidence for that exact
fixture; maintainers should still generalize a structural rule instead of adding
filename-specific automatic permission.


## v1.1: promoting a runtime-proven exact recipe

The first completed community loop is case `73bb3d0635170dad4cb3f7a8`. After the manual solution passed in Palworld, v1.1 stores a sanitized contribution record and a strict recipe in `Knowledge/production-recipes.json`. A production recipe is allowed only for an exact input fixture and must reuse a current provider cooked family whose bytes are pinned by the recipe. It is not permission to extrapolate from mod names or natural-language intent. Updated/different inputs must be analyzed again.

## v1.1 local Game Reference and one-file contribution

PMM can now build a reusable local Vanilla Game Reference from the user's own
`Pal-Windows.pak`. When current, HAND TO AI / MODDER selects a small relevant Vanilla
neighborhood and records `reference-reasons.json`, making the handoff usable by a fresh
AI with no previous PMM/game dump context. The entire local reference is never attached
blindly.

After the user has tested an accepted manual/AI solution successfully, Settings ->
**Create tested contribution...** packages the original handoff, validated returned
solution and runtime PASS into `PMM_KNOWLEDGE_CONTRIBUTION_V1`. This package is intended
for maintainer/community intake and does not grant automatic write permission.

The future web/intake boundary is specified in `COMMUNITY_KNOWLEDGE_SERVER_SPEC.md`.

