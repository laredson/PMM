# Troubleshooting

## Analyze says Unsupported

This is not necessarily proof that the mods are incompatible. It means no current safe adapter proved the composition.

Try:

1. Open the blocked asset details.
2. Review the involved providers.
3. Use the suggested least-impact disable option if you just want a build now.
4. Or use **HAND TO AI / MODDER** to export the exact case.

## Build is disabled

Common reasons:

- unresolved True Conflict;
- Unsupported asset with no accepted manual solution;
- Analyze state is stale after changing source mods;
- source hashes/mappings changed since Analyze.

Analyze again after changing the library.

## Deploy is disabled

A matching current/saved patch may not exist yet, or the selected patch does not belong to the exact current source hashes/mappings.

## A saved patch radio button is disabled

That patch is historical but does not match the exact current active source signature and mappings. Re-enable the original source set or build a new patch.

## Game folder contains an unknown same-name PAK

PMM intentionally refuses to overwrite/delete a file it cannot identify as managed. Move/rename/inspect the external PAK yourself before retrying.

## A manual AI solution imports but does not work in-game

Structural validation is not gameplay validation. Remove/disable the experimental solution, return to a known safe source set, and keep the handoff + solution + FAIL runtime report for further investigation.

## Save restore

Do not interrupt restore deliberately. PMM creates a safety backup before replacing the world, but keeping independent backups is still recommended.

## Logs

Use `Logs/PalModMerger.log` for setup/Analyze/Build/Deploy history and send that **single file** when reporting a problem. v1.1.1 uses an append-only Smart Log: every physical line is timestamped, process sessions are marked, and exact consecutive repeats are coalesced into count + first/last-time checkpoints instead of flooding the file. Distinct diagnostic lines are preserved rather than rotated or truncated away. For developer reports, include PMM version, active source hashes where practical, the relevant AI_HANDOFF/review case, and exact error text.
