# PMM Knowledge Base

This directory records regression fixtures and human-readable semantic hints that
help Palworld Manager Merger explain known mod behavior. It is **not an allow-list**.
Ordinary Knowledge entries never override a merge adapter's structural proof. The only
production exception is `production-recipes.json`, whose entries must be explicitly
runtime-proven and must re-match exact pinned hashes before they can authorize Build.

Rules:

1. A known mod name or description may improve labels/explanations only.
2. A known fixture may define expected hashes/routing for regression testing.
3. Automatic Build still requires a production adapter to prove the exact input
   bytes/family currently being analyzed.
4. If a provider or Palworld asset changes hash, the old fixture is historical
   evidence rather than permission to merge the new bytes.
5. Runtime status is recorded separately from structural/fixture status.

`behavior-symbols.json` contains generic Unreal/Palworld symbol hints for the
read-only Semantic Lab. These hints describe likely effects and are deliberately
non-authoritative.

`known-fixtures.json` contains exact hashes and the acceptance expectation for
real cases that have taught PMM a reusable rule.

`known-behaviors.json` records broader lessons from runtime/fixture cases even when a full exact-provider hash set is not available. It is shipped in AI_HANDOFF packages as context only; it never bypasses structural validation.

## Community growth contract

Release-candidate builds ship this directory intentionally. When PMM cannot prove a
safe composition, the Unsupported panel creates a self-contained `AI_HANDOFF_<case>.zip`.
That ZIP includes the exact case hashes, cooked families, involved source PAKs, Semantic
Lab evidence, global source-set context and a copy of this Knowledge directory. It can be
sent as-is to an AI or another modder.

A returned solution does **not** become trusted knowledge merely because it loads. PMM
first validates the `PMM_MANUAL_SOLUTION_V1` contract, provenance, topology, hashes and
read-only parse. The user then tests gameplay explicitly. Only after structural evidence
and runtime evidence are recorded should a maintainer generalize the lesson into a future
Knowledge entry or production adapter.

Useful contribution bundle after a successful manual/AI case:

- the original `AI_HANDOFF_<case>.zip`;
- the returned solution ZIP;
- a short runtime result describing what was tested;
- the PMM version used.

Knowledge entries are evidence and regression fixtures, never an allow-list.


## Production recipes (v1.1)

Most Knowledge remains explanatory and cannot authorize Build. `production-recipes.json` is a deliberately narrow exception for solutions that completed the full AI_HANDOFF -> PMM validation -> in-game PASS cycle. Recipes are exact hash-pinned and revalidated during Analyze and Build. They are not filename whitelists and do not apply to updated providers unless the current bytes still match every pinned input.

The first recipe is the runtime-proven RushRoar Leather Drop v2 + FasterMounts `DT_PalMonsterParameter_Common` solution from case `73bb3d0635170dad4cb3f7a8`. Sanitized evidence is stored under `Knowledge/Contributions/73bb3d0635170dad4cb3f7a8/`.
