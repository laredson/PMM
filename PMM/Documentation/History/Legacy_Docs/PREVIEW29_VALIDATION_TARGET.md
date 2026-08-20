# Preview29 regression target

PMMCore: 0.7.1 (unchanged from preview28)

Primary application regression:

- Analyze the same active set that passed preview28.
- Expected compatibility summary remains:
  `Shared 4 | merged automatically 3 | true-conflict decisions 1 | unsupported 0 | identical 0`.
- The one decision remains MultiJump Triple vs Quad inside BP_PlayerBase.
- Choose Triple (or the previously runtime-tested value), Build, Deploy and start Palworld.
- Verify Fly + chosen MultiJump + Stack + NoSpoil + Early Aquatic + the other existing test mods.

Preview29-specific lifecycle regression:

1. After a successful Build/Deploy, run Analyze again so it takes the current-patch short-circuit.
2. Press Deploy again and inspect its preview.
3. The unselected pure MultiJump alternative must remain suppressed.
4. Put a different same-name PAK in ~mods (only in a disposable test setup): Deploy must block rather than overwrite/delete it.
5. Delete/disable a PMM library source, then Deploy: PMM may remove the game copy only when its SHA-256 matches a trusted managed hash.
6. Confirm `Builds\DeploymentBackups` receives rollback metadata/backups only for files actually replaced/removed.

Do not broaden adapters if this lifecycle test fails. Debug deployment/plan-state code first.
