# PMM v1.1.1 — QA status

Build: `PMM-v1.1.1`

## Release status

v1.1.1 is the maintenance release on top of the known-good public v1.1 baseline. It contains only two maintenance areas: exact `repak get` hang protection and the Smart Log redesign. No Fix Lab code is included and no merge/conflict authorization behavior is changed.

The project owner approved promotion of the maintenance line to a publish-ready v1.1.1 package after reviewing the logging design. This environment can perform static/package validation but cannot execute the Windows WPF + Palworld runtime path; real Windows/Palworld verification remains the final external runtime check.

## Package contracts

- PMMCore: 0.9.0
- merge-plan schema: 15
- build-manifest schema: 8
- .NET Runtime: exact 8.0.30, bundled
- repak: bundled and SHA-256 pinned
- mappings: bundled and SHA-256 pinned
- AssetReader/PMMCore managed runtime files: SHA-256 pinned
- Oodle: not redistributed
- end-user compilation/NuGet restore: not used
- user PAKs/saves/logs/generated builds/local Game Reference: not shipped

## v1.1.1 maintenance assertions

- exact `repak get` consumes redirected stdout/stderr concurrently;
- each exact extraction is bounded to 180 seconds;
- partial output is removed after timeout/failure;
- the logger uses one append-only `Logs\PalModMerger.log` rather than ZIP rotation;
- every logged physical line has a timestamp;
- UI/background worker sessions have start/end markers;
- exact consecutive repeats are coalesced with count, first timestamp, last timestamp, and periodic checkpoints;
- unique child-process diagnostic output is not truncated by the logger;
- successful `repak list` and redundant fast extraction-success lines are suppressed;
- Settings identifies the single support-log path;
- no Fix Lab implementation is present.

See `Documentation/V1_1_1_RELEASE_VALIDATION.md` for the focused runtime checks.


## v1.1.1 FIX3 package-choice preflight
- Adds curated package-choice rules before asset merge analysis.
- Nexus Palworld #4935 is treated as `Luny` OR `Ribunny + Shine`; all three active produces one explicit Decision Required instead of entering asset merge analysis.
- The unselected alternative remains in the PMM library but is excluded from the second Analyze pass and Deploy.
- Analyze now saves any live decision-grid selection before rerunning, so choosing a package variant and pressing Analyze applies it.
- Package choices never create patch bytes by themselves and are honored even in source-mod-only Deploy.
- `HeaderPath` family-export handling is hardened and `Get-PakEntry` output is explicitly suppressed inside exact family extraction.
- Merge-plan schema is 15. No Fix Lab code is included.

## v1.1.1 FIX4 startup/validation separation

- Public `Start.cmd` no longer runs the maintainer/source `SmokeTest.ps1` before every launch.
- `Start.cmd` now verifies/repairs runtime dependencies and then starts PMM directly; a real application failure returns to the launcher with the support-log path.
- `RUN_VALIDATION.cmd` is the explicit maintainer/developer release-validation entry point.
- `SmokeTest.ps1` writes validation failures and pass/fail status to `Logs/Validation.log`, so a failed validation is no longer lost when the console closes.
- FIX3 package-choice behavior, HeaderPath hardening, bounded `repak get`, and Smart Log behavior are retained unchanged.
- No Fix Lab implementation is included.
