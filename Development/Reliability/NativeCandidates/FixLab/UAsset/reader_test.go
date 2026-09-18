package uasset

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"reflect"
	"testing"
)

type vector struct {
	ID           string `json:"id"`
	Header, Data []byte
	Fields       map[string]int
	Expected     struct {
		HeaderSize, SummaryEnd int
		Names                  []string
		NameSpans              [][2]int
		Imports                []struct {
			Offset int
			Outer  int32
			Name   int32
		}
		Exports []struct {
			Offset, PayloadOffset, Size int
			Name, Number, FirstDep      int32
		}
		Unversioned, Opaque      bool
		HeaderSHA256, DataSHA256 string
	}
}

func vectors(t testing.TB) []vector {
	t.Helper()
	b, e := os.ReadFile("testdata/vectors.json")
	if e != nil {
		t.Fatal(e)
	}
	var v []vector
	if e = json.Unmarshal(b, &v); e != nil {
		t.Fatal(e)
	}
	return v
}
func options() Options { return Options{Profile: CookedUE51} }
func parse(v vector) (*Package, error) {
	o := options()
	o.AllowUnversioned = v.Expected.Unversioned
	data := v.Data
	if data == nil {
		data = []byte{}
	}
	return Read(context.Background(), v.Header, data, o)
}
func put32(b []byte, off int, n int32) { binary.LittleEndian.PutUint32(b[off:], uint32(n)) }
func reject(t testing.TB, b []byte) {
	t.Helper()
	p, e := Read(context.Background(), b, nil, options())
	if e == nil || p != nil {
		t.Fatalf("accepted malformed input or leaked partial package: %v", e)
	}
}

