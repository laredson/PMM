// Package pmmdlt1 reconstructs the PMMDLT1 byte-patch component, not FixLab.
// No filesystem writes, process execution, network access or game integration.
// Callers must keep input slices immutable throughout each call. Recipe trust,
// file acquisition, persistence and PAK validation are outside this package.
package pmmdlt1

import (
	"bytes"
	"compress/zlib"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"sort"
)

const Magic = "PMMDLT1\n"
const chunkSize = 32 << 10

var (
	ErrArgument  = errors.New("invalid codec argument")
	ErrIntegrity = errors.New("SHA-256 mismatch")
	ErrFormat    = errors.New("invalid PMMDLT1 structure")
	ErrBounds    = errors.New("patch range out of bounds")
	ErrLimit     = errors.New("codec resource limit exceeded")
)

// Limits are per invocation, not a bound on total process RSS. Zero fields use
// the default. Nonzero fields may only tighten the candidate's reviewed caps.
// Larger assets need an explicit profile review, not automatic limit increases.
type Limits struct {
	PatchBytes, DecodedBytes, OutputBytes uint64
	Operations, References                uint64
	ReferenceBytes, TotalReferenceBytes   uint64
}

func DefaultLimits() Limits {
	return Limits{16 << 20, 64 << 20, 256 << 20, 1_000_000, 1024, 256 << 20, 512 << 20}
}
func (l Limits) normalized() (Limits, error) {
	d := DefaultLimits()
	pairs := [][2]*uint64{{&l.PatchBytes, &d.PatchBytes}, {&l.DecodedBytes, &d.DecodedBytes},
		{&l.OutputBytes, &d.OutputBytes}, {&l.Operations, &d.Operations},
		{&l.References, &d.References}, {&l.ReferenceBytes, &d.ReferenceBytes},
		{&l.TotalReferenceBytes, &d.TotalReferenceBytes}}
	for _, p := range pairs {
		if *p[0] == 0 {
			*p[0] = *p[1]
		}
		if *p[0] > *p[1] {
			return l, fmt.Errorf("%w: limits may only tighten defaults", ErrArgument)
		}
	}
	return l, nil
}

type Reference struct {
	Data   []byte
	SHA256 string // Required even for references not used by this patch.
}
type Request struct {
	Patch        []byte
	PatchSHA256  string
	References   []Reference // COPY indices address this ordered list, starting at 0.
	OutputSHA256 string
	Limits       Limits
}
type ReferenceUse struct {
	Index        uint16 `json:"index"`
	MinimumBytes uint64 `json:"minimumBytes"`
}
type Info struct {
	PatchSHA256       string         `json:"patchSha256"`
	PatchBytes        uint64         `json:"patchBytes"`
	DecodedBytes      uint64         `json:"decodedBytes"`
	OutputBytes       uint64         `json:"outputBytes"`
	Operations        uint32         `json:"operations"`
	CopyOperations    uint32         `json:"copyOperations"`
	LiteralOperations uint32         `json:"literalOperations"`
	CopyBytes         uint64         `json:"copyBytes"`
	LiteralBytes      uint64         `json:"literalBytes"`
	References        []ReferenceUse `json:"references"`
}

func parseDigest(text string) ([32]byte, error) {
	var d [32]byte
	if len(text) != 64 {
		return d, fmt.Errorf("%w: a 64-digit SHA-256 is required", ErrArgument)
	}
	b, e := hex.DecodeString(text)
	if e != nil {
		return d, fmt.Errorf("%w: invalid SHA-256", ErrArgument)
	}
	copy(d[:], b)
	return d, nil
}
func checkContext(ctx context.Context) error {
	if ctx == nil {
		return fmt.Errorf("%w: nil context", ErrArgument)
	}
	return ctx.Err()
}
func hashBytes(ctx context.Context, b []byte) ([32]byte, error) {
	var result [32]byte
	h := sha256.New()
	for len(b) > 0 {
		if e := checkContext(ctx); e != nil {
			return result, e
		}
		n := min(chunkSize, len(b))
		_, _ = h.Write(b[:n])
		b = b[n:]
	}
	if e := checkContext(ctx); e != nil {
		return result, e
	}
	copy(result[:], h.Sum(nil))
	return result, nil
}
func verify(ctx context.Context, b []byte, want [32]byte, what string) error {
	got, e := hashBytes(ctx, b)
	if e != nil {
		return e
	}
	if got != want {
		return fmt.Errorf("%w: %s", ErrIntegrity, what)
	}
	return nil
}

