# PMM v1.1 CLEAN RC1 — Windows / Palworld validation plan

Build ID expected everywhere: `PMM-v1.1-CLEAN-RC1`

Do not publish the candidate until the required checks below pass.

## A. Clean extraction / identity

- [ ] Extract the ZIP into a **new empty folder**.
- [ ] Confirm `BUILD_ID.txt` contains `PMM-v1.1-CLEAN-RC1`.
- [ ] Launch only that extraction via `Start.cmd`.
- [ ] Confirm the title shows `Palworld Manager Merger v1.1 CLEAN RC1`.
- [ ] Confirm the visible product tabs are **Mods & Merge**, **Saves**, and **Settings**.
- [ ] Confirm there is no Developer Console tab and no Mod Edit tab.

## B. Offline-first dependency startup

Recommended: disconnect the network temporarily for this test.

- [ ] Start PMM with the bundled files untouched.
- [ ] Confirm startup reaches the GUI without trying to download .NET/PMMCore/AssetReader/repak/mappings.
- [ ] Reconnect the network after the check.
- [ ] Do not deliberately corrupt dependencies on the release-candidate machine unless you want to test repair separately.

## C. Analyze background worker

Use a known mod set that previously analyzed successfully.

- [ ] Import/select the source mods.
- [ ] Click **Analyze**.
- [ ] While Analyze runs, drag/move the PMM window.
- [ ] Change to the Saves or Settings tab and back.
- [ ] Confirm the progress text/bar continues updating.
- [ ] Confirm the UI does not freeze.
- [ ] Confirm Analyze completes and the expected shared/auto/conflict/unsupported counts appear.
- [ ] Confirm `Cache/OperationJobs` does not retain the completed temporary job.

## D. Build background worker

- [ ] Resolve any real conflict rows as expected.
- [ ] Click **Build**.
- [ ] While Build runs, move the window and switch tabs.
- [ ] Confirm Build progress continues updating and the UI remains responsive.
- [ ] Confirm Build completes successfully.
- [ ] Inspect `Builds/Current`.
- [ ] Confirm PMM produced only its managed compatibility patch/manifest.
- [ ] Confirm the original source PAKs were not rewritten or replaced.

## E. Deploy / game runtime

- [ ] Deploy the built patch.
- [ ] Confirm the original source mods remain present.
- [ ] Confirm the PMM compatibility overlay is the added managed output.
- [ ] Launch Palworld.
- [ ] Load a known-good existing world and verify expected mod behavior.
- [ ] When practical, create/load a new test world as an additional clean-state check.
- [ ] Exit Palworld normally.

## F. Priority / effective-order patch reuse

Choose a saved patch whose source set contains at least one mod that does **not** participate in the relevant conflict.

### Harmless reorder

- [ ] Reorder only a source mod that does not change any priority-resolved conflict winner.
- [ ] Confirm the saved patch remains compatible/current where appropriate.
- [ ] Confirm PMM does not invalidate the patch merely because the full list order changed.

### Relevant reorder

- [ ] Reorder two providers that request different values for the same supported conflict so the priority winner changes.
- [ ] Confirm PMM treats the previous patch as not current / effective order changed.
- [ ] Re-run Analyze and Build.
- [ ] Confirm the new result follows the new intended priority.

## G. Game Reference background worker

- [ ] Settings -> **Build / refresh Game Reference**.
- [ ] Confirm progress is visible.
- [ ] Move the window and change tabs during the operation.
- [ ] Confirm the UI remains responsive.
- [ ] Confirm Game Reference completes and can be opened.
- [ ] Confirm Palworld installation files were not modified.

## H. Unsupported -> AI_HANDOFF

Use a known Unsupported combination if available.

- [ ] Run Analyze.
- [ ] Select the Unsupported asset.
- [ ] Open/generate its AI_HANDOFF.
- [ ] Confirm the handoff ZIP exists.
- [ ] If Game Reference is missing/stale and you choose to build it, confirm Game Reference runs in background and Analyze is regenerated afterward.
- [ ] Confirm the handoff still contains exact case/hash/context material expected by the existing v1.1 workflow.

## I. Manual/AI solution contribution

Only if you have a known returned `PMM_MANUAL_SOLUTION_V1`.

- [ ] Import the solution.
- [ ] Confirm PMM validates it as experimental rather than silently trusted.
- [ ] Confirm automatic Analyze after import runs without freezing the UI.
- [ ] Build and Deploy.
- [ ] Test in Palworld.
- [ ] After a real PASS, Settings -> **Create tested contribution...**.
- [ ] Confirm a `PMM_KNOWLEDGE_CONTRIBUTION_<case>.zip` is created under `Data/KnowledgeContributions`.
- [ ] Confirm exporting a contribution does not modify `Knowledge/production-recipes.json`.

## J. Saves / manager-only workflow

- [ ] Backup a test world.
- [ ] Confirm the backup is created.
- [ ] Verify the manager-only / No compatibility patch selection still behaves normally.
- [ ] Deploy source mods without a PMM compatibility patch.
- [ ] Confirm an old PMM overlay is removed when requested and source mods remain intact.

## K. Restart regression

- [ ] Close PMM normally.
- [ ] Reopen the same candidate.
- [ ] Confirm no background worker is left running.
- [ ] Confirm library/order/settings persist.
- [ ] Repeat one Analyze -> Build -> Deploy cycle.

## Pass criteria

Publish v1.1 only when:

- all required sections pass;
- no source mod is unexpectedly modified;
- no UI deadlock occurs during Analyze/Build/Game Reference;
- known-good merge behavior remains correct in Palworld;
- relevant priority changes invalidate/rebuild correctly;
- harmless full-list reordering does not invalidate a patch solely because of unrelated order;
- AI_HANDOFF and manual contribution export still work;
- no Console, Mod Edit, or MegaMerge path appears in the public workflow.

Record failures with the BUILD_ID, exact steps, screenshots, and `Logs/PalModMerger.log`.
