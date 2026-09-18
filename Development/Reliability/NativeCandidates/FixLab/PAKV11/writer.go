package pakv11

import (
	"context"
	"errors"
	"sort"
	"strings"
)

// Build returns a deterministic archive or nil/error, never a partial archive.
// Profile: fixed mount, seed zero, compact 32-bit records, all parent directories,
// no compression, encryption, signatures, delete records, or filesystem I/O.
func Build(ctx context.Context, files []File, requested Limits) ([]byte, error) {
	if e := checkContext(ctx); e != nil {
		return nil, e
	}
	l, e := limits(requested)
	if e != nil {
		return nil, e
	}
	if e = validateSet(ctx, files, l); e != nil {
		return nil, e
	}
	files = sortedFiles(files)
	var dataSize uint64
	offsets := make([]uint32, len(files))
	for i, f := range files {
		size := uint64(EntryHeaderSize + len(f.Data))
		if dataSize > l.ArchiveBytes || size > l.ArchiveBytes-dataSize {
			return nil, errors.New("archive exceeds limit")
		}
		offsets[i] = uint32(dataSize)
		dataSize += size
	}
	// Encoded entry locations address bytes in the compact-entry array, not files.
	var encoded []byte
	phi := put32(nil, uint32(len(files)))
	hashes := map[uint64]bool{}
	dirs := map[string]map[string]uint32{"/": {}}
	for i, f := range files {
		if e = ctx.Err(); e != nil {
			return nil, e
		}
		loc := uint32(i * 12)
		encoded = put32(encoded, encodedFlags)
		encoded = put32(encoded, offsets[i])
		encoded = put32(encoded, uint32(len(f.Data)))
		h, _ := HashPath(f.Path, 0)
		if hashes[h] {
			return nil, errors.New("path hash collision")
		}
		hashes[h] = true
		phi = put64(phi, h)
		phi = put32(phi, loc)
		parts := strings.Split(f.Path, "/")
		dir := "/"
		for j := 1; j < len(parts); j++ {
			dir = strings.Join(parts[:j], "/") + "/"
			if dirs[dir] == nil {
				dirs[dir] = map[string]uint32{}
			}
		}
		dirs[dir][parts[len(parts)-1]] = loc
	}
	phi = put32(phi, 0) // empty pruned-directory index
	keys := make([]string, 0, len(dirs))
	for k := range dirs {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	fdi := put32(nil, uint32(len(keys)))
	for _, dir := range keys {
		if e = ctx.Err(); e != nil {
			return nil, e
		}
		fdi = putString(fdi, dir)
		fdi = put32(fdi, uint32(len(dirs[dir])))
		names := make([]string, 0, len(dirs[dir]))
		for n := range dirs[dir] {
			names = append(names, n)
		}
		sort.Strings(names)
		for _, n := range names {
			fdi = putString(fdi, n)
			fdi = put32(fdi, dirs[dir][n])
		}
	}
	// Only the primary index belongs to footer.IndexSize/IndexHash.
	primarySize := uint64(4 + len(MountPoint) + 1 + 4 + 8 + 40 + 40 + 4 + len(encoded) + 4)
	metadataSize := primarySize + uint64(len(phi)) + uint64(len(fdi))
	if metadataSize > l.IndexBytes || dataSize > l.ArchiveBytes || metadataSize+FooterSize > l.ArchiveBytes-dataSize {
		return nil, errors.New("index/archive exceeds limit")
	}
	phiHash, e := sha1Bytes(ctx, phi)
	if e != nil {
		return nil, e
	}
	fdiHash, e := sha1Bytes(ctx, fdi)
	if e != nil {
		return nil, e
	}
	index := putString(nil, MountPoint)
	index = put32(index, uint32(len(files)))
	index = put64(index, 0)
	index = put32(index, 1)
	index = put64(index, dataSize+primarySize)
	index = put64(index, uint64(len(phi)))
	index = append(index, phiHash...)
	index = put32(index, 1)
	index = put64(index, dataSize+primarySize+uint64(len(phi)))
	index = put64(index, uint64(len(fdi)))
	index = append(index, fdiHash...)
	index = put32(index, uint32(len(encoded)))
	index = append(index, encoded...)
	index = put32(index, 0)
	indexHash, e := sha1Bytes(ctx, index)
	if e != nil {
		return nil, e
	}
	out := make([]byte, 0, int(dataSize+metadataSize+FooterSize))
	for _, f := range files {
		h, e := sha1Bytes(ctx, f.Data)
		if e != nil {
			return nil, e
		}
		out = put64(out, 0)
		out = put64(out, uint64(len(f.Data)))
		out = put64(out, uint64(len(f.Data)))
		out = put32(out, 0)
		out = append(out, h...)
		out = append(out, 0)
		out = put32(out, 0)
		out, e = appendData(ctx, out, f.Data)
		if e != nil {
			return nil, e
		}
	}
	for _, part := range [][]byte{index, phi, fdi} {
		out, e = appendData(ctx, out, part)
		if e != nil {
			return nil, e
		}
	}
	out = append(out, make([]byte, 17)...)
	out = put32(out, Magic)
	out = put32(out, Version)
	out = put64(out, dataSize)
	out = put64(out, primarySize)
	out = append(out, indexHash...)
	out = append(out, make([]byte, 160)...)
	if e = ctx.Err(); e != nil {
		return nil, e
	}
	return out, nil
}