// decode consumes exactly one zlib stream including its checksum/trailer.
// bytes.Reader implements ReadByte, so trailing compressed data is not swallowed
// by a buffering wrapper. Both compressed and decompressed suffixes are rejected.
func decode(ctx context.Context, patch []byte, pin string, l Limits) ([]byte, Info, error) {
	var info Info
	if e := checkContext(ctx); e != nil {
		return nil, info, e
	}
	expected, e := parseDigest(pin)
	if e != nil {
		return nil, info, e
	}
	if uint64(len(patch)) > l.PatchBytes {
		return nil, info, ErrLimit
	}
	if e = verify(ctx, patch, expected, "patch"); e != nil {
		return nil, info, e
	}
	if len(patch) < len(Magic) || string(patch[:len(Magic)]) != Magic {
		return nil, info, ErrFormat
	}
	compressed := bytes.NewReader(patch[len(Magic):])
	zr, e := zlib.NewReader(compressed)
	if e != nil {
		return nil, info, fmt.Errorf("%w: zlib header: %v", ErrFormat, e)
	}
	defer zr.Close()
	var body []byte
	buf := make([]byte, chunkSize)
	for {
		if e = checkContext(ctx); e != nil {
			return nil, info, e
		}
		n, re := zr.Read(buf)
		if uint64(n) > l.DecodedBytes-uint64(len(body)) {
			return nil, info, fmt.Errorf("%w: inflated bytes", ErrLimit)
		}
		body = append(body, buf[:n]...)
		if re == io.EOF {
			break
		}
		if re != nil {
			return nil, info, fmt.Errorf("%w: zlib stream: %v", ErrFormat, re)
		}
	}
	if e = zr.Close(); e != nil {
		return nil, info, fmt.Errorf("%w: zlib close: %v", ErrFormat, e)
	}
	if compressed.Len() != 0 {
		return nil, info, fmt.Errorf("%w: compressed suffix", ErrFormat)
	}
	info, e = walk(ctx, body, l, nil)
	if e != nil {
		return nil, Info{}, e
	}
	info.PatchBytes = uint64(len(patch))
	info.DecodedBytes = uint64(len(body))
	info.PatchSHA256 = hex.EncodeToString(expected[:])
	return body, info, nil
}

type visitOperation func(kind byte, ref uint16, off, n uint64, literal []byte) error

func walk(ctx context.Context, body []byte, l Limits, visit visitOperation) (Info, error) {
	var info Info
	if len(body) < 12 {
		return info, fmt.Errorf("%w: truncated header", ErrFormat)
	}
	info.OutputBytes = binary.LittleEndian.Uint64(body[:8])
	info.Operations = binary.LittleEndian.Uint32(body[8:12])
	if info.OutputBytes > l.OutputBytes || uint64(info.Operations) > l.Operations {
		return Info{}, ErrLimit
	}
	// Every instruction has at least an opcode and uint64 length.
	if uint64(info.Operations) > uint64(len(body)-12)/9 {
		return Info{}, fmt.Errorf("%w: impossible operation count", ErrFormat)
	}
	pos := 12
	produced := uint64(0)
	used := map[uint16]uint64{}
	take := func(n uint64) ([]byte, error) {
		if n > uint64(len(body)-pos) {
			return nil, fmt.Errorf("%w: truncated instruction", ErrFormat)
		}
		b := body[pos : pos+int(n)]
		pos += int(n)
		return b, nil
	}
	for i := uint32(0); i < info.Operations; i++ {
		if e := checkContext(ctx); e != nil {
			return Info{}, e
		}
		op, e := take(1)
		if e != nil {
			return Info{}, e
		}
		kind := op[0]
		var ref uint16
		var off, n uint64
		var literal []byte
		switch kind {
		case 0:
			b, e := take(18)
			if e != nil {
				return Info{}, e
			}
			ref = binary.LittleEndian.Uint16(b[:2])
			off = binary.LittleEndian.Uint64(b[2:10])
			n = binary.LittleEndian.Uint64(b[10:18])
			if uint64(ref) >= l.References {
				return Info{}, fmt.Errorf("%w: reference index", ErrLimit)
			}
			if off > l.ReferenceBytes || n > l.ReferenceBytes-off {
				return Info{}, fmt.Errorf("%w: COPY range/profile", ErrBounds)
			}
			end := off + n
			if old, exists := used[ref]; !exists || end > old {
				used[ref] = end
			}
			info.CopyOperations++
			info.CopyBytes += n
		case 1:
			b, e := take(8)
			if e != nil {
				return Info{}, e
			}
			n = binary.LittleEndian.Uint64(b)
			literal, e = take(n)
			if e != nil {
				return Info{}, e
			}
			info.LiteralOperations++
			info.LiteralBytes += n
		default:
			return Info{}, fmt.Errorf("%w: unknown opcode %d", ErrFormat, kind)
		}
		// Subtraction avoids overflow on malicious uint64 ranges.
		if n > info.OutputBytes-produced {
			return Info{}, fmt.Errorf("%w: output overrun", ErrBounds)
		}
		produced += n
		if visit != nil {
			if e := visit(kind, ref, off, n, literal); e != nil {
				return Info{}, e
			}
		}
	}
	if pos != len(body) {
		return Info{}, fmt.Errorf("%w: decoded suffix", ErrFormat)
	}
	if produced != info.OutputBytes {
		return Info{}, fmt.Errorf("%w: output size mismatch", ErrBounds)
	}
	for id, n := range used {
		info.References = append(info.References, ReferenceUse{id, n})
	}
	sort.Slice(info.References, func(i, j int) bool { return info.References[i].Index < info.References[j].Index })
	return info, nil
}

