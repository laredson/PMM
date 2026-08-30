# Palworld Manager Merger v1.3.0 RC27

RC27 introduces the local-first **AI & Help** workspace, strict manual ZIP AIIO sessions/candidates, local diagnostics and validation, the image-capable theme editor, equal responsive header halves and the official/user theme architecture. It preserves the complete RC22–RC26 regression chain. See `RC27_RELEASE_NOTES.md` and `PMM/Documentation/TEST_THIS_BUILD_RC27.txt`.

No automatic upload, provider login, returned-code execution, Apply Fix, Build, Deploy or publication is enabled. Windows acceptance remains required before final promotion.

---

# Historical: Palworld Manager Merger v1.2.1

## Stable 1.2.1 desktop polish

- `PMM.exe` is now linked as a Windows GUI-subsystem application and is the documented normal entry point.
- PMM Host/Runtime launch console-subsystem helpers with `CREATE_NO_WINDOW`, eliminating the startup CMD/PowerShell flash while keeping the actual WPF/native GUI visible.
- The selected PMM icon is converted to a multi-resolution `UI/PMM.ico`, embedded into both native executables, loaded by the WPF window, and used by the native fallback shell.
- `Start.cmd` remains only as a compatibility launcher; `QUICK_START.txt` and current user/publishing documentation now point to `PMM.exe`.
- Version/build identity is finalized as `v1.2.1` / `PMM-v1.2.1`.

## Included

- Native `PMM.exe` supervisor/host with stdout/stderr/session evidence and emergency AI handoff creation.
- Native `PMMRuntime.exe` capability layer with dependency verification, process execution, hashing,
  archive handling, Palworld discovery, Knowledge validation and native Win32 fallback UI.
- PowerShell-free normal startup route: `PMM.exe -> Runner/routes.json -> PMMRuntime.exe start`.
- Complete open source for both executables and rebuild scripts.
- External editable Compatibility Knowledge Library (`Knowledge/*.json`).
- Proven v1.1.1 FIX4 merge baseline, including the Ribunny package choice:
  `Luny` OR `Ribunny + Shine`.
- Repak timeout, Smart Log, HeaderPath hardening and the existing schema-15 merge-plan behavior.

## PowerShell language-mode boundary

v1.2.1 keeps an explicit ConstrainedLanguage migration boundary. Startup,
dependency preparation, supervision and the native fallback UI no longer require FullLanguage,
but the complete existing Analyze/Build/Deploy/Saves workspace still runs through the proven
PowerShell/WPF/Core path on FullLanguage systems. Do not advertise the WPF workspace as fully CLM-native until
those remaining end-user operations are migrated behind PMMRuntime or independently proven CLM-safe.

Fix Lab is not included in this baseline; it is intended to be integrated from the separate Fix Lab
handoff after preserving this candidate's regression behavior.

## AIIO disk-safety correction

- `Analyze` is metadata/report only and no longer creates AI handoff ZIPs or persists cooked source payloads in `Data/Review`.
- `Core/AIIO.ps1` creates one explicit handoff bundle for all current Unsupported cases, extracting only the exact conflicting files/families from each active provider and installed Vanilla.
- Whole source `.pak` files are forbidden in AIIO bundles and the completed ZIP is verified before publication.
- Normal handoff limits are 5 GiB uncompressed input and a 512 MiB ZIP target; larger bundles require explicit user approval.
- AIIO uses the native `PMMRuntime.exe archive create` path instead of PowerShell `Compress-Archive` and always removes staging/partial output in `finally`.
- Startup hygiene removes abandoned Analyze/AIIO staging, old review payload directories, legacy per-case AI handoff ZIPs and partial handoff files while preserving valid final handoffs, mods, saves, builds, Knowledge, ManualSolutions and Game Reference.

## AIIO / disk-safety QA2 hardening

- AIIO now fails closed if any current Unsupported `case.json` is missing, corrupt, duplicated, inconsistent with the merge plan, or no longer matches its pinned provider/file hashes.
- Analyze uses per-asset scratch directories and deletes each asset's extraction immediately after analysis, bounding temporary disk use by the current asset group instead of accumulating every conflict until the end.
- Plain/non-Unreal shared Unsupported files now receive metadata-only review cases and are included in the same combined AIIO bundle; automatic returned-solution import remains limited to validated Unreal cooked families.
- AIIO performs conservative free-space preflight for staging plus worst-case incompressible ZIP output and a reserve, rechecks before compression, serializes writers across PMM instances, and refuses a bundle if Analyze changes while packaging.
- Analyze, Build and AI handoff background operations are serialized across PMM instances for the same installation.
- Merge plans and saved patches now carry a quick Vanilla PAK-set signature, so a Palworld update invalidates stale analysis/build output even when the mod list did not change.
- Exact PAK extraction and native ZIP extraction reject traversal, Windows ADS/device names, invalid Windows path components, symlinks and case-colliding duplicate paths.
- Native archive creation closes each source file immediately; stress testing under a 64-file-descriptor ceiling covers large handoffs without handle accumulation.
- Returned AI/manual solution ZIPs are prevalidated for safe paths, duplicates and a 5 GiB expanded-size limit before extraction.
- ZIP mod imports use native safe extraction and free-space preflight. `.7z`/`.rar` imports remain on the external 7-Zip path.
- Save backup and Knowledge contribution packaging use the native archiver. Save restore extracts/validates to staging before touching the live save, performs a safety backup, attempts rollback on copy failure, and now checks working disk space before extraction.
- Game Reference refresh uses an owned incoming stage plus rollback/recovery markers so a hard process kill can be repaired on the next startup.
- Startup hygiene recognizes active-process ownership and cleans only known abandoned PMM transient paths; unknown user context under Review is preserved.
