# Name-table serialization / relocation contract - 04A-4B

RECONSTRUCTION. Extends the explicit 522/1008 profile; no full FixLab/core R1.
The API is RewriteNames in rewrite.go. Existing Read and its layout are unchanged.

## Allowed transformation

Replace existing name slots by exact serialized entries selected from externally
approved, SHA-256-pinned reference headers. No insertion, deletion, deduplication,
index remapping, arbitrary new text, hash recomputation, or GUID changes. Sources
are parsed under the same explicit profile. The caller selects Source/SourceIndex;
all FName index/number pairs and generation/name counts remain unchanged.

The complete raw FString and its two stored hash values are copied. This preserves
ASCII/UTF-16 choice and even noncanonical empty-string encodings. No assumption
that the reader's text representation can reconstruct every original byte.
Unedited entries and summary bytes are preserved rather than re-encoded globally.
Only known offset fields are serialized in little-endian form when they must move.

## Identity and ownership

HeaderSHA256 and ExportSHA256 are mandatory, lowercase 64-digit SHA-256 strings.
Every NameSource also requires its expected header SHA-256. Expected values must
come from a separately approved source/recipe, never autoaccepted from supplied
bytes. A matching pin is identity, not authenticity or permission for a rename.
Snapshot copies are checked against pins BEFORE parsing. Inputs, sources and the
edit plan must be immutable during the call; unsynchronized caller writes remain
a data race, not a supported input mode. Results do not alias caller buffers.
A nil .uexp is rejected, even for no-op: supply explicit empty bytes when empty.

## Opaque-data policy (intentional current limitation)

If EACH edited slot retains its serialized width, every byte position stays put.
Opaque header regions and the entire .uexp are copied unchanged. That proves byte
preservation, not that changed names satisfy game semantics or opaque name caches.

If ANY slot width changes, even when total growth is zero, the operation rejects:
- any opaque header region, including zero-filled gaps or an asset registry;
- any nonempty .uexp (payloads may contain absolute offsets we do not decode);
- any nonzero BulkDataStart (external bulk placement is not established).
There is NO override flag or hash-whitelist bypass for this restriction.
Thus growth/shrinkage currently supports fully parsed, export-data-free headers.
Tests use synthetic headers with zero-size exports, not a real repaired mesh.
Typical meshes/donors require a payload/core serializer BEFORE general relocation.

## Coordinates and invariants

Splice exactly the existing name-table span. HeaderSize changes by the signed byte
delta. Summary offset markers after the old table move by delta; markers before
it stay fixed. Zero sentinels stay zero. Markers inside the replaced table are
ambiguous and rejected, including zero-count optional-list markers.

For every nonzero export SerialOffset:
newSerialOffset = newTotalHeaderSize + (oldSerialOffset - oldTotalHeaderSize).
The address of that field is moved only if the export MAP itself follows names.
This also handles names located after the export map. The zero-size/zero-offset
sentinel stays zero. No BulkDataStart rewriting is claimed.

Read validates the reconstructed header and supplied .uexp again. Selected raw
entries, counts and logical export coordinates are checked. Any failure returns
nil. Report lists pins, selected sources/indices, delta and changed offset fields.
No-op and inverse transformations are tested for full byte identity. No files are
written, no subprocess runs, and no output is installed by this API.

## Limits and evidence

Reader limits still apply. At most 8 source headers; their AGGREGATE bytes must
fit the header limit (64 MiB default, reducible). Edits cannot exceed the name
limit. Final table/header size is bounded before allocation. Context cancellation
is checked during snapshots, hashes, copies, edits and re-reading. Not an RSS cap
or a promise to interrupt an unresponsive kernel operation.

verify_rewrite.py independently reconstructs expected bytes and re-reads twelve
SYNTHETIC result packets. It imports no Go code. This and the old independent
reader can share a format assumption: not Unreal/Palworld or original parity.

References: FORMAT.md preserves the exact UAssetAPI source commit. Epic field
semantics consulted 2026-09-18 (not a replacement for the fixed on-disk profile):
https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/CoreUObject/FPackageFileSummary
https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/CoreUObject/FObjectExport

The four original transform-function ranges and core recipe were reviewed as
static evidence only. We do NOT claim this API reproduces serializeSummary,
relocatePackage or patchPostProcess in the original; those implement wider work.
