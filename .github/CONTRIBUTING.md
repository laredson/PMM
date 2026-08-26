# Contributing to Palworld Manager Merger (PMM)

PMM welcomes focused code, documentation, tests, mappings, validators and compatibility-knowledge contributions.

## Development workflow

1. Read `Development/AI/CURRENT_STATE.md` and the relevant engineering documentation.
2. Fork the repository or create a branch from the appropriate stable/development branch.
3. Keep changes focused and testable.
4. Add/update tests when practical.
5. Do not commit game saves, extracted copyrighted game assets, credentials, personal data, logs, caches, local Game Reference data or user Workspace contents.
6. Open a pull request describing what changed, why, how it was tested and any compatibility concerns.

Recommended branch names:

- `dev/<version-or-feature>`
- `feature/<short-name>`
- `fix/<short-name>`
- `knowledge/<short-name>`
- `docs/<short-name>`
- `release/<version>`

## Repository layout

- `PMM/` is the portable application tree.
- `Development/Source/` contains source snapshots.
- `Development/Scripts/` contains build/validation tools.
- `Development/Tests/` contains repository QA.
- `Development/Docs/` contains engineering/history/protocol docs.
- `Development/AI/` contains continuation state and handoffs.

Do not put repository-only files inside `PMM/` unless they are genuinely required by the user's portable application.

## Knowledge contributions

Validated production knowledge belongs in `PMM/CKL/` according to its channel and validation contract. Untrusted intake must never be promoted directly to Stable.

Do not submit complete `.sav`, `.pak`, `.ucas` or `.utoc` files, extracted commercial game assets, usernames, Steam IDs, machine names, full local paths, tokens or credentials as repository evidence.

## Releases

Do not commit release ZIPs. Publish release artifacts through GitHub Releases after the exact source/application commit is finalized and tagged.
