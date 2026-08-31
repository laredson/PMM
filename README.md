# Palworld Manager Merger (PMM)

**Current release candidate: PMM 1.3.0 RC29 — AI & Help feedback and UI fix.**

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

RC29 retains the complete RC22–RC28 merge, Fix Lab, validation, responsive-layout, progress, Gura-preflight, theme and AIIO correction chain. It fixes delayed AIIO completion scope, reuses one session per diagnostic, deduplicates repeated automatic errors, enlarges the exact-validation dialog and retires the false RC28 diagnostics during migration. The header now reads Detect/status, folders/optional Play, then AUTO. A successful Deploy highlights Play as ready without presenting it as required.

## AI & Help / AIIO

The visible **AI & Help** workspace is backed by persistent local AIIO sessions, diagnostics, Knowledge, save activity, a recoverable operation journal, deterministic build validation and a color-scheme editor with image-backed V2 packs. Its Feedback view creates inspectable local JSON for general comments, PMM issues, an exact merge/validation or Knowledge/CKL. AI-specific behavior and Game Reference controls live in its Settings view.

The current AI transport is deliberately manual and local: PMM prepares bounded ZIPs and validates returned ZIPs as untrusted data. It does not log into a provider, upload automatically, execute returned code, apply a fix, build, deploy or publish without an explicit user action. Returned solutions remain staged until they satisfy an exact current case contract; accepting an eligible candidate forces Analyze and never triggers Build or Deploy.

Continue development from `Development/AI/AI_CONTINUE_HERE.md` and `Development/AI/AIIO_1_3_0_HANDOFF.md`. The runnable `PMM/` tree and packaged binaries are the release authority. Do not rebuild the older native-source snapshot over those binaries until parity is proven.

Created by **laredson**.
