# PMM 1.3.1 Mod Creation — engineering notes

## Base and scope

This branch is derived from GitHub `main` commit `9886c4fcb58654c81894f429a60bba5a704af6de`, the refreshed PMM v1.3.0 Stable source tree. It includes the post-release RC30 timestamp, singleton, CKL-catalog and handoff-path fixes. Existing packaged binaries and the merge/Fix Lab/deployment engines are unchanged apart from those exact upstream text corrections.

The change turns the already-declared `CREATE_MOD` AIIO task into an enforceable end-to-end data contract:

- visible creation-project entry point;
- persistent manual AIIO request/response exchange;
- focused Game Reference search;
- exact or bounded Game Reference evidence requests;
- hash-bound standalone cooked-tree candidate staging;
- explicit background PAK construction;
- permanent separation from compatibility-patch deployment and Knowledge promotion.

## Trust boundaries

`AIIO.ModCreationService.ps1` is the only new creation service. `AIIO.ResponseService.ps1` remains the hostile-archive boundary. It rejects unadvertised capabilities and validates the exact session/reference/source/output identities before committing a candidate.

`AIIOModBuild` runs in `OperationWorker.ps1`, not the WPF dispatcher. The worker packs a temporary payload composed from:

1. the already validated `cooked/Pal/Content` candidate tree; and
2. generated `PMM/Metadata/created-with-pmm.json` attribution metadata.

The marker contains no username, local path, machine identifier or credential. `mod-build.json` records the same attribution and the required public-description sentence.

The service contains no Deploy, `~mods`, automatic activation, remote upload, Git publication or Knowledge-promotion call. Build output lives under:

```text
Workspace/AIIO/Sessions/<session>/artifacts/mod-builds/<solution-id>/
```

## Schemas

- Capability set: `PMM_CAPABILITIES_V2`
- Candidate: `PMM_MOD_CREATION_CANDIDATE_V1`
- Build evidence: `PMM_MOD_CREATION_BUILD_V1`
- Internal PAK attribution: `PMM_MOD_ATTRIBUTION_V1`

The public protocol stays AIIO v2 and the generic response remains `PMM_AI_RESPONSE_V2`.

## Runtime acceptance still required

This environment cannot execute the Windows WPF workspace or Palworld. Static/model validation can prove archive/path/hash/reference/entry-set policy, localized XAML parity and preservation of packaged binaries, but not gameplay semantics. The first real inventory project should therefore remain `UNPROVEN` until its exact PAK is installed, tested and reported through PMM feedback.
