# Palworld Manager Merger preview34 RC5 validation target

RC5 fixes only the UI/state gate that unnecessarily required Analyze before redeploying an already saved compatible patch after manager-only deployment.

## Required test

1. Start from an active source set with at least one saved compatible patch.
2. Select **No compatibility patch** and Deploy. Confirm the PMM overlay is removed.
3. Without running Analyze, select the saved patch radio button.
4. **Deploy must enable immediately.**
5. Deploy and confirm the selected PMM overlay returns to the game folder.
6. Close/reopen PMM and confirm selection/deployed state remains coherent.

A saved patch is eligible without Analyze only when its manifest/hash checks prove the exact active source signature and mappings. Build remains tied to a current Analyze plan.

PMMCore 0.8.1, adapters, mappings, save service and deployment transaction code are frozen from RC4.
