# PMM Community Knowledge Library (CKL)

This directory contains compatibility knowledge, not executable engine binaries.
It is intentionally independent so reviewed knowledge can evolve without rebuilding PMM.

- `Stable/` — reviewed knowledge distributed to normal users.
- `Experimental/` — candidate evidence; never automatic merge permission.
- `Catalog/case-index.json` — compact master index queried by Analyze before detailed records.
- `channels.json` — Stable/Experimental channel identity and repository references.

Analyze first searches the catalog by asset + provider identity/hash. Normal PMM adapters remain the primary proof mechanism. Only a `production.enabled=true` Stable recipe whose complete exact validation contract matches may authorize a known-recipe output.

AIIO includes relevant CKL references in user-requested handoffs, and tested returned solutions can be exported as contribution evidence for later review/promotion.

See the repository document `docs/CKL_ARCHITECTURE.md` for the full model.

## Fix Lab namespace

Legacy/broken-mod repair knowledge lives under `CKL/FixLab/` and is intentionally separate from normal merge recipes. Fix Lab can match exact source signatures, expose documented output variants, and package the relevant repair evidence without granting automatic build permission unless the recipe's executor and validation contract are ready.
