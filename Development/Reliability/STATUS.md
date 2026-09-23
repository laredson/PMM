# Current status - PMM v1.5.0.2

## Identity

Branch: `v1.5.0.2`

Distributed package remains unchanged:
- VERSION: `1.5.0.2`
- BUILD_ID: `PMM-v1.5.0.2-development-baseline`
- PMM.exe: unchanged
- PMMRuntime.exe: unchanged
- PMMFixLab.exe: unchanged

## Environment gate

A real local clone was attempted again on 2026-09-23 and failed:

`Could not resolve host: github.com`

The execution environment also has no Wine/Windows runtime.

Therefore this prompt could not honestly close:
- NF01-L exact checkout/index/hash confirmation;
- NF02A exact-clone build;
- NF02A Windows runtime acceptance.

No package integration was performed because Windows acceptance is mandatory.

## NF02A integration preparation

Canonical source:
`Development/Source/PMM/`

Architecture:
`PMM.exe Host -> separate child PMM.exe runtime <command>`

Prepared in this block:
- Host doctor no longer requires `Engine/PMMRuntime.exe`;
- Runtime doctor no longer requires `Engine/PMMRuntime.exe`;
- native-shell text/version handling reflects same-binary Runtime mode;
- Windows Host contract test added for same-executable Runtime routing;
- build.py now cross-compiles Windows test sets for dispatch/host/runtime/supervision/uibridge;
- build.py validates PE32+ / x86-64 / Windows GUI metadata;
- build-report schema advanced to `PMM_NF02A_UNIFIED_BUILD_V2`;
- disposable `Development/Tools/nf02a_windows_stage.py` added;
- staging transformation tested against current routes.json: all 5 native routes convert to `PMM.exe runtime ...`;
- Python syntax validation for build/staging tooling: PASS.

## NF02 plan refinement

NF02 is explicitly split:

- **NF02A:** unified Host+Runtime candidate + Windows acceptance;
- **NF02B:** migrate every active direct PMMRuntime.exe caller;
- **NF02C:** delete PMMRuntime.exe only after zero active direct callers remain.

Reason: editable modules may call PMMRuntime.exe directly outside Host routes.

Docs:
- `NF02_PACKAGE_INTEGRATION.md`
- `NF02B_RUNTIME_CALLSITE_MIGRATION.md`

## Prior cross-build evidence

`NF02A_BUILD_EVIDENCE.json` remains historical evidence for the canonical source
through commit `1dea2074322215d65ab75ed963f4f82aec74a577`.

This block changes canonical source/build tooling, so the current source must be
rebuilt from an exact clone before Windows acceptance. Do not reuse the old
reconstruction EXE hash as current evidence.

## Roadmap

- NF00: CLOSED
- PRE-NF01: CLOSED
- NF01 evidence: COMPLETE
- NF01-L exact local confirmation: PENDING ENVIRONMENT
- NF02A canonical source: COMPLETE
- NF02A integration-prep delta: COMPLETE
- NF02A exact-clone build: NEXT
- NF02A Windows acceptance: NEXT
- NF02A package integration: BLOCKED UNTIL WINDOWS PASS
- NF02B direct-call migration: PENDING
- NF02C PMMRuntime deletion: PENDING
- NF03+: PENDING
