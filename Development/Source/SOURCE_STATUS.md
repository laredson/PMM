# Native source snapshot status

This directory was imported from `PMM_v1.2.1_RESTRUCTURED_REPOSITORY`.

The packaged `PMM/` directory is the later Guided Flow build confirmed working by the user. Its `PMM.exe` and `Engine/PMMRuntime.exe` contain native changes that are not present in this source snapshot.

For that reason the repository build scripts currently compile into a temporary file and intentionally **do not overwrite the packaged binaries**. Reconcile/recover the matching Guided Flow Host/Runtime source before restoring automatic replacement of those executables.

This warning does not apply to the PowerShell/WPF application code under `PMM/Modules/` and `PMM/Resources/`, which comes directly from the working Guided Flow package.
