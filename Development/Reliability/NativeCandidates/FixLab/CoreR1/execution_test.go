package corer1

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"

	pakv11 "pmm.local/fixlab/pakv11"
)

//go:embed testdata/execution-vectors.json
var executionVectors []byte

type executionVector struct {
	ID                                                                                  string `json:"id"`
	Header, Data, NamesHeader, AfterNamesHeader, FinalPostHeader, FinalPostData, Layout []byte
	Slot, SourceSlot                                                                    int
	Post                                                                                ExecutionPostProcess
}

func executorVectors(t testing.TB) []executionVector {
	t.Helper()
	var v struct {
		Schema   string
		Fixtures []executionVector
	}
	if e := json.Unmarshal(executionVectors, &v); e != nil || v.Schema != "PMM_R1_EXECUTION_SYNTHETIC_V1" || len(v.Fixtures) != 3 {
		t.Fatalf("fixture: %v", e)
	}
	return v.Fixtures
}
func executionPlan(t testing.TB, q ExecutionRequest) ExecutionPlan {
	t.Helper()
	var p ExecutionPlan
	if e := json.Unmarshal(q.Plan.Data, &p); e != nil {
		t.Fatal(e)
	}
	return p
}
func updateExecutionPlan(q *ExecutionRequest, p ExecutionPlan) {
	q.Plan = pinned(p)
	q.Review = pinned(ExecutionReview{"PMM_R1_EXECUTION_REVIEW_V1", q.Plan.SHA256, "fixture-author", "own artificial fixture", "1", "Python expected edits, not a game review", []string{"Not a real SkeletalMesh layout; no production authorization"}})
}
func executorFixture(t *testing.T, id int) (CaptureRequest, *CapturedInputs, *MembershipEvidence, ExecutionRequest, map[string][]byte) {
	t.Helper()
	v := executorVectors(t)[id]
	q, _ := captureFixture(t, false)
	var r Recipe
	var d, c Inventory
	json.Unmarshal(q.Plan.Recipe.Data, &r)
	json.Unmarshal(q.Plan.DonorInventory.Data, &d)
	json.Unmarshal(q.Plan.CurrentInventory.Data, &c)
	r.Relocate[0].PostProcess = &PostProcess{"ABP_Gura_C", "Body", []int64{int64(v.Post.ExpectedSerializedOffset)}}
	for _, group := range []struct {
		inv  *Inventory
		root string
	}{{&d, q.Roots.Donor}, {&c, q.Roots.Current}} {
		for i, f := range group.inv.Files {
			b := v.Header
			if strings.HasSuffix(f.Path, ".uexp") {
				b = v.Data
			}
			if f.Path == "C/Names.uasset" {
				b = v.NamesHeader
			}
			group.inv.Files[i] = put(t, group.root, f.Path, b)
		}
	}
	q.Plan.Recipe = pinned(r)
	q.Plan.DonorInventory = pinned(d)
	q.Plan.CurrentInventory = pinned(c)
	providers := []File{}
	for _, s := range []struct {
		inv        Inventory
		root, name string
	}{{d, q.Roots.Donor, "donor.pak"}, {c, q.Roots.Current, "current.pak"}} {
		files := []pakv11.File{}
		for _, f := range s.inv.Files {
			b, e := os.ReadFile(filepath.Join(s.root, filepath.FromSlash(f.Path)))
			if e != nil {
				t.Fatal(e)
			}
			files = append(files, pakv11.File{Path: f.Path, Data: b})
		}
		archive, e := pakv11.Build(context.Background(), files, pakv11.Limits{})
		if e != nil {
			t.Fatal(e)
		}
		f := put(t, q.Roots.Archives, s.name, archive)
		if s.name == "donor.pak" {
			q.DonorArchive = f
		} else {
			providers = append(providers, f)
		}
	}
	rebindMembership(t, &q, providers)
	json.Unmarshal(q.Plan.Recipe.Data, &r)
	json.Unmarshal(q.Plan.DonorInventory.Data, &d)
	json.Unmarshal(q.Plan.CurrentInventory.Data, &c)
	claim := claimFor(q.Plan, r, d, c)
	claim.LayoutSHA256 = hash(v.Layout)
	review := pinned(SchemaReview{"PMM_R1_SCHEMA_REVIEW_V1", claim.RecipeSHA256, claim.DonorHeaderSHA256, claim.DonorExportSHA256, claim.CurrentProviderSHA256, claim.LayoutSHA256, claim.Profile, claim.ClassPath, claim.Origin, claim.Revision, "fixture-author", "own artificial layout", []string{"synthetic-only"}})
	claim.ReviewRecordSHA256 = review.SHA256
	pin := pinned(claim)
	q.Plan.SchemaClaims = []PinnedJSON{pin}
	q.Dossiers = []DossierFiles{{pin.SHA256, put(t, q.Roots.Schemas, "layout.json", v.Layout), put(t, q.Roots.Schemas, "review.json", review.Data)}}
	captured := mustCapture(t, q)
	member := mustMembership(t, captured, memberRequest(q))
	var plan Plan
	json.Unmarshal(captured.planJSON, &plan)
	p := ExecutionPlan{Schema: "PMM_R1_BOUNDED_EXECUTION_V1", Profile: ExecutionProfile, RecipeSHA256: q.Plan.Recipe.SHA256, PlanSHA256: hash(captured.planJSON), CaptureSHA256: hash(captured.reportJSON), MembershipSHA256: hash(member.reportJSON), UAssetProfile: "cooked-ue4-522-ue5-1008", Families: []ExecutionFamily{}, Outputs: []File{}}
	want := map[string][]byte{}
	for _, task := range plan.Tasks {
		f := ExecutionFamily{Group: task.Group, TargetPath: task.Target.Header.Path, DonorHeaderSHA256: task.Donor.Header.SHA256, DonorExportSHA256: task.Donor.Export.SHA256, TargetHeaderSHA256: task.Target.Header.SHA256, TargetExportSHA256: task.Target.Export.SHA256, NameEdits: []ExecutionNameEdit{{v.Slot, "C/Names.uasset", v.SourceSlot}}, AfterNamesHeaderSHA256: hash(v.AfterNamesHeader), AfterNamesExportSHA256: hash(v.Data)}
		h, dx := v.AfterNamesHeader, v.Data
		if task.PostProcess != nil {
			pp := v.Post
			pp.ClaimSHA256 = pin.SHA256
			f.PostProcess = &pp
			h, dx = v.FinalPostHeader, v.FinalPostData
		}
		want[task.Target.Header.Path] = h
		want[task.Target.Export.Path] = dx
		p.Families = append(p.Families, f)
	}
	for _, f := range plan.SupportFiles {
		b, _ := captured.Bytes("donor", f.Path)
		want[f.Path] = b
	}
	for _, o := range plan.Outputs {
		b := want[o.Path]
		p.Outputs = append(p.Outputs, File{o.Path, hash(b), int64(len(b))})
	}
	request := ExecutionRequest{}
	updateExecutionPlan(&request, p)
	return q, captured, member, request, want
}
func executeOK(t testing.TB, c *CapturedInputs, m *MembershipEvidence, q ExecutionRequest) *MemoryResult {
	t.Helper()
	r, e := ExecuteBounded(context.Background(), c, m, q)
	if e != nil || r == nil {
		t.Fatalf("execution: %v", e)
	}
	return r
}
func executeReject(t testing.TB, c *CapturedInputs, m *MembershipEvidence, q ExecutionRequest, text string) {
	t.Helper()
	r, e := ExecuteBounded(context.Background(), c, m, q)
	if r != nil || e == nil || !strings.Contains(e.Error(), text) {
		t.Fatalf("expected nil, %q; got result=%v err=%v", text, r != nil, e)
	}
}
func TestExecutionFullMemoryPipeline(t *testing.T) {
	for i, v := range executorVectors(t) {
		t.Run(v.ID, func(t *testing.T) {
			_, c, m, q, want := executorFixture(t, i)
			r := executeOK(t, c, m, q)
			for p, b := range want {
				got, ok := r.Bytes(p)
				if !ok || !bytes.Equal(got, b) {
					t.Fatal(p)
				}
			}
			var report ExecutionReport
			json.Unmarshal(r.ReportJSON(), &report)
			if !report.OutputPinsChecked || !report.PAKReadbackByteEqual || len(report.Families) != 3 || len(report.Outputs) != 10 || report.PAKSHA256 != hash(r.PAKBytes()) {
				t.Fatal("report")
			}
			files := []pakv11.File{}
			for p, b := range want {
				files = append(files, pakv11.File{Path: p, Data: b})
			}
			if _, e := pakv11.Verify(context.Background(), r.PAKBytes(), files, pakv11.Limits{}); e != nil {
				t.Fatal(e)
			}
		})
	}
}
func TestExecutionDoesNotPromotePriorEvidence(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	a, b, d := c.PlanJSON(), c.ReportJSON(), m.ReportJSON()
	r := executeOK(t, c, m, q)
	var rep ExecutionReport
	json.Unmarshal(r.ReportJSON(), &rep)
	if rep.TransformReady || rep.BuildReady || rep.Validated || rep.Installed || rep.SchemaSemanticsVerified || rep.ReviewerAuthenticated || rep.CoreR1Complete {
		t.Fatal("false readiness")
	}
	if !bytes.Equal(a, c.PlanJSON()) || !bytes.Equal(b, c.ReportJSON()) || !bytes.Equal(d, m.ReportJSON()) {
		t.Fatal("prior evidence changed")
	}
}
func TestExecutionUsesSnapshotsWithoutReopening(t *testing.T) {
	cap, c, m, q, want := executorFixture(t, 0)
	for _, root := range []string{cap.Roots.Donor, cap.Roots.Current, cap.Roots.Archives, cap.Roots.Schemas} {
		if e := os.RemoveAll(root); e != nil {
			t.Fatal(e)
		}
	}
	r := executeOK(t, c, m, q)
	for p, b := range want {
		got, _ := r.Bytes(p)
		if !bytes.Equal(got, b) {
			t.Fatal(p)
		}
	}
}
func TestExecutionMandatoryPinsAndReview(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	for _, k := range []string{"plan", "review", "wrong-review", "empty-findings", "approved"} {
		t.Run(k, func(t *testing.T) {
			x := q
			switch k {
			case "plan":
				x.Plan.SHA256 = ""
			case "review":
				x.Review.SHA256 = ""
			case "wrong-review":
				var v ExecutionReview
				json.Unmarshal(x.Review.Data, &v)
				v.ExecutionPlanSHA256 = strings.Repeat("0", 64)
				x.Review = pinned(v)
			case "empty-findings":
				var v ExecutionReview
				json.Unmarshal(x.Review.Data, &v)
				v.Findings = []string{}
				x.Review = pinned(v)
			case "approved":
				x.Review = repin(bytes.Replace(q.Review.Data, []byte(`"schema":`), []byte(`"approved":true,"schema":`), 1))
			}
			executeReject(t, c, m, x, "")
		})
	}
}
func TestExecutionStrictPlanJSON(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	for _, raw := range [][]byte{[]byte(`{"schema":"x","schema":"x"}`), []byte(`null`), append(append([]byte{}, q.Plan.Data...), []byte(` {}`)...), bytes.Replace(q.Plan.Data, []byte(`"allowUnversioned":false`), []byte(`"allowUnversioned":null`), 1)} {
		x := q
		x.Plan = repin(raw)
		executeReject(t, c, m, x, "JSON")
	}
}
func TestExecutionSnapshotAndMembershipBindings(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	for _, k := range []string{"recipe", "capture", "member", "plan"} {
		t.Run(k, func(t *testing.T) {
			p := executionPlan(t, q)
			switch k {
			case "recipe":
				p.RecipeSHA256 = hash(nil)
			case "capture":
				p.CaptureSHA256 = hash(nil)
			case "member":
				p.MembershipSHA256 = hash(nil)
			case "plan":
				p.PlanSHA256 = hash(nil)
			}
			x := q
			updateExecutionPlan(&x, p)
			executeReject(t, c, m, x, "BINDING")
		})
	}
	_, c2, m2, _, _ := executorFixture(t, 1)
	executeReject(t, c2, m, q, "")
	executeReject(t, c, m2, q, "")
}
func TestExecutionMissingOrForgedEvidence(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	executeReject(t, nil, m, q, "EVIDENCE")
	executeReject(t, c, nil, q, "EVIDENCE")
	executeReject(t, &CapturedInputs{}, m, q, "EVIDENCE")
	executeReject(t, c, &MembershipEvidence{}, q, "EVIDENCE")
	var rep MembershipReport
	json.Unmarshal(m.reportJSON, &rep)
	rep.ListedEntriesMembershipVerified = false
	raw, _ := json.Marshal(rep)
	executeReject(t, c, &MembershipEvidence{reportJSON: raw}, q, "EVIDENCE")
}
func TestExecutionRechecksRetainedBytes(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	key := "donor:D/Body.uasset"
	c.data[key][0] ^= 1
	executeReject(t, c, m, q, "PIN")
}
func TestExecutionTaskAndOutputCoverage(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	for _, kind := range []string{"missing-task", "extra-task", "duplicate-task", "missing-output", "duplicate-output", "extra-output", "wrong-group", "wrong-source", "wrong-target"} {
		t.Run(kind, func(t *testing.T) {
			p := executionPlan(t, q)
			switch kind {
			case "missing-task":
				p.Families = p.Families[1:]
			case "extra-task":
				p.Families = append(p.Families, p.Families[0])
			case "duplicate-task":
				p.Families[1] = p.Families[0]
			case "missing-output":
				p.Outputs = p.Outputs[1:]
			case "duplicate-output":
				p.Outputs[1] = p.Outputs[0]
			case "extra-output":
				p.Outputs[0].Path = "../outside.uasset"
			case "wrong-group":
				p.Families[0].Group = "fake"
			case "wrong-source":
				p.Families[0].DonorHeaderSHA256 = hash(nil)
			case "wrong-target":
				p.Families[0].TargetHeaderSHA256 = hash(nil)
			}
			x := q
			updateExecutionPlan(&x, p)
			executeReject(t, c, m, x, "")
		})
	}
}
func TestExecutionNameSourceAndWidthPolicy(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	for _, kind := range []string{"unlisted", "index", "source-index", "duplicate", "width", "pin"} {
		t.Run(kind, func(t *testing.T) {
			p := executionPlan(t, q)
			f := &p.Families[0]
			switch kind {
			case "unlisted":
				f.NameEdits[0].SourcePath = "C/Body1.uasset"
			case "index":
				f.NameEdits[0].Index = -1
			case "source-index":
				f.NameEdits[0].SourceIndex = 9999
			case "duplicate":
				f.NameEdits = append(f.NameEdits, f.NameEdits[0])
			case "width":
				f.NameEdits[0].SourceIndex = 0
			case "pin":
				f.AfterNamesHeaderSHA256 = hash(nil)
			}
			x := q
			updateExecutionPlan(&x, p)
			executeReject(t, c, m, x, "")
		})
	}
}
func TestExecutionCannotOmitOrAddPostProcess(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	p := executionPlan(t, q)
	p.Families[0].PostProcess = nil
	x := q
	updateExecutionPlan(&x, p)
	executeReject(t, c, m, x, "POSTPROCESS")
	p = executionPlan(t, q)
	p.Families[2].PostProcess = p.Families[0].PostProcess
	updateExecutionPlan(&x, p)
	executeReject(t, c, m, x, "POSTPROCESS")
}
func TestExecutionPostProcessBindingsAndPreconditions(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	for _, kind := range []string{"claim", "offset", "stale", "safe", "export-index", "preload"} {
		t.Run(kind, func(t *testing.T) {
			p := executionPlan(t, q)
			pp := p.Families[0].PostProcess
			switch kind {
			case "claim":
				pp.ClaimSHA256 = hash(nil)
			case "offset":
				pp.ExpectedSerializedOffset++
			case "stale":
				pp.Stale.Path = "/Wrong.ABP_Gura_C"
			case "safe":
				pp.Safe.ClassName = "BadClass"
			case "export-index":
				pp.ExportIndex = 0
			case "preload":
				pp.PreloadIndex = 0
			}
			x := q
			updateExecutionPlan(&x, p)
			executeReject(t, c, m, x, "")
		})
	}
}
func TestExecutionDossierBytesRechecked(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	c.data["schema:layout.json"][0] = '!'
	executeReject(t, c, m, q, "PIN")
}
func TestExecutionFinalOutputPinsAndNoPartialResults(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	p := executionPlan(t, q)
	for i := range p.Outputs {
		if p.Outputs[i].Path == "C/Body2.uexp" {
			p.Outputs[i].SHA256 = hash(nil)
		}
	}
	updateExecutionPlan(&q, p)
	executeReject(t, c, m, q, "result SHA-256 mismatch")
}
func TestExecutionSupportCannotBeChanged(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	p := executionPlan(t, q)
	for i := range p.Outputs {
		if strings.HasPrefix(p.Outputs[i].Path, "D/") {
			p.Outputs[i].SHA256 = hash(nil)
			break
		}
	}
	updateExecutionPlan(&q, p)
	executeReject(t, c, m, q, "support")
}
func TestExecutionLimitsAndProfile(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	for _, l := range []ExecutionLimits{{Families: 257}, {Families: 2}, {Outputs: 9}, {EditsPerFamily: 257}, {DocumentBytes: 100}, {SnapshotBytes: 2}, {OutputBytes: 2}} {
		x := q
		x.Limits = l
		executeReject(t, c, m, x, "")
	}
	p := executionPlan(t, q)
	p.Profile = "UNIVERSAL"
	updateExecutionPlan(&q, p)
	executeReject(t, c, m, q, "UNSUPPORTED")
}
func TestExecutionNilAndCancellation(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	r, e := ExecuteBounded(nil, c, m, q)
	if r != nil || e == nil {
		t.Fatal("nil context")
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	r, e = ExecuteBounded(ctx, c, m, q)
	if r != nil || !errors.Is(e, context.Canceled) {
		t.Fatal(e)
	}
}
func TestExecutionCancellationAtEveryBoundary(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	ctx := &cancellation{}
	r, e := ExecuteBounded(ctx, c, m, q)
	if e != nil || r == nil {
		t.Fatal(e)
	}
	n := ctx.calls
	for i := 1; i <= n; i++ {
		x := &cancellation{at: i}
		r, e := ExecuteBounded(x, c, m, q)
		if r != nil || !errors.Is(e, context.Canceled) {
			t.Fatalf("boundary %d/%d: %v", i, n, e)
		}
	}
}
func TestExecutionNoAliasesOrInputMutation(t *testing.T) {
	_, c, m, q, want := executorFixture(t, 0)
	before := append([]byte{}, q.Plan.Data...)
	r := executeOK(t, c, m, q)
	a, _ := r.Bytes("C/Body1.uasset")
	a[0] ^= 1
	b := r.PAKBytes()
	b[0] ^= 1
	rep := r.ReportJSON()
	rep[0] = '!'
	again, _ := r.Bytes("C/Body1.uasset")
	if !bytes.Equal(again, want["C/Body1.uasset"]) || r.ReportJSON()[0] != '{' || !bytes.Equal(before, q.Plan.Data) {
		t.Fatal("alias")
	}
	if _, ok := r.Bytes("missing"); ok {
		t.Fatal("missing")
	}
	var empty *MemoryResult
	if empty.PAKBytes() != nil || empty.ReportJSON() != nil {
		t.Fatal("nil")
	}
}
func TestExecutionDeterministicOrderAndConcurrentCalls(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	first := executeOK(t, c, m, q)
	p := executionPlan(t, q)
	for i, j := 0, len(p.Families)-1; i < j; i, j = i+1, j-1 {
		p.Families[i], p.Families[j] = p.Families[j], p.Families[i]
	}
	for i, j := 0, len(p.Outputs)-1; i < j; i, j = i+1, j-1 {
		p.Outputs[i], p.Outputs[j] = p.Outputs[j], p.Outputs[i]
	}
	x := q
	updateExecutionPlan(&x, p)
	if !bytes.Equal(first.PAKBytes(), executeOK(t, c, m, x).PAKBytes()) {
		t.Fatal("order")
	}
	var wg sync.WaitGroup
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			r, e := ExecuteBounded(context.Background(), c, m, q)
			if e != nil {
				t.Error(e)
				return
			}
			if !reflect.DeepEqual(first.ReportJSON(), r.ReportJSON()) {
				t.Error("nondeterministic")
			}
		}()
	}
	wg.Wait()
}
func TestExecutionFixtureExport(t *testing.T) {
	root := os.Getenv("PMM_R1_EXECUTION_OUTPUT")
	if root == "" {
		t.Skip("opt-in synthetic export")
	}
	if e := os.Mkdir(root, 0700); e != nil {
		t.Fatal(e)
	}
	for i, v := range executorVectors(t) {
		cap, c, m, q, want := executorFixture(t, i)
		r := executeOK(t, c, m, q)
		dir := filepath.Join(root, v.ID)
		os.Mkdir(dir, 0700)
		for name, b := range map[string][]byte{"execution.json": q.Plan.Data, "review.json": q.Review.Data, "capture.json": c.ReportJSON(), "membership.json": m.ReportJSON(), "plan.json": c.PlanJSON(), "report.json": r.ReportJSON(), "output.pak": r.PAKBytes()} {
			if e := os.WriteFile(filepath.Join(dir, name), b, 0600); e != nil {
				t.Fatal(e)
			}
		}
		for p, b := range want {
			put(t, filepath.Join(dir, "expected"), p, b)
			actual, _ := r.Bytes(p)
			put(t, filepath.Join(dir, "actual"), p, actual)
		}
		for key, b := range c.data {
			parts := strings.SplitN(key, ":", 2)
			put(t, filepath.Join(dir, "captured", parts[0]), parts[1], b)
		}
		_ = cap
	}
}
func FuzzExecutionDocument(f *testing.F) {
	f.Add([]byte(`{}`))
	f.Add([]byte(`{"schema":"PMM_R1_BOUNDED_EXECUTION_V1"}`))
	f.Fuzz(func(t *testing.T, b []byte) {
		if len(b) > 16<<10 {
			t.Skip()
		}
		var p ExecutionPlan
		_ = decode(context.Background(), repin(b), 16<<10, "fuzz plan", &p)
	})
}

