package pakv11

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"sort"
	"strings"
)

type cursor struct {
	b   []byte
	pos uint64
	err error
}

func (c *cursor) take(n uint64) []byte {
	if c.err != nil {
		return nil
	}
	if n > uint64(len(c.b))-c.pos {
		c.err = errors.New("truncated field")
		return nil
	}
	r := c.b[c.pos : c.pos+n]
	c.pos += n
	return r
}
func (c *cursor) u32() uint32 {
	b := c.take(4)
	if b == nil {
		return 0
	}
	return binary.LittleEndian.Uint32(b)
}
func (c *cursor) u64() uint64 {
	b := c.take(8)
	if b == nil {
		return 0
	}
	return binary.LittleEndian.Uint64(b)
}
func (c *cursor) str(max uint32) string {
	n := c.u32()
	if n < 1 || uint64(n) > uint64(max)+1 {
		c.err = errors.New("unsupported FString length")
		return ""
	}
	b := c.take(uint64(n))
	if b == nil {
		return ""
	}
	if b[len(b)-1] != 0 || bytes.IndexByte(b[:len(b)-1], 0) >= 0 {
		c.err = errors.New("invalid FString termination")
		return ""
	}
	return string(b[:len(b)-1])
}
func (c *cursor) finish() error {
	if c.err != nil {
		return c.err
	}
	if c.pos != uint64(len(c.b)) {
		return errors.New("trailing index bytes")
	}
	return nil
}

type location struct {
	off, size uint64
	hash      []byte
}

func (c *cursor) indexLocation() location {
	present := c.u32()
	if present != 1 {
		c.err = errors.New("both secondary indexes required")
	}
	return location{c.u64(), c.u64(), c.take(20)}
}
func checkedSlice(b []byte, off, size uint64) ([]byte, error) {
	if off > uint64(len(b)) || size > uint64(len(b))-off {
		return nil, errors.New("range outside archive")
	}
	return b[off : off+size], nil
}
func checkedIndex(ctx context.Context, b []byte, p location) ([]byte, error) {
	data, e := checkedSlice(b, p.off, p.size)
	if e != nil {
		return nil, e
	}
	h, e := sha1Bytes(ctx, data)
	if e != nil {
		return nil, e
	}
	if !bytes.Equal(h, p.hash) {
		return nil, errors.New("index SHA-1 mismatch")
	}
	return data, nil
}
func allZero(b []byte) bool {
	for _, v := range b {
		if v != 0 {
			return false
		}
	}
	return true
}

