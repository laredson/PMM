package pmmdlt1

import (
	"bytes"
	"compress/zlib"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"math"
	"math/rand"
	"reflect"
	"strings"
	"testing"
)

// Test encoders are independent fixtures, NOT a production patch generator.
func pin(b []byte) string { d := sha256.Sum256(b); return hex.EncodeToString(d[:]) }
func u64(n uint64) []byte { b := make([]byte, 8); binary.LittleEndian.PutUint64(b, n); return b }
func cp(id uint16, off, n uint64) []byte {
	b := make([]byte, 19)
	binary.LittleEndian.PutUint16(b[1:3], id)
	binary.LittleEndian.PutUint64(b[3:11], off)
	binary.LittleEndian.PutUint64(b[11:], n)
	return b
}
func lit(b []byte) []byte { return append(append([]byte{1}, u64(uint64(len(b)))...), b...) }
func raw(target uint64, ops ...[]byte) []byte {
	b := make([]byte, 12)
	binary.LittleEndian.PutUint64(b, target)
	binary.LittleEndian.PutUint32(b[8:], uint32(len(ops)))
	for _, op := range ops {
		b = append(b, op...)
	}
	return b
}
func envelope(body []byte) []byte {
	var b bytes.Buffer
	b.WriteString(Magic)
	w := zlib.NewWriter(&b)
	if _, e := w.Write(body); e != nil {
		panic(e)
	}
	if e := w.Close(); e != nil {
		panic(e)
	}
	return b.Bytes()
}
func request(body, expected []byte, refs ...[]byte) Request {
	p := envelope(body)
	r := Request{Patch: p, PatchSHA256: pin(p), OutputSHA256: pin(expected)}
	for _, b := range refs {
		r.References = append(r.References, Reference{b, pin(b)})
	}
	return r
}
func rejected(t *testing.T, r Request, want error) {
	t.Helper()
	out, e := Apply(context.Background(), r)
	if out != nil || !errors.Is(e, want) {
		t.Fatalf("out=%d err=%v want=%v", len(out), e, want)
	}
}
func TestApplyMixedReferencesAndInputImmutability(t *testing.T) {
	refs := [][]byte{[]byte("012345"), {0, 255, 128, 9}}
	body := raw(10, cp(0, 2, 3), lit([]byte("XY")), cp(1, 0, 4), cp(0, 0, 1))
	expected := []byte{'2', '3', '4', 'X', 'Y', 0, 255, 128, 9, '0'}
	r := request(body, expected, refs...)
	saved := append([]byte(nil), r.Patch...)
	out, e := Apply(context.Background(), r)
	if e != nil || !bytes.Equal(out, expected) {
		t.Fatal(out, e)
	}
	out[0] = 'z'
	if !bytes.Equal(r.Patch, saved) || string(refs[0]) != "012345" {
		t.Fatal("input changed")
	}
}
func TestInspectReportsSortedReferenceBounds(t *testing.T) {
	r := request(raw(7, cp(2, 7, 2), lit([]byte("x")), cp(0, 2, 4)), nil)
	info, e := Inspect(context.Background(), r.Patch, r.PatchSHA256, Limits{})
	if e != nil || info.Operations != 3 || info.CopyBytes != 6 || info.LiteralBytes != 1 || !reflect.DeepEqual(info.References, []ReferenceUse{{0, 6}, {2, 9}}) {
		t.Fatal(info, e)
	}
}
func TestLiteralOnlyAndEmpty(t *testing.T) {
	for _, b := range [][]byte{nil, {}, []byte("text\x00\xff")} {
		ops := [][]byte{lit(b)}
		if b == nil {
			ops = nil
		}
		r := request(raw(uint64(len(b)), ops...), b)
		out, e := Apply(context.Background(), r)
		if e != nil || !bytes.Equal(out, b) {
			t.Fatal(out, e)
		}
	}
}
func TestZeroLengthInstructionsAtReferenceEnd(t *testing.T) {
	r := request(raw(0, cp(0, 3, 0), lit(nil)), nil, []byte("abc"))
	if _, e := Apply(context.Background(), r); e != nil {
		t.Fatal(e)
	}
	r = request(raw(0, cp(0, 4, 0)), nil, []byte("abc"))
	rejected(t, r, ErrBounds)
}
func TestRequiredDigests(t *testing.T) {
	for _, bad := range []string{"", "abcd", strings.Repeat("z", 64), " " + strings.Repeat("0", 64)} {
		for _, field := range []string{"patch", "output", "reference"} {
			r := request(raw(1, cp(0, 0, 1)), []byte("a"), []byte("a"))
			switch field {
			case "patch":
				r.PatchSHA256 = bad
			case "output":
				r.OutputSHA256 = bad
			default:
				r.References[0].SHA256 = bad
			}
			rejected(t, r, ErrArgument)
		}
	}
}
func TestDigestMismatchAtEachBoundary(t *testing.T) {
	for _, field := range []string{"patch", "output", "reference", "unused"} {
		r := request(raw(1, cp(0, 0, 1)), []byte("a"), []byte("a"), []byte("unused"))
		switch field {
		case "patch":
			r.PatchSHA256 = pin(nil)
		case "output":
			r.OutputSHA256 = pin(nil)
		case "reference":
			r.References[0].SHA256 = pin(nil)
		default:
			r.References[1].SHA256 = pin(nil)
		}
		rejected(t, r, ErrIntegrity)
	}
}
func TestUppercaseDigestAccepted(t *testing.T) {
	r := request(raw(1, lit([]byte("a"))), []byte("a"))
	r.PatchSHA256 = strings.ToUpper(r.PatchSHA256)
	if _, e := Apply(context.Background(), r); e != nil {
		t.Fatal(e)
	}
}
func TestInvalidMagicAndCompression(t *testing.T) {
	for _, p := range [][]byte{nil, []byte("PMMDLT1"), []byte("PMMDLT2\n"), []byte(Magic + "invalid zlib")} {
		rejected(t, Request{Patch: p, PatchSHA256: pin(p), OutputSHA256: pin(nil)}, ErrFormat)
	}
}
func TestChecksumTrailerAndCompressedSuffix(t *testing.T) {
	valid := envelope(raw(1, lit([]byte("a"))))
	damaged := append([]byte(nil), valid...)
	damaged[len(damaged)-1] ^= 1
	for _, p := range [][]byte{damaged, append(append([]byte(nil), valid...), 0), append(append([]byte(nil), valid...), valid[8:]...)} {
		// The test repins deliberately to exercise syntax; production pins are immutable.
		rejected(t, Request{Patch: p, PatchSHA256: pin(p), OutputSHA256: pin([]byte("a"))}, ErrFormat)
	}
}
func TestEveryCompressedTruncationRejected(t *testing.T) {
	p := envelope(raw(3, lit([]byte("abc"))))
	for i := 0; i < len(p); i++ {
		r := Request{Patch: p[:i], PatchSHA256: pin(p[:i]), OutputSHA256: pin([]byte("abc"))}
		rejected(t, r, ErrFormat)
	}
}
func TestTruncatedBodiesAndUnknownOpcodes(t *testing.T) {
	full := raw(2, cp(0, 0, 1), lit([]byte("b")))
	for i := 0; i < len(full); i++ {
		rejected(t, request(full[:i], []byte("ab"), []byte("a")), ErrFormat)
	}
	rejected(t, request(raw(0, append([]byte{2}, make([]byte, 8)...)), nil), ErrFormat)
	rejected(t, request(append(raw(0), 0), nil), ErrFormat)
}
func TestOutputSizeMismatch(t *testing.T) {
	for _, size := range []uint64{0, 2} {
		rejected(t, request(raw(size, lit([]byte("a"))), []byte("a")), ErrBounds)
	}
}
func TestCopyBoundsAndOverflow(t *testing.T) {
	for _, b := range [][]byte{raw(1, cp(1, 0, 1)), raw(4, cp(0, 0, 4)), raw(1, cp(0, 3, 1)), raw(1, cp(0, math.MaxUint64, 1)), raw(1, cp(0, 1, math.MaxUint64))} {
		rejected(t, request(b, []byte("a"), []byte("abc")), ErrBounds)
	}
}
func TestDeclaredAllocationAndOperationLimits(t *testing.T) {
	rejected(t, request(raw(math.MaxUint64), nil), ErrLimit)
	b := raw(0)
	binary.LittleEndian.PutUint32(b[8:], math.MaxUint32)
	rejected(t, request(b, nil), ErrLimit)
	b = raw(0)
	binary.LittleEndian.PutUint32(b[8:], 2)
	rejected(t, request(b, nil), ErrFormat)
}
func TestCompressedDecodedAndOutputCaps(t *testing.T) {
	r := request(raw(256, lit(bytes.Repeat([]byte{0}, 256))), bytes.Repeat([]byte{0}, 256))
	for _, l := range []Limits{{PatchBytes: 8}, {DecodedBytes: 12}, {OutputBytes: 255}} {
		r.Limits = l
		rejected(t, r, ErrLimit)
	}
	r.Limits = Limits{PatchBytes: uint64(len(r.Patch)), DecodedBytes: 277, OutputBytes: 256}
	if _, e := Apply(context.Background(), r); e != nil {
		t.Fatal(e)
	}
}
func TestReferenceCapsAndOperationCap(t *testing.T) {
	r := request(raw(1, cp(0, 0, 1)), []byte("a"), []byte("abc"), []byte("def"))
	for _, l := range []Limits{{References: 1}, {ReferenceBytes: 2}, {TotalReferenceBytes: 5}} {
		r.Limits = l
		rejected(t, r, ErrLimit)
	}
	r = request(raw(2, lit([]byte("a")), lit([]byte("b"))), []byte("ab"))
	r.Limits = Limits{Operations: 1}
	rejected(t, r, ErrLimit)
	r = request(raw(1, cp(1024, 0, 1)), nil)
	rejected(t, r, ErrLimit)
	r = request(raw(0), nil)
	r.Limits = Limits{OutputBytes: math.MaxUint64}
	rejected(t, r, ErrArgument)
}
func TestNilAndCancelledContext(t *testing.T) {
	r := request(raw(0), nil)
	if b, e := Apply(nil, r); b != nil || !errors.Is(e, ErrArgument) {
		t.Fatal(b, e)
	}
	if _, e := Inspect(nil, r.Patch, r.PatchSHA256, Limits{}); !errors.Is(e, ErrArgument) {
		t.Fatal(e)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if b, e := Apply(ctx, r); b != nil || !errors.Is(e, context.Canceled) {
		t.Fatal(b, e)
	}
}

// A deterministic test context cancels at a chosen checkpoint, without timing races.
type budgetContext struct {
	context.Context
	cancel    context.CancelFunc
	remaining int
}

func (b *budgetContext) Err() error {
	b.remaining--
	if b.remaining <= 0 {
		b.cancel()
	}
	return b.Context.Err()
}
func TestCancellationAtHashInflateParseAndCopyCheckpoints(t *testing.T) {
	data := bytes.Repeat([]byte("abcd"), 20000)
	r := request(raw(uint64(len(data)), cp(0, 0, uint64(len(data)))), data, data)
	var cancelled, completed int
	for n := 1; n <= 80; n++ {
		c, cancel := context.WithCancel(context.Background())
		ctx := &budgetContext{c, cancel, n}
		out, e := Apply(ctx, r)
		cancel()
		if e != nil {
			if out != nil || !errors.Is(e, context.Canceled) {
				t.Fatal(e)
			}
			cancelled++
		} else {
			if !bytes.Equal(out, data) {
				t.Fatal("output")
			}
			completed++
		}
	}
	if cancelled == 0 || completed == 0 {
		t.Fatal(cancelled, completed)
	}
}
func TestDeterministicRandomPrograms(t *testing.T) {
	rng := rand.New(rand.NewSource(40402))
	for iteration := 0; iteration < 100; iteration++ {
		refs := [][]byte{make([]byte, 97), make([]byte, 83)}
		for _, b := range refs {
			_, _ = rng.Read(b)
		}
		var want []byte
		var ops [][]byte
		for j := 0; j < 32; j++ {
			if rng.Intn(2) == 0 {
				id := rng.Intn(2)
				off := rng.Intn(len(refs[id]) + 1)
				n := rng.Intn(len(refs[id]) - off + 1)
				ops = append(ops, cp(uint16(id), uint64(off), uint64(n)))
				want = append(want, refs[id][off:off+n]...)
			} else {
				b := make([]byte, rng.Intn(40))
				_, _ = rng.Read(b)
				ops = append(ops, lit(b))
				want = append(want, b...)
			}
		}
		out, e := Apply(context.Background(), request(raw(uint64(len(want)), ops...), want, refs...))
		if e != nil || !bytes.Equal(out, want) {
			t.Fatal(iteration, e)
		}
	}
}
func FuzzInstructions(f *testing.F) {
	f.Add(raw(0))
	f.Add(raw(1, lit([]byte("a"))))
	f.Add(raw(1, cp(0, 0, 1)))
	f.Fuzz(func(t *testing.T, b []byte) {
		if len(b) > 16384 {
			return
		}
		p := envelope(b)
		l := Limits{DecodedBytes: 16384, OutputBytes: 4096, Operations: 256, References: 4, ReferenceBytes: 4096}
		info, e := Inspect(context.Background(), p, pin(p), l)
		if e == nil && (info.CopyBytes+info.LiteralBytes != info.OutputBytes || info.Operations != info.CopyOperations+info.LiteralOperations) {
			t.Fatal(info)
		}
	})
}
func FuzzEnvelope(f *testing.F) {
	f.Add(envelope(raw(0)))
	f.Add([]byte(Magic))
	f.Fuzz(func(t *testing.T, p []byte) {
		if len(p) > 16384 {
			return
		}
		_, _ = Inspect(context.Background(), p, pin(p), Limits{DecodedBytes: 16384, OutputBytes: 4096, Operations: 256, References: 4, ReferenceBytes: 4096})
	})
}

func TestReferenceIndexIsLittleEndianUint16(t *testing.T) {
	refs := make([][]byte, 257)
	refs[256] = []byte("xyz")
	out, e := Apply(context.Background(), request(raw(2, cp(256, 1, 2)), []byte("yz"), refs...))
	if e != nil || string(out) != "yz" {
		t.Fatal(out, e)
	}
}
func TestExternalDictionaryNotAccepted(t *testing.T) {
	var b bytes.Buffer
	b.WriteString(Magic)
	w, e := zlib.NewWriterLevelDict(&b, zlib.BestCompression, []byte("external dictionary"))
	if e != nil {
		t.Fatal(e)
	}
	_, _ = w.Write(raw(0))
	if e = w.Close(); e != nil {
		t.Fatal(e)
	}
	p := b.Bytes()
	rejected(t, Request{Patch: p, PatchSHA256: pin(p), OutputSHA256: pin(nil)}, ErrFormat)
}
