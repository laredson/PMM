# PMM 1.2.1 — continue here

This tree is the stable 1.2.1 baseline derived from the QA2 disk-safety candidate and maintainer-tested
Analyze -> Build -> Deploy workflow.

Read `Documentation/V1_2_1_VALIDATION.md`, `ARCHITECTURE.md`, `HANDOFF.md`, and `QA_REPORT.md` before
changing merge behavior. Preserve the tested AIIO rule: Analyze never creates AI handoff archives;
AIIO creates at most one explicit bundle for the current analysis and never includes whole source PAKs.

Normal user startup is `PMM.exe`. The Host is built as a Windows GUI-subsystem executable, child
console processes are created with `CREATE_NO_WINDOW`, and the PMM icon is embedded in PMM.exe /
PMMRuntime.exe and loaded by the WPF workspace.
