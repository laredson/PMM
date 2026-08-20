# Palworld Manager Merger 1.0 pre-release checklist

## RC acceptance

- [ ] Analyze expected full regression stack.
- [ ] `Shared 6 | Auto merged 4 | Decisions 1 | Unsupported 0 | Experimental 0 | Identical 1` for the current captured 2/3/4 + Fly/Wing fixture.
- [ ] Build Double variant.
- [ ] Build Triple and/or Quad variant.
- [ ] Select older saved patch by radio and Deploy without Build.
- [ ] Verify selected jump behavior in-game.
- [ ] Verify Fly + Wing behavior still works.
- [ ] Verify representative StaticItem/BreedFarm/PlayerStatus behaviors.
- [ ] Verify RushRoar Leather still works as normal source PAK if kept in the test set.
- [ ] Change active source set and confirm saved old-set patches become non-selectable.

## Product

- [ ] Final version/branding strings.
- [ ] Final README points users to `Documentation/README.md`.
- [ ] English and Spanish quick-start docs included.
- [ ] Screenshots prepared.
- [ ] Final SHA256SUMS rebuilt after all edits.
- [ ] Windows `SmokeTest.ps1` passes.
- [ ] Fresh-folder first-run setup tested.

## Open-source / third-party release blockers

- [ ] Choose and add PMM `LICENSE`.
- [ ] Add third-party license/notice files.
- [ ] Audit every bundled binary/resource for redistribution.
- [ ] Specifically resolve `oo2core_9_win64.dll` public-packaging basis.
- [ ] Add final no-affiliation notice.

## AI/Knowledge

- [ ] `Knowledge/` ships with current runtime evidence.
- [ ] `AI_HANDOFF` instructions and manual solution contract ship.
- [ ] User docs clearly state AI is optional and manual solutions are runtime-unproven.
- [ ] User docs warn about external sharing of third-party/game files.
- [ ] Community contribution workflow included.
