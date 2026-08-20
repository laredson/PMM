# Contributing to Palworld Manager Merger (PMM)

PMM welcomes code, documentation, tests, mappings, validators, and knowledge-library contributions.

## Development contributions

1. Fork the repository.
2. Create a branch from `main`.
3. Keep changes focused and testable.
4. Add or update tests when practical.
5. Do not commit game saves, extracted copyrighted game assets, credentials, personal data, logs, caches, or local Game Reference data.
6. Open a pull request describing what changed, why, how it was tested, and compatibility concerns.

Recommended branches:

- `feature/<short-name>`
- `fix/<short-name>`
- `knowledge/<short-name>`
- `docs/<short-name>`
- `release/<version>`

## Knowledge contributions

Validated knowledge belongs under `Knowledge/`.

Never place untrusted submissions directly in the validated library.

Expected flow:

`submission -> quarantine -> schema validation -> duplicate detection -> safety checks -> community evidence -> runtime validation -> experimental/stable/rejected`

Prefer normalized JSON, hashes, semantic diffs, internal object paths, mappings, and PMM-generated fixtures.

Do not submit complete `.sav`/`.pak` files, executables, scripts as evidence, extracted commercial game assets, usernames, Steam IDs, machine names, full local paths, tokens, or credentials.

## Knowledge channels

### Stable
Highly validated knowledge with strong evidence and successful runtime tests.

### Experimental
Knowledge that passed safety/schema validation and has enough supporting evidence for broader testing, but has not yet met the stable threshold.

Negative reports are first-class evidence. Competing experimental recipes may coexist until evidence favors one.

## Releases

Do not commit release ZIPs. Publish release artifacts through GitHub Releases after the source commit/tag is finalized.
