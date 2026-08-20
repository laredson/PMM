# PMM v1.1 - Game Reference and Community Knowledge Contributions

## Why this exists

`AI_HANDOFF` already contains the exact conflict family, source PAKs, hashes, PMMCore
reports and Knowledge snapshot. That is enough for many byte-local conflicts, but some
real problems require surrounding Vanilla context before a fresh AI can understand the
subsystem.

The first end-to-end example was RushRoar Leather Drop v2 + FasterMounts. The exact
conflict was `DT_PalMonsterParameter_Common`, while useful reasoning also required
Vanilla examples around Pal Blueprint actions, `SpawnItem`, Ranch Pals and lottery
DataTables.

PMM v1.1 therefore adds a **local Game Reference Library** generated from the user's
own installed `Pal-Windows.pak` and a **tested contribution package** for returning
successful AI/manual solutions to the PMM maintainer/community.

## 1. Local Game Reference Library

The public PMM release does **not** bundle extracted Palworld cooked assets. In Settings,
**Build / refresh Game Reference** reads the user's own `Pal-Windows.pak` and creates:

```text
Data/GameReference/
  current.json
  current/
    state.json
    cooked/...
    index/
      pak-index.txt
      selected-entries.txt
      families.jsonl
```

Each family index record pins the complete `.uasset/.uexp/.ubulk/.uptnl` family by path,
size and SHA-256. `current.json` also pins the source PAK identity, mappings hash and
reference-scope version. A Palworld/mappings/scope change makes the cache **Stale**.

### Fast extraction contract

The large PAK must not be reopened once per asset. PMM:

1. lists `Pal-Windows.pak` once and caches the index;
2. selects exact supported cooked roots;
3. extracts the five broad roots in **one selective `repak unpack` process**;
4. extracts only a tiny exact allow-list outside those roots in one small pass;
5. uses per-file `repak get` only as an exceptional verification fallback.

Broad roots:

- `Pal/Content/Pal/DataTable/`
- `Pal/Content/Pal/Blueprint/Action/`
- `Pal/Content/Pal/Blueprint/Character/Monster/`
- `Pal/Content/Pal/Blueprint/Character/Player/`
- `Pal/Content/Pal/Blueprint/Component/`

Outside those roots, useful PMM fixtures use exact asset names. Do not use unrestricted
substring searches such as `ranch`, because `branch` is an unrelated match.

The development research capture supplied for the 2026-08-17 game build contained
185,014 PAK entries. The production selector chooses 7,134 cooked files / 3,565 complete
families / about 66.8 MiB raw for that build. Counts are diagnostic, not hard-coded.

## 2. Enriched AI_HANDOFF for a fresh AI

The complete local Game Reference is **not** copied into every handoff. When an
Unsupported case is exported, PMM builds a deterministic local neighborhood and adds:

```text
references/
  Vanilla/...
  Providers/...                  # focused source-mod context when small enough
  provider-indexes/*.txt
  provider-context.json
  reference-index.json
  reference-reasons.json
  game-reference-context.json
```

The existing exact target remains authoritative:

```text
case.json
Vanilla/<conflict-family>
<Provider>/<conflict-family>
source-paks/
semantic-evidence.json
pmmcore-report.json
knowledge/
context/
```

### Reference selection

Reference selection is evidence discovery, not merge authorization. The current policy
uses:

- exact cooked families also present in a focused involved provider;
- exact entity/name tokens from the conflict and involved provider indexes;
- same Vanilla subsystem directory;
- explicit `Knowledge/reference-relations.json` relations;
- focused provider-side non-conflict families for small mods.

Selection is bounded (default maximum 40 Vanilla families / roughly 25 MiB raw) and
records *why* each family was included. Knowledge relations can force a small number of
high-value exemplars above the normal byte budget.

For Ranch/SpawnItem cases the relation library can include native examples such as
`BP_Action_SpawnItemBase`, native SpawnItem actions, native Ranch Pal Blueprints and the
lottery DataTables. Those assets explain the subsystem to an AI that has never seen PMM
or the user's previous chats.

