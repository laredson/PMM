# RC30 static validation record

Candidate: `PMM-v1.3.0-RC30-LEAN-AI-VALIDATION-FLOW`  
Date: 2026-08-31

## Proven in the build environment

- The submitted RC29 log shows global post-validation UI refresh stalls and repeated unchanged theme application. RC30 removes that validation refresh and suppresses same-theme reapplication.
- Main and nested AI tab handlers reject routed selection events whose `OriginalSource` is a child selector.
- Feedback merge binding is not rebuilt while its ComboBox popup is open and restores selection by stable patch key.
- First and repeat validation use the enlarged dialog; PASS/PASS_RECONFIRMED has an explicit feedback contribution route tied to the exact patch.
- The permanent 500 ms UI diagnostic timer is absent. Activation and the remaining idle heartbeat share one 60-second throttle; the check is metadata-only and gated by active/non-minimized/non-processing state.
- AI assistance/reception and selected-case/new-case panels are structurally present; new cases use explicit PMM feature targets and do not raise the main badge.
- Standard AI responses route by embedded session ID. Standalone theme responses are detected by schema and enter only as uninstalled drafts.
- Vanilla Game Reference controls are in the normal Settings tab in all localized XAML files.
- Default, English and Spanish XAML parse with 288 unique `x:Name` controls and exact control-set parity.
- The theme editor records dirty color fields and preserves untouched source values; contrast validation remains mandatory for edited/returned definitions.
- All 48 application JSON documents parse. The internal SHA-256 manifest covers 473 files and verifies exactly against the 474-file portable tree.
- All nine cross-platform RC22–RC30 model regressions pass. A lexical delimiter/string/comment audit covers all 41 PowerShell files; Windows PowerShell's real parser remains the publication gate.
- All 204 inherited executable/DLL/image/icon/audio/mapping files are byte-identical to the executed RC29. The only common application files changed are the two PowerShell controllers, three localized XAML files, release metadata/checksums and current documentation.
- The 724-file root-ready source tree and 474-file portable tree contain no Workspace, PAK/UCAS/UTOC, Oodle, `.git`, `__pycache__` or `.pyc` payloads.

## Still requires Windows

This environment does not provide Windows PowerShell 5.1, WPF, Steam or Palworld. Run `PMM/Documentation/TEST_THIS_BUILD_RC30.txt` before publication. In particular, measure PMM CPU after five idle minutes, exercise the feedback selector immediately after deleting/building a merge, validate the same merge twice, test the successful-validation contribution route and import a real safe AI response ZIP.
