# NEXT SESSION - PMM v1.5.0.2

## Active gate: exact build -> disposable Windows stage -> NF02A acceptance

Do not repeat architecture research.

### 1. Exact local confirmation

On a network-capable Windows/local Codex clone:

1. fetch + checkout `v1.5.0.2`;
2. fast-forward only;
3. require clean tree;
4. run `python Development/Tools/build_repo_index.py`;
5. recompute SHA-256 of PMM.exe, PMMRuntime.exe, PMMFixLab.exe;
6. compare Bypass/process inventory with `NF01_FINDINGS.md`.

If no critical contradiction appears, close NF01-L.

### 2. Build current canonical source

Run:

```text
python Development/Source/PMM/build.py --out <new-dir-outside-repo>
```

Require:
- schema `PMM_NF02A_UNIFIED_BUILD_V2`;
- cross-platform tests PASS;
- Windows test binaries compile for dispatch/host/runtime/supervision/uibridge;
- PE contract = 0x8664 / PE32+ / GUI subsystem;
- source tree remains clean.

### 3. Create disposable final-route Windows stage

Run:

```text
python Development/Tools/nf02a_windows_stage.py \
  --candidate <build>/PMMUnified-candidate.exe \
  --build-report <build>/build-report.json \
  --out <new-dir-outside-repo> \
  --run-diagnostics
```

Require all five automated diagnostic exit codes = 0.
The stage must report five Runtime routes rewritten to `PMM.exe runtime ...`.

### 4. Manual Windows behavior gate

Follow `NF02A_ACCEPTANCE.md`:
- normal startup;
- splash;
- WPF foreground handoff;
- clean close;
- Host session/result evidence;
- forced Runtime child failure -> Host survives/records it;
- no unexpected console window.

### 5. If and only if NF02A passes

Perform NF02A first package integration in the same prompt if context permits:

- replace repository PMM.exe with the exact accepted candidate;
- rewrite distributed native routes to `PMM.exe runtime ...`;
- update VERSION/BUILD_ID/RELEASE_MANIFEST/SHA256SUMS atomically;
- **retain PMMRuntime.exe**.

Then begin NF02B:
`NF02B_RUNTIME_CALLSITE_MIGRATION.md`.

Do not delete PMMRuntime.exe until NF02B proves zero active direct callers.

Still do not mix NF03/NF04/P01 work into NF02.
