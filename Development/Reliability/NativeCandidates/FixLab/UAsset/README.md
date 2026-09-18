# UAsset - read and bounded name rewriting

Isolated RECONSTRUCTION, not original source or a full FixLab engine.
04A-4 implemented Read; 04A-4B adds RewriteNames. The original reader and FORMAT.md
remain unchanged. The new transformation contract is REWRITE_CONTRACT.md.

Read accepts explicit cooked-ue4-522-ue5-1008; unversioned requires caller assertion.
RewriteNames requires pinned header/export bytes and pinned reference headers.
NameEdit selects an existing destination index and a source index; stored hashes
and serialization come from the source, not invented CRCs. Indices/counts stay put.

Fixed-width name changes preserve all other bytes and positions. Width-changing
rewrites REJECT opaque header regions, nonempty .uexp and nonzero bulk offsets,
including net-zero changes to multiple slot widths. There is no unsafe override.
Growth/shrink tests use completely parsed, export-data-free synthetic headers.
This limitation is a prerequisite for the future payload/core work, not a full
implementation of the recipe's relocatePackage or postProcess operations.

Inputs remain immutable during calls. Output is in memory with owned buffers;
errors return nil. No network, subprocess, file write or installation side effect.
Pins identify bytes; the caller must establish their provenance and authorization.

## Reproduce

From this directory with installed Go1.23.2, module/toolchain downloads disabled:

    go test -count=1 ./...
    python -B -m unittest -v test_reference test_rewrite_reference
    python -B build.py --out <NEW directory OUTSIDE repository>

Set GOTOOLCHAIN=local, GOPROXY=off, GOSUMDB=off, GOWORK=off for Go commands.
The builder sets them itself. Its UAsset-tests.exe is NOT PMMFixLab.exe and must
not replace it. Windows test execution and Unreal compatibility are NOT_RUN.

Optional test exports (set environment in your shell):
PMM_UASSET_FIXTURE_OUTPUT=<new directory> exports the six reader results.
PMM_UASSET_REWRITE_OUTPUT=<new directory> exports twelve synthetic rewrite packets.
Then run verify_reference.py or verify_rewrite.py with that respective directory.
Without these variables two export tests SKIP; never count skips as passes.

39 Go assertion tests passed with both exports enabled (23 reader + 16 rewrite),
20 Python tests (12 earlier + 8 new), race Linux and bounded FuzzRewritePinned.
Two FINAL Windows TEST builds matched in the recorded Go1.23.2 Linux environment.
Historical evidence is unchanged; new results are under evidence/s04a4b/.

Next: payload/core R1 transformation contracts, not a full engine comparison yet.
No real donor/game assets were read or transformed, and no original EXE ran.
