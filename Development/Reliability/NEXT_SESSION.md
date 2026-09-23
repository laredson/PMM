# NEXT SESSION - PMM v1.5.0.2

## Active gate: exact-clone confirmation + NF02A Windows acceptance

NF02A no longer needs architectural investigation. The unified source cross-compiles successfully.

### A. Exact local confirmation

On a network-capable local clone:

1. fetch + checkout `v1.5.0.2`;
2. fast-forward only;
3. require clean tree;
4. run:
   `python Development/Tools/build_repo_index.py`;
5. recompute SHA-256 of:
   - PMM/PMM.exe
   - PMM/Engine/PMMRuntime.exe
   - PMM/Engine/PMMFixLab.exe
6. compare Bypass/process inventory with `NF01_FINDINGS.md`.

If no critical contradiction appears, mark NF01-L CLOSED.

### B. Exact NF02A build

Run from the exact clone:

```
python Development/Source/PMM/build.py --out <new-directory-outside-repo>
```

The updated build report records:
- source SHA-256 inventory;
- package tests;
- Windows Host test compile;
- candidate SHA/size;
- no package installation.

Required:
- all migrated tests that are present in Git execute/compile as appropriate;
- no network/toolchain download;
- build-report.json PASS;
- source tree remains clean.

Do not compare the exact candidate hash with the connector-reconstruction hash as a parity requirement; the reconstruction hash is evidence only.

### C. Windows gate

Follow:
`Development/Reliability/NF02A_ACCEPTANCE.md`

Run the exact-clone-built candidate beside a disposable complete PMM package.

If all Windows checks pass:
- record acceptance evidence;
- then perform NF02 package integration in the same prompt if context permits.

### Still out of scope

Do not yet:
- remove ExecutionPolicy Bypass;
- change startup repair/network behavior;
- migrate OperationWorker;
- merge FixLab;
- repair Updates.

Those remain NF03/NF04/P01.

One coherent commit per prompt, `[skip ci]`; no Actions/remote CI.
