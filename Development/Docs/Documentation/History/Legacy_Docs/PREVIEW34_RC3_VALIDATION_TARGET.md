# Palworld Manager Merger preview34 RC3 validation target

RC3 fixes one RC2 Windows PowerShell runtime regression in the source-mod checkbox workflow.

## Primary acceptance test

1. Start from a fresh PMM folder with no Analyze result and no saved compatibility patch required.
2. Import one or more PAK mods.
3. Immediately uncheck one source mod.
4. Expected: the mod moves to `Mods/_Disabled`, no error dialog appears, and Analyze is not required.
5. Re-check the same mod.
6. Expected: the mod returns to the active library.
7. With `No compatibility patch` selected, Deploy should synchronize the resulting active source-mod set normally.

No merge-engine regression retest is required beyond a normal application smoke test because PMMCore and all merge adapters are unchanged from the runtime-proven RC2 baseline.
