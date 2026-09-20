package corer1

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func put(t *testing.T, root, path string, data []byte) File {
	t.Helper()
	p := filepath.Join(root, filepath.FromSlash(path))
	if e := os.MkdirAll(filepath.Dir(p), 0700); e != nil {
		t.Fatal(e)
	}
	if e := os.WriteFile(p, data, 0600); e != nil {
		t.Fatal(e)
	}
	return File{path, hash(data), int64(len(data))}
}
func captureFixture(t *testing.T, withSchema bool) (CaptureRequest, map[string][]byte) {
	t.Helper()
	q, r, d, c := fixture()
	base := t.TempDir()
	roots := CaptureRoots{filepath.Join(base, "donor"), filepath.Join(base, "current"), filepath.Join(base, "archives"), filepath.Join(base, "schemas")}
	for _, p := range []string{roots.Donor, roots.Current, roots.Archives, roots.Schemas} {
		if e := os.Mkdir(p, 0700); e != nil {
			t.Fatal(e)
		}
	}
	donor := put(t, roots.Archives, "donor.pak", []byte("SYNTHETIC DONOR ARCHIVE - NOT A PAK"))
	current := put(t, roots.Archives, "current.pak", []byte("SYNTHETIC CURRENT ARCHIVE - NOT A PAK"))
	set := pinned(ProviderSet{"PMM_R1_PROVIDER_SET_V1", r.TargetBuild, []File{current}})
	r.Signatures[0].SHA256 = donor.SHA256
	d.ProviderSHA256 = donor.SHA256
	c.ProviderSHA256 = set.SHA256
	expected := map[string][]byte{}
	for _, x := range []struct {
		role, root string
		inv        *Inventory
	}{{"donor", roots.Donor, &d}, {"current", roots.Current, &c}} {
		for i, f := range x.inv.Files {
			b := []byte("SYNTHETIC ASSET BYTES " + f.Path)
			x.inv.Files[i] = put(t, x.root, f.Path, b)
			expected[x.role+":"+f.Path] = b
		}
	}
	q.Recipe = pinned(r)
	q.DonorInventory = pinned(d)
	q.CurrentInventory = pinned(c)
	out := CaptureRequest{Plan: q, Roots: roots, DonorArchive: donor, CurrentProviderSet: set}
	if withSchema {
		s := claimFor(q, r, d, c)
		lay := pinned(scalarLayout{"PMM_FIXED_UNVERSIONED_SCHEMA_V1", s.Profile, s.ClassPath, []scalarLayoutField{{"Prefix", "IntProperty", ""}, {"PostProcessAnimBlueprint", "ClassProperty", ""}}})
		s.LayoutSHA256 = lay.SHA256
		rev := pinned(SchemaReview{"PMM_R1_SCHEMA_REVIEW_V1", s.RecipeSHA256, s.DonorHeaderSHA256, s.DonorExportSHA256, s.CurrentProviderSHA256, s.LayoutSHA256, s.Profile, s.ClassPath, s.Origin, s.Revision, "synthetic reviewer", "fixture-only, NOT semantic validation", []string{"Artificial layout; not a game schema"}})
		s.ReviewRecordSHA256 = rev.SHA256
		claim := pinned(s)
		out.Plan.SchemaClaims = []PinnedJSON{claim}
		lf := put(t, roots.Schemas, "layout.json", lay.Data)
		rf := put(t, roots.Schemas, "review.json", rev.Data)
		out.Dossiers = []DossierFiles{{claim.SHA256, lf, rf}}
		expected["schema:layout.json"] = lay.Data
		expected["schema:review.json"] = rev.Data
	}
	return out, expected
}
func mustCapture(t *testing.T, q CaptureRequest) *CapturedInputs {
	t.Helper()
	v, e := CaptureCore(context.Background(), q)
	if e != nil {
		t.Fatal(e)
	}
	if v == nil {
		t.Fatal("nil success")
	}
	return v
}
func captureError(t *testing.T, q CaptureRequest) {
	t.Helper()
	v, e := CaptureCore(context.Background(), q)
	if e == nil || v != nil {
		t.Fatalf("expected nil,error got %v %v", v, e)
	}
}
func report(t *testing.T, c *CapturedInputs) CaptureReport {
	t.Helper()
	var r CaptureReport
	if e := json.Unmarshal(c.ReportJSON(), &r); e != nil {
		t.Fatal(e)
	}
	return r
}

