# AI_HANDOFF, AIIO and Knowledge Library

This is the advanced extension path for conflicts PMM cannot yet prove automatically.

## Analyze and AIIO are separate

Analyze only analyzes the current source graph. For every Unsupported item it records an exact review case (`case.json`, input hashes/sizes and analysis evidence). Unreal cooked families keep the existing manual-solution contract; plain/non-Unreal shared files are included as investigation evidence without pretending PMM can auto-import a replacement for those formats. Analyze does **not** build AI handoff ZIPs and does **not** copy source PAKs.

When the user explicitly chooses **CREATE AI HANDOFF**, AIIO creates **one** `AI_HANDOFF_<bundleId>.zip` for the complete current Unsupported set. After a normal Analyze with Unsupported items, PMM can also ask whether the user wants to create that bundle now.

The bundle contains:

- `cases/<caseId>/` — exact PMM analysis evidence for each Unsupported case;
- `sources/Vanilla/<logical game path>` — the exact conflicting Vanilla file/family when available;
- `sources/<mod name>/<logical game path>` — only the exact conflicting file/family extracted from each involved mod;
- `merge-plan.json`, `source-map.json` and bundled PMM CKL knowledge/documentation.

Whole source PAKs are intentionally never included.

## Size policy

AIIO targets a handoff ZIP of at most 512 MiB and uses a 5 GiB normal uncompressed-bundle budget. The preflight estimate uses a conservative planning ratio and AIIO also enforces the raw budget while extracting. If the handoff is expected to exceed the normal budget, PMM asks the user whether to create the large package anyway.

Temporary AIIO stages and partial ZIPs are deleted in a `finally` path. PMM also removes abandoned Analyze/AIIO staging, partial archives and legacy per-case handoff ZIPs during startup hygiene.

## Returned solutions

One incoming handoff can contain many cases, but PMM continues to validate returned cooked solutions per exact case. For each solved Unreal cooked-family case, return one ZIP following `PMM_MANUAL_SOLUTION_V1`. This preserves the existing caseId/hash safety model and allows an AI/modder to solve all, some or none of the cases independently.

Gameplay semantics still require in-game testing. Successful cases can be contributed back as handoff + returned solution + runtime result so maintainers can generalize the structural lesson rather than add filename exceptions.

See:

- `../Docs/COMMUNITY_KNOWLEDGE_WORKFLOW.md`
- `../Docs/MANUAL_SOLUTION_CONTRACT.md`
- `KNOWLEDGE_LIBRARY.md`
- `DEVELOPERS_AND_AI.md`
