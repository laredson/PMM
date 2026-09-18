package uasset

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func digestTest(b []byte) string { d := sha256.Sum256(b); return hex.EncodeToString(d[:]) }
func rewriteRequest(v vector, sources ...vector) RewriteRequest {
	r := RewriteRequest{HeaderSHA256: digestTest(v.Header), ExportSHA256: digestTest(v.Data)}
	for _, s := range sources {
		r.Sources = append(r.Sources, NameSource{s.Header, digestTest(s.Header)})
	}
	return r
}
func rewriteCall(v vector, req RewriteRequest) (*RewriteResult, error) {
	o := options()
	o.AllowUnversioned = v.Expected.Unversioned
	x := v.Data
	if x == nil {
		x = []byte{}
	}
	return RewriteNames(context.Background(), v.Header, x, o, req)
}
func emptyExports(t testing.TB, v vector) vector {
	t.Helper()
	v.Header = bytes.Clone(v.Header)
	v.Data = []byte{}
	for _, x := range v.Expected.Exports {
		binary.LittleEndian.PutUint64(v.Header[x.Offset+28:], 0)
		binary.LittleEndian.PutUint64(v.Header[x.Offset+36:], uint64(len(v.Header)))
	}
	binary.LittleEndian.PutUint64(v.Header[v.Fields["bulkDataStart"]:], 0)
	if _, e := parse(v); e != nil {
		t.Fatal(e)
	}
	return v
}
func sameWidthSource(t testing.TB, v vector) vector {
	t.Helper()
	v.Header = bytes.Clone(v.Header)
	n := v.Expected.NameSpans[4]
	copy(v.Header[n[0]+4:], []byte("Other"))
	binary.LittleEndian.PutUint16(v.Header[n[0]+n[1]-4:], 0x7531)
	binary.LittleEndian.PutUint16(v.Header[n[0]+n[1]-2:], 0x2468)
	if _, e := parse(v); e != nil {
		t.Fatal(e)
	}
	return v
}
func TestRewriteNoopByteIdentity(t *testing.T) {
	for _, v := range vectors(t) {
		t.Run(v.ID, func(t *testing.T) {
			r, e := rewriteCall(v, rewriteRequest(v))
			if e != nil || !bytes.Equal(r.Header, v.Header) || !bytes.Equal(r.ExportData, v.Data) || r.Report.Changed || len(r.Report.Offsets) != 0 {
				t.Fatal(r, e)
			}
		})
	}
}
func TestRewriteFixedWidthPreservesOpaque(t *testing.T) {
	for _, k := range []int{0, 1, 4, 5} {
		v := vectors(t)[k]
		src := sameWidthSource(t, v)
		req := rewriteRequest(v, src)
		req.Edits = []NameEdit{{4, 0, 4}}
		r, e := rewriteCall(v, req)
		if e != nil {
			t.Fatal(e)
		}
		p, _ := parse(v)
		n := p.Names[4]
		want := bytes.Clone(v.Header)
		copy(want[n.Offset:n.Offset+n.Size], src.Header[n.Offset:n.Offset+n.Size])
		if !bytes.Equal(r.Header, want) || !bytes.Equal(r.ExportData, v.Data) || !r.Report.Changed || r.Report.NameLayoutChanged || len(r.Report.Offsets) != 0 {
			t.Fatal("unauthorized bytes changed")
		}
		if r.Package.Names[4].HashLower != 0x7531 || r.Package.Names[4].HashCase != 0x2468 {
			t.Fatal("hash not taken from source")
		}
	}
}
func checkShift(t testing.TB, v vector, r *RewriteResult) {
	t.Helper()
	p, _ := parse(v)
	q := r.Package
	delta := int64(len(r.Header) - len(v.Header))
	if q.Summary.HeaderSize != int32(len(r.Header)) || int64(r.Report.HeaderDelta) != delta {
		t.Fatal("delta")
	}
	if q.Summary.NameCount != p.Summary.NameCount || !reflect.DeepEqual(q.Depends, p.Depends) || !reflect.DeepEqual(q.Preload, p.Preload) {
		t.Fatal("indices changed")
	}
	for i, x := range p.Exports {
		y := q.Exports[i]
		if x.SerialOffset != 0 && y.SerialOffset-int64(q.Summary.HeaderSize) != x.SerialOffset-int64(p.Summary.HeaderSize) {
			t.Fatal("serial coordinate")
		}
		if x.SerialOffset == 0 && y.SerialOffset != 0 {
			t.Fatal("zero sentinel")
		}
	}
	for i, x := range p.Imports {
		y := q.Imports[i]
		x.Span = y.Span
		if !reflect.DeepEqual(x, y) {
			t.Fatal("import modified")
		}
	}
}
func TestRewriteGrowthShrinkAndUnicode(t *testing.T) {
	for _, edit := range []NameEdit{{4, 0, 5}, {1, 0, 0}} {
		v := emptyExports(t, vectors(t)[0])
		s := vectors(t)[1]
		req := rewriteRequest(v, s)
		req.Edits = []NameEdit{edit}
		r, e := rewriteCall(v, req)
		if e != nil {
			t.Fatal(e)
		}
		checkShift(t, v, r)
		if !r.Report.NameLayoutChanged || r.Report.HeaderDelta == 0 {
			t.Fatal("not relocalized")
		}
		if edit.Index == 4 && !r.Package.Names[4].UTF16 {
			t.Fatal("wide source lost")
		}
	}
}
func TestRewriteNetZeroReflowStillProtected(t *testing.T) {
	for _, clean := range []bool{false, true} {
		v := vectors(t)[0]
		if clean {
			v = emptyExports(t, v)
		}
		req := rewriteRequest(v, v)
		req.Edits = []NameEdit{{3, 0, 4}, {4, 0, 3}}
		r, e := rewriteCall(v, req)
		if !clean {
			if !errors.Is(e, ErrUnsupported) || r != nil {
				t.Fatal("opaque net-zero reflow accepted")
			}
		} else {
			if e != nil {
				t.Fatal(e)
			}
			if !r.Report.NameLayoutChanged || r.Report.HeaderDelta != 0 {
				t.Fatal("reflow classification")
			}
			checkShift(t, v, r)
		}
	}
}
func TestRewriteOpaqueRelocationRejected(t *testing.T) {
	v := vectors(t)[0]
	source := vectors(t)[1]
	samples := []vector{v, emptyExports(t, vectors(t)[4])}
	bulk := emptyExports(t, v)
	binary.LittleEndian.PutUint64(bulk.Header[bulk.Fields["bulkDataStart"]:], uint64(len(bulk.Header)))
	samples = append(samples, bulk)
	gap := emptyExports(t, v)
	gap.Header = append(gap.Header, 0)
	put32(gap.Header, gap.Fields["headerSize"], int32(len(gap.Header)))
	for _, x := range gap.Expected.Exports {
		binary.LittleEndian.PutUint64(gap.Header[x.Offset+36:], uint64(len(gap.Header)))
	}
	samples = append(samples, gap)
	for _, v := range samples {
		req := rewriteRequest(v, source)
		req.Edits = []NameEdit{{4, 0, 5}}
		r, e := rewriteCall(v, req)
		if !errors.Is(e, ErrUnsupported) || r != nil {
			t.Fatal("moved unknown content", e)
		}
	}
}
func TestRewriteInactiveMarkersAndZeroSentinel(t *testing.T) {
	v := emptyExports(t, vectors(t)[0])
	source := vectors(t)[1]
	for _, f := range []string{"softObjectOffset", "gatherOffset", "softPackageOffset"} {
		put32(v.Header, v.Fields[f], int32(len(v.Header)))
	}
	binary.LittleEndian.PutUint64(v.Header[v.Expected.Exports[1].Offset+36:], 0)
	req := rewriteRequest(v, source)
	req.Edits = []NameEdit{{4, 0, 5}}
	r, e := rewriteCall(v, req)
	if e != nil {
		t.Fatal(e)
	}
	checkShift(t, v, r)
	for _, f := range []string{"softObjectOffset", "gatherOffset", "softPackageOffset"} {
		if int(binary.LittleEndian.Uint32(r.Header[v.Fields[f]:])) != len(r.Header) {
			t.Fatal("inactive marker not moved")
		}
	}
	// A marker inside a name string is not a table endpoint; do not guess.
	put32(v.Header, v.Fields["softObjectOffset"], int32(v.Expected.NameSpans[1][0]+2))
	req = rewriteRequest(v, source)
	req.Edits = []NameEdit{{4, 0, 5}}
	if r, e = rewriteCall(v, req); !errors.Is(e, ErrUnsupported) || r != nil {
		t.Fatal(e)
	}
}
func TestRewriteNamesAfterOtherTables(t *testing.T) {
	v := emptyExports(t, vectors(t)[0])
	p, _ := parse(v)
	first := p.Names[0].Offset
	last := p.Names[len(p.Names)-1]
	end := last.Offset + last.Size
	n := end - first
	h := append(bytes.Clone(v.Header[:first]), v.Header[end:]...)
	h = append(h, v.Header[first:end]...)
	v.Header = h
	put32(h, v.Fields["nameOffset"], int32(len(h)-n))
	for _, f := range []string{"importOffset", "exportOffset", "dependsOffset", "preloadOffset"} {
		put32(h, v.Fields[f], int32(binary.LittleEndian.Uint32(h[v.Fields[f]:]))-int32(n))
	}
	p, e := Read(context.Background(), h, []byte{}, options())
	if e != nil {
		t.Fatal(e)
	}
	req := rewriteRequest(v, vectors(t)[1])
	req.Edits = []NameEdit{{4, 0, 5}}
	r, e := rewriteCall(v, req)
	if e != nil {
		t.Fatal(e)
	}
	if r.Package.Summary.ImportOffset != p.Summary.ImportOffset || r.Package.Summary.ExportOffset != p.Summary.ExportOffset {
		t.Fatal("shifted earlier tables")
	}
	for _, ex := range r.Package.Exports {
		if ex.SerialOffset != int64(len(r.Header)) {
			t.Fatal("logical offsets must move even if export TABLE does not")
		}
	}
}
func TestRewritePinsMandatoryBeforeParse(t *testing.T) {
	v := vectors(t)[0]
	s := sameWidthSource(t, v)
	req := rewriteRequest(v, s)
	req.Edits = []NameEdit{{4, 0, 4}}
	for _, which := range []string{"header", "data", "source"} {
		for _, pin := range []string{"", "ABC", fmt.Sprintf("%064d", 0)} {
			bad := req
			bad.Sources = append([]NameSource(nil), req.Sources...)
			switch which {
			case "header":
				bad.HeaderSHA256 = pin
			case "data":
				bad.ExportSHA256 = pin
			case "source":
				bad.Sources[0].SHA256 = pin
			}
			if r, e := rewriteCall(v, bad); e == nil || r != nil {
				t.Fatal(which, pin)
			}
		}
	}
	bad := req
	bad.HeaderSHA256 = "A" + req.HeaderSHA256[1:]
	if r, e := rewriteCall(v, bad); e == nil || r != nil {
		t.Fatal("uppercase pin")
	}
}
func TestRewriteEditsAndSourceBounds(t *testing.T) {
	v := vectors(t)[0]
	for _, edits := range [][]NameEdit{{{-1, 0, 0}}, {{6, 0, 0}}, {{4, -1, 0}}, {{4, 1, 0}}, {{4, 0, -1}}, {{4, 0, 6}}, {{4, 0, 4}, {4, 0, 4}}} {
		req := rewriteRequest(v, v)
		req.Edits = edits
		if r, e := rewriteCall(v, req); e == nil || r != nil {
			t.Fatal(edits)
		}
	}
	req := rewriteRequest(v)
	req.Edits = []NameEdit{{4, 0, 0}}
	if r, e := rewriteCall(v, req); e == nil || r != nil {
		t.Fatal("missing source")
	}
}
func TestRewriteExplicitProfileAndData(t *testing.T) {
	v := vectors(t)[0]
	req := rewriteRequest(v)
	for _, o := range []Options{{}, {Profile: "guess"}} {
		if r, e := RewriteNames(context.Background(), v.Header, v.Data, o, req); e == nil || r != nil {
			t.Fatal(o)
		}
	}
	if r, e := RewriteNames(context.Background(), v.Header, nil, options(), req); !errors.Is(e, ErrUnsupported) || r != nil {
		t.Fatal("nil uexp")
	}
	v = vectors(t)[2]
	req = rewriteRequest(v)
	if r, e := RewriteNames(context.Background(), v.Header, v.Data, options(), req); e == nil || r != nil {
		t.Fatal("guessed unversioned")
	}
}
func TestRewriteLimits(t *testing.T) {
	v := emptyExports(t, vectors(t)[0])
	req := rewriteRequest(v, v)
	req.Edits = []NameEdit{{4, 0, 1}}
	o := options()
	o.Limits.HeaderBytes = len(v.Header)
	if r, e := RewriteNames(context.Background(), v.Header, v.Data, o, req); !errors.Is(e, ErrLimit) || r != nil {
		t.Fatal("output header limit", e)
	}
	req.Edits = nil
	req.Sources = append(req.Sources, req.Sources[0])
	o.Limits.HeaderBytes = len(v.Header)*2 - 1
	if r, e := RewriteNames(context.Background(), v.Header, v.Data, o, req); !errors.Is(e, ErrLimit) || r != nil {
		t.Fatal("aggregate", e)
	}
	req.Sources = make([]NameSource, 9)
	if r, e := rewriteCall(v, req); !errors.Is(e, ErrLimit) || r != nil {
		t.Fatal("source cap")
	}
}
func TestRewriteNoInputOrResultAlias(t *testing.T) {
	v := vectors(t)[0]
	s := sameWidthSource(t, v)
	req := rewriteRequest(v, s)
	req.Edits = []NameEdit{{4, 0, 4}}
	h, x, sh := bytes.Clone(v.Header), bytes.Clone(v.Data), bytes.Clone(s.Header)
	r, e := rewriteCall(v, req)
	if e != nil {
		t.Fatal(e)
	}
	if !bytes.Equal(v.Header, h) || !bytes.Equal(v.Data, x) || !bytes.Equal(s.Header, sh) {
		t.Fatal("inputs changed")
	}
	r.Header[0] ^= 1
	r.ExportData[0] ^= 1
	r.Report.Edits[0].Index = 0
	r.Package.Names[4].Text = "mutation"
	if !bytes.Equal(v.Header, h) || !bytes.Equal(v.Data, x) || !bytes.Equal(s.Header, sh) || req.Edits[0].Index != 4 {
		t.Fatal("alias")
	}
}
func TestRewriteCancellationEveryBoundary(t *testing.T) {
	v := emptyExports(t, vectors(t)[0])
	req := rewriteRequest(v, vectors(t)[1])
	req.Edits = []NameEdit{{4, 0, 5}}
	if r, e := RewriteNames(nil, v.Header, v.Data, options(), req); e == nil || r != nil {
		t.Fatal("nil context")
	}
	finished := false
	for n := 1; n < 3000; n++ {
		ctx := &countingContext{context.Background(), n}
		r, e := RewriteNames(ctx, v.Header, v.Data, options(), req)
		if e == nil {
			finished = true
			break
		}
		if !errors.Is(e, context.Canceled) || r != nil {
			t.Fatal(n, e)
		}
	}
	if !finished {
		t.Fatal("did not finish")
	}
}
func TestRewriteDeterminismAndInverse(t *testing.T) {
	v := emptyExports(t, vectors(t)[0])
	src := vectors(t)[1]
	req := rewriteRequest(v, src)
	req.Edits = []NameEdit{{4, 0, 5}}
	a, e := rewriteCall(v, req)
	if e != nil {
		t.Fatal(e)
	}
	b, e := rewriteCall(v, req)
	if e != nil || !bytes.Equal(a.Header, b.Header) {
		t.Fatal("nondeterministic")
	}
	back := RewriteRequest{HeaderSHA256: a.Report.HeaderAfter, ExportSHA256: a.Report.ExportSHA256, Sources: []NameSource{{v.Header, req.HeaderSHA256}}, Edits: []NameEdit{{4, 0, 4}}}
	c, e := RewriteNames(context.Background(), a.Header, a.ExportData, options(), back)
	if e != nil || !bytes.Equal(c.Header, v.Header) {
		t.Fatal("inverse not byte exact", e)
	}
}
func TestRewriteMalformedPinnedInput(t *testing.T) {
	v := vectors(t)[0]
	for n := 0; n < len(v.Header); n++ {
		b := v
		b.Header = v.Header[:n]
		if r, e := rewriteCall(b, rewriteRequest(b)); e == nil || r != nil {
			t.Fatal("accepted truncation", n)
		}
	}
	v.Header = bytes.Clone(v.Header)
	put32(v.Header, v.Fields["customCount"], 1)
	if r, e := rewriteCall(v, rewriteRequest(v)); e == nil || r != nil {
		t.Fatal("unsupported custom version")
	}
}

