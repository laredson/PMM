package corer1

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// No path-based Lstat-then-Open fallback: every child is opened relative to an
// already held directory handle. The platform adapter rejects links/devices.
type anchoredRoot struct {
	chain []*os.File
	file  *os.File
}
type anchoredFile struct {
	chain []*os.File
	file  *os.File
}
type diskStamp struct {
	volume, id, links                uint64
	size                             int64
	writeA, writeB, changeA, changeB int64
	flags                            uint32
}

func closeChain(chain []*os.File) error {
	var es []error
	for i := len(chain) - 1; i >= 0; i-- {
		if e := chain[i].Close(); e != nil {
			es = append(es, e)
		}
	}
	return errors.Join(es...)
}
func (r *anchoredRoot) Close() error { return closeChain(r.chain) }
func (f *anchoredFile) Close() error { return closeChain(f.chain) }
func openRoot(path string) (_ *anchoredRoot, err error) {
	start, parts, e := absoluteRootParts(path)
	if e != nil {
		return nil, e
	}
	if len(parts) > 64 {
		return nil, fail("LIMIT", "root", "at most 64 directory components")
	}
	f, e := openAnchor(start)
	if e != nil {
		return nil, e
	}
	chain := []*os.File{f}
	defer func() {
		if err != nil {
			err = errors.Join(err, closeChain(chain))
		}
	}()
	for _, part := range parts {
		if part == "" || part == "." || part == ".." || strings.ContainsAny(part, "\x00/\\:") {
			return nil, fail("PATH", "root", "invalid component")
		}
		next, e := openChild(f, part, true)
		if e != nil {
			return nil, e
		}
		chain = append(chain, next)
		f = next
	}
	if e := localFilesystem(f); e != nil {
		return nil, e
	}
	return &anchoredRoot{chain, f}, nil
}
func (r *anchoredRoot) Open(path string) (_ *anchoredFile, err error) {
	if e := safePath(path); e != nil {
		return nil, e
	}
	parts := strings.Split(path, "/")
	parent := r.file
	chain := []*os.File{}
	defer func() {
		if err != nil {
			err = errors.Join(err, closeChain(chain))
		}
	}()
	anchor, e := stamp(r.file, true)
	if e != nil {
		return nil, e
	}
	for i, part := range parts {
		dir := i < len(parts)-1
		f, e := openChild(parent, part, dir)
		if e != nil {
			return nil, e
		}
		chain = append(chain, f)
		st, e := stamp(f, dir)
		if e != nil {
			return nil, e
		}
		if st.volume != anchor.volume {
			return nil, fail("FILESYSTEM", path, "cross-volume traversal unsupported")
		}
		parent = f
	}
	return &anchoredFile{chain, parent}, nil
}

// exactRead hashes precisely the declared bytes AND demands EOF. It never
// returns a partial snapshot as success. Blocking kernel I/O is not preempted.
func exactRead(ctx context.Context, r io.Reader, n int64, keep bool) ([]byte, string, error) {
	h := sha256.New()
	var out []byte
	if keep {
		out = make([]byte, 0, int(n))
	}
	buf := make([]byte, 32768)
	left := n
	for left > 0 {
		if e := ctx.Err(); e != nil {
			return nil, "", e
		}
		want := int64(len(buf))
		if want > left {
			want = left
		}
		nr, e := io.ReadFull(r, buf[:int(want)])
		if e != nil {
			return nil, "", e
		}
		h.Write(buf[:nr])
		if keep {
			out = append(out, buf[:nr]...)
		}
		left -= int64(nr)
	}
	if e := ctx.Err(); e != nil {
		return nil, "", e
	}
	var tail [1]byte
	nr, e := r.Read(tail[:])
	if nr != 0 || e != io.EOF {
		return nil, "", fail("IO", "file", "expected exact length and EOF")
	}
	if e := ctx.Err(); e != nil {
		return nil, "", e
	}
	return out, hex.EncodeToString(h.Sum(nil)), nil
}
func captureFile(ctx context.Context, root *anchoredRoot, want File, keep bool, limit int64, afterRead func()) (data []byte, err error) {
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	if !validHash(want.SHA256) || want.SizeBytes < 0 || want.SizeBytes > limit {
		return nil, fail("LIMIT", want.Path, "invalid pin/size or acquisition ceiling")
	}
	f, e := root.Open(want.Path)
	if e != nil {
		return nil, e
	}
	defer func() {
		err = errors.Join(err, f.Close())
		if err != nil {
			data = nil
		}
	}()
	before, e := stamp(f.file, false)
	if e != nil {
		return nil, e
	}
	if before.size != want.SizeBytes {
		return nil, fail("SIZE", want.Path, "before read")
	}
	b, digest, e := exactRead(ctx, f.file, want.SizeBytes, keep)
	if e != nil {
		return nil, e
	}
	if afterRead != nil {
		afterRead()
	} // internal deterministic I/O fault hook; public API always nil
	after, e := stamp(f.file, false)
	if e != nil {
		return nil, e
	}
	if before != after {
		return nil, fail("CHANGED", want.Path, "handle metadata changed during capture")
	}
	// Re-resolve within the SAME held root and compare object identity. Namespace
	// changes outside the anchored root cannot redirect this lookup.
	check, e := root.Open(want.Path)
	if e != nil {
		return nil, e
	}
	checkStamp, se := stamp(check.file, false)
	ce := check.Close()
	if se != nil || ce != nil {
		return nil, errors.Join(se, ce)
	}
	if before != checkStamp {
		return nil, fail("CHANGED", want.Path, "path no longer identifies captured file")
	}
	if digest != want.SHA256 {
		return nil, fail("PIN", want.Path, "file content differs from expected SHA-256")
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	return b, nil
}

func cleanAbsolute(path string) error {
	if path == "" || !filepath.IsAbs(path) || filepath.Clean(path) != path || len(path) > 4096 {
		return fail("PATH", "root", "absolute canonical directory required")
	}
	for _, c := range path {
		if c < 32 {
			return fail("PATH", "root", "control character")
		}
	}
	return nil
}
