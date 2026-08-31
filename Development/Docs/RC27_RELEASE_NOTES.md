# Palworld Manager Merger 1.3.0 RC27

Build ID: `PMM-v1.3.0-RC27-AIIO-LOCAL-FIRST`

RC27 is an editable PowerShell/XAML/data delta over RC26. The packaged native executables, managed runtime, mappings, merge engine, production recipes and package-choice rules remain byte-identical to RC26.

## AI & Help / AIIO

- Adds the top-level AI & Help tab with Help diagnostics, persistent AI sessions, Knowledge/storage/recovery and the color-scheme editor.
- Implements `PMM_AIIO_SESSION_V2`, `PMM_AI_HANDOFF_BUNDLE_V2`, `PMM_AI_RESPONSE_V2` and a capability registry.
- Runs AIIO preparation, requested-data fulfillment, response import, candidate activation and artifact inventory through the supervised background worker.
- Treats response ZIPs as untrusted data and stages valid candidates without executing code.
- Allows only a current exact manual cooked-family candidate to be explicitly submitted to Merge validation; accepting it forces Analyze and never Build/Deploy.
- Adds local diagnostics, save activity, an operation journal, artifact cleanup classification, deterministic build validation and inspectable feedback files.

## UI, themes and progress

- Makes branding and actions equal responsive header halves and enlarges the transparent logo/three-line title.
- Keeps the normal minimum at 900×600 and stacks actions at narrow widths.
- Displays eleven hash-pinned JSON schemes plus Night/Light as official choices and user schemes in a separate bordered collection matching the sound architecture.
- Adds the AI & Help theme editor with fallback colors, optional PNG/JPEG brushes, V1/V2 export and offline AI draft exchange.
- Keeps smoothed progress below 100%; confirmed completion jumps immediately to 100%.

## Preserved regressions

- RC22 effective patch reuse;
- RC23 singleton collection guards;
- RC24 Fix Lab/deployed-merge ownership and deferred UI refresh;
- RC25 responsive behavior and Gura preflight;
- RC26 official themes, immediate completion and exact FasterMounts/RushRoar rule.

Static validation is documented by `Development/Tests/rc27_aiio_local_first_model.py`. Windows PowerShell 5.1, WPF, audio, external tools and Palworld acceptance remain mandatory before public promotion.
