# UAsset 04A-4: explicit read-only profile

RECONSTRUCTION, not original FixLab source. Profile key:
`cooked-ue4-522-ue5-1008` (UE5.1-style cooked package summary and resource maps).
The caller MUST select it. Serialized versions must be 522/1008; 0/0 is accepted
only with explicit AllowUnversioned=true, an external assertion, not detection.
A different unversioned layout cannot be authenticated from zero version fields.

## Basis and boundaries

Primary format references are fixed to UAssetAPI commit
3228c1e86261aa08131f7ec0ff1a395f5d0b2a84:
- UAssetAPI/UAsset.cs, ReadHeader and name/import/export loading.
- UAssetAPI/Import.cs, the editor-filtered import map plus optional-resource bool.
- UAssetAPI/ExportTypes/Export.cs, export map serialization.
- UAssetAPI/UnrealTypes/ObjectVersion.cs, UE4 522 and UE5 thresholds 1000..1009.

Links: https://github.com/atenfyr/UAssetAPI/tree/3228c1e86261aa08131f7ec0ff1a395f5d0b2a84/UAssetAPI
Epic's FPackageFileSummary/FObjectImport/FObjectExport documentation supplies the
meaning of fields, not a fixed on-disk layout for all engine versions:
https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/CoreUObject/FPackageFileSummary
https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/CoreUObject/FObjectExport

The pinned PMMFixLab binary's readHeader/readNames/readImports/readExports were
inspected statically. They support the zero custom-version container, soft-object
summary slots, 32-byte imports, 96-byte exports and final payload-TOC field of this
profile. Original readHeader ends without the DATA_RESOURCES field (UE5 1009).
The exact ranges/hashes and the limits of this inference are in static-origin.json.
No original EXE, upstream library, UnrealPak, game or game asset was executed.
This is a new implementation from the documented layout, not an upstream fork.

## Header in byte order

All numbers little-endian. Tag 0x9e2a83c1; legacy -8; legacy UE3 0 or 864;
UE4/UE5; licensee 0; custom-version count 0; TotalHeaderSize; Folder FString;
PackageFlags (Cooked 0x200 AND FilterEditorOnly 0x80000000 required).
Then signed int32 counts/offsets in order: Names, SoftObjectPaths, GatherableText,
Exports, Imports, DependsOffset, SoftPackageReferences, SearchableNamesOffset,
ThumbnailOffset. Package GUID is 16 raw bytes, preserved as hex, not reinterpreted
as a host-endian GUID string. Generations: count + (exports,names) int32 pairs.
Two FEngineVersion records: uint16 major/minor/patch, uint32 changelist, FString.
Compression flags/count must both be zero. uint32 PackageSource; zero additional
packages; int32 AssetRegistryOffset; int64 BulkDataStart; int32 WorldTileOffset;
count + int32 chunk IDs; Preload count/offset; NamesReferenced int32; PayloadToc
int64 (-1 required). Header size must equal the supplied separate .uasset length.

Names are FString plus two uint16 hashes. Narrow strings are ASCII; wide strings
are strict UTF16-LE, including valid surrogate pairs. Embedded NUL, malformed
terminators/surrogates, huge lengths and narrow non-ASCII are rejected. Hash values
are preserved, NOT recalculated or treated as signatures. FName is int32 index +
int32 nonnegative number; nonzero number uses the usual displayed suffix number-1.
Duplicate name-map texts are preserved by index, not silently deduplicated.

Imports (32 bytes): FName ClassPackage, FName ClassName, int32 OuterIndex,
FName ObjectName, int32 boolean Optional. No editor-only PackageName field.
Exports (96 bytes): four int32 package indices (class,super,template,outer),
FName ObjectName, uint32 ObjectFlags, int64 SerialSize/SerialOffset, four int32
booleans (forced,not-client,not-server,inherited), uint32 PackageFlags, three
int32 booleans (not-always-loaded,is-asset,public-hash), first preload index and
four dependency counts. No object GUID, script offsets or class-specific payloads.
Package index 0 is null, negative refers to import (-index-1), positive to export
(index-1). All indices and outer chains are validated; no recursive traversal.

DependsMap is one count+int32-array per export when present. Preload is an int32
package-index array. -1 preload count with zero offset represents absent data;
export first-dependency -1 requires zero counts. Other spans must fit their next
active section, so reading one table cannot consume another table's bytes.

## Explicitly not decoded

Nonempty soft-object/gatherable-text/soft-package lists, searchable-name,
thumbnail/world-tile sections, custom versions, payload TOC, editor data,
compressed packages and other versions are UNSUPPORTED, not guessed.
Asset registry bytes and header gaps/tail are reported as opaque ranges; their
internal structure is NOT validated. BulkDataStart is recorded with minimal
range checks; external bulkdata is neither loaded nor validated.

A nil .uexp means header-only. Export offsets must be outside the header (except
zero-size/zero-offset exports), bounded by profile limits and nonoverlapping.
Supplying .uexp additionally checks all declared extents against its length and
hashes the input. `exportRangesChecked` is NOT property validation or authenticity.
No meshes, Blueprints, DataTables, properties, bulkdata or game objects are decoded.
Unknown header bytes are never discarded or called validated.
