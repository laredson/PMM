// Package pakv11 reconstructs a deliberately narrow, unencrypted PAK v11 profile.
// It never opens files, launches tools, or installs a generated archive.
package pakv11

import (
	"context"
	"crypto/sha1"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"fmt"
	"hash"
	"sort"
	"strings"
)

const (
	FooterSize             = 221
	EntryHeaderSize        = 53
	Magic           uint32 = 0x5a6f12e1
	Version         uint32 = 11
	MountPoint             = "../../../"
	encodedFlags    uint32 = 0xe0000000
	chunkSize              = 1 << 20
)

type File struct {
	Path string
	Data []byte
}

// Zero fields choose defaults. Positive overrides may only LOWER hard ceilings.
// These are API limits, not a bound on total process RSS. Inputs must be immutable
// for the call; the caller owns acquisition and transactional publication.
type Limits struct {
	ArchiveBytes uint64
	FileBytes    uint64
	IndexBytes   uint64
	Files        uint32
	PathBytes    uint32
	Depth        uint32
}

func limits(l Limits) (Limits, error) {
	d := Limits{256 << 20, 64 << 20, 32 << 20, 16384, 1024, 32}
	for _, p := range []struct {
		v   *uint64
		cap uint64
	}{{&l.ArchiveBytes, d.ArchiveBytes}, {&l.FileBytes, d.FileBytes}, {&l.IndexBytes, d.IndexBytes}} {
		if *p.v == 0 {
			*p.v = p.cap
		}
		if *p.v > p.cap {
			return l, errors.New("limit exceeds hard ceiling")
		}
	}
	for _, p := range []struct {
		v   *uint32
		cap uint32
	}{{&l.Files, d.Files}, {&l.PathBytes, d.PathBytes}, {&l.Depth, d.Depth}} {
		if *p.v == 0 {
			*p.v = p.cap
		}
		if *p.v > p.cap {
			return l, errors.New("limit exceeds hard ceiling")
		}
	}
	return l, nil
}
func checkContext(ctx context.Context) error {
	if ctx == nil {
		return errors.New("nil context")
	}
	return ctx.Err()
}
func digest(ctx context.Context, h hash.Hash, b []byte) ([]byte, error) {
	for len(b) > 0 {
		if e := ctx.Err(); e != nil {
			return nil, e
		}
		n := len(b)
		if n > chunkSize {
			n = chunkSize
		}
		_, _ = h.Write(b[:n])
		b = b[n:]
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	return h.Sum(nil), nil
}
func sha1Bytes(ctx context.Context, b []byte) ([]byte, error)   { return digest(ctx, sha1.New(), b) }
func sha256Bytes(ctx context.Context, b []byte) ([]byte, error) { return digest(ctx, sha256.New(), b) }
func appendData(ctx context.Context, out, b []byte) ([]byte, error) {
	for len(b) > 0 {
		if e := ctx.Err(); e != nil {
			return nil, e
		}
		n := len(b)
		if n > chunkSize {
			n = chunkSize
		}
		out = append(out, b[:n]...)
		b = b[n:]
	}
	return out, ctx.Err()
}
func validPath(s string, l Limits) error {
	if s == "" || uint64(len(s)) > uint64(l.PathBytes) {
		return errors.New("path length outside profile")
	}
	parts := strings.Split(s, "/")
	if len(parts) > int(l.Depth) {
		return errors.New("path depth outside profile")
	}
	for _, p := range parts {
		if p == "" || p == "." || p == ".." || len(p) > 255 || strings.HasSuffix(p, ".") || strings.HasSuffix(p, " ") {
			return fmt.Errorf("unsafe path %q", s)
		}
		for _, b := range []byte(p) {
			if b < 32 || b > 126 || strings.ContainsRune(`<>:"\|?*`, rune(b)) {
				return fmt.Errorf("unsupported/unsafe path %q", s)
			}
		}
		base := strings.ToUpper(strings.TrimRight(strings.SplitN(p, ".", 2)[0], " "))
		if base == "CON" || base == "PRN" || base == "AUX" || base == "NUL" || base == "CLOCK$" || base == "CONIN$" || base == "CONOUT$" ||
			(len(base) == 4 && (strings.HasPrefix(base, "COM") || strings.HasPrefix(base, "LPT")) && base[3] >= '1' && base[3] <= '9') {
			return fmt.Errorf("reserved path %q", s)
		}
	}
	return nil
}
func validateSet(ctx context.Context, files []File, l Limits) error {
	if uint64(len(files)) > uint64(l.Files) {
		return errors.New("too many files")
	}
	// Bound index growth before materializing directories or serialization buffers.
	indexBudget := uint64(136) + uint64(len(files))*24
	if indexBudget > l.IndexBytes {
		return errors.New("index exceeds limit")
	}
	names := map[string]bool{}
	dirs := map[string]string{}
	for _, f := range files {
		if e := ctx.Err(); e != nil {
			return e
		}
		if e := validPath(f.Path, l); e != nil {
			return e
		}
		if uint64(len(f.Data)) > l.FileBytes {
			return errors.New("file exceeds limit")
		}
		key := strings.ToLower(f.Path)
		if names[key] {
			return errors.New("duplicate/case-colliding file")
		}
		names[key] = true
		parts := strings.Split(f.Path, "/")
		indexBudget += uint64(len(parts[len(parts)-1]) + 9)
		if indexBudget > l.IndexBytes {
			return errors.New("index exceeds limit")
		}
		for i := 1; i < len(parts); i++ {
			s := strings.Join(parts[:i], "/")
			k := strings.ToLower(s)
			if v, ok := dirs[k]; ok && v != s {
				return errors.New("case-colliding directory")
			}
			if _, ok := dirs[k]; !ok {
				indexBudget += uint64(len(s) + 10)
				if indexBudget > l.IndexBytes {
					return errors.New("index exceeds limit")
				}
			}
			dirs[k] = s
		}
	}
	for k := range dirs {
		if names[k] {
			return errors.New("file/directory collision")
		}
	}
	return nil
}

// HashPath is v11 FNV-1a over lowercase UTF-16LE bytes, initialized with
// offset-basis + seed (wrapping). The exposed profile accepts ASCII only.
func HashPath(path string, seed uint64) (uint64, error) {
	l, _ := limits(Limits{})
	if e := validPath(path, l); e != nil {
		return 0, e
	}
	h := uint64(0xcbf29ce484222325) + seed
	for _, b := range []byte(strings.ToLower(path)) {
		h ^= uint64(b)
		h *= 0x100000001b3
		h *= 0x100000001b3
	}
	return h, nil
}
func put32(b []byte, n uint32) []byte { return binary.LittleEndian.AppendUint32(b, n) }
func put64(b []byte, n uint64) []byte { return binary.LittleEndian.AppendUint64(b, n) }
func putString(b []byte, s string) []byte {
	b = put32(b, uint32(len(s)+1))
	b = append(b, s...)
	return append(b, 0)
}
func sortedFiles(files []File) []File {
	out := append([]File(nil), files...)
	sort.Slice(out, func(i, j int) bool { return out[i].Path < out[j].Path })
	return out
}