// Read validates every index, entry header and content digest, and copies data
// out only after successful parsing. It is intentionally NOT a general PAK reader.
// It accepts the declared contiguous v11/ASCII/32-bit/uncompressed profile only.
func Read(ctx context.Context, archive []byte, requested Limits) ([]File, error) {
	if e := checkContext(ctx); e != nil {
		return nil, e
	}
	l, e := limits(requested)
	if e != nil {
		return nil, e
	}
	if len(archive) < FooterSize || uint64(len(archive)) > l.ArchiveBytes {
		return nil, errors.New("archive size outside limits")
	}
	footerAt := uint64(len(archive) - FooterSize)
	f := cursor{b: archive[footerAt:]}
	guid := f.take(16)
	encrypted := f.take(1)
	magic, version := f.u32(), f.u32()
	primary := location{f.u64(), f.u64(), f.take(20)}
	compression := f.take(160)
	if f.finish() != nil || !allZero(guid) || encrypted[0] != 0 || magic != Magic || version != Version || !allZero(compression) {
		return nil, errors.New("unsupported footer/profile")
	}
	if primary.off > footerAt || primary.size > footerAt-primary.off || footerAt-primary.off > l.IndexBytes {
		return nil, errors.New("index region outside limits")
	}
	data, e := checkedIndex(ctx, archive, primary)
	if e != nil {
		return nil, e
	}
	p := cursor{b: data}
	if p.str(32) != MountPoint {
		return nil, errors.New("unsupported mount point")
	}
	count := p.u32()
	seed := p.u64()
	phiLoc, fdiLoc := p.indexLocation(), p.indexLocation()
	if p.err != nil || count > l.Files {
		return nil, errors.New("invalid primary index/count")
	}
	encodedLen := p.u32()
	if uint64(encodedLen) != uint64(count)*12 {
		return nil, errors.New("unsupported encoded array length")
	}
	encoded := p.take(uint64(encodedLen))
	unused := p.u32()
	if e = p.finish(); e != nil {
		return nil, e
	}
	if unused != 0 {
		return nil, errors.New("unencoded/deleted entries unsupported")
	}
	// Bounds before additions; require no aliases, overlaps, slack, or trailing data.
	if phiLoc.off != primary.off+primary.size || phiLoc.off > footerAt || phiLoc.size > footerAt-phiLoc.off ||
		fdiLoc.off != phiLoc.off+phiLoc.size || fdiLoc.off > footerAt || fdiLoc.size != footerAt-fdiLoc.off {
		return nil, errors.New("noncontiguous secondary indexes")
	}
	phiData, e := checkedIndex(ctx, archive, phiLoc)
	if e != nil {
		return nil, e
	}
	fdiData, e := checkedIndex(ctx, archive, fdiLoc)
	if e != nil {
		return nil, e
	}
	type entry struct{ off, size uint64 }
	entries := make([]entry, int(count))
	ec := cursor{b: encoded}
	for i := range entries {
		if ec.u32() != encodedFlags {
			return nil, errors.New("unsupported encoded flags")
		}
		off, size := ec.u32(), ec.u32()
		if uint64(size) > l.FileBytes {
			return nil, errors.New("file size exceeds limit")
		}
		entries[i] = entry{uint64(off), uint64(size)}
	}
	ph := cursor{b: phiData}
	if ph.u32() != count {
		return nil, errors.New("path-hash count mismatch")
	}
	pathHashes := map[uint64]uint32{}
	phiUsed := map[uint32]bool{}
	for i := uint32(0); i < count; i++ {
		if e = ctx.Err(); e != nil {
			return nil, e
		}
		h, loc := ph.u64(), ph.u32()
		if ph.err != nil || loc%12 != 0 || loc >= encodedLen || phiUsed[loc] {
			return nil, errors.New("invalid path-hash location")
		}
		if _, ok := pathHashes[h]; ok {
			return nil, errors.New("duplicate path hash")
		}
		pathHashes[h] = loc
		phiUsed[loc] = true
	}
	if ph.u32() != 0 {
		return nil, errors.New("pruned directory index unsupported")
	}
	if e = ph.finish(); e != nil {
		return nil, e
	}
	fd := cursor{b: fdiData}
	dirCount := fd.u32()
	if dirCount == 0 || uint64(dirCount) > 1+uint64(count)*uint64(l.Depth) {
		return nil, errors.New("directory count outside limits")
	}
	dirs := map[string]bool{}
	used := map[uint32]bool{}
	files := make([]File, 0, int(count))
	locs := make([]uint32, 0, int(count))
	for i := uint32(0); i < dirCount; i++ {
		if e = ctx.Err(); e != nil {
			return nil, e
		}
		dir := fd.str(l.PathBytes + 1)
		if fd.err != nil {
			return nil, fd.err
		}
		if dirs[dir] {
			return nil, errors.New("duplicate directory")
		}
		dirs[dir] = true
		if dir != "/" {
			if !strings.HasSuffix(dir, "/") {
				return nil, errors.New("directory missing slash")
			}
			if e = validPath(strings.TrimSuffix(dir, "/"), l); e != nil {
				return nil, e
			}
		}
		n := fd.u32()
		if uint64(n) > uint64(count)-uint64(len(files)) {
			return nil, errors.New("directory file count mismatch")
		}
		for j := uint32(0); j < n; j++ {
			name := fd.str(l.PathBytes)
			loc := fd.u32()
			if fd.err != nil {
				return nil, fd.err
			}
			if strings.Contains(name, "/") || loc%12 != 0 || loc >= encodedLen || used[loc] {
				return nil, errors.New("invalid directory entry")
			}
			path := name
			if dir != "/" {
				path = dir + name
			}
			if e = validPath(path, l); e != nil {
				return nil, e
			}
			h, _ := HashPath(path, seed)
			want, ok := pathHashes[h]
			if !ok || want != loc {
				return nil, errors.New("directory/path-hash disagreement")
			}
			files = append(files, File{Path: path})
			locs = append(locs, loc)
			used[loc] = true
		}
	}
	if e = fd.finish(); e != nil {
		return nil, e
	}
	if uint32(len(files)) != count {
		return nil, errors.New("incomplete directory index")
	}
	if e = validateSet(ctx, files, l); e != nil {
		return nil, e
	}
	wantedDirs := map[string]bool{"/": true}
	for _, f := range files {
		parts := strings.Split(f.Path, "/")
		for j := 1; j < len(parts); j++ {
			wantedDirs[strings.Join(parts[:j], "/")+"/"] = true
		}
	}
	if len(dirs) != len(wantedDirs) {
		return nil, errors.New("directory ancestry mismatch")
	}
	for k := range wantedDirs {
		if !dirs[k] {
			return nil, errors.New("missing parent directory")
		}
	}
	// Every byte before the primary index must be one entry header or file payload.
	order := make([]int, len(entries))
	for i := range order {
		order[i] = i
	}
	sort.Slice(order, func(i, j int) bool { return entries[order[i]].off < entries[order[j]].off })
	next := uint64(0)
	for _, i := range order {
		ent := entries[i]
		if ent.off != next || ent.off > primary.off || EntryHeaderSize > primary.off-ent.off || ent.size > primary.off-ent.off-EntryHeaderSize {
			return nil, errors.New("overlap/gap or invalid data range")
		}
		header, _ := checkedSlice(archive, ent.off, EntryHeaderSize)
		hc := cursor{b: header}
		zero, compressed, uncompressed, method := hc.u64(), hc.u64(), hc.u64(), hc.u32()
		hash := hc.take(20)
		flags, blockSize := hc.take(1), hc.u32()
		if zero != 0 || compressed != ent.size || uncompressed != ent.size || method != 0 || flags[0] != 0 || blockSize != 0 {
			return nil, errors.New("entry header/index disagreement")
		}
		payload, _ := checkedSlice(archive, ent.off+EntryHeaderSize, ent.size)
		actual, e := sha1Bytes(ctx, payload)
		if e != nil {
			return nil, e
		}
		if !bytes.Equal(actual, hash) {
			return nil, errors.New("payload SHA-1 mismatch")
		}
		next = ent.off + EntryHeaderSize + ent.size
	}
	if next != primary.off {
		return nil, errors.New("unreferenced data before index")
	}
	for i, loc := range locs {
		ent := entries[loc/12]
		src, _ := checkedSlice(archive, ent.off+EntryHeaderSize, ent.size)
		files[i].Data, e = appendData(ctx, make([]byte, 0, int(ent.size)), src)
		if e != nil {
			return nil, e
		}
	}
	if e = ctx.Err(); e != nil {
		return nil, e
	}
	return sortedFiles(files), nil
}

