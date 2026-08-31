# PMM 1.3.0 RC21 — clean reconciled release candidate

Build ID: `PMM-v1.3.0-RC21-CLEAN-RECONCILED-RELEASE-CANDIDATE`

## Provenance

RC21 is built from the complete RC19 release tree. RC20-1 was consulted only for its successful header/detection concept and initial cache design; no RC20-1 module or XAML file was copied wholesale. The GitHub `1.3.0final` RC20-2 tree was treated as read-only evidence and was not used as a runtime base because its bootstrap and XAML had lost substantial RC19 functionality.

The RC19 package actually run by the user was compared with the clean RC19 release. Its only binary differences were a locally acquired Oodle DLL and a changed portable .NET `coreclr.dll`; neither runtime-local change is included in RC21.

## RC21 changes

- Transparent 512×512 PMM header mark and three-line PALWORLD / MANAGER / MERGER title.
- The header installation status is the Detect button. Startup still searches automatically; the button is enabled only when action is needed, and a failed click opens one Steam-or-Palworld chooser.
- Apply changes and Restore defaults are grouped at the upper right of Settings. Restore defaults stages only theme, ColorFlow hint and audio defaults; paths, language, library and user data are preserved.
- A current deployment always leaves ColorFlow on the Play button with “Everything is ready to play” / “Ya está todo listo para jugar”. The checkbox still controls automatic launch.
- The visible error cue name is now `3 beeps` / `3 pitidos`; the distinct Microwave finish sound and RC19-tested audio files remain intact.
- Merge-plan schema 17 and conservative repeat-Analyze optimization:
  - persistent `repak list` entry-name indexes keyed by PAK path, size and write time;
  - deterministic group-result cache limited to decision-free automatic modes;
  - exact-plan reuse only for unchanged, decision-free plans containing exclusively those safe modes;
  - no caching of Unsupported, package choice, KnownRecipe, experimental/manual solutions or decision rows;
  - forced Analyze bypasses plan and group-result reuse.

## Preserved RC19 behavior

Fix Lab, package-choice flow, Resolution & Review decision styling/guards, sound-event profiles, Saves, Game Reference, AIIO safety limits, deployment rollback/hash checks and all other RC19 modules remain the baseline. RC21 intentionally does not adopt RC20's shortened bootstrap/XAML or simplified sound UI.

## Packaging rules

The public package contains no `Workspace`, game PAK/UCAS/UTOC files, user mods, saves, logs or proprietary Oodle DLL. `PMM.exe` remains the user-facing launcher. Runtime-created caches stay under `Workspace\Cache` and can be deleted safely; PMM reconstructs them as needed.

## Validation boundary

The release package is designed for Windows. Static source, XAML/control-parity, JSON, manifest/hash and archive checks can be performed cross-platform. Final WPF launch plus real Palworld Analyze/Build/Deploy smoke testing must be performed on Windows before promoting RC21 to final.
