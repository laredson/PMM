# Preview30 validation target

Preview30 does not change PMMCore 0.7.1 or merge algorithms.

Known-working manually deployed preview29 overlay:
`zzzzzzzzzz_PMM_Merge_20260816_133452_P.pak`
SHA-256 `528e11410847709f88c48e9f89b958cbf87d1b8b532b09eb15fed7be249075bb`.

Acceptance:
1. press Deploy with the same current library;
2. no unconditional modal confirmation;
3. no `Argument types do not match` failure;
4. `Data/deployment-state.json` exists after success;
5. deployed overlay hash equals local current overlay hash;
6. short Palworld smoke test preserves Fly + Triple + Stack/weight + NoSpoil +
   Early Aquatic.

If it fails, preserve `Logs/PalModMerger.log` and the newest
`Builds/DeploymentBackups/<transaction>/` folder.
