# PalModMerger preview30 — Deploy hotfix

The real preview29 workspace localizes the Deploy error to transaction-journal
preparation, before commit. The failing code wrapped a generic `List[object]`
created through `New-Object` in `@(...)`, which can trigger PowerShell's
`Argument types do not match` binder error.

Preview30 is intentionally narrow:

- only the Deploy transaction backup/staging generic lists (plus rollback-error
  list) switch to direct .NET constructors;
- deployment journal object lists use `ToArray()`;
- the unexpected unconditional Deploy confirmation dialog is removed;
- preflight collision checks and transactional staging/hash/backup/rollback stay;
- PMMCore 0.7.1 and merge algorithms are unchanged.

Runtime evidence from the user's preview29 folder:

- 41-source final Triple-only set;
- four shared families merged automatically;
- final overlay SHA-256
  `528e11410847709f88c48e9f89b958cbf87d1b8b532b09eb15fed7be249075bb`;
- size 1,320,508 bytes;
- manual deployment reported working in Palworld;
- Save backup and world restore reported working.

Preview30 now needs one Windows test of Deploy itself.