// Inspect verifies patch identity and complete syntax, but has no source assets:
// it does NOT validate reference identities, transformed bytes or a game repair.
func Inspect(ctx context.Context, patch []byte, pin string, limits Limits) (Info, error) {
	l, e := limits.normalized()
	if e != nil {
		return Info{}, e
	}
	_, info, e := decode(ctx, patch, pin, l)
	return info, e
}

// Apply returns bytes ONLY after patch/reference/output hashes and every bound
// have passed. Any error returns nil, never a partially accepted output. It does
// not publish files. Digests must come from an independently trusted recipe;
// computing a digest from arbitrary input at this boundary does not authenticate it.
func Apply(ctx context.Context, req Request) ([]byte, error) {
	if e := checkContext(ctx); e != nil {
		return nil, e
	}
	l, e := req.Limits.normalized()
	if e != nil {
		return nil, e
	}
	outPin, e := parseDigest(req.OutputSHA256)
	if e != nil {
		return nil, e
	}
	if uint64(len(req.References)) > l.References {
		return nil, ErrLimit
	}
	refPins := make([][32]byte, len(req.References))
	var total uint64
	for i, r := range req.References {
		if uint64(len(r.Data)) > l.ReferenceBytes || uint64(len(r.Data)) > l.TotalReferenceBytes-total {
			return nil, ErrLimit
		}
		total += uint64(len(r.Data))
		refPins[i], e = parseDigest(r.SHA256)
		if e != nil {
			return nil, e
		}
	}
	body, info, e := decode(ctx, req.Patch, req.PatchSHA256, l)
	if e != nil {
		return nil, e
	}
	for _, u := range info.References {
		if int(u.Index) >= len(req.References) || u.MinimumBytes > uint64(len(req.References[u.Index].Data)) {
			return nil, fmt.Errorf("%w: reference %d", ErrBounds, u.Index)
		}
	}
	for i, r := range req.References {
		if e = verify(ctx, r.Data, refPins[i], fmt.Sprintf("reference %d", i)); e != nil {
			return nil, e
		}
	}
	if e = checkContext(ctx); e != nil {
		return nil, e
	}
	output := make([]byte, int(info.OutputBytes))
	at := 0
	_, e = walk(ctx, body, l, func(kind byte, ref uint16, off, n uint64, literal []byte) error {
		src := literal
		if kind == 0 {
			src = req.References[ref].Data[int(off):int(off+n)]
		}
		for len(src) > 0 {
			if e := checkContext(ctx); e != nil {
				return e
			}
			count := min(chunkSize, len(src))
			copy(output[at:at+count], src[:count])
			at += count
			src = src[count:]
		}
		return nil
	})
	if e != nil {
		return nil, e
	}
	if e = verify(ctx, output, outPin, "output"); e != nil {
		return nil, e
	}
	return output, nil
}
