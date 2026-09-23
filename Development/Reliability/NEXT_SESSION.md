# NEXT SESSION - PMM v1.5.0.2

## Active gate: NF01-L confirmation + NF02A build/acceptance

Use a network-capable local clone.

### 1. NF01-L confirmation

- fetch + checkout `v1.5.0.2`;
- fast-forward only;
- clean tree;
- run `python Development/Tools/build_repo_index.py`;
- recompute SHA-256 of PMM.exe, PMMRuntime.exe, PMMFixLab.exe;
- exhaustive local search for Bypass/process-launch sites;
- compare with `Development/Reliability/NF01_FINDINGS.md`.

If no critical contradiction appears, mark NF01 CLOSED.

### 2. Build NF02A canonical source

Run:

```
python Development/Source/PMM/build.py --out <new-directory-outside-repo>
```

Expected:
- local tests PASS;
- Windows Host test compile PASS;
- `PMMUnified-candidate.exe` produced;
- build-report.json produced;
- package untouched.

If compilation reveals migration defects, fix only the unified source under `Development/Source/PMM/` and keep the old snapshots/candidates unchanged.

### 3. Windows acceptance

Follow:
`Development/Reliability/NF02A_ACCEPTANCE.md`

If Windows acceptance passes:
- record evidence;
- then prepare NF02 package integration in the same prompt if context permits.

Do not yet:
- remove PMMRuntime.exe;
- merge FixLab;
- remove Bypass;
- change startup repair semantics;
- change Updates behavior.

One coherent commit per prompt, `[skip ci]`, no Actions/remote CI.