func TestCapturePinnedBytesAndAllDeclarations(t *testing.T) {
	q, want := captureFixture(t, false)
	got := mustCapture(t, q)
	r := report(t, got)
	if !r.ListedAssetBytesVerified || !r.ListedArchiveBytesVerified || len(r.Files) != len(want)+2 {
		t.Fatal("wrong scope")
	}
	var total int64
	for key, b := range want {
		parts := strings.SplitN(key, ":", 2)
		actual, ok := got.Bytes(parts[0], parts[1])
		if !ok || !bytes.Equal(actual, b) {
			t.Fatal(key)
		}
		total += int64(len(b))
	}
	if total != r.SnapshotBytes {
		t.Fatal("wrong byte budget")
	}
	if _, ok := got.Bytes("archive", "donor.pak"); ok {
		t.Fatal("archive should not be retained")
	}
}
func TestCaptureNeverClaimsMembershipOrReadiness(t *testing.T) {
	q, _ := captureFixture(t, true)
	got := mustCapture(t, q)
	r := report(t, got)
	if r.TransformReady || r.BuildReady || r.Validated || r.Installed || r.BuildAuthenticated || r.AtomicFilesystemSnapshot || r.CompleteFilesystemInventory || r.ExtractionMembershipVerified {
		t.Fatal("unproved claim")
	}
	var p Plan
	json.Unmarshal(got.PlanJSON(), &p)
	if p.InputBytesVerified || p.TransformReady || p.Status != "PLAN_VALID" {
		t.Fatal("planner modified")
	}
	if len(r.Dossiers) != 1 || !r.Dossiers[0].BytesVerified || r.Dossiers[0].LayoutSemanticsVerified || r.Dossiers[0].ReviewerAuthenticated {
		t.Fatal("false schema proof")
	}
}
func TestCaptureSnapshotNoAliasAndRemainsStable(t *testing.T) {
	q, want := captureFixture(t, true)
	got := mustCapture(t, q)
	before := got.ReportJSON()
	b, _ := got.Bytes("donor", "D/Body.uasset")
	b[0] ^= 255
	before[0] = '!'
	put(t, q.Roots.Donor, "D/Body.uasset", []byte("changed after capture"))
	b, _ = got.Bytes("donor", "D/Body.uasset")
	if !bytes.Equal(b, want["donor:D/Body.uasset"]) {
		t.Fatal("snapshot aliases source")
	}
	if got.ReportJSON()[0] != '{' {
		t.Fatal("report alias")
	}
	p := got.PlanJSON()
	p[0] = '!'
	if got.PlanJSON()[0] != '{' {
		t.Fatal("plan alias")
	}
}
func TestCaptureAssetHashMismatch(t *testing.T) {
	q, _ := captureFixture(t, false)
	p := filepath.Join(q.Roots.Donor, "D/Body.uasset")
	b, _ := os.ReadFile(p)
	b[0] ^= 1
	os.WriteFile(p, b, 0600)
	captureError(t, q)
}
func TestCaptureAssetSizeAndMissing(t *testing.T) {
	for _, mode := range []string{"short", "long", "missing", "directory"} {
		t.Run(mode, func(t *testing.T) {
			q, _ := captureFixture(t, false)
			p := filepath.Join(q.Roots.Donor, "D/Body.uasset")
			switch mode {
			case "short":
				os.WriteFile(p, nil, 0600)
			case "long":
				f, _ := os.OpenFile(p, os.O_APPEND|os.O_WRONLY, 0600)
				f.WriteString("extra")
				f.Close()
			case "missing":
				os.Remove(p)
			case "directory":
				os.Remove(p)
				os.Mkdir(p, 0700)
			}
			captureError(t, q)
		})
	}
}
func TestCaptureProviderSetAndArchiveBindings(t *testing.T) {
	for _, mode := range []string{"doc-pin", "archive-pin", "archive-size", "wrong-build", "empty", "duplicate", "unknown-key"} {
		t.Run(mode, func(t *testing.T) {
			q, _ := captureFixture(t, false)
			var set ProviderSet
			json.Unmarshal(q.CurrentProviderSet.Data, &set)
			switch mode {
			case "doc-pin":
				q.CurrentProviderSet.SHA256 = hash([]byte("wrong"))
			case "archive-pin":
				put(t, q.Roots.Archives, "donor.pak", []byte("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"))
			case "archive-size":
				q.DonorArchive.SizeBytes++
			case "wrong-build":
				set.Build = "OTHER"
			case "empty":
				set.Providers = []File{}
			case "duplicate":
				set.Providers = append(set.Providers, set.Providers[0])
			case "unknown-key":
			}
			if mode == "wrong-build" || mode == "empty" || mode == "duplicate" || mode == "unknown-key" {
				q.CurrentProviderSet = pinned(set)
				if mode == "unknown-key" {
					q.CurrentProviderSet = repin(append(q.CurrentProviderSet.Data[:len(q.CurrentProviderSet.Data)-1], []byte(`,"approved":true}`)...))
				}
				var c Inventory
				json.Unmarshal(q.Plan.CurrentInventory.Data, &c)
				c.ProviderSHA256 = q.CurrentProviderSet.SHA256
				q.Plan.CurrentInventory = pinned(c)
			}
			captureError(t, q)
		})
	}
}
func TestCaptureLimitsBeforeOpeningRoots(t *testing.T) {
	for _, limits := range []CaptureLimits{{FileBytes: 1}, {SnapshotBytes: 1}, {ArchiveBytes: 1}, {TotalArchiveBytes: 1}, {FileBytes: -1}, {FileBytes: (256 << 20) + 1}, {SnapshotBytes: (512 << 20) + 1}, {Providers: 65}} {
		q, _ := captureFixture(t, false)
		q.Limits = limits
		q.Roots = CaptureRoots{"missing", "missing", "missing", "missing"}
		_, e := CaptureCore(context.Background(), q)
		var typed *Error
		if e == nil || !errors.As(e, &typed) || typed.Code != "LIMIT" {
			t.Fatalf("want pre-I/O limit, got %v", e)
		}
	}
}
func TestCaptureDeterminismAndNoRequestMutation(t *testing.T) {
	q, _ := captureFixture(t, true)
	before, _ := json.Marshal(q)
	a := mustCapture(t, q)
	b := mustCapture(t, q)
	after, _ := json.Marshal(q)
	if !bytes.Equal(before, after) || !bytes.Equal(a.ReportJSON(), b.ReportJSON()) || !bytes.Equal(a.PlanJSON(), b.PlanJSON()) {
		t.Fatal("nondeterministic or mutated")
	}
}
func TestCaptureNilAndCancelledContext(t *testing.T) {
	q, _ := captureFixture(t, false)
	if x, e := CaptureCore(nil, q); x != nil || e == nil {
		t.Fatal("nil")
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if x, e := CaptureCore(ctx, q); x != nil || !errors.Is(e, context.Canceled) {
		t.Fatal("cancel")
	}
}
func TestCaptureDossierCountAndReferences(t *testing.T) {
	for _, mode := range []string{"missing", "extra", "claim", "layout", "review", "path"} {
		t.Run(mode, func(t *testing.T) {
			q, _ := captureFixture(t, true)
			switch mode {
			case "missing":
				q.Dossiers = nil
			case "extra":
				q.Dossiers = append(q.Dossiers, q.Dossiers[0])
			case "claim":
				q.Dossiers[0].ClaimSHA256 = hash([]byte("wrong"))
			case "layout":
				q.Dossiers[0].Layout.SHA256 = hash([]byte("wrong"))
			case "review":
				q.Dossiers[0].Review.SHA256 = hash([]byte("wrong"))
			case "path":
				q.Dossiers[0].Layout.Path = "../layout.json"
			}
			captureError(t, q)
		})
	}
}
func repinDossier(t *testing.T, q *CaptureRequest, layout, review []byte) {
	t.Helper()
	var claim SchemaClaim
	json.Unmarshal(q.Plan.SchemaClaims[0].Data, &claim)
	if layout != nil {
		q.Dossiers[0].Layout = put(t, q.Roots.Schemas, "layout.json", layout)
		claim.LayoutSHA256 = hash(layout)
	}
	if review != nil {
		q.Dossiers[0].Review = put(t, q.Roots.Schemas, "review.json", review)
		claim.ReviewRecordSHA256 = hash(review)
	}
	q.Plan.SchemaClaims[0] = pinned(claim)
	q.Dossiers[0].ClaimSHA256 = q.Plan.SchemaClaims[0].SHA256
}
func TestCaptureDossierStrictLayout(t *testing.T) {
	for _, mode := range []string{"array", "duplicate-field", "no-target", "wrong-class", "unknown-key", "duplicate-key", "case-key", "null"} {
		t.Run(mode, func(t *testing.T) {
			q, _ := captureFixture(t, true)
			b, _ := os.ReadFile(filepath.Join(q.Roots.Schemas, "layout.json"))
			var s scalarLayout
			json.Unmarshal(b, &s)
			switch mode {
			case "array":
				s.Fields[0].Type = "ArrayProperty"
			case "duplicate-field":
				s.Fields = append(s.Fields, s.Fields[0])
			case "no-target":
				s.Fields = s.Fields[:1]
			case "wrong-class":
				s.ClassPath = "/Script/Other.Class"
			}
			b = pinned(s).Data
			switch mode {
			case "unknown-key":
				b = append(b[:len(b)-1], []byte(`,"approved":true}`)...)
			case "duplicate-key":
				b = append(b[:len(b)-1], []byte(`,"schema":"PMM_FIXED_UNVERSIONED_SCHEMA_V1"}`)...)
			case "case-key":
				b = bytes.Replace(b, []byte(`"fields"`), []byte(`"Fields"`), 1)
			case "null":
				b = bytes.Replace(b, []byte(`"IntProperty"`), []byte("null"), 1)
			}
			repinDossier(t, &q, b, nil)
			captureError(t, q)
		})
	}
}
func TestCaptureDossierV2ScalarArray(t *testing.T) {
	q, _ := captureFixture(t, true)
	layout := scalarLayout{"PMM_FIXED_UNVERSIONED_SCHEMA_V2", "cooked-ue4-522-ue5-1008", "/Script/Engine.SkeletalMesh", []scalarLayoutField{{"ScalarValues", "ArrayProperty", "IntProperty"}, {"PostProcessAnimBlueprint", "ClassProperty", ""}}}
	layoutBytes := pinned(layout).Data
	var review SchemaReview
	reviewBytes, e := os.ReadFile(filepath.Join(q.Roots.Schemas, "review.json"))
	if e != nil {
		t.Fatal(e)
	}
	if e = json.Unmarshal(reviewBytes, &review); e != nil {
		t.Fatal(e)
	}
	review.LayoutSHA256 = hash(layoutBytes)
	repinDossier(t, &q, layoutBytes, pinned(review).Data)
	got := mustCapture(t, q)
	report := report(t, got)
	if len(report.Dossiers) != 1 || !report.Dossiers[0].BytesVerified || !report.Dossiers[0].BindingsChecked || report.Dossiers[0].FieldCount != 2 || report.Dossiers[0].LayoutSemanticsVerified {
		t.Fatal(report.Dossiers)
	}
}
func TestCaptureDossierV2RejectsInvalidArrayShape(t *testing.T) {
	for _, inner := range []string{"", "StructProperty", "ArrayProperty"} {
		q, _ := captureFixture(t, true)
		layout := scalarLayout{"PMM_FIXED_UNVERSIONED_SCHEMA_V2", "cooked-ue4-522-ue5-1008", "/Script/Engine.SkeletalMesh", []scalarLayoutField{{"Values", "ArrayProperty", inner}, {"PostProcessAnimBlueprint", "ClassProperty", ""}}}
		layoutBytes := pinned(layout).Data
		var review SchemaReview
		reviewBytes, _ := os.ReadFile(filepath.Join(q.Roots.Schemas, "review.json"))
		json.Unmarshal(reviewBytes, &review)
		review.LayoutSHA256 = hash(layoutBytes)
		repinDossier(t, &q, layoutBytes, pinned(review).Data)
		captureError(t, q)
	}
}
func TestCaptureDossierReviewBindings(t *testing.T) {
	for _, mode := range []string{"recipe", "provider", "layout", "revision", "reviewer", "unknown", "findings"} {
		t.Run(mode, func(t *testing.T) {
			q, _ := captureFixture(t, true)
			b, _ := os.ReadFile(filepath.Join(q.Roots.Schemas, "review.json"))
			var r SchemaReview
			json.Unmarshal(b, &r)
			switch mode {
			case "recipe":
				r.RecipeSHA256 = hash([]byte("wrong"))
			case "provider":
				r.CurrentProviderSHA256 = hash([]byte("wrong"))
			case "layout":
				r.LayoutSHA256 = hash([]byte("wrong"))
			case "revision":
				r.Revision = "other"
			case "reviewer":
				r.Reviewer = ""
			case "findings":
				r.Findings = []string{}
			}
			b = pinned(r).Data
			if mode == "unknown" {
				b = append(b[:len(b)-1], []byte(`,"approved":true}`)...)
			}
			repinDossier(t, &q, nil, b)
			captureError(t, q)
		})
	}
}
func TestCaptureDossierRealBytesNotClaimAlone(t *testing.T) {
	q, _ := captureFixture(t, true)
	put(t, q.Roots.Schemas, "review.json", []byte("not the reviewed bytes"))
	captureError(t, q)
}
func TestCaptureExtraUnlistedFileIsNotProvenAbsent(t *testing.T) {
	q, _ := captureFixture(t, false)
	put(t, q.Roots.Donor, "not-in-inventory.bin", []byte("EXTRA"))
	got := mustCapture(t, q)
	if _, ok := got.Bytes("donor", "not-in-inventory.bin"); ok || report(t, got).CompleteFilesystemInventory {
		t.Fatal("not a recursive inventory")
	}
}
func TestCaptureUnsafeArchivePaths(t *testing.T) {
	for _, path := range []string{"../donor.pak", "C:/donor.pak", "dir\\donor.pak", "NUL.pak", "dir/a:stream.pak"} {
		q, _ := captureFixture(t, false)
		q.DonorArchive.Path = path
		captureError(t, q)
	}
}
func TestCaptureRootPathsAreNotNormalized(t *testing.T) {
	q, _ := captureFixture(t, false)
	q.Roots.Donor += "/../donor"
	captureError(t, q)
}

type failReader struct{}

func (failReader) Read([]byte) (int, error) { return 0, errors.New("synthetic read failure") }

type cancelReader struct {
	r      io.Reader
	cancel context.CancelFunc
}

func (r cancelReader) Read(b []byte) (int, error) { n, e := r.r.Read(b); r.cancel(); return n, e }
func TestCaptureExactReaderRejectsIncompleteAndExtra(t *testing.T) {
	for _, r := range []io.Reader{bytes.NewReader([]byte("ab")), bytes.NewReader([]byte("abcd")), failReader{}} {
		if b, _, e := exactRead(context.Background(), r, 3, true); e == nil || b != nil {
			t.Fatal("accepted partial")
		}
	}
	b, h, e := exactRead(context.Background(), bytes.NewReader(nil), 0, true)
	if e != nil || len(b) != 0 || h != hash(nil) {
		t.Fatal("empty")
	}
}
func TestCaptureExactReaderCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	b, _, e := exactRead(ctx, cancelReader{bytes.NewReader(make([]byte, 100000)), cancel}, 100000, true)
	if b != nil || !errors.Is(e, context.Canceled) {
		t.Fatal("partial cancelled")
	}
}
func TestCaptureExactReadLargeBlocks(t *testing.T) {
	data := bytes.Repeat([]byte{1, 2, 0, 255}, 300000)
	b, h, e := exactRead(context.Background(), bytes.NewReader(data), int64(len(data)), true)
	if e != nil || !bytes.Equal(b, data) || h != hash(data) {
		t.Fatal(e)
	}
	b, h, e = exactRead(context.Background(), bytes.NewReader(data), int64(len(data)), false)
	if e != nil || b != nil || h != hash(data) {
		t.Fatal(e)
	}
}
func TestCaptureClosedHandleError(t *testing.T) {
	q, _ := captureFixture(t, false)
	r, e := openRoot(q.Roots.Donor)
	if e != nil {
		t.Fatal(e)
	}
	r.Close()
	if b, e := captureFile(context.Background(), r, File{"D/Body.uasset", hash(nil), 0}, true, 1, nil); b != nil || e == nil {
		t.Fatal("closed handle")
	}
}

