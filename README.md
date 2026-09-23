# Palworld Manager Merger (PMM)

> **Development branch note:** active v1.5.0.2 engineering continuity starts at [START_HERE_NEW_PROJECT.md](START_HERE_NEW_PROJECT.md). The release-oriented text below documents the public/product lineage and is not the current development handoff.

**PMM 1.3.1ModCreator — portable mod management and assisted mod creation.**

Download the program-only ZIP from the [latest release](https://github.com/laredson/PMM/releases/latest). Extract it and run `PMM.exe`. Generated mods, game files and optional tool installers are not bundled.

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

## Local MCP preview

An optional Windows PowerShell MCP bridge exposes bounded AIIO case, staged-artifact and current hydrated Vanilla-reference tools. Enable it from AI Settings and import the generated client configuration once. This is a local STDIO preview; A local Codex client can process published requests and return visible advisory responses. MCP 0.5.0 includes automatic reference preparation and structured AssetReader inspection without Unreal or Python. An optional Unreal 5.1 adapter is included but requires installed dependencies and real project verification; it supports bounded texture authoring and Windows candidates. See [optional Unreal setup](PMM/Documentation/UNREAL_SETUP.md). Continuous chat and remote transport remain future work. See [MCP bridge guide](PMM/Documentation/MCP_BRIDGE.md).

## Workspaces / AIIO

The **Mod Creation**, **Mods & Merge**, **FIX LAB** and **Help** workspaces are backed by persistent local AIIO sessions, diagnostics, Knowledge, save activity, a recoverable operation journal, deterministic build validation and a color-scheme editor with image-backed V2 packs. **AI assistance** shows the selected case or an explicit new-case form; **AI reception** accepts a returned ZIP and keeps candidates staged; **Feedback & Knowledge** creates inspectable local files for an exact merge/validation, CKL or general comments. AI-specific behavior remains in its own Settings view, while Vanilla Game Reference is also available from normal Settings.

The manual AIIO transport remains available: PMM prepares bounded ZIPs and validates returned ZIPs as untrusted data. It does not log into a provider, upload automatically or execute returned code. Returned compatibility solutions remain staged until they satisfy an exact current case contract; accepting an eligible compatibility candidate forces Analyze and never triggers Build or Deploy.

For standalone creation, open **Mod Creation → Projects** and create a new case. A `CREATE_MOD` exchange can query the current local Vanilla GameReference and request only an exact hash-bound family or a bounded deterministic neighborhood. A returned `PMM_MOD_CREATION_CANDIDATE_V1` cooked tree remains inactive until the user explicitly chooses **Build standalone PAK...**. PMM then verifies and packs it locally, but never deploys, enables, uploads, publishes or promotes it to Knowledge. Every new mod remains runtime **UNPROVEN** until tested in Palworld.

The complete creation contract is in `PMM/Documentation/MOD_CREATION_AIIO.md`; engineering notes are in `Development/Docs/PMM_1_3_1_MOD_CREATION.md`. Continue broader AIIO development from `Development/AI/AI_CONTINUE_HERE.md` and `Development/AI/AIIO_1_3_0_HANDOFF.md`. The runnable `PMM/` tree and packaged binaries are the release authority. Do not rebuild the older native-source snapshot over those binaries until parity is proven.

Created by **laredson**.

## Optional modding setup / Instalación opcional

[Español: tutorial completo](PMM/Documentation/UNREAL_SETUP.es.md) · [English: complete tutorial](PMM/Documentation/UNREAL_SETUP.en.md). Also available inside **Settings → Installations → Installation tutorial**.

Unreal and Wwise are **not required for every mod**. PMM’s own supported inspection, extraction, editing and repacking workflows run without them. Editor/cooker workflows need Unreal; the full kit profile additionally needs Wwise/AkAudio. Dependencies being detected does not certify cooking or in-game behavior.

This setup branch preserves PMM adapters, pinned versions and portable defaults. Proprietary offline installers remain in a separate private personal backup, never in this public Git tree or public PMM ZIP. The tutorial explains verified offline restoration and official first-time acquisition.


ChatGPT Desktop (preview): installation pairing and a per-case destination selector; no Codex CLI required for Desktop. Links prepare local chats with assisted submission when accessibility cannot verify the destination. [Español](PMM/Documentation/CHATGPT_SETUP.es.md) · [English](PMM/Documentation/CHATGPT_SETUP.en.md). Free-account and game validation remain pending.
