# AI_HANDOFF and Knowledge Library

This is the advanced extension path for conflicts PMM cannot yet prove automatically.

When Analyze marks a shared asset Unsupported, PMM can create a self-contained `AI_HANDOFF_<caseId>.zip` containing the exact Vanilla/provider cooked families, involved source PAKs, hashes, PMM structural reports, Semantic Lab evidence, Knowledge snapshot, global merge context and the return contract.

Give that ZIP to a capable AI or human modder together with a short description of the behavior you want preserved. The solver returns one ZIP following `PMM_MANUAL_SOLUTION_V1`; PMM validates provenance, case identity, hashes, asset topology and readability before allowing the user to accept it as an **experimental** solution. Gameplay semantics still require in-game testing.

Successful cases can be contributed back as: original handoff + returned solution + runtime result. Maintainers should turn those examples into generic structural knowledge/adapters rather than filename-specific exceptions.

See:

- `../Docs/COMMUNITY_KNOWLEDGE_WORKFLOW.md`
- `../Docs/MANUAL_SOLUTION_CONTRACT.md`
- `KNOWLEDGE_LIBRARY.md`
- `DEVELOPERS_AND_AI.md`

## Fresh-session enrichment in v1.1

Build **Vanilla Game Reference** once from Settings. PMM extracts/indexes a reusable
subset from the installed `Pal-Windows.pak`. New AI_HANDOFF ZIPs then include a bounded
`references/` neighborhood with exact reasons for every selected Vanilla family and,
for focused source mods, a small provider-side non-conflict neighborhood. The receiver
is explicitly instructed to assume zero prior chat/project context.

The local reference is evidence only and becomes Stale when the source PAK, mappings or
reference-scope identity changes.

## One-file tested contribution

After a returned solution is imported and passes an in-game test, Settings -> **Create
tested contribution...** creates `PMM_KNOWLEDGE_CONTRIBUTION_<caseId>.zip`. Send that
single artifact to the maintainer or a future approved community intake service. The
package contains the exact case, original handoff when available, returned validated
solution and explicit runtime PASS evidence.

Importing/submitting this evidence never activates a production recipe by itself. See
`GAME_REFERENCE_AND_COMMUNITY_CONTRIBUTIONS.md` and
`../Docs/COMMUNITY_KNOWLEDGE_SERVER_SPEC.md`.

