# Current status - PMM v1.5.0.2

## Identity

Branch: `v1.5.0.2`

Distributed package remains unchanged:
- VERSION: `1.5.0.2`
- BUILD_ID: `PMM-v1.5.0.2-development-baseline`
- PMM.exe: unchanged
- PMMRuntime.exe: unchanged
- PMMFixLab.exe: unchanged

## NF01-L

A true local clone was attempted again and the execution container still cannot resolve/connect to `github.com`.

Therefore these exact-checkout confirmations remain open:
- local `.pmm-index` full-repository scan;
- byte-level SHA-256 recomputation of the three distributed PMM-owned EXEs.

NF01 architectural evidence remains uncontradicted.

## NF02A source/build

State:
**CANONICAL SOURCE CONSOLIDATED / CROSS-BUILD PROOF PASS / EXACT-CLONE + WINDOWS ACCEPTANCE PENDING**

Canonical source:
`Development/Source/PMM/`

Architecture:
`PMM.exe Host -> separate child PMM.exe runtime <command>`

A connector-backed local reconstruction of the canonical source was compiled with:
- Go 1.23.2;
- GOTOOLCHAIN=local;
- GOPROXY=off;
- GOSUMDB=off;
- CGO_ENABLED=0;
- target windows/amd64.

Results:
- dispatcher tests: PASS;
- Runtime Linux compile: PASS;
- Supervision Linux compile: PASS;
- UIBridge Linux compile: PASS;
- Host Windows test binary cross-compile: PASS;
- Runtime Windows cross-compile: PASS;
- unified Windows GUI executable cross-build: PASS.

Reconstruction candidate:
- size: 6,526,464 bytes;
- SHA-256: `e0ad8c0a4cc872f30c7077428aedcc66895966111bfc95a38d0e3bb8cd0cae14`;
- PE32+ x86-64;
- Windows GUI subsystem.

This hash is **compile evidence only**, not an official package/candidate identity, because the execution environment could not produce an exact Git checkout and did not materialize every remote test file.

No actual canonical-source compile defect was found.

Build tooling was improved so future exact builds record a per-file source SHA-256 inventory and use the corrected `pmmRuntimeRemoved` field.

Evidence:
`Development/Reliability/NF02A_BUILD_EVIDENCE.json`

## Remaining NF02A gate

A network-capable local/Windows environment must:
1. complete NF01-L against the exact checkout;
2. run canonical `build.py` from that checkout, including all migrated tests;
3. execute `NF02A_ACCEPTANCE.md` on Windows.

Only then may package integration replace PMM.exe or retire PMMRuntime.exe.

## Roadmap

- NF00: CLOSED
- PRE-NF01: CLOSED
- NF01 evidence: COMPLETE
- NF01-L exact local confirmation: PENDING
- NF02A source consolidation: COMPLETE
- NF02A connector-backed cross-build proof: **PASS**
- NF02A exact-clone build: PENDING
- NF02A Windows acceptance: **NEXT**
- NF02 package integration: PENDING
- NF03+: PENDING
