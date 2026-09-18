# UAsset structure reader - 04A-4

Isolated Go library: RECONSTRUCTION, not recovered original source and not a
complete FixLab engine. No CLI that pretends to repair mods. No file writes,
extraction, loading objects, subprocesses or network in the library.

## API

```go
opts := uasset.Options{Profile: uasset.CookedUE51}
pkg, err := uasset.Read(ctx, uassetBytes, nil, opts) // header-only
// Read(ctx, uassetBytes, uexpBytes, opts) checks serial extents in supplied .uexp.
// opts.AllowUnversioned = true only after establishing the layout externally.
```

Results include summary/field offsets, name entries and stored hashes, FNames,
imports/exports, dependency maps, section spans, explicit opaque spans and input
SHA-256. Header-only results do not claim export data has been supplied.
Failure returns nil, never a partially validated Package. Inputs must remain
immutable for the duration of a call; returned metadata does not alias them.
SHA-256 is an identity report, not a trusted expected hash or authenticity proof.

Profile and rejected features: FORMAT.md. In particular this is NOT a general
UAsset reader for every Unreal version. Unversioned layouts require explicit
caller assertion; an old/new donor's compatibility still needs actual evidence.
This session did not read, transform or redistribute game or donor assets.

## Limits per call

64 MiB header, 256 MiB supplied export data/logical export span, 8192 bytes per
serialized string, 65536 names, 16384 total objects, 262144 dependency entries per
map, 128 generations/chunk IDs. Zero option selects the default; callers can lower
but cannot raise it. Limits are not original-engine limits or an RSS guarantee.
Cancellation is checked during primitive reads, graph traversal and chunked hashes.
Unsupported input errors are explicit rather than guessed or silently skipped.

## Reproduction

From this directory, using installed Go1.23.2 (no module dependencies):

```text
GOTOOLCHAIN=local GOPROXY=off GOSUMDB=off go test -count=1 ./...
python -B -m unittest -v test_reference
python -B build.py --out <NEW directory OUTSIDE repo>
```

The first line uses POSIX environment syntax; on Windows set those variables
in the shell first. The Python builder sets offline variables itself and refuses
existing/internal output paths. It creates UAsset-tests.exe, NOT PMMFixLab.exe,
and never executes it. Windows execution/Unreal compatibility remain NOT_RUN.

`PMM_UASSET_FIXTURE_OUTPUT=<new directory>` activates Go's synthetic result export;
then `python -B verify_reference.py <that directory>` compares its output with an
independent Python reader. All six base64 fixture vectors are artificial; their
standalone generator is testdata/make_fixtures.py. Without the opt-in, the export
test SKIPs: do not count that skip as PASS. Fuzz seeds are not separate Test cases.

23 Go Test functions passed with export enabled, 12 Python tests, race Linux,
plus two bounded fuzz runs. Evidence includes exact commands and counts.
Two final Windows TEST harness builds match, not the original FixLab executable.

## Continuity

04A-4 closes structure reading only. PMMDLT1/PAKV11 and all packaged PMM files are
unchanged. Next 04A-4B is serialization/relocation with protected opaque regions,
synthetic fixtures and exact recipe constraints. This reader does not authorize
rewriting a header it cannot fully account for. Complete core/V2/CLI, original
comparison and real Windows/game acceptance remain later gates.