The handoff README explicitly tells the receiver to assume **zero prior context** and to
rank evidence as:

1. exact cooked bytes + hashes + case identity;
2. PMM structural/semantic reports;
3. local Vanilla references and Knowledge history;
4. human descriptions as useful intent hints.

If evidence is insufficient, the correct response is Unsupported / request for specific
evidence - never an invented whole-file winner.

## 3. Tested Knowledge contribution package

After PMM validates/imports an AI/manual `PMM_MANUAL_SOLUTION_V1` and the user tests that
exact solution successfully in Palworld, Settings offers **Create tested contribution**.

It creates one:

```text
PMM_KNOWLEDGE_CONTRIBUTION_<caseId>.zip
```

with schema `PMM_KNOWLEDGE_CONTRIBUTION_V1`. It contains:

- exact `case.json`;
- the original AI_HANDOFF when still available;
- the exact returned solution ZIP (PMM now preserves it on import), or a reconstruction
  from the validated stored bytes;
- `validation.json`;
- `runtime-result.json` with an explicit user-reported PASS;
- `contribution.json` with package hashes and safety metadata.

Creating or receiving this ZIP **does not** activate an automatic merger recipe. It is a
portable evidence package for review.

## 4. Future community website / intake service

The natural next layer is a PMM Knowledge intake service. The app-side contribution
format is intentionally independent of any single website so the current v1.1 remains
fully usable offline.

Recommended server pipeline:

```text
Upload contribution
  -> quarantine
  -> safe ZIP/path/schema checks
  -> verify nested package hashes
  -> identify exact case/input signature
  -> deduplicate related reports
  -> maintainer/automated structural review
  -> optional reproduction / multiple runtime reports
  -> extract reusable structural lesson
  -> publish sanitized approved Knowledge pack
```

### Trust tiers

Keep at least these separate:

1. **Community evidence** - user report + exact artifacts. Useful for investigation.
2. **Reviewed explanatory Knowledge** - recognized behavior/relationship. May improve
   Semantic Lab and future handoff selection, but never authorizes a cooked write.
3. **Runtime-proven exact recipe** - exact hash/mappings/Vanilla/provider preconditions,
   reusing a pinned cooked provider/output according to the production recipe contract.
4. **Generic production adapter** - reusable structural proof implemented/tested in the
   merger.

A website must never convert tier 1 directly into tier 3/4.

### Raw assets and source PAKs

Contribution/handoff ZIPs can contain Vanilla cooked context and third-party source
PAKs. An intake service should treat those as **private validation material** and should
not republish them as part of public Knowledge packs. Public packs should normally
contain sanitized metadata, hashes, structural lessons and approved recipes that do not
redistribute proprietary game/mod assets.

### Future API shape (non-binding)

A future service can expose endpoints conceptually equivalent to:

- submit one `PMM_KNOWLEDGE_CONTRIBUTION_V1`;
- query submission status by content hash / case signature;
- list approved Knowledge-pack manifests;
- download an explicitly trusted/signed sanitized pack.

The v1.1 client does not depend on these endpoints and does not auto-install arbitrary
community submissions.

## 5. Security boundary

Game Reference, Semantic Lab, AI output and community Knowledge can improve explanation
and evidence selection. None of them bypass:

- exact provider/Vanilla provenance;
- mappings identity;
- cooked-family topology;
- hash/precondition validation;
- the active production adapter / exact trusted recipe contract.

This boundary is intentional and must survive future community/web features.

## Clean v1.1 execution note

Game Reference is built by `Core/GameReferenceWorker.ps1` in a child PowerShell process. Progress is reported through an atomic JSON file and polled by WPF. The same clean release uses `Core/OperationWorker.ps1` for Analyze and Build.

Community upload/download is not automatic in v1.1. Use the tested-contribution exporter and share the resulting ZIP manually; see `SHARING_KNOWLEDGE_MANUALLY.md`.
