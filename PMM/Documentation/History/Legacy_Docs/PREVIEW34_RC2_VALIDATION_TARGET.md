# Palworld Manager Merger preview34 RC2 validation target

RC2 is intended to be the final functional candidate before v1.0.
The merge engine is frozen; validation is about manager-only deployment and branding.

## A. Existing merger regression

With the known runtime-tested source set, Analyze/Build/Deploy must behave the
same as RC1. Saved compatible patches must remain selectable and deployable.

## B. No compatibility patch mode

1. Ensure one PMM compatibility overlay is deployed.
2. Select **No compatibility patch / source mods only** in Compatibility patches.
3. Deploy.
4. Expected:
   - active source mods are synchronized;
   - the deployed PMM overlay and its managed sidecar are removed;
   - saved patches remain under Builds/Current or Builds/Previous;
   - deployment-state records no compatibility patch;
   - normal source PAKs are not deleted except managed disabled/deleted files
     and redundant byte-identical duplicates.
5. Change an On checkbox and Deploy again without Analyze.
6. Expected: manager-only Deploy is allowed and synchronizes the new active set.
7. Select a saved same-source patch and Deploy.
8. Expected: the selected overlay is restored normally and promoted to Current.

## C. Branding

The main window and startup console should say **Palworld Manager Merger** and
retain **PMM** as the short project name.