// Export only our synthetic inputs and outputs for the independent Python reader.
func TestRewriteIndependentCorpusExport(t *testing.T) {
	dir := os.Getenv("PMM_UASSET_REWRITE_OUTPUT")
	if dir == "" {
		t.Skip("opt-in synthetic export")
	}
	if e := os.Mkdir(dir, 0700); e != nil {
		t.Fatal(e)
	}
	type job struct {
		ID      string
		V       vector
		Request RewriteRequest
	}
	var jobs []job
	for _, v := range vectors(t) {
		jobs = append(jobs, job{"noop-" + v.ID, v, rewriteRequest(v)})
	}
	for _, k := range []int{0, 1, 4} {
		v := vectors(t)[k]
		s := sameWidthSource(t, v)
		req := rewriteRequest(v, s)
		req.Edits = []NameEdit{{4, 0, 4}}
		jobs = append(jobs, job{"fixed-" + v.ID, v, req})
	}
	v := emptyExports(t, vectors(t)[0])
	s := vectors(t)[1]
	for _, item := range []struct {
		id    string
		edits []NameEdit
	}{{"grow-unicode", []NameEdit{{4, 0, 5}}}, {"shrink", []NameEdit{{1, 0, 0}}}, {"net-zero", []NameEdit{{3, 0, 4}, {4, 0, 3}}}} {
		req := rewriteRequest(v, s)
		req.Edits = item.edits
		jobs = append(jobs, job{item.id, v, req})
	}
	for _, j := range jobs {
		r, e := rewriteCall(j.V, j.Request)
		if e != nil {
			t.Fatal(j.ID, e)
		}
		b, e := json.MarshalIndent(struct {
			ID                     string
			InputHeader, InputData []byte
			Fields                 map[string]int
			Request                RewriteRequest
			Result                 *RewriteResult
		}{j.ID, j.V.Header, j.V.Data, j.V.Fields, j.Request, r}, "", "  ")
		if e != nil {
			t.Fatal(e)
		}
		if e = os.WriteFile(filepath.Join(dir, j.ID+".json"), b, 0600); e != nil {
			t.Fatal(e)
		}
	}
}
func FuzzRewritePinned(f *testing.F) {
	base := vectors(f)[0]
	f.Add([]byte{0})
	f.Add([]byte{255, 0, 1})
	f.Fuzz(func(t *testing.T, mut []byte) {
		if len(mut) > 1024 {
			t.Skip()
		}
		v := base
		v.Header = bytes.Clone(base.Header)
		start := base.Fields["nameCount"]
		for i, c := range mut {
			v.Header[start+i%(len(v.Header)-start)] ^= c
		}
		req := rewriteRequest(v, base)
		req.Edits = []NameEdit{{4, 0, 4}}
		r, e := rewriteCall(v, req)
		if e != nil && r != nil {
			t.Fatal("partial result")
		}
		if e == nil {
			if !bytes.Equal(r.ExportData, v.Data) {
				t.Fatal("payload changed")
			}
			if _, e = Read(context.Background(), r.Header, r.ExportData, options()); e != nil {
				t.Fatal(e)
			}
		}
	})
}
