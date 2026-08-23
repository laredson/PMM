# PMM 1.2 RC1 — continue here

This folder is the clean integration baseline for the next development chat.

Read `Documentation/V1_2_RC1_VALIDATION.md` and the separate `PMM-v1.2-RC1-NEXT-CHAT-HANDOFF.zip`.
Use this exact RC1 package as the source baseline when integrating the separate Fix Lab handoff.
Do not reconstruct PMM from older v1.1/Alpha snapshots.

Preserve these boundaries:

- `PMM.exe` / PMMH stays a small stable supervisor.
- `PMMRuntime.exe` / PMMRT owns capabilities that cannot depend on FullLanguage.
- `Runner/`, external config and UI data remain editable where safe.
- `Knowledge/*.json` remains the external PMMCKL source of truth.
- Future PMMFLKL stays external and reviewable.

The next combined build must preserve the Ribunny PackageChoice regression and must not claim full
ConstrainedLanguage support until Analyze/Build/Deploy/Saves actually work without FullLanguage.
