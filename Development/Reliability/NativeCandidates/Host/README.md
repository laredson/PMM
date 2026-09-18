# Host S02B - candidate, NOT installed

Current candidate SHA-256:
`a5f50c5677608c9875eefb65fe75fd7efb3460808be2f53df7ea3ec6db195d97`.
S02B preserves the S02A reconstruction and fixes complete-record framing,
close/failure priority and foreground-check ordering. The original source is
still not recovered; no Windows acceptance or replacement is authorized.

Build with the existing command below, choosing a new S02B output directory.
Compare without executing either EXE:

```text
python -B Development/Reliability/NativeCandidates/Host/compare_host.py --candidate <BUILD_OUT>/PMMHost-candidate.exe --build-report <BUILD_OUT>/build-report.json --out <NEW_COMPARISON_OUT>
```

Optional `--previous <S02A_EXE>` adds the pinned historical candidate to the
comparison. Go1.23.2 is required locally. No downloads, CI, installs or AV uploads.
The helper reads PE/Go function tables, not source semantics. The original and
S02B differ in bytes; equivalence remains UNVERIFIED.

Current evidence: `evidence/s02b/`. All previous files directly under `evidence/`
remain historical S02A records. `build.py` now builds S02B; checkout the S02A
commit baa063933c8940a7654d3350f728a81ed967f92c to reproduce that older candidate.
See ../../SESSION02B_FINDINGS.md and ../../WINDOWS_HOST_ACCEPTANCE.md for the
contract matrix and blockers (HWND origin, security probe, pipes/logs, Windows).

## Reproduction and limits

```text
python -B Development/Reliability/NativeCandidates/Host/build.py --out <NEW_BUILD_OUTSIDE_REPO>
```

Build outputs never overwrite the original. Go1.23.2 and Python3.9+ must already
be installed. build.py pins the original Host, icon and existing icon helper,
records inputs/commands and marks a successful build with COMPLETE.txt.
The helper only adds the verified icon to a new candidate, not to PMM.exe.

Nine Go model tests and thirteen Python tool tests passed; they do not execute
Win32 or validate the CLI behavior on Windows. Two S02B builds in different
output directories were byte-identical on Linux/amd64; cross-host reproducibility
has not been checked. No source original, functional equivalence, signature
validation or antivirus verdict is asserted.

S02A sources and full historical README remain available at commit
baa063933c8940a7654d3350f728a81ed967f92c. Do not reuse its expected candidate hash
for a build of the current source. Packaged PMM/ remains the unchanged reference.