func TestIndependentVectors(t *testing.T) {
	for _, v := range vectors(t) {
		t.Run(v.ID, func(t *testing.T) {
			p, e := parse(v)
			if e != nil {
				t.Fatal(e)
			}
			x := v.Expected
			if p.Summary.HeaderSize != int32(x.HeaderSize) || p.Sections[0].Size != x.SummaryEnd || len(p.Names) != len(x.Names) || len(p.Imports) != len(x.Imports) || len(p.Exports) != len(x.Exports) || p.Summary.Unversioned != x.Unversioned {
				t.Fatal("counts/summary")
			}
			if p.HeaderSHA256 != x.HeaderSHA256 || p.ExportDataSHA256 != x.DataSHA256 || !p.ExportRangesChecked {
				t.Fatal("hashes/scope")
			}
			for i, n := range p.Names {
				if n.Text != x.Names[i] || n.Offset != x.NameSpans[i][0] || n.Size != x.NameSpans[i][1] || n.HashLower != uint16(i*11) || n.HashCase != uint16(i*13) {
					t.Fatal(n)
				}
			}
			for i, n := range p.Imports {
				if n.Offset != x.Imports[i].Offset || n.Outer != x.Imports[i].Outer || n.ObjectName.Index != x.Imports[i].Name || n.Size != 32 {
					t.Fatal(n)
				}
			}
			for i, n := range p.Exports {
				y := x.Exports[i]
				if n.Offset != y.Offset || n.Size != 96 || n.SerialSize != int64(y.Size) || n.SerialOffset != int64(x.HeaderSize+y.PayloadOffset) || n.FirstDependency != y.FirstDep || n.ObjectName != (FName{y.Name, y.Number}) {
					t.Fatal(n)
				}
			}
			if (len(p.Opaque) > 0) != x.Opaque {
				t.Fatal("opaque scope", p.Opaque)
			}
		})
	}
}
func TestHeaderOnlyDoesNotClaimExportData(t *testing.T) {
	v := vectors(t)[0]
	p, e := Read(context.Background(), v.Header, nil, options())
	if e != nil || p.ExportRangesChecked || p.ExportDataSHA256 != "" {
		t.Fatal(p, e)
	}
}
func TestExplicitVersionPolicy(t *testing.T) {
	v := vectors(t)[0]
	for _, o := range []Options{{}, {Profile: "auto"}, {Profile: "ue5-latest"}} {
		if p, e := Read(context.Background(), v.Header, nil, o); e == nil || p != nil {
			t.Fatal(o)
		}
	}
	for _, field := range []string{"legacy", "ue4", "ue5", "licensee", "customCount"} {
		b := bytes.Clone(v.Header)
		put32(b, v.Fields[field], 123)
		reject(t, b)
	}
	u := vectors(t)[2]
	reject(t, u.Header)
	if _, e := parse(u); e != nil {
		t.Fatal(e)
	}
	b := bytes.Clone(u.Header)
	put32(b, u.Fields["ue4"], 522)
	o := options()
	o.AllowUnversioned = true
	if p, e := Read(context.Background(), b, nil, o); e == nil || p != nil {
		t.Fatal("mixed version accepted")
	}
}
func TestAllHeaderTruncationsAndSuffix(t *testing.T) {
	v := vectors(t)[0]
	for i := 0; i < len(v.Header); i++ {
		reject(t, v.Header[:i])
	}
	reject(t, append(bytes.Clone(v.Header), 0))
}
func TestMagicAndCookedFlags(t *testing.T) {
	v := vectors(t)[0]
	b := bytes.Clone(v.Header)
	b[0] ^= 255
	reject(t, b)
	for _, flags := range []uint32{0, 0x200, 0x80000000} {
		b = bytes.Clone(v.Header)
		put32(b, v.Fields["flags"], int32(flags))
		reject(t, b)
	}
}
func TestCountsAndOffsets(t *testing.T) {
	v := vectors(t)[0]
	for _, f := range []string{"nameCount", "importCount", "exportCount", "nameOffset", "importOffset", "exportOffset", "dependsOffset", "preloadOffset"} {
		for _, n := range []int32{-1, 2147483647} {
			b := bytes.Clone(v.Header)
			put32(b, v.Fields[f], n)
			reject(t, b)
		}
	}
	for _, f := range []string{"nameOffset", "importOffset", "exportOffset"} {
		b := bytes.Clone(v.Header)
		put32(b, v.Fields[f], 12)
		reject(t, b)
	}
	b := bytes.Clone(v.Header)
	put32(b, v.Fields["importOffset"], int32(v.Expected.NameSpans[0][0]))
	reject(t, b)
}
func TestOptionalSectionsFailClosed(t *testing.T) {
	v := vectors(t)[0]
	for _, f := range []string{"softObjectCount", "gatherCount", "softPackageCount", "searchableOffset", "thumbnailOffset", "worldTileOffset", "compressedChunks", "compressionFlags", "additionalPackages"} {
		b := bytes.Clone(v.Header)
		put32(b, v.Fields[f], 1)
		reject(t, b)
	}
	b := bytes.Clone(v.Header)
	binary.LittleEndian.PutUint64(b[v.Fields["payloadToc"]:], 1)
	reject(t, b)
}
func TestNarrowStringAndTerminators(t *testing.T) {
	v := vectors(t)[0]
	start := v.Expected.NameSpans[0][0]
	for _, n := range []int32{2147483647, -2147483648} {
		b := bytes.Clone(v.Header)
		put32(b, start, n)
		reject(t, b)
	}
	for _, pos := range []int{start + 4, start + 7, start + 8} {
		b := bytes.Clone(v.Header)
		if pos == start+8 {
			b[pos] = 1
		} else {
			b[pos] = 0
		}
		reject(t, b)
	}
	b := bytes.Clone(v.Header)
	b[start+4] = 255
	reject(t, b)
}
func TestUTF16Validation(t *testing.T) {
	v := vectors(t)[1]
	p, e := parse(v)
	if e != nil || !p.Names[5].UTF16 {
		t.Fatal(e)
	}
	start := v.Expected.NameSpans[5][0]
	end := start + v.Expected.NameSpans[5][1] - 4
	for _, x := range []struct {
		pos int
		n   uint16
	}{{start + 4, 0xd800}, {start + 4, 0xdc00}, {start + 4, 0}, {end - 2, 1}} {
		b := bytes.Clone(v.Header)
		binary.LittleEndian.PutUint16(b[x.pos:], x.n)
		reject(t, b)
	}
}
func TestFNameBoundsAndSuffix(t *testing.T) {
	v := vectors(t)[0]
	imp := v.Expected.Imports[0].Offset
	for _, n := range []int32{-1, 2147483647} {
		b := bytes.Clone(v.Header)
		put32(b, imp, n)
		reject(t, b)
	}
	b := bytes.Clone(v.Header)
	put32(b, imp+4, -1)
	reject(t, b)
	p, e := parse(v)
	if e != nil {
		t.Fatal(e)
	}
	s, e := p.ResolveName(FName{4, 2})
	if e != nil || s != "First_1" {
		t.Fatal(s, e)
	}
	if _, e = p.ResolveName(FName{999, 0}); e == nil {
		t.Fatal("bad name")
	}
}
func TestBooleans(t *testing.T) {
	v := vectors(t)[0]
	for _, off := range []int{v.Expected.Imports[0].Offset + 28, v.Expected.Exports[0].Offset + 44, v.Expected.Exports[0].Offset + 64} {
		b := bytes.Clone(v.Header)
		put32(b, off, 2)
		reject(t, b)
	}
}
func TestObjectReferencesAndOuterCycles(t *testing.T) {
	v := vectors(t)[0]
	for _, off := range []int{v.Expected.Imports[0].Offset + 16, v.Expected.Exports[0].Offset} {
		for _, n := range []int32{-2147483648, 2147483647} {
			b := bytes.Clone(v.Header)
			put32(b, off, n)
			reject(t, b)
		}
	}
	b := bytes.Clone(v.Header)
	put32(b, v.Expected.Imports[0].Offset+16, -2)
	reject(t, b)
	b = bytes.Clone(v.Header)
	put32(b, v.Expected.Exports[0].Offset+12, 1)
	reject(t, b)
	b = bytes.Clone(v.Header)
	put32(b, v.Expected.Imports[0].Offset+16, 1)
	put32(b, v.Expected.Exports[0].Offset+12, -1)
	reject(t, b)
}
func TestDependencyRanges(t *testing.T) {
	v := vectors(t)[0]
	off := v.Expected.Exports[0].Offset
	for _, x := range []struct {
		off int
		n   int32
	}{{off + 76, -2}, {off + 80, -1}, {off + 80, 2147483647}, {off + 76, 99}} {
		b := bytes.Clone(v.Header)
		put32(b, x.off, x.n)
		reject(t, b)
	}
	p, e := parse(v)
	if e != nil {
		t.Fatal(e)
	}
	b := bytes.Clone(v.Header)
	put32(b, p.Sections[len(p.Sections)-1].Offset, -99)
	reject(t, b)
}
func TestSerialBoundsAndOverlap(t *testing.T) {
	v := vectors(t)[0]
	off := v.Expected.Exports[0].Offset
	for _, x := range []struct {
		off int
		n   uint64
	}{{off + 28, ^uint64(0)}, {off + 36, ^uint64(0)}, {off + 36, 1}, {off + 28, 1 << 62}} {
		b := bytes.Clone(v.Header)
		binary.LittleEndian.PutUint64(b[x.off:], x.n)
		reject(t, b)
	}
	m := vectors(t)[5]
	b := bytes.Clone(m.Header)
	binary.LittleEndian.PutUint64(b[m.Expected.Exports[2].Offset+36:], uint64(m.Expected.HeaderSize))
	reject(t, b)
	if p, e := Read(context.Background(), v.Header, v.Data[:len(v.Data)-1], options()); e == nil || p != nil {
		t.Fatal("truncated .uexp accepted")
	}
}
func TestOpaqueAndNonCanonicalGapsRemainExplicit(t *testing.T) {
	v := vectors(t)[4]
	p, e := parse(v)
	if e != nil || len(p.Opaque) != 1 || p.Opaque[0].Name != "assetRegistry" {
		t.Fatal(p, e)
	}
	v = vectors(t)[0]
	b := append(bytes.Clone(v.Header), 9, 8, 7)
	put32(b, v.Fields["headerSize"], int32(len(b)))
	for _, x := range v.Expected.Exports {
		binary.LittleEndian.PutUint64(b[x.Offset+36:], uint64(len(b)+x.PayloadOffset))
	}
	binary.LittleEndian.PutUint64(b[v.Fields["bulkDataStart"]:], uint64(len(b)+len(v.Data)))
	p, e = Read(context.Background(), b, nil, options())
	if e != nil || len(p.Opaque) != 1 || p.Opaque[0].Name != "unparsedTail" {
		t.Fatal(p, e)
	}
}
func TestLimitsCannotBeRaised(t *testing.T) {
	v := vectors(t)[0]
	for _, l := range []Limits{{HeaderBytes: len(v.Header) - 1}, {Objects: 1}, {StringBytes: 2}, {Names: 1}, {HeaderBytes: 65 << 20}, {Names: -1}} {
		o := options()
		o.Limits = l
		if p, e := Read(context.Background(), v.Header, nil, o); e == nil || p != nil {
			t.Fatal(l)
		}
	}
}
func TestNilAndCancelledContext(t *testing.T) {
	v := vectors(t)[0]
	if p, e := Read(nil, v.Header, nil, options()); e == nil || p != nil {
		t.Fatal("nil context")
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if p, e := Read(ctx, v.Header, nil, options()); !errors.Is(e, context.Canceled) || p != nil {
		t.Fatal(e)
	}
}

type countingContext struct {
	context.Context
	n int
}

func (c *countingContext) Err() error {
	c.n--
	if c.n <= 0 {
		return context.Canceled
	}
	return nil
}
func TestCancellationAtEveryReadBoundary(t *testing.T) {
	v := vectors(t)[0]
	success := false
	for n := 1; n < 1000; n++ {
		c := &countingContext{context.Background(), n}
		p, e := Read(c, v.Header, v.Data, options())
		if e == nil {
			success = true
			break
		}
		if !errors.Is(e, context.Canceled) || p != nil {
			t.Fatalf("n=%d p=%v err=%v", n, p != nil, e)
		}
	}
	if !success {
		t.Fatal("never completed")
	}
}
func TestNoInputAliasing(t *testing.T) {
	v := vectors(t)[0]
	p, e := parse(v)
	if e != nil {
		t.Fatal(e)
	}
	before, _ := json.Marshal(p)
	for i := range v.Header {
		v.Header[i] = 0
	}
	after, _ := json.Marshal(p)
	if !bytes.Equal(before, after) {
		t.Fatal("input alias")
	}
}
func TestDeterminism(t *testing.T) {
	v := vectors(t)[0]
	a, e := parse(v)
	if e != nil {
		t.Fatal(e)
	}
	b, e := parse(v)
	if e != nil || !reflect.DeepEqual(a, b) {
		t.Fatal(e)
	}
}
func TestHeaderHashIsNotAuthenticity(t *testing.T) {
	v := vectors(t)[0]
	p, e := parse(v)
	if e != nil {
		t.Fatal(e)
	}
	b := bytes.Clone(v.Data)
	b[0] ^= 1
	q, e := Read(context.Background(), v.Header, b, options())
	if e != nil || q.ExportDataSHA256 == p.ExportDataSHA256 {
		t.Fatal("opaque payloads are hashed, not authenticated")
	}
}
func TestExportMetadataJSON(t *testing.T) {
	dir := os.Getenv("PMM_UASSET_FIXTURE_OUTPUT")
	if dir == "" {
		t.Skip("opt-in synthetic export")
	}
	if e := os.Mkdir(dir, 0700); e != nil {
		t.Fatal(e)
	}
	for _, v := range vectors(t) {
		p, e := parse(v)
		if e != nil {
			t.Fatal(e)
		}
		b, _ := json.MarshalIndent(p, "", "  ")
		if e = os.WriteFile(fmt.Sprintf("%s/%s.json", dir, v.ID), b, 0600); e != nil {
			t.Fatal(e)
		}
	}
}
func FuzzRead(f *testing.F) {
	for _, v := range vectors(f) {
		f.Add(v.Header)
	}
	f.Fuzz(func(t *testing.T, b []byte) {
		if len(b) > 2<<20 {
			t.Skip()
		}
		o := options()
		o.AllowUnversioned = true
		o.Limits = Limits{HeaderBytes: 2 << 20, ExportBytes: 2 << 20, Names: 2048, Objects: 2048, Dependencies: 4096}
		p, e := Read(context.Background(), b, nil, o)
		if e != nil && p != nil {
			t.Fatal("partial result")
		}
	})
}

func TestDisabledPreloadAndZeroSizeExport(t *testing.T) {
	v := vectors(t)[0]
	b := bytes.Clone(v.Header)
	put32(b, v.Fields["preloadCount"], -1)
	put32(b, v.Fields["preloadOffset"], 0)
	for _, x := range v.Expected.Exports {
		put32(b, x.Offset+76, -1)
		for i := 0; i < 4; i++ {
			put32(b, x.Offset+80+4*i, 0)
		}
	}
	x := v.Expected.Exports[1]
	binary.LittleEndian.PutUint64(b[x.Offset+36:], 0)
	p, e := Read(context.Background(), b, nil, options())
	if e != nil || len(p.Preload) != 0 || len(p.Opaque) == 0 {
		t.Fatal(p, e)
	}
}
func FuzzTables(f *testing.F) {
	base := vectors(f)[0]
	f.Add([]byte{0, 0, 0, 0})
	f.Add([]byte{255, 255, 255, 255})
	f.Fuzz(func(t *testing.T, mut []byte) {
		if len(mut) > 512 {
			t.Skip()
		}
		b := bytes.Clone(base.Header)
		start := base.Fields["nameCount"]
		if len(mut) > 0 {
			start = base.Expected.Imports[0].Offset + int(mut[0])%(len(b)-base.Expected.Imports[0].Offset)
		}
		for i, c := range mut {
			b[start+i%(len(b)-start)] ^= c
		}
		p, e := Read(context.Background(), b, nil, options())
		if e != nil && p != nil {
			t.Fatal("partial result")
		}
	})
}