// Synthetic export only; this harness never captures user/game data implicitly.
func TestCaptureFixtureExport(t *testing.T) {
	out := os.Getenv("PMM_R1_CAPTURE_OUTPUT")
	if out == "" {
		t.Skip("no synthetic capture export requested")
	}
	if _, e := os.Stat(out); !os.IsNotExist(e) {
		t.Fatal("output must be new")
	}
	if e := os.MkdirAll(out, 0700); e != nil {
		t.Fatal(e)
	}
	for _, id := range []string{"without-schema", "with-schema"} {
		q, _ := captureFixture(t, id == "with-schema")
		got := mustCapture(t, q)
		dest := filepath.Join(out, id)
		os.Mkdir(dest, 0700)
		for _, x := range []struct{ src, part string }{{q.Roots.Donor, "donor"}, {q.Roots.Current, "current"}, {q.Roots.Archives, "archives"}, {q.Roots.Schemas, "schemas"}} {
			e := filepath.WalkDir(x.src, func(p string, d os.DirEntry, e error) error {
				if e != nil {
					return e
				}
				if d.IsDir() {
					return nil
				}
				rel, _ := filepath.Rel(x.src, p)
				b, e := os.ReadFile(p)
				if e != nil {
					return e
				}
				put(t, filepath.Join(dest, x.part), filepath.ToSlash(rel), b)
				return nil
			})
			if e != nil {
				t.Fatal(e)
			}
		}
		for path, b := range map[string][]byte{"report.json": got.ReportJSON(), "plan.json": got.PlanJSON(), "recipe.json": q.Plan.Recipe.Data, "donor.json": q.Plan.DonorInventory.Data, "current.json": q.Plan.CurrentInventory.Data, "provider-set.json": q.CurrentProviderSet.Data} {
			put(t, dest, path, b)
		}
		if len(q.Plan.SchemaClaims) > 0 {
			put(t, dest, "claim.json", q.Plan.SchemaClaims[0].Data)
		}
	}
}
func FuzzDossierDocuments(f *testing.F) {
	layout := pinned(scalarLayout{"PMM_FIXED_UNVERSIONED_SCHEMA_V1", "cooked-ue4-522-ue5-1008", "/Script/Engine.SkeletalMesh", []scalarLayoutField{{"PostProcessAnimBlueprint", "ClassProperty", ""}}})
	s := SchemaClaim{Schema: "PMM_R1_SCHEMA_PROVENANCE_V1", RecipeSHA256: hash([]byte("recipe")), DonorUasset: "D/Body.uasset", DonorHeaderSHA256: hash([]byte("header")), DonorExportSHA256: hash([]byte("export")), CurrentProviderSHA256: hash([]byte("provider")), Profile: "cooked-ue4-522-ue5-1008", ClassPath: "/Script/Engine.SkeletalMesh", LayoutSHA256: layout.SHA256, Origin: "synthetic", Revision: "1"}
	review := pinned(SchemaReview{"PMM_R1_SCHEMA_REVIEW_V1", s.RecipeSHA256, s.DonorHeaderSHA256, s.DonorExportSHA256, s.CurrentProviderSHA256, s.LayoutSHA256, s.Profile, s.ClassPath, s.Origin, s.Revision, "fixture", "fixture", []string{"not game evidence"}})
	f.Add(layout.Data, review.Data)
	f.Add([]byte(`{}`), []byte(`{}`))
	f.Fuzz(func(t *testing.T, b, r []byte) {
		if len(b) > 16384 || len(r) > 16384 {
			t.Skip()
		}
		claim := s
		claim.LayoutSHA256 = hash(b)
		claim.ReviewRecordSHA256 = hash(r)
		cp := pinned(claim)
		rec := ClaimRecord{cp.SHA256, claim, "DECLARED_UNVERIFIED"}
		files := DossierFiles{cp.SHA256, File{"layout.json", claim.LayoutSHA256, int64(len(b))}, File{"review.json", claim.ReviewRecordSHA256, int64(len(r))}}
		result, e := verifyDossier(context.Background(), rec, files, b, r)
		if e != nil && !reflect.DeepEqual(result, DossierResult{}) {
			t.Fatal("partial dossier success")
		}
		if e == nil && (result.LayoutSemanticsVerified || result.ReviewerAuthenticated || !result.BytesVerified || !result.BindingsChecked) {
			t.Fatal("false readiness")
		}
	})
}
func TestCaptureCloseErrorsReported(t *testing.T) {
	f, e := os.CreateTemp(t.TempDir(), "fixture")
	if e != nil {
		t.Fatal(e)
	}
	f.Close()
	if closeChain([]*os.File{f}) == nil {
		t.Fatal("close error hidden")
	}
}
