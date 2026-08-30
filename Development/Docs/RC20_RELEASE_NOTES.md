# Palworld Manager Merger 1.3.0 RC20

> Historical reference only. RC20 was not accepted as the final runtime baseline; use `RC24_RELEASE_NOTES.md` and the RC24 `PMM/` tree.

RC20 is a release-candidate polish pass built directly from the user-tested RC19 baseline.

## User experience

- Header branding uses the transparent HD PMM logo and a three-line PALWORLD / MANAGER / MERGER title.
- The top-right Palworld status is the detection button. It is disabled once a valid installation is known.
- Startup performs automatic detection; if it fails PMM offers Steam-folder or Palworld-folder selection.
- Settings places **Apply changes** at the upper-right of Interface and adds **Restore defaults**.
- Restore defaults resets theme, ColorFlow hint timing and sound preferences without clearing the Palworld path, language or mod library.
- The error sound is displayed as **3 beeps**, distinct from **Microwave finish**.
- Once Analyze/Build/Deploy state is current, ColorFlow ends on **Start Palworld** with **Ready to play / Everything is ready to play**. AUTO launches the game only when `Run Palworld after Deploy` is enabled.

## Analyze performance

RC20 adds two conservative persistent caches:

1. `Workspace/Cache/PakIndexesV1`: repak entry lists are reused between background workers and invalidated by path + file length + LastWriteTimeUtc.
2. `Workspace/Cache/AnalyzeGroupsV1`: deterministic decision-free automatic results are reused only when PMM build ID, mappings, vanilla signature, asset identity and provider name/hash/priority inputs remain unchanged.

Unsupported/manual/AI solution routes, human decisions and `KnownRecipeAuto` are not cached. This specifically makes a repeat Analyze after one isolated repaired/changed mod much lighter without authorizing stale semantic decisions.

## AIIO boundary

The existing merge knowledge/community controls are a migration surface for the future **AI & Help / AIIO** module. AIIO should consume existing review cases, exact handoffs, Game Reference, CKL, tested contributions and Fix Lab handoff services instead of duplicating them.
