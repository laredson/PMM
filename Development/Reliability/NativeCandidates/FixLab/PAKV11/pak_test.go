package pakv11

import (
	"bytes"
	"context"
	"crypto/sha1"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func sample() []File {
	return []File{{"a.txt", []byte("abc")}, {"dir/B.bin", []byte{0, 1, 255}}, {"dir/empty", nil}}
}
func buildSample(t *testing.T) []byte {
	t.Helper()
	b, e := Build(context.Background(), sample(), Limits{})
	if e != nil {
		t.Fatal(e)
	}
	return b
}
func golden(t *testing.T) ([]byte, []File) {
	t.Helper()
	b, e := os.ReadFile("testdata/golden.json")
	if e != nil {
		t.Fatal(e)
	}
	var v struct {
		ArchiveHex, SHA256 string
		Expected           map[string]string
	}
	if e = json.Unmarshal(b, &v); e != nil {
		t.Fatal(e)
	}
	raw, e := hex.DecodeString(v.ArchiveHex)
	if e != nil {
		t.Fatal(e)
	}
	h := sha256.Sum256(raw)
	if fmt.Sprintf("%x", h) != v.SHA256 {
		t.Fatal("golden hash")
	}
	var files []File
	for p, h := range v.Expected {
		d, e := hex.DecodeString(h)
		if e != nil {
			t.Fatal(e)
		}
		files = append(files, File{p, d})
	}
	return raw, files
}
func TestIndependentGoldenBytes(t *testing.T) {
	raw, files := golden(t)
	b, e := Build(context.Background(), files, Limits{})
	if e != nil || !bytes.Equal(raw, b) {
		t.Fatal("writer differs from hand-laid-out golden", e)
	}
	r, e := Verify(context.Background(), raw, files, Limits{})
	if e != nil || !r.ByteExact {
		t.Fatal(r, e)
	}
}
func TestEmptyAndBinaryFiles(t *testing.T) {
	for _, files := range [][]File{nil, {{"empty", nil}}, {{"bin", []byte{0, 255, 1, 0, 13, 10}}}, sample()} {
		b, e := Build(context.Background(), files, Limits{})
		if e != nil {
			t.Fatal(e)
		}
		r, e := Verify(context.Background(), b, files, Limits{})
		if e != nil || !r.ByteExact {
			t.Fatal(r, e)
		}
	}
}
func TestDeterministicInputOrdering(t *testing.T) {
	a := buildSample(t)
	f := sample()
	f[0], f[2] = f[2], f[0]
	b, e := Build(context.Background(), f, Limits{})
	if e != nil || !bytes.Equal(a, b) {
		t.Fatal(e)
	}
}
func TestNoInputOrOutputAliasing(t *testing.T) {
	f := sample()
	before := append([]byte(nil), f[0].Data...)
	b := buildSample(t)
	_, e := Build(context.Background(), f, Limits{})
	if e != nil || !bytes.Equal(f[0].Data, before) {
		t.Fatal(e)
	}
	read, e := Read(context.Background(), b, Limits{})
	if e != nil {
		t.Fatal(e)
	}
	read[0].Data[0] ^= 1
	if _, e = Verify(context.Background(), b, sample(), Limits{}); e != nil {
		t.Fatal(e)
	}
}
func TestPathRejection(t *testing.T) {
	bad := []string{"", "/a", "../a", "a/../b", "a//b", "a/./b", "a\\b", "C:/x", "file:stream", "a\x00b", "a\nb", "a.", "a ", "a/b/", "CON", "CON .txt", "nul.txt", "COM1.dat", "LPT9", "CONIN$", "x/aux/y", "a*b", "caf\u00e9", strings.Repeat("x", 256), strings.Repeat("a/", 32) + "x", strings.Repeat("a/", 20) + strings.Repeat("b", 1024)}
	for _, p := range bad {
		t.Run(fmt.Sprintf("%q", p), func(t *testing.T) {
			b, e := Build(context.Background(), []File{{p, nil}}, Limits{})
			if e == nil || b != nil {
				t.Fatal("accepted", p)
			}
		})
	}
}
func TestCaseAndDirectoryCollisions(t *testing.T) {
	for _, f := range [][]File{{{"a", nil}, {"A", nil}}, {{"a", nil}, {"a/x", nil}}, {{"Dir/a", nil}, {"dir/b", nil}}} {
		if b, e := Build(context.Background(), f, Limits{}); e == nil || b != nil {
			t.Fatal(f)
		}
	}
}
func TestPathHashVectors(t *testing.T) {
	b, e := os.ReadFile("testdata/golden.json")
	if e != nil {
		t.Fatal(e)
	}
	var v struct{ PathHashes map[string]string }
	if e = json.Unmarshal(b, &v); e != nil {
		t.Fatal(e)
	}
	for p, want := range v.PathHashes {
		h, e := HashPath(p, 0)
		if e != nil || fmt.Sprintf("%016x", h) != want {
			t.Fatal(p, h, want, e)
		}
		h2, _ := HashPath(strings.ToUpper(p), 0)
		if h != h2 {
			t.Fatal("case hash")
		}
	}
	if _, e := HashPath("../x", 0); e == nil {
		t.Fatal("unsafe hash input")
	}
}
func TestResourceLimits(t *testing.T) {
	for _, l := range []Limits{{ArchiveBytes: 100}, {FileBytes: 2}, {IndexBytes: 130}, {Files: 1}, {PathBytes: 3}, {Depth: 1}, {ArchiveBytes: (256 << 20) + 1}, {FileBytes: (64 << 20) + 1}, {IndexBytes: (32 << 20) + 1}, {Files: 16385}, {PathBytes: 1025}, {Depth: 33}} {
		b, e := Build(context.Background(), sample(), l)
		if e == nil || b != nil {
			t.Fatal(l)
		}
		if _, e = Read(context.Background(), buildSample(t), l); e == nil {
			t.Fatal("reader", l)
		}
	}
}
func TestCancellationAndNilContext(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	for _, c := range []context.Context{nil, ctx} {
		if b, e := Build(c, sample(), Limits{}); e == nil || b != nil {
			t.Fatal(e)
		}
		if b, e := Read(c, buildSample(t), Limits{}); e == nil || b != nil {
			t.Fatal(e)
		}
		if r, e := Verify(c, buildSample(t), sample(), Limits{}); e == nil || r.ByteExact {
			t.Fatal(e)
		}
	}
}

type stepContext struct {
	context.Context
	cancel    context.CancelFunc
	remaining int
}

func (c *stepContext) Err() error {
	c.remaining--
	if c.remaining <= 0 {
		c.cancel()
	}
	return c.Context.Err()
}
func TestCancellationDuringWork(t *testing.T) {
	files := []File{{"big.bin", bytes.Repeat([]byte("x"), 3<<20)}}
	archive, e := Build(context.Background(), files, Limits{})
	if e != nil {
		t.Fatal(e)
	}
	for _, n := range []int{2, 6, 10, 14} {
		ctx, cancel := context.WithCancel(context.Background())
		c := &stepContext{ctx, cancel, n}
		b, e := Build(c, files, Limits{})
		cancel()
		if e == nil || b != nil {
			t.Fatal("build cancellation", n)
		}
		ctx, cancel = context.WithCancel(context.Background())
		c = &stepContext{ctx, cancel, n}
		r, e := Read(c, archive, Limits{})
		cancel()
		if e == nil || r != nil {
			t.Fatal("read cancellation", n)
		}
	}
}
func TestEveryGoldenTruncation(t *testing.T) {
	b := buildSample(t)
	for n := 0; n < len(b); n++ {
		if out, e := Read(context.Background(), b[:n], Limits{}); e == nil || out != nil {
			t.Fatalf("accepted %d bytes", n)
		}
	}
}
func TestFooterAndSuffixRejection(t *testing.T) {
	base := buildSample(t)
	for _, off := range []int{0, 16, 17, 21, 25, 33, 41, 61} {
		b := append([]byte(nil), base...)
		b[len(b)-FooterSize+off] ^= 1
		if _, e := Read(context.Background(), b, Limits{}); e == nil {
			t.Fatal(off)
		}
	}
	if _, e := Read(context.Background(), append(base, 0), Limits{}); e == nil {
		t.Fatal("suffix accepted")
	}
}

// TEST-ONLY resealing lets logical-corruption tests reach semantic checks instead
// of failing at their outer checksum. It is never used on product archives.
func offsets(b []byte) (int, int, int, int) {
	f := len(b) - FooterSize
	p := int(binary.LittleEndian.Uint64(b[f+25:]))
	ps := int(binary.LittleEndian.Uint64(b[f+33:]))
	ph := int(binary.LittleEndian.Uint64(b[p+30:]))
	fd := int(binary.LittleEndian.Uint64(b[p+70:]))
	return p, ps, ph, fd
}
func reseal(b []byte) {
	p, ps, ph, fd := offsets(b)
	f := len(b) - FooterSize
	h := sha1.Sum(b[ph:fd])
	copy(b[p+46:p+66], h[:])
	h = sha1.Sum(b[fd:f])
	copy(b[p+86:p+106], h[:])
	h = sha1.Sum(b[p : p+ps])
	copy(b[f+41:f+61], h[:])
}
func TestLogicalTamperAfterResealing(t *testing.T) {
	base := buildSample(t)
	p, _, ph, fd := offsets(base)
	cases := map[string]func([]byte){
		"wrong count":        func(b []byte) { binary.LittleEndian.PutUint32(b[p+14:], 4) },
		"too many":           func(b []byte) { binary.LittleEndian.PutUint32(b[p+14:], 0xffffffff) },
		"record flags":       func(b []byte) { b[p+110] ^= 1 },
		"overlap data":       func(b []byte) { binary.LittleEndian.PutUint32(b[p+126:], 0) },
		"size mismatch":      func(b []byte) { binary.LittleEndian.PutUint32(b[p+118:], 2) },
		"unencoded count":    func(b []byte) { b[ph-4] = 1 },
		"duplicate hash":     func(b []byte) { copy(b[ph+16:ph+24], b[ph+4:ph+12]) },
		"duplicate phi loc":  func(b []byte) { binary.LittleEndian.PutUint32(b[ph+24:], 0) },
		"deleted location":   func(b []byte) { binary.LittleEndian.PutUint32(b[ph+12:], 0x80000000) },
		"middle of record":   func(b []byte) { binary.LittleEndian.PutUint32(b[ph+12:], 1) },
		"pruned directory":   func(b []byte) { b[fd-4] = 1 },
		"invalid FString":    func(b []byte) { binary.LittleEndian.PutUint32(b[fd+14:], 0x80000000) },
		"traversal name":     func(b []byte) { copy(b[fd+18:fd+23], []byte("../xx")) },
		"ads name":           func(b []byte) { copy(b[fd+18:fd+23], []byte("a:txt")) },
		"nonascii name":      func(b []byte) { b[fd+18] = 255 },
		"missing terminator": func(b []byte) { b[fd+23] = 1 },
		"directory count":    func(b []byte) { binary.LittleEndian.PutUint32(b[fd:], 0xffffffff) },
		"duplicate fdi loc":  func(b []byte) { binary.LittleEndian.PutUint32(b[fd+51:], 0) },
	}
	for name, mutate := range cases {
		t.Run(name, func(t *testing.T) {
			b := append([]byte(nil), base...)
			mutate(b)
			reseal(b)
			if out, e := Read(context.Background(), b, Limits{}); e == nil || out != nil {
				t.Fatal("logical error accepted")
			}
		})
	}
}
func TestHugeOffsetAndSecondaryOverlap(t *testing.T) {
	base := buildSample(t)
	p, ps, _, _ := offsets(base)
	for _, off := range []int{len(base) - FooterSize + 25, len(base) - FooterSize + 33, p + 30, p + 38, p + 70, p + 78} {
		b := append([]byte(nil), base...)
		binary.LittleEndian.PutUint64(b[off:], ^uint64(0))
		if off >= p && off < p+ps {
			h := sha1.Sum(b[p : p+ps])
			copy(b[len(b)-FooterSize+41:], h[:])
		}
		if _, e := Read(context.Background(), b, Limits{}); e == nil {
			t.Fatal(off)
		}
	}
}
func TestDataHashesAndHeaderChecks(t *testing.T) {
	for _, off := range []int{0, 8, 16, 24, 28, 48, 49, 53} {
		b := buildSample(t)
		b[off] ^= 1
		if _, e := Read(context.Background(), b, Limits{}); e == nil {
			t.Fatal(off)
		}
	}
}
func TestExpectedBytesNotArchiveChecksumAlone(t *testing.T) {
	b := buildSample(t)
	b[53] = 'X'
	h := sha1.Sum(b[53:56])
	copy(b[28:48], h[:])
	if _, e := Read(context.Background(), b, Limits{}); e != nil {
		t.Fatal("rehashed content should parse", e)
	}
	if r, e := Verify(context.Background(), b, sample(), Limits{}); e == nil || r.ByteExact {
		t.Fatal("rehashed different data accepted")
	}
	for _, f := range [][]File{nil, {{"a.txt", nil}}, {{"different", []byte("abc")}}} {
		if r, e := Verify(context.Background(), buildSample(t), f, Limits{}); e == nil || r.ByteExact {
			t.Fatal(f)
		}
	}
}
func TestNonzeroSeedReadback(t *testing.T) {
	b := buildSample(t)
	p, _, ph, _ := offsets(b)
	seed := ^uint64(0)
	binary.LittleEndian.PutUint64(b[p+18:], seed)
	for i, f := range sample() {
		h, _ := HashPath(f.Path, seed)
		binary.LittleEndian.PutUint64(b[ph+4+i*12:], h)
	}
	reseal(b)
	if _, e := Verify(context.Background(), b, sample(), Limits{}); e != nil {
		t.Fatal(e)
	}
}
func syntheticCases() [][]File {
	r := rand.New(rand.NewSource(403))
	out := [][]File{nil, sample(), {{"Root space.txt", []byte("\r\nno newline")}}, {{"deep/a/b/c.bin", []byte{0, 255, 0}}}}
	for k := 0; k < 12; k++ {
		var files []File
		for j := 0; j < (k+1)*3; j++ {
			data := make([]byte, r.Intn(4096))
			_, _ = r.Read(data)
			files = append(files, File{fmt.Sprintf("d%d/f%03d.bin", j%4, j), data})
		}
		out = append(out, files)
	}
	out = append(out, []File{{"long.bin", bytes.Repeat([]byte{0, 1, 255, 10}, (3<<20)/4)}})
	return out
}
func TestSyntheticRoundtrips(t *testing.T) {
	for i, f := range syntheticCases() {
		b, e := Build(context.Background(), f, Limits{})
		if e != nil {
			t.Fatal(i, e)
		}
		r, e := Verify(context.Background(), b, f, Limits{})
		if e != nil || !r.ByteExact {
			t.Fatal(i, r, e)
		}
	}
}
func TestIndependentReadbackCorpusExport(t *testing.T) {
	dir := os.Getenv("PMM_PAKV11_EXPORT")
	if dir == "" {
		t.Skip("opt-in synthetic export for independent Python verifier")
	}
	if !filepath.IsAbs(dir) {
		t.Fatal("output must be absolute and new")
	}
	if e := os.Mkdir(dir, 0700); e != nil {
		t.Fatal(e)
	}
	for i, f := range syntheticCases() {
		b, e := Build(context.Background(), f, Limits{})
		if e != nil {
			t.Fatal(e)
		}
		report, e := Verify(context.Background(), b, f, Limits{})
		if e != nil {
			t.Fatal(e)
		}
		expected := map[string]string{}
		for _, item := range f {
			expected[item.Path] = hex.EncodeToString(item.Data)
		}
		j, e := json.MarshalIndent(map[string]any{"expected": expected, "goReport": report}, "", "  ")
		if e != nil {
			t.Fatal(e)
		}
		prefix := filepath.Join(dir, fmt.Sprintf("synthetic-%02d", i))
		if e = os.WriteFile(prefix+".pak", b, 0600); e != nil {
			t.Fatal(e)
		}
		if e = os.WriteFile(prefix+".json", j, 0600); e != nil {
			t.Fatal(e)
		}
	}
}
func TestLimitsDoNotChangeCanonicalBytes(t *testing.T) {
	b := buildSample(t)
	lower := Limits{ArchiveBytes: 1024, FileBytes: 16, IndexBytes: 512, Files: 4, PathBytes: 20, Depth: 3}
	c, e := Build(context.Background(), sample(), lower)
	if e != nil || !bytes.Equal(b, c) {
		t.Fatal(e)
	}
	r, e := Read(context.Background(), b, lower)
	if e != nil || len(r) != 3 {
		t.Fatal(e)
	}
}
func FuzzRead(f *testing.F) {
	b, e := Build(context.Background(), sample(), Limits{})
	if e != nil {
		f.Fatal(e)
	}
	f.Add(b)
	f.Add([]byte("PAK"))
	f.Fuzz(func(t *testing.T, b []byte) {
		if len(b) > 1<<20 {
			return
		}
		r, e := Read(context.Background(), b, Limits{ArchiveBytes: 1 << 20, FileBytes: 1 << 20, IndexBytes: 1 << 20, Files: 128})
		if e != nil {
			if r != nil {
				t.Fatal("partial result")
			}
			return
		}
		out, e := Build(context.Background(), r, Limits{ArchiveBytes: 2 << 20, FileBytes: 1 << 20, IndexBytes: 1 << 20, Files: 128})
		if e != nil {
			t.Fatal(e)
		}
		rr, e := Read(context.Background(), out, Limits{})
		if e != nil || !reflect.DeepEqual(r, rr) {
			t.Fatal("nonstable parsed content", e)
		}
	})
}

// Reach inner metadata validation with independently resealed synthetic hashes.
func FuzzResealedIndexes(f *testing.F) {
	base, e := Build(context.Background(), sample(), Limits{})
	if e != nil {
		f.Fatal(e)
	}
	p, _, ph, fd := offsets(base)
	f.Add(uint16(0), []byte{0, 0, 0, 224})
	f.Add(uint16(46), []byte{255, 255, 255, 255})
	f.Fuzz(func(t *testing.T, start uint16, mut []byte) {
		if len(mut) > 256 {
			return
		}
		b := append([]byte(nil), base...)
		positions := make([]int, 0, 149)
		for _, span := range [][2]int{{p + 110, p + 146}, {ph, fd}, {fd, len(b) - FooterSize}} {
			for j := span[0]; j < span[1]; j++ {
				positions = append(positions, j)
			}
		}
		for j, v := range mut {
			b[positions[(int(start)+j)%len(positions)]] = v
		}
		reseal(b)
		out, e := Read(context.Background(), b, Limits{ArchiveBytes: 4096, FileBytes: 1024, IndexBytes: 4096, Files: 8})
		if e != nil && out != nil {
			t.Fatal("partial result on corruption")
		}
	})
}