type FileDigest struct {
	Path   string `json:"path"`
	Bytes  int    `json:"bytes"`
	SHA256 string `json:"sha256"`
}
type Report struct {
	ArchiveSHA256 string       `json:"archiveSha256"`
	Files         []FileDigest `json:"files"`
	ByteExact     bool         `json:"byteExact"`
}

// Verify compares the re-read names AND bytes with independently supplied expected
// inputs, not just stored hashes. SHA-1 detects format corruption, not authenticity.
func Verify(ctx context.Context, archive []byte, expected []File, l Limits) (Report, error) {
	var zero Report
	if e := checkContext(ctx); e != nil {
		return zero, e
	}
	lim, e := limits(l)
	if e != nil {
		return zero, e
	}
	if e = validateSet(ctx, expected, lim); e != nil {
		return zero, e
	}
	actual, e := Read(ctx, archive, l)
	if e != nil {
		return zero, e
	}
	want := sortedFiles(expected)
	if len(want) != len(actual) {
		return zero, errors.New("expected file set differs")
	}
	report := Report{Files: make([]FileDigest, 0, len(actual))}
	for i, f := range actual {
		if f.Path != want[i].Path || len(f.Data) != len(want[i].Data) {
			return zero, errors.New("expected name/size differs")
		}
		for pos := 0; pos < len(f.Data); {
			if e = ctx.Err(); e != nil {
				return zero, e
			}
			end := pos + chunkSize
			if end > len(f.Data) {
				end = len(f.Data)
			}
			if !bytes.Equal(f.Data[pos:end], want[i].Data[pos:end]) {
				return zero, errors.New("expected bytes differ")
			}
			pos = end
		}
		h, e := sha256Bytes(ctx, f.Data)
		if e != nil {
			return zero, e
		}
		report.Files = append(report.Files, FileDigest{f.Path, len(f.Data), hex.EncodeToString(h)})
	}
	h, e := sha256Bytes(ctx, archive)
	if e != nil {
		return zero, e
	}
	report.ArchiveSHA256 = fmt.Sprintf("%x", h)
	report.ByteExact = true
	return report, nil
}
