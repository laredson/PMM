package uasset

import "encoding/hex"

func readSummary(r *reader, opt Options) Summary {
	var s Summary
	if r.u32() != 0x9e2a83c1 {
		r.fail(ErrInvalid, "magic")
		return s
	}
	s.Legacy = r.field32("legacy")
	if s.Legacy != -8 {
		r.fail(ErrUnsupported, "legacy must be -8")
		return s
	}
	s.UE3 = r.field32("ue3")
	s.UE4 = r.field32("ue4")
	s.UE5 = r.field32("ue5")
	s.Licensee = r.field32("licensee")
	s.Unversioned = s.UE4 == 0 && s.UE5 == 0
	if s.Licensee != 0 || (s.UE3 != 0 && s.UE3 != 864) || (!s.Unversioned && (s.UE4 != 522 || s.UE5 != 1008)) || (s.Unversioned && !opt.AllowUnversioned) {
		r.fail(ErrUnsupported, "version requires exact 522/1008 or explicitly asserted unversioned profile")
		return s
	}
	if r.field32("customCount") != 0 {
		r.fail(ErrUnsupported, "custom version container")
		return s
	}
	s.HeaderSize = r.field32("headerSize")
	if int64(s.HeaderSize) != int64(len(r.b)) {
		r.fail(ErrInvalid, "input must be exactly the separate .uasset header")
		return s
	}
	s.Folder, _ = r.str()
	s.Flags = uint32(r.field32("flags"))
	if s.Flags&0x80000200 != 0x80000200 {
		r.fail(ErrUnsupported, "requires cooked and editor-filtered package")
		return s
	}
	s.NameCount = r.field32("nameCount")
	s.NameOffset = r.field32("nameOffset")
	s.SoftObjectCount = r.field32("softObjectCount")
	s.SoftObjectOffset = r.field32("softObjectOffset")
	s.GatherCount = r.field32("gatherCount")
	s.GatherOffset = r.field32("gatherOffset")
	s.ExportCount = r.field32("exportCount")
	s.ExportOffset = r.field32("exportOffset")
	s.ImportCount = r.field32("importCount")
	s.ImportOffset = r.field32("importOffset")
	s.DependsOffset = r.field32("dependsOffset")
	s.SoftPackageCount = r.field32("softPackageCount")
	s.SoftPackageOffset = r.field32("softPackageOffset")
	s.SearchableOffset = r.field32("searchableOffset")
	s.ThumbnailOffset = r.field32("thumbnailOffset")
	s.GUID = hex.EncodeToString(r.take(16))
	n := r.count(r.limits.Generations)
	for i := 0; i < n && r.err == nil; i++ {
		g := Generation{r.i32(), r.i32()}
		if g.Exports < 0 || g.Names < 0 || int64(g.Exports) > int64(r.limits.Objects) || int64(g.Names) > int64(r.limits.Names) {
			r.fail(ErrLimit, "generation counts")
		}
		s.Generations = append(s.Generations, g)
	}
	s.SavedEngine = r.engine()
	s.CompatibleEngine = r.engine()
	s.CompressionFlags = uint32(r.field32("compressionFlags"))
	chunks := r.field32("compressedChunks")
	if s.CompressionFlags != 0 || chunks != 0 {
		r.fail(ErrUnsupported, "package compression")
		return s
	}
	s.PackageSource = r.u32()
	if r.field32("additionalPackages") != 0 {
		r.fail(ErrUnsupported, "additional cook packages")
		return s
	}
	s.AssetRegistryOffset = r.field32("assetRegistryOffset")
	s.BulkDataStart = r.field64("bulkDataStart")
	s.WorldTileOffset = r.field32("worldTileOffset")
	n = r.count(r.limits.Generations)
	for i := 0; i < n && r.err == nil; i++ {
		id := r.i32()
		if id < 0 {
			r.fail(ErrInvalid, "negative chunk ID")
		}
		s.ChunkIDs = append(s.ChunkIDs, id)
	}
	s.PreloadCount = r.field32("preloadCount")
	s.PreloadOffset = r.field32("preloadOffset")
	s.NamesReferenced = r.field32("namesReferenced")
	s.PayloadToc = r.field64("payloadToc")
	if s.SoftObjectCount != 0 || s.GatherCount != 0 || s.SoftPackageCount != 0 || s.SearchableOffset != 0 || s.ThumbnailOffset != 0 || s.WorldTileOffset != 0 || s.PayloadToc != -1 {
		r.fail(ErrUnsupported, "nonempty optional section or payload TOC")
	}
	if s.NamesReferenced < 0 || s.NamesReferenced > s.NameCount {
		r.fail(ErrInvalid, "names referenced count")
	}
	if s.BulkDataStart < 0 || (s.BulkDataStart != 0 && s.BulkDataStart < int64(s.HeaderSize)) {
		r.fail(ErrInvalid, "bulk data offset")
	}
	return s
}
