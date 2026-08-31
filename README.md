# Palworld Manager Merger (PMM)

**Current development branch: PMM 1.3.1 Mod Creation preview, based exactly on v1.3.0 Stable.**

Palworld Manager Merger is a local Palworld mod manager, compatibility analyzer/overlay builder and legacy-mod repair platform. It preserves source mods and creates only the compatibility overlay required by shared assets.

## Repository layout

- `PMM/` — complete portable application.
- `Development/` — engineering source, tests, architecture and continuation handoffs.
- `.github/` — contribution and project-policy files.
- `LICENSE` — MIT project license.

Runtime-created `PMM/Workspace/` is private local state and must never be committed or shipped.

## Start PMM

Extract the portable package and run `PMM.exe`.

The guided workflow is:

`Detect if needed -> Import -> Fix Lab when required -> Analyze -> Build only when required -> Deploy -> Play ready`

v1.3.1 retains the complete published v1.3.0 Stable merge, Fix Lab, validation, responsive-layout, progress, theme and AIIO behavior. It adds a separate standalone-mod creation workflow without changing compatibility-patch ownership or deployment. The header reads Detect/status, folders/optional Play, then AUTO. A successful Deploy highlights Play as ready without presenting it as required.

## AI & Help / AIIO

The visible **AI & Help** workspace is backed by persistent local AIIO sessions, diagnostics, Knowledge, save activity, a recoverable operation journal, deterministic build validation and a color-scheme editor with image-backed V2 packs. **AI assistance** shows the selected case or an explicit new-case form; **AI reception** accepts a returned ZIP and keeps candidates staged; **Feedback & Knowledge** creates inspectable local files for an exact merge/validation, CKL or general comments. AI-specific behavior remains in its own Settings view, while Vanilla Game Reference is also available from normal Settings.

The current AI transport is deliberately manual and local: PMM prepares bounded ZIPs and validates returned ZIPs as untrusted data. It does not log into a provider, upload automatically or execute returned code. Returned compatibility solutions remain staged until they satisfy an exact current case contract; accepting an eligible compatibility candidate forces Analyze and never triggers Build or Deploy.

For standalone creation, press **AI & Help → AI assistance → New mod project...**. A `CREATE_MOD` exchange can query the current local Vanilla GameReference and request only an exact hash-bound family or a bounded deterministic neighborhood. A returned `PMM_MOD_CREATION_CANDIDATE_V1` cooked tree remains inactive until the user explicitly chooses **Build standalone PAK...**. PMM then verifies and packs it locally, but never deploys, enables, uploads, publishes or promotes it to Knowledge. Every new mod remains runtime **UNPROVEN** until tested in Palworld.

The complete creation contract is in `PMM/Documentation/MOD_CREATION_AIIO.md`; engineering notes are in `Development/Docs/PMM_1_3_1_MOD_CREATION.md`. Continue broader AIIO development from `Development/AI/AI_CONTINUE_HERE.md` and `Development/AI/AIIO_1_3_0_HANDOFF.md`. The runnable `PMM/` tree and packaged binaries are the release authority. Do not rebuild the older native-source snapshot over those binaries until parity is proven.

Created by **laredson**.
