# PMM v1.1 Game Reference / community extension - Windows validation target

This candidate deliberately leaves PMMCore 0.9.0, mappings and the existing
runtime-proven merge/deploy services unchanged. Validate the new shell/evidence path:

1. Start PMM normally and configure the same Palworld installation used for v1.1.
2. Settings -> **Build / refresh Game Reference**.
3. Expected on the supplied 2026-08-17 game build: approximately 7,134 cooked files,
   3,565 families and 66.8 MiB raw. Counts may change on a different Palworld build.
4. Status must become **Current**. Open folder and confirm `current/index/families.jsonl`
   plus `current/cooked/` exist.
5. Close/reopen PMM: status must remain Current without rebuilding.
6. If Pal-Windows.pak/mappings/scope changes, status must become Stale rather than being
   silently reused.
7. For any Unsupported case, click **HAND TO AI / MODDER**. If reference is missing or
   older than the handoff, PMM should offer to build/regenerate first.
8. Inspect the new AI_HANDOFF ZIP. It should retain the exact old conflict evidence and
   additionally contain `references/provider-context.json`, provider indexes and, when
   Game Reference is Current, `reference-index.json`, `reference-reasons.json`,
   `game-reference-context.json` and a bounded `references/Vanilla/` tree.
9. A fresh AI should be able to read README_FOR_HUMAN_OR_AI.md and understand it must
   assume zero previous chat context and must not invent a winner if evidence is short.
10. Regression smoke: Analyze/Build/Deploy the existing v1.1 runtime-proven set. Results
    should be unchanged because PMMCore/adapters/deploy services are frozen.
11. When another AI/manual solution is imported and then actually passes in Palworld,
    Settings -> **Create tested contribution...** should create one
    `PMM_KNOWLEDGE_CONTRIBUTION_<caseId>.zip` under Data/KnowledgeContributions.
12. Inspect that contribution: case + original handoff (when retained) + returned
    solution + validation + runtime-result PASS + contribution manifest. It must not
    modify `Knowledge/production-recipes.json` on the submitting machine.

Run `SmokeTest.ps1` on Windows before publication. It uses the real PowerShell parser in
addition to the static Linux QA shipped with this candidate.
