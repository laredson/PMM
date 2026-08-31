# AIIO continuation handoff — PMM 1.3.0 RC25

Current code authority: the complete RC25 `PMM/` tree in the Git-root-ready package.

- version: **1.3.0 RC25**;
- build ID: `PMM-v1.3.0-RC25-RESPONSIVE-THEMES-ANALYZE-PROGRESS`;
- Analyze plan schema: 17;
- build manifest schema: 9;
- packaged native/managed binaries: unchanged RC21 authority;
- next visible module: **AI & Help**; internal engine name: AIIO.

Read `AIIO_HANDOFF_RC24.md`, `AIIO_HANDOFF_RC23.md` and `AIIO_HANDOFF_RC22.md` for inherited deployment ownership, UI refresh, collection-shape and patch-proof contracts. RC25 adds these boundaries.

## Shared theme contract

Use `Modules/Theme/ThemeService.ps1` and `PMM_COLOR_SCHEME_V1`; do not invent a second AIIO theme format or import path. Release themes are immutable under `Resources/Themes`; user output/imports belong in `Workspace/Themes`.

The future AI & Help color-scheme editor may create data, previews and manual handoffs, but it must reuse:

- strict lowercase scheme IDs and official-ID reservation;
- the complete palette/ColorFlow model;
- 4.5:1 real-surface contrast validation;
- JSON/ZIP size, entry-count, path, link, nested-archive and executable-content limits;
- parse-all-before-commit behavior;
- explicit user confirmation plus backup for replacement;
- PMM Crystal → hard-coded Night fallback without silently overwriting the saved choice.

Treat image-derived colors as untrusted suggestions until the resulting JSON passes the same validator. Never load scripts, XAML, DLLs or executable behavior from a theme package.

## Package-choice and Analyze boundary

The five Gura Fix Lab outputs are complete mutually exclusive variants. Their `anyTwoActive` package rule runs before asset enumeration. AIIO must not reinterpret two alternatives as an unsupported merge case or create a handoff for their large female-model families. It should surface/retain the human package choice and operate only on the effective provider set after suppression.

Package choices are user intent, not byte-level conflict decisions. Do not auto-select a cosmetic/behavior variant without an exact prior choice. Do not weaken ordinary Unsupported handling for unrelated providers.

## Progress boundary

Worker progress is the only authority. Presentation may lag and interpolate integer points up to a proven target, but must never invent progress beyond it. A new target may first catch the visible bar up to the previous proven target, then animate forward. AIIO background jobs should call the existing progress surfaces instead of adding their own timer or fake percentages.

## Responsive and refresh boundary

AI & Help must fit the RC25 adaptive window contract: 900×600 normal minimum, work-area/DPI clamping, usable extreme layout, and no fixed child minimums that can starve a sibling pane. Navigation/expand/collapse must paint first. Filesystem scans, hashing, archives, model calls and handoff generation remain supervised worker work with an explicit refresh/action.

## Inherited non-negotiable safety

- Analyze never creates AI handoff archives automatically.
- Standard AIIO bundles never contain whole source PAKs.
- Vanilla and provider provenance remain separate and hash-bound.
- Imported AI answers are declarative data, not executable scripts.
- AI & Help, Fix Lab and source-library actions cannot remove a deployed compatibility merge; only Compatibility patches owns Deploy/No patch/UNDEPLOY/Delete.
- Keep zero/one/many collections as real arrays where Windows PowerShell 5.1 code counts or indexes them.
- Preserve RC22 effective-conflict patch reuse and all negative proof gates.
- Do not claim runtime proof until the RC25 Windows checklist passes.
