# PMM unified native source

Status: **NF02A canonical candidate source**

This directory is the new canonical source target for PMM-owned Host + Runtime convergence.

## Architecture

One executable file, separate processes:

```text
PMM.exe                 # Host mode
  -> PMM.exe runtime start
```

The second invocation is a separate OS process. Runtime failure therefore does not imply Host-process failure.

## Source lineage

This source was consolidated from the latest Reliability NativeCandidates for:
- Host;
- Runtime;
- Supervision;
- UIBridge.

It deliberately does not promote the older `Development/Source/Host` or `Development/Source/Runtime` snapshots.

Transformations from the latest candidates are intentionally narrow:
- Host/Runtime `package main` -> internal packages;
- candidate `main()` -> exported `Main()`;
- Supervision/UIBridge become internal module imports;
- Host native routes targeting `Engine/PMMRuntime.exe` execute the same binary as `runtime <route args>`;
- Runtime help text reflects `PMM.exe runtime ...`.

No NF03/NF04 product hardening is folded into this migration.

## Build

From repository root or this directory:

```
python Development/Source/PMM/build.py --out <new-directory-outside-repo>
```

The build:
- requires installed Go 1.23.2;
- forces local/offline toolchain/module settings;
- runs cross-platform package tests;
- cross-compiles the Windows test sets for dispatch/Host/Runtime/Supervision/UIBridge;
- validates the candidate PE32+ x86-64 GUI contract;
- builds `PMMUnified-candidate.exe`;
- records source/test/candidate hashes;
- never replaces `PMM/PMM.exe`.

## Acceptance

Do not package this candidate until the Windows gate in
`Development/Reliability/NF02A_ACCEPTANCE.md` passes.

PMMRuntime.exe and PMMFixLab.exe remain distributed during NF02A.


## Windows staging

After an exact build, create a disposable package outside the repository:

```text
python Development/Tools/nf02a_windows_stage.py \
  --candidate <build>/PMMUnified-candidate.exe \
  --build-report <build>/build-report.json \
  --out <new-dir-outside-repo> \
  --run-diagnostics
```

The staging copy rewrites the native Host routes to `PMM.exe runtime ...`
and replaces only the staged PMM.exe. PMMRuntime.exe remains until NF02B proves
that every direct module callsite has migrated.
