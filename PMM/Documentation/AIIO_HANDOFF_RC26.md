# AIIO continuation handoff — PMM 1.3.0 RC26

Current code authority: the complete RC26 `PMM/` tree in the Git-root-ready package.

- version: **1.3.0 RC26**;
- build ID: `PMM-v1.3.0-RC26-OFFICIAL-THEMES-PROGRESS-COMPATIBILITY`;
- Analyze plan schema: 18;
- build manifest schema: 9;
- packaged native/managed binaries: unchanged RC21 authority;
- next visible module: **AI & Help**; internal engine name: AIIO.

Read the RC25, RC24, RC23 and RC22 handoffs for inherited responsive-layout, package-choice, deployment-ownership, collection-shape and patch-proof contracts. RC26 adds the following non-negotiable boundaries.

## One theme system, two ownership sections

Use `Modules/Theme/ThemeService.ps1` and `PMM_COLOR_SCHEME_V1`. The eleven JSON schemes under `Resources\Themes`, plus legacy Night and Light, are official choices. User-created/imported definitions belong only in `Workspace\Themes` and are presented separately. AI & Help may edit or propose user schemes but must not write or shadow an official ID.

Keep the existing contrast validation, data-only JSON/ZIP boundary, size/path/link/executable checks, parse-all-before-commit behavior and explicit replacement backup.

## Progress ownership

Worker progress remains authoritative. Presentation may interpolate only below the latest reported target and must never exceed it. A confirmed 100% is an operation boundary: display it immediately and discard pending interpolation before starting/presenting another task. AIIO must reuse the shared progress service rather than introduce fake activity percentages.

## Runtime-proven semantic compatibility rules

RC26 does not introduce a generic “larger value wins” policy. `KnowledgeRecipeService.ps1` may authorize one DataTable conflict only when a production-enabled, runtime-proven rule matches the exact asset, property path, competing provider set and canonical value tuple. The current providers and Vanilla are still processed by the normal DataTable adapter; historical cooked output is not reused.

For the current rule, FasterMounts value 10 semantically satisfies RushRoar's value-1 Boar ranch requirement while RushRoar's separate assets remain installed. Any different path/provider/value tuple remains a normal user decision.

Preserve these proof surfaces:

- `AutomaticResolutions` on the analyzed asset and manifest proof;
- `automatic-compatibility-resolutions.json` review evidence;
- `KnowledgeRulesSha256` in schema-18 plans and Analyze-cache identity;
- `ProductionRecipesSha256` and the automatic-resolution signature in patch reuse;
- normal source hash, Vanilla, mappings, adapter, decision and effective-order gates.

AIIO may help propose a rule, but it must not promote one automatically. Promotion requires explicit stable data, a narrow semantic justification and real runtime evidence.

## Inherited safety

- Analyze never creates AI handoff archives automatically.
- Standard handoffs never contain whole source PAKs.
- Vanilla/provider provenance remains distinct and hash-bound.
- Imported AI responses are declarative data, never executable scripts.
- AI & Help, Fix Lab and source-library actions cannot remove a deployed compatibility merge.
- Preserve real arrays for zero/one/many values counted or indexed under Windows PowerShell 5.1.
- Keep package-choice preflight before asset enumeration and long work outside the WPF dispatcher.
- Do not claim RC26 runtime proof until its Windows/Palworld checklist passes.
