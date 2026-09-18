package uasset

import (
	"bytes"
	"compress/zlib"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type postVector struct {
	ID                                         string `json:"id"`
	Header, Data, ExpectedHeader, ExpectedData []byte
	Request                                    PostProcessRequest
	Positions                                  struct {
		Imports, Exports             []int
		Preload, Property, PrefixEnd int
		Fields                       map[string]int
	}
}

func postVectors(t testing.TB) []postVector {
	t.Helper()
	b, e := os.ReadFile("testdata/postprocess-vectors.json")
	if e != nil {
		t.Fatal(e)
	}
	var envelope struct {
		Schema        string
		DecodedBytes  int
		DecodedSha256 string
		Content       []byte
	}
	if e = json.Unmarshal(b, &envelope); e != nil {
		t.Fatal(e)
	}
	if envelope.Schema != "PMM_SYNTHETIC_FIXTURE_ZLIB_V1" || envelope.DecodedBytes > 1<<20 {
		t.Fatal("fixture envelope")
	}
	zr, e := zlib.NewReader(bytes.NewReader(envelope.Content))
	if e != nil {
		t.Fatal(e)
	}
	raw, e := io.ReadAll(io.LimitReader(zr, (1<<20)+1))
	ce := zr.Close()
	if e != nil || ce != nil || len(raw) != envelope.DecodedBytes || digestTest(raw) != envelope.DecodedSha256 {
		t.Fatal("fixture integrity", e, ce)
	}
	var v []postVector
	if e = json.Unmarshal(raw, &v); e != nil {
		t.Fatal(e)
	}
	return v
}
func postCall(v postVector) (*PostProcessResult, error) {
	return PatchPostProcess(context.Background(), v.Header, v.Data, options(), v.Request)
}
func repin(v *postVector) {
	v.Request.HeaderSHA256 = digestTest(v.Header)
	v.Request.ExportSHA256 = digestTest(v.Data)
	v.Request.SchemaSHA256 = digestTest(v.Request.Schema)
}
func postReject(t testing.TB, v postVector, part string) {
	t.Helper()
	r, e := postCall(v)
	if e == nil || r != nil || !strings.Contains(e.Error(), part) {
		t.Fatalf("expected %q; result=%v err=%v", part, r != nil, e)
	}
}
func TestPostProcessIndependentVectors(t *testing.T) {
	for _, v := range postVectors(t) {
		t.Run(v.ID, func(t *testing.T) {
			r, e := postCall(v)
			if e != nil {
				t.Fatal(e)
			}
			if !bytes.Equal(r.Header, v.ExpectedHeader) || !bytes.Equal(r.ExportData, v.ExpectedData) {
				t.Fatal("not the separately authored expected bytes")
			}
			if r.Report.ParsedPrefixEnd != v.Positions.PrefixEnd || r.Report.Field != PostProcessField || r.Report.FunctionalParityVerified || !r.Report.ExternalSchemaRequired {
				t.Fatal(r.Report)
			}
			if r.Report.ExportRelativeOffset != v.Positions.Property-6 || r.Report.LogicalOffset != int64(len(v.Header)+v.Positions.Property) {
				t.Fatal("wrong coordinate system")
			}
			if len(r.Report.Edits) != 2 || r.Report.Edits[0].After != -6 || r.Report.Edits[1].After != 0 {
				t.Fatal("safe preload is NOT the serialized property replacement", r.Report)
			}
		})
	}
}
func TestPostProcessExactlyTwoFixedWidthEdits(t *testing.T) {
	for _, v := range postVectors(t) {
		r, e := postCall(v)
		if e != nil {
			t.Fatal(e)
		}
		if len(r.Header) != len(v.Header) || len(r.ExportData) != len(v.Data) {
			t.Fatal("resized")
		}
		for i, b := range v.Header {
			if (i < v.Positions.Preload || i >= v.Positions.Preload+4) && r.Header[i] != b {
				t.Fatal("header unrelated byte changed")
			}
		}
		for i, b := range v.Data {
			if (i < v.Positions.Property || i >= v.Positions.Property+4) && r.ExportData[i] != b {
				t.Fatal("payload unrelated byte changed")
			}
		}
		if r.Package.Summary.BulkDataStart != int64(len(v.Header)+len(v.Data)) {
			t.Fatal("moved bulk offset")
		}
	}
}
func TestPostProcessDoesNotReplaceOpaqueDecoy(t *testing.T) {
	v := postVectors(t)[6]
	r, e := postCall(v)
	if e != nil {
		t.Fatal(e)
	}
	old := []byte{0xfc, 0xff, 0xff, 0xff}
	if bytes.Count(v.Data, old) != 2 || bytes.Count(r.ExportData, old) != 1 || r.Report.OpaqueExportTailBytes == 0 {
		t.Fatal("decoy was used as authority or replaced")
	}
}
func TestPostProcessMandatoryPins(t *testing.T) {
	for _, key := range []string{"header", "export", "schema", "resultHeader", "resultExport"} {
		for _, pin := range []string{"", strings.Repeat("0", 64), strings.Repeat("A", 64), strings.Repeat("0", 1000)} {
			v := postVectors(t)[0]
			switch key {
			case "header":
				v.Request.HeaderSHA256 = pin
			case "export":
				v.Request.ExportSHA256 = pin
			case "schema":
				v.Request.SchemaSHA256 = pin
			case "resultHeader":
				v.Request.ResultHeaderSHA256 = pin
			case "resultExport":
				v.Request.ResultExportSHA256 = pin
			}
			r, e := postCall(v)
			if e == nil || r != nil {
				t.Fatal(key, "accepted missing/incorrect/noncanonical pin")
			}
		}
	}
}
func TestPostProcessOffsetIsCheckedNotTrusted(t *testing.T) {
	for _, off := range []int{-1, 0, 114, 119, 121, 1000000000} {
		v := postVectors(t)[0]
		v.Request.ExpectedSerializedOffset = off
		postReject(t, v, "offset")
	}
	v := postVectors(t)[0]
	put32(v.Data, 120, -6)
	repin(&v)
	postReject(t, v, "prior reference")
}
func TestPostProcessExportIdentityAndClass(t *testing.T) {
	for _, mode := range []string{"index", "name", "class", "outer", "cdo", "tagged"} {
		v := postVectors(t)[0]
		at := v.Positions.Exports[1]
		switch mode {
		case "index":
			v.Request.ExportIndex = 99
		case "name":
			v.Request.ExportObject = "NotTheObject"
		case "class":
			put32(v.Header, at, -6)
		case "outer":
			put32(v.Header, at+12, 1)
		case "cdo":
			put32(v.Header, at+24, 0x11)
		case "tagged":
			at = v.Positions.Fields["flags"]
			put32(v.Header, at, int32(binary.LittleEndian.Uint32(v.Header[at:])&^0x2000))
		}
		repin(&v)
		r, e := postCall(v)
		if e == nil || r != nil {
			t.Fatal(mode)
		}
	}
}
func TestPostProcessFullImportIdentity(t *testing.T) {
	for _, mode := range []string{"short", "classPackage", "className", "safe", "same", "optional", "namespace"} {
		v := postVectors(t)[0]
		switch mode {
		case "short":
			v.Request.Stale.Path = "ABP_Gura_C"
		case "classPackage":
			v.Request.Stale.ClassPackage = "/Script/Wrong"
		case "className":
			v.Request.Stale.ClassName = "Class"
		case "safe":
			v.Request.Safe.Path = "/Game/Synthetic/Other.Body"
		case "same":
			v.Request.Safe = v.Request.Stale
		case "optional":
			put32(v.Header, v.Positions.Imports[3]+28, 1)
		case "namespace":
			put32(v.Header, v.Positions.Imports[3]+16, -5)
		}
		repin(&v)
		r, e := postCall(v)
		if e == nil || r != nil {
			t.Fatal(mode)
		}
	}
}
func TestPostProcessDuplicateImportIdentity(t *testing.T) {
	v := postVectors(t)[0]
	copy(v.Header[v.Positions.Imports[5]:v.Positions.Imports[5]+32], v.Header[v.Positions.Imports[3]:v.Positions.Imports[3]+32])
	repin(&v)
	postReject(t, v, "ambiguous")
}
func TestPostProcessPreloadOwnership(t *testing.T) {
	for _, mode := range []string{"duplicate", "wrongRow", "wrongGroup", "unowned", "shared"} {
		v := postVectors(t)[0]
		switch mode {
		case "duplicate":
			put32(v.Header, v.Positions.Preload-4, -4)
		case "wrongRow":
			v.Request.PreloadIndex = 0
		case "wrongGroup":
			v.Request.DependencyGroup = 0
		case "unowned":
			put32(v.Header, v.Positions.Exports[1]+76, -1)
			put32(v.Header, v.Positions.Exports[1]+84, 0)
		case "shared":
			put32(v.Header, v.Positions.Exports[0]+76, 1)
		}
		repin(&v)
		postReject(t, v, "preload")
	}
}
func TestPostProcessStrictSchema(t *testing.T) {
	for _, mode := range []string{"duplicate", "escapedDuplicate", "null", "unknown", "caseAlias", "trailing", "wrongProfile", "wrongClass", "duplicateField", "variable", "wrongFieldType", "badName", "malformed", "oversize", "empty", "invalidUTF8"} {
		v := postVectors(t)[0]
		var s fixedSchema
		json.Unmarshal(v.Request.Schema, &s)
		switch mode {
		case "duplicate":
			v.Request.Schema = []byte(`{"schema":"a","schema":"b"}`)
		case "escapedDuplicate":
			v.Request.Schema = []byte(`{"schema":"a","\u0073chema":"b"}`)
		case "null":
			v.Request.Schema = []byte(`null`)
		case "unknown":
			v.Request.Schema = []byte(`{"skipBytes":120}`)
		case "caseAlias":
			v.Request.Schema = []byte(`{"Schema":"a"}`)
		case "trailing":
			v.Request.Schema = append(v.Request.Schema, []byte(`{}`)...)
		case "malformed":
			v.Request.Schema = []byte(`{"schema":`)
		case "oversize":
			v.Request.Schema = bytes.Repeat([]byte{' '}, MaxSchemaBytes+1)
		case "invalidUTF8":
			v.Request.Schema = []byte{0xff}
		default:
			switch mode {
			case "wrongProfile":
				s.Profile = "auto"
			case "wrongClass":
				s.ClassPath = "/Script/Engine.Actor"
			case "duplicateField":
				s.Fields[0].Name = s.Fields[1].Name
			case "variable":
				s.Fields[0].Type = "StructProperty"
			case "wrongFieldType":
				s.Fields[len(s.Fields)-1].Type = "IntProperty"
			case "badName":
				s.Fields[0].Name = "a/b"
			case "empty":
				s.Fields = nil
			}
			v.Request.Schema, _ = json.Marshal(s)
		}
		repin(&v)
		r, e := postCall(v)
		if e == nil || r != nil {
			t.Fatal(mode)
		}
	}
}
func TestPostProcessTruncations(t *testing.T) {
	v := postVectors(t)[0]
	for n := 0; n < len(v.Data); n++ {
		w := v
		w.Data = v.Data[:n]
		repin(&w)
		r, e := postCall(w)
		if e == nil || r != nil {
			t.Fatal("accepted truncated .uexp", n)
		}
	}
	for n := 0; n < len(v.Header); n++ {
		w := v
		w.Header = v.Header[:n]
		repin(&w)
		r, e := postCall(w)
		if e == nil || r != nil {
			t.Fatal("accepted truncated .uasset", n)
		}
	}
}
func TestPostProcessNoAliasOrMutation(t *testing.T) {
	v := postVectors(t)[0]
	h, x := bytes.Clone(v.Header), bytes.Clone(v.Data)
	r, e := postCall(v)
	if e != nil {
		t.Fatal(e)
	}
	if !bytes.Equal(v.Header, h) || !bytes.Equal(v.Data, x) {
		t.Fatal("mutated input")
	}
	r.Header[0] = 0
	r.ExportData[0] = 0
	r.Package.Names[0].Text = "changed"
	if !bytes.Equal(v.Header, h) || !bytes.Equal(v.Data, x) {
		t.Fatal("output alias")
	}
	v.Request.ResultExportSHA256 = strings.Repeat("0", 64)
	postReject(t, v, "result SHA")
	if !bytes.Equal(v.Header, h) || !bytes.Equal(v.Data, x) {
		t.Fatal("failed call mutated input")
	}
}
func TestPostProcessRejectsReplay(t *testing.T) {
	v := postVectors(t)[0]
	r, e := postCall(v)
	if e != nil {
		t.Fatal(e)
	}
	v.Header, v.Data = r.Header, r.ExportData
	repin(&v)
	postReject(t, v, "prior reference")
}
func TestPostProcessLimitsAndCancellation(t *testing.T) {
	v := postVectors(t)[0]
	for _, lim := range []Limits{{HeaderBytes: 16}, {ExportBytes: 16}, {HeaderBytes: 65 << 20}} {
		o := options()
		o.Limits = lim
		r, e := PatchPostProcess(context.Background(), v.Header, v.Data, o, v.Request)
		if e == nil || r != nil {
			t.Fatal(lim)
		}
	}
	r, e := PatchPostProcess(nil, v.Header, v.Data, options(), v.Request)
	if e == nil || r != nil {
		t.Fatal("nil context")
	}
	r, e = PatchPostProcess(context.Background(), v.Header, nil, options(), v.Request)
	if e == nil || r != nil {
		t.Fatal("absent export data")
	}
	completed := false
	for n := 1; n < 5000; n++ {
		ctx := &countingContext{context.Background(), n}
		r, e = PatchPostProcess(ctx, v.Header, v.Data, options(), v.Request)
		if e == nil {
			completed = true
			break
		}
		if !errors.Is(e, context.Canceled) || r != nil {
			t.Fatalf("boundary %d result=%v err=%v", n, r != nil, e)
		}
	}
	if !completed {
		t.Fatal("no completion")
	}
}
func TestFixedPropertiesMaskWidths(t *testing.T) {
	v := postVectors(t)[0]
	p, e := Read(context.Background(), v.Header, v.Data, options())
	if e != nil {
		t.Fatal(e)
	}
	for _, n := range []int{1, 8, 9, 16, 17, 32, 33, 127, 128, 256, 1024} {
		t.Run(fmt.Sprint(n), func(t *testing.T) {
			s := &fixedSchema{}
			for i := 0; i < n; i++ {
				s.Fields = append(s.Fields, scalarField{fmt.Sprintf("Pad%d", i), "IntProperty"})
			}
			s.Fields[n-1] = scalarField{PostProcessField, "ClassProperty"}
			b := []byte{}
			for i := 0; i < n; {
				count := n - i
				if count > 127 {
					count = 127
				}
				bits := uint16(count<<9) | 128
				i += count
				if i == n {
					bits |= 256
				}
				b = binary.LittleEndian.AppendUint16(b, bits)
			}
			width := 1
			if n > 8 {
				width = 2
			}
			if n > 16 {
				width = ((n + 31) / 32) * 4
			}
			mask := make([]byte, width)
			for j := 0; j < n-1; j++ {
				mask[j/8] |= 1 << uint(j%8)
			}
			b = append(b, mask...)
			target := len(b)
			b = binary.LittleEndian.AppendUint32(b, 0xfffffffc)
			ex := p.Exports[1]
			ex.SerialOffset = int64(len(v.Header))
			ex.SerialSize = int64(len(b))
			r, e := readFixedProperties(context.Background(), p, b, ex, s)
			if e != nil {
				t.Fatal(e)
			}
			if len(r.Fields) != n || r.Target.Offset != target || r.End != len(b) {
				t.Fatal(r)
			}
			for _, f := range r.Fields[:n-1] {
				if !f.Zero || f.Size != 0 {
					t.Fatal(f)
				}
			}
		})
	}
}
func TestFixedPropertiesInvalidFragmentsAndValues(t *testing.T) {
	v := postVectors(t)[0]
	p, _ := Read(context.Background(), v.Header, v.Data, options())
	s := &fixedSchema{Fields: []scalarField{{PostProcessField, "ClassProperty"}}}
	for _, b := range [][]byte{nil, {0}, {0, 0}, {127, 3}, {0, 5}, {128, 1}, {128, 3, 255}, {0, 3, 0, 0, 0, 128}, {128, 3, 1}} {
		ex := p.Exports[1]
		ex.SerialOffset = int64(len(v.Header))
		ex.SerialSize = int64(len(b))
		r, e := readFixedProperties(context.Background(), p, b, ex, s)
		if e == nil || r != nil {
			t.Fatalf("accepted %x", b)
		}
	}
}
func TestPostProcessExportFixtures(t *testing.T) {
	out := os.Getenv("PMM_POSTPROCESS_FIXTURE_OUTPUT")
	if out == "" {
		t.Skip("synthetic packet export is opt-in")
	}
	if e := os.Mkdir(out, 0700); e != nil {
		t.Fatal(e)
	}
	for _, v := range postVectors(t) {
		r, e := postCall(v)
		if e != nil {
			t.Fatal(e)
		}
		packet := struct {
			Input                    postVector
			ResultHeader, ResultData []byte
			Report                   PostProcessReport
		}{v, r.Header, r.ExportData, r.Report}
		b, e := json.MarshalIndent(packet, "", "  ")
		if e != nil {
			t.Fatal(e)
		}
		if e = os.WriteFile(filepath.Join(out, v.ID+".json"), append(b, '\n'), 0600); e != nil {
			t.Fatal(e)
		}
	}
}
func FuzzFixedPostProcess(f *testing.F) {
	v := postVectors(f)[0]
	f.Add(v.Data)
	f.Add([]byte{})
	f.Add([]byte{0, 3, 0xfc, 0xff, 0xff, 0xff})
	f.Fuzz(func(t *testing.T, b []byte) {
		if len(b) > 8192 {
			return
		}
		w := v
		w.Header = bytes.Clone(v.Header)
		w.Data = bytes.Clone(b)
		repin(&w)
		r, e := postCall(w)
		if e != nil && r != nil {
			t.Fatal("partial result")
		}
		if e == nil && (!bytes.Equal(r.Header, v.ExpectedHeader) || !bytes.Equal(r.ExportData, v.ExpectedData)) {
			t.Fatal("pins or edit invariant")
		}
	})
}
