# PMM Community Knowledge Design

## Goal

Allow PMM to evolve with minimal maintainer intervention while keeping stable users protected from untrusted or weakly tested knowledge.

## Knowledge lifecycle

Suggested states:

- `quarantine`
- `candidate`
- `experimental`
- `stable`
- `deprecated`
- `rejected`

Promotion is evidence-driven, never upload-count-only.

## Evidence

Each report should be append-only and tied to a permanent knowledge ID plus immutable revision hash.

Positive and negative reports are both evidence.

## Experimental

An entry may become experimental after:
- schema validation;
- safety validation;
- no executable payloads;
- duplicate/contradiction analysis;
- a plausible reproduction path;
- configurable minimum community evidence.

## Stable

Stable should require:
- successful runtime tests across independent environments;
- no unresolved critical negative evidence;
- deterministic validator pass;
- trusted CI/runtime verification where possible.

## Contradictions

Competing experimental recipes may coexist. PMM should track worked / failed / alternative-worked reports and prefer the highest-confidence recipe for the current environment.

## Intake

Normal users should not need Git.

Recommended flow:

`Create contribution -> sanitize -> preview -> submit`

Anonymous by default, optional alias/contact.

## Updates

Application updates and knowledge updates are separate systems.

Application channels:
- stable
- beta

Knowledge channels:
- stable
- experimental

Never install an arbitrary Git branch directly. A branch/PR must pass validation and produce a versioned artifact plus signed update manifest.

## Rollback

Always preserve the previous known-good application version and knowledge bundle until the new version is confirmed healthy.