func TestExecutionPreflightRejectsSidecars(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	l, _ := (ExecutionLimits{}).checked()
	x, e := checkExecutionInputs(context.Background(), c, m, l)
	if e != nil {
		t.Fatal(e)
	}
	x.plan.Tasks[0].Donor.Sidecars = []File{{Path: "D/Body.ubulk", SHA256: hash(nil), SizeBytes: 0}}
	_, _, e = prepareExecution(context.Background(), c, x, executionPlan(t, q), l)
	if e == nil || !strings.Contains(e.Error(), "bulk sidecars") {
		t.Fatal(e)
	}
}
func TestExecutionNoPostprocessStillRequiresExpectedStage(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	p := executionPlan(t, q)
	p.Families[2].AfterNamesHeaderSHA256 = hash(nil)
	updateExecutionPlan(&q, p)
	executeReject(t, c, m, q, "non-postprocess final pins")
}
func TestExecutionEvidenceEntriesCannotBeOmitted(t *testing.T) {
	_, c, m, q, _ := executorFixture(t, 0)
	var r MembershipReport
	json.Unmarshal(m.reportJSON, &r)
	r.Entries = r.Entries[1:]
	raw, _ := json.Marshal(r)
	executeReject(t, c, &MembershipEvidence{reportJSON: raw}, q, "EVIDENCE")
}
