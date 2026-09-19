package corer1

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	pakv11 "pmm.local/fixlab/pakv11"
	uasset "pmm.local/fixlab/uasset"
)

type executionInputs struct {
	plan    Plan
	capture CaptureReport
	member  MembershipReport
	files   map[string]File
}

// The evidence and capture have private state and no JSON-import constructor.
// Recheck their bindings and every retained buffer; never trust a bool from a
// caller-built report. This is NOT a sandbox against hostile in-process code.
func checkExecutionInputs(ctx context.Context, c *CapturedInputs, m *MembershipEvidence, l ExecutionLimits) (*executionInputs, error) {
	if c == nil || m == nil || len(c.reportJSON) == 0 || len(c.planJSON) == 0 || len(m.reportJSON) == 0 || c.data == nil {
		return nil, fail("EVIDENCE", "execution", "capture and membership required")
	}
	if len(c.reportJSON) > 32<<20 || len(c.planJSON) > 32<<20 || len(m.reportJSON) > 32<<20 {
		return nil, fail("LIMIT", "evidence", "metadata size")
	}
	x := &executionInputs{files: map[string]File{}}
	if e := json.Unmarshal(c.reportJSON, &x.capture); e != nil {
		return nil, e
	}
	if e := json.Unmarshal(c.planJSON, &x.plan); e != nil {
		return nil, e
	}
	if e := json.Unmarshal(m.reportJSON, &x.member); e != nil {
		return nil, e
	}
	r, p, b := x.capture, x.plan, x.member
	if r.Schema != "PMM_R1_CAPTURE_REPORT_V1" || p.Schema != "PMM_CORE_R1_PLAN_V1" || p.Status != "PLAN_VALID" || !r.ListedAssetBytesVerified || !r.ListedArchiveBytesVerified || r.PlanSHA256 != bytesDigest(c.planJSON) || r.ProviderSetSHA256 != p.DeclaredCurrentProvider {
		return nil, fail("EVIDENCE", "capture", "inconsistent capture/plan")
	}
	if b.Schema != "PMM_R1_MEMBERSHIP_REPORT_V1" || !b.ListedEntriesMembershipVerified || !b.AllListedProvidersParsed || !b.UniqueCurrentOwners || b.Profile != MembershipProfile || b.CurrentOwnership != UniqueCurrentOwner || b.CaptureReportSHA256 != bytesDigest(c.reportJSON) || b.PlanSHA256 != r.PlanSHA256 || b.ProviderSetSHA256 != r.ProviderSetSHA256 {
		return nil, fail("EVIDENCE", "membership", "not bound to this capture/profile")
	}
	if len(p.Tasks) == 0 || len(p.Tasks) > l.Families || len(p.Outputs) == 0 || len(p.Outputs) > l.Outputs {
		return nil, fail("LIMIT", "plan", "family/output count")
	}
	var total int64
	assetCount := 0
	for _, row := range r.Files {
		if e := ctx.Err(); e != nil {
			return nil, e
		}
		if row.Role == "archive" {
			continue
		}
		if row.Role != "donor" && row.Role != "current" && row.Role != "schema" {
			return nil, fail("EVIDENCE", "role", "unknown")
		}
		f := row.File
		key := row.Role + ":" + f.Path
		if _, ok := x.files[key]; ok {
			return nil, fail("EVIDENCE", key, "duplicate")
		}
		if e := safePath(f.Path); e != nil {
			return nil, e
		}
		data, ok := c.data[key]
		if !row.Retained || !ok || !validHash(f.SHA256) || f.SizeBytes < 0 || int64(len(data)) != f.SizeBytes || f.SizeBytes > l.SnapshotBytes-total {
			return nil, fail("EVIDENCE", key, "missing buffer/size/budget")
		}
		digest, e := membershipDigest(ctx, data)
		if e != nil {
			return nil, e
		}
		if digest != f.SHA256 {
			return nil, fail("PIN", key, "retained bytes changed")
		}
		total += f.SizeBytes
		x.files[key] = f
		if row.Role != "schema" {
			assetCount++
		}
	}
	if len(x.files) != len(c.data) || total != r.SnapshotBytes || len(b.Entries) != assetCount {
		return nil, fail("EVIDENCE", "coverage", "retained/captured/member sets differ")
	}
	seen := map[string]bool{}
	for _, row := range b.Entries {
		if e := ctx.Err(); e != nil {
			return nil, e
		}
		key := row.Role + ":" + row.File.Path
		f, ok := x.files[key]
		if !ok || row.Role == "schema" || seen[key] || f != row.File || row.EntryPath != f.Path || !row.ByteEqual {
			return nil, fail("EVIDENCE", key, "membership mismatch")
		}
		seen[key] = true
	}
	return x, ctx.Err()
}

type executionPrepared struct {
	task         Task
	family       ExecutionFamily
	header, data []byte
	names        uasset.RewriteRequest
	post         *uasset.PostProcessRequest
}

func executionAsset(c *CapturedInputs, x *executionInputs, role string, f File) ([]byte, error) {
	key := role + ":" + f.Path
	if actual, ok := x.files[key]; !ok || actual != f {
		return nil, fail("BINDING", key, "not this captured descriptor")
	}
	return c.data[key], nil
}
func shortImport(i uasset.ImportIdentity) string {
	pos := strings.LastIndexByte(i.Path, '.')
	if pos < 0 {
		return ""
	}
	return i.Path[pos+1:]
}

func prepareExecution(ctx context.Context, c *CapturedInputs, x *executionInputs, p ExecutionPlan, l ExecutionLimits) ([]executionPrepared, map[string]File, error) {
	opt := uasset.Options{Profile: p.UAssetProfile, AllowUnversioned: p.AllowUnversioned}
	if p.Schema != "PMM_R1_BOUNDED_EXECUTION_V1" || p.Profile != ExecutionProfile || p.UAssetProfile != uasset.CookedUE51 {
		return nil, nil, fail("UNSUPPORTED", "execution profile", "explicit fixed-width scalar profile required")
	}
	if len(p.Families) != len(x.plan.Tasks) || len(p.Outputs) != len(x.plan.Outputs) {
		return nil, nil, fail("COVERAGE", "execution", "every task and output required")
	}
	outputs := map[string]File{}
	expectedPaths := map[string]bool{}
	for _, o := range x.plan.Outputs {
		expectedPaths[o.Path] = true
	}
	var total int64
	for _, f := range p.Outputs {
		if !expectedPaths[f.Path] || !validHash(f.SHA256) || f.SizeBytes < 0 || f.SizeBytes > 64<<20 || f.SizeBytes > l.OutputBytes-total {
			return nil, nil, fail("OUTPUT", f.Path, "pin/size/coverage/budget")
		}
		if _, ok := outputs[f.Path]; ok {
			return nil, nil, fail("OUTPUT", f.Path, "duplicate")
		}
		outputs[f.Path] = f
		total += f.SizeBytes
	}
	sources := map[string]File{}
	for _, f := range x.plan.NameReferences {
		sources[f.Path] = f
	}
	// Read reference headers once. These bytes were checked against the PAK too.
	maps := map[string]*uasset.Package{}
	families := map[string]ExecutionFamily{}
	for _, f := range p.Families {
		if _, ok := families[f.TargetPath]; ok {
			return nil, nil, fail("FAMILY", f.TargetPath, "duplicate")
		}
		families[f.TargetPath] = f
	}
	prepared := make([]executionPrepared, 0, len(x.plan.Tasks))
	for _, t := range x.plan.Tasks {
		if e := ctx.Err(); e != nil {
			return nil, nil, e
		}
		f, ok := families[t.Target.Header.Path]
		if !ok || f.Group != t.Group || f.DonorHeaderSHA256 != t.Donor.Header.SHA256 || f.DonorExportSHA256 != t.Donor.Export.SHA256 || f.TargetHeaderSHA256 != t.Target.Header.SHA256 || f.TargetExportSHA256 != t.Target.Export.SHA256 {
			return nil, nil, fail("BINDING", t.Target.Header.Path, "family inputs")
		}
		if len(t.Donor.Sidecars) > 0 || len(t.Target.Sidecars) > 0 {
			return nil, nil, fail("UNSUPPORTED", t.Target.Header.Path, "bulk sidecars")
		}
		h, e := executionAsset(c, x, "donor", t.Donor.Header)
		if e != nil {
			return nil, nil, e
		}
		d, e := executionAsset(c, x, "donor", t.Donor.Export)
		if e != nil {
			return nil, nil, e
		}
		th, e := executionAsset(c, x, "current", t.Target.Header)
		if e != nil {
			return nil, nil, e
		}
		td, e := executionAsset(c, x, "current", t.Target.Export)
		if e != nil {
			return nil, nil, e
		}
		parsed, e := uasset.Read(ctx, h, d, opt)
		if e != nil {
			return nil, nil, fmt.Errorf("donor %s: %w", t.Donor.Header.Path, e)
		}
		if _, e = uasset.Read(ctx, th, td, opt); e != nil {
			return nil, nil, fmt.Errorf("target %s: %w", t.Target.Header.Path, e)
		}
		oh, od := outputs[t.Target.Header.Path], outputs[t.Target.Export.Path]
		if oh.SizeBytes != int64(len(h)) || od.SizeBytes != int64(len(d)) || !validHash(f.AfterNamesHeaderSHA256) || f.AfterNamesExportSHA256 != t.Donor.Export.SHA256 {
			return nil, nil, fail("UNSUPPORTED", f.TargetPath, "layout changes or missing stage pins")
		}
		if len(f.NameEdits) > l.EditsPerFamily {
			return nil, nil, fail("LIMIT", f.TargetPath, "name edits")
		}
		req := uasset.RewriteRequest{HeaderSHA256: t.Donor.Header.SHA256, ExportSHA256: t.Donor.Export.SHA256, Sources: []uasset.NameSource{}, Edits: []uasset.NameEdit{}}
		sourceIDs := map[string]int{}
		seen := map[int]bool{}
		for _, edit := range f.NameEdits {
			if e := ctx.Err(); e != nil {
				return nil, nil, e
			}
			ref, ok := sources[edit.SourcePath]
			if !ok {
				return nil, nil, fail("BINDING", edit.SourcePath, "not an allowed current name source")
			}
			raw, e := executionAsset(c, x, "current", ref)
			if e != nil {
				return nil, nil, e
			}
			pm := maps[edit.SourcePath]
			if pm == nil {
				pm, e = uasset.Read(ctx, raw, nil, opt)
				if e != nil {
					return nil, nil, e
				}
				maps[edit.SourcePath] = pm
			}
			if edit.Index < 0 || edit.Index >= len(parsed.Names) || edit.SourceIndex < 0 || edit.SourceIndex >= len(pm.Names) || seen[edit.Index] {
				return nil, nil, fail("NAME_EDIT", f.TargetPath, "index/duplicate")
			}
			seen[edit.Index] = true
			if parsed.Names[edit.Index].Size != pm.Names[edit.SourceIndex].Size {
				return nil, nil, fail("UNSUPPORTED", f.TargetPath, "any name-slot width change is rejected")
			}
			id, ok := sourceIDs[edit.SourcePath]
			if !ok {
				if len(req.Sources) >= uasset.MaxNameSources {
					return nil, nil, fail("LIMIT", f.TargetPath, "name sources")
				}
				id = len(req.Sources)
				sourceIDs[edit.SourcePath] = id
				req.Sources = append(req.Sources, uasset.NameSource{Header: raw, SHA256: ref.SHA256})
			}
			req.Edits = append(req.Edits, uasset.NameEdit{Index: edit.Index, Source: id, SourceIndex: edit.SourceIndex})
		}
		pr := executionPrepared{task: t, family: f, header: h, data: d, names: req}
		if (t.PostProcess == nil) != (f.PostProcess == nil) {
			return nil, nil, fail("POSTPROCESS", f.TargetPath, "cannot omit or add a recipe operation")
		}
		if f.PostProcess != nil {
			pp := f.PostProcess
			if len(t.PostProcess.ExpectedSerializedOffsets) != 1 || int64(pp.ExpectedSerializedOffset) != t.PostProcess.ExpectedSerializedOffsets[0] || shortImport(pp.Stale) != t.PostProcess.StaleClass || shortImport(pp.Safe) != t.PostProcess.SafeClass {
				return nil, nil, fail("POSTPROCESS", f.TargetPath, "recipe identity or expected offset")
			}
			var claim *ClaimRecord
			var dossier *DossierResult
			for i := range x.plan.SchemaClaims {
				v := &x.plan.SchemaClaims[i]
				if v.SHA256 == pp.ClaimSHA256 {
					claim = v
				}
			}
			for i := range x.capture.Dossiers {
				v := &x.capture.Dossiers[i]
				if v.ClaimSHA256 == pp.ClaimSHA256 {
					dossier = v
				}
			}
			if claim == nil || dossier == nil || claim.Claim.DonorUasset != t.Donor.Header.Path || claim.Claim.DonorHeaderSHA256 != t.Donor.Header.SHA256 || claim.Claim.DonorExportSHA256 != t.Donor.Export.SHA256 || claim.Claim.RecipeSHA256 != p.RecipeSHA256 || claim.Claim.CurrentProviderSHA256 != x.plan.DeclaredCurrentProvider || claim.Claim.Profile != p.UAssetProfile {
				return nil, nil, fail("DOSSIER", f.TargetPath, "missing or unrelated schema claim")
			}
			layout, e := executionAsset(c, x, "schema", dossier.Layout)
			if e != nil {
				return nil, nil, e
			}
			review, e := executionAsset(c, x, "schema", dossier.Review)
			if e != nil {
				return nil, nil, e
			}
			if _, e = verifyDossier(ctx, *claim, DossierFiles{pp.ClaimSHA256, dossier.Layout, dossier.Review}, layout, review); e != nil {
				return nil, nil, e
			}
			pr.post = &uasset.PostProcessRequest{HeaderSHA256: f.AfterNamesHeaderSHA256, ExportSHA256: f.AfterNamesExportSHA256, ResultHeaderSHA256: oh.SHA256, ResultExportSHA256: od.SHA256, Schema: layout, SchemaSHA256: claim.Claim.LayoutSHA256, ExportIndex: pp.ExportIndex, ExportObject: pp.ExportObject, Stale: pp.Stale, Safe: pp.Safe, PreloadIndex: pp.PreloadIndex, DependencyGroup: pp.DependencyGroup, ExpectedSerializedOffset: pp.ExpectedSerializedOffset}
		} else if oh.SHA256 != f.AfterNamesHeaderSHA256 || od.SHA256 != f.AfterNamesExportSHA256 {
			return nil, nil, fail("OUTPUT", f.TargetPath, "non-postprocess final pins differ from name stage")
		}
		prepared = append(prepared, pr)
	}
	for _, f := range x.plan.SupportFiles {
		if strings.HasSuffix(f.Path, ".ubulk") || strings.HasSuffix(f.Path, ".uptnl") {
			return nil, nil, fail("UNSUPPORTED", f.Path, "bulk support")
		}
		if outputs[f.Path] != f {
			return nil, nil, fail("OUTPUT", f.Path, "support must remain byte-identical")
		}
		if _, e := executionAsset(c, x, "donor", f); e != nil {
			return nil, nil, e
		}
	}
	return prepared, outputs, ctx.Err()
}

// ExecuteBounded runs the explicit reviewed plan using already captured bytes
// and non-forgeable-by-JSON membership evidence. NO filesystem or network I/O.
// It does not discover operations, authenticate reviews, or prove mesh semantics.
// Caller must freeze all request bytes during the call. Existing UAsset guards
// are not relaxed. On ANY failure the result is nil, even after an earlier family.
func ExecuteBounded(ctx context.Context, c *CapturedInputs, m *MembershipEvidence, q ExecutionRequest) (*MemoryResult, error) {
	if ctx == nil {
		return nil, fail("CONTEXT", "execution", "nil")
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	l, e := q.Limits.checked()
	if e != nil {
		return nil, e
	}
	var p ExecutionPlan
	var review ExecutionReview
	if e = decode(ctx, q.Plan, l.DocumentBytes, "execution plan", &p); e != nil {
		return nil, e
	}
	if e = decode(ctx, q.Review, 16<<10, "execution review", &review); e != nil {
		return nil, e
	}
	if review.Schema != "PMM_R1_EXECUTION_REVIEW_V1" || review.ExecutionPlanSHA256 != q.Plan.SHA256 || !label(review.Reviewer) || !label(review.Origin) || !label(review.Revision) || !label(review.Method) || len(review.Findings) < 1 || len(review.Findings) > 64 {
		return nil, fail("REVIEW", "execution", "missing or unrelated declaration")
	}
	for _, f := range review.Findings {
		if !label(f) {
			return nil, fail("REVIEW", "execution", "invalid finding")
		}
	}
	x, e := checkExecutionInputs(ctx, c, m, l)
	if e != nil {
		return nil, e
	}
	if p.RecipeSHA256 != x.plan.RecipeSHA256 || p.PlanSHA256 != bytesDigest(c.planJSON) || p.CaptureSHA256 != bytesDigest(c.reportJSON) || p.MembershipSHA256 != bytesDigest(m.reportJSON) {
		return nil, fail("BINDING", "execution", "snapshot/recipe/membership changed")
	}
	tasks, expected, e := prepareExecution(ctx, c, x, p, l)
	if e != nil {
		return nil, e
	}
	result := &MemoryResult{files: map[string][]byte{}}
	report := ExecutionReport{Schema: "PMM_R1_BOUNDED_EXECUTION_REPORT_V1", Status: "MEMORY_OUTPUTS_VERIFIED_NOT_GAME_ACCEPTED", ExecutionPlanSHA256: q.Plan.SHA256, ReviewSHA256: q.Review.SHA256, CaptureSHA256: p.CaptureSHA256, MembershipSHA256: p.MembershipSHA256, RecipeSHA256: p.RecipeSHA256, Families: []ExecutedFamily{}, Outputs: []File{}, ReviewState: "BYTES_AND_BINDINGS_CHECKED_NOT_AUTHENTICATED", Blockers: []string{"REAL_SCHEMA_SEMANTICS_UNVERIFIED", "VARIABLE_LAYOUT_RELOCATION_UNSUPPORTED", "FULL_CORE_R1_V2_CLI_NOT_IMPLEMENTED", "UNREAL_WINDOWS_ACCEPTANCE_NOT_RUN", "TRANSACTIONAL_PUBLICATION_NOT_IMPLEMENTED"}}
	opt := uasset.Options{Profile: p.UAssetProfile, AllowUnversioned: p.AllowUnversioned}
	for _, t := range tasks {
		if e = ctx.Err(); e != nil {
			return nil, e
		}
		r, err := uasset.RewriteNames(ctx, t.header, t.data, opt, t.names)
		if err != nil {
			return nil, fmt.Errorf("names %s: %w", t.family.TargetPath, err)
		}
		if r.Report.NameLayoutChanged || r.Report.HeaderDelta != 0 || r.Package.HeaderSHA256 != t.family.AfterNamesHeaderSHA256 || r.Package.ExportDataSHA256 != t.family.AfterNamesExportSHA256 {
			return nil, fail("PIN", t.family.TargetPath, "name stage result or layout mismatch")
		}
		h, d := r.Header, r.ExportData
		step := ExecutedFamily{TargetPath: t.family.TargetPath, Names: r.Report}
		if t.post != nil {
			pp, err := uasset.PatchPostProcess(ctx, h, d, opt, *t.post)
			if err != nil {
				return nil, fmt.Errorf("postprocess %s: %w", t.family.TargetPath, err)
			}
			h, d = pp.Header, pp.ExportData
			step.PostProcess = &pp.Report
		}
		result.files[t.task.Target.Header.Path] = h
		result.files[t.task.Target.Export.Path] = d
		report.Families = append(report.Families, step)
	}
	for _, f := range x.plan.SupportFiles {
		src := c.data["donor:"+f.Path]
		dst := make([]byte, len(src))
		if e = executionCopy(ctx, dst, src); e != nil {
			return nil, e
		}
		result.files[f.Path] = dst
	}
	if len(result.files) != len(expected) {
		return nil, fail("OUTPUT", "execution", "coverage differs")
	}
	paths := make([]string, 0, len(expected))
	for path := range expected {
		paths = append(paths, path)
	}
	sort.Strings(paths)
	pakFiles := make([]pakv11.File, 0, len(paths))
	for _, path := range paths {
		data, ok := result.files[path]
		f := expected[path]
		if !ok || int64(len(data)) != f.SizeBytes {
			return nil, fail("OUTPUT", path, "missing or size mismatch")
		}
		digest, err := membershipDigest(ctx, data)
		if err != nil {
			return nil, err
		}
		if digest != f.SHA256 {
			return nil, fail("PIN", path, "final output mismatch")
		}
		pakFiles = append(pakFiles, pakv11.File{Path: path, Data: data})
		report.Outputs = append(report.Outputs, f)
	}
	// External per-file expected pins were checked BEFORE packaging. Readback is
	// additional consistency evidence, not authentication of a newly computed hash.
	result.pak, e = pakv11.Build(ctx, pakFiles, pakv11.Limits{})
	if e != nil {
		return nil, e
	}
	if _, e = pakv11.Verify(ctx, result.pak, pakFiles, pakv11.Limits{}); e != nil {
		return nil, e
	}
	report.PAKSHA256, e = membershipDigest(ctx, result.pak)
	if e != nil {
		return nil, e
	}
	report.PAKBytes = len(result.pak)
	report.OutputPinsChecked = true
	report.PAKReadbackByteEqual = true
	result.report, e = json.MarshalIndent(report, "", "  ")
	if e != nil {
		return nil, e
	}
	if e = ctx.Err(); e != nil {
		return nil, e
	}
	return result, nil
}
func executionCopy(ctx context.Context, dst, src []byte) error {
	for i := 0; i < len(src); i += 65536 {
		if e := ctx.Err(); e != nil {
			return e
		}
		end := i + 65536
		if end > len(src) {
			end = len(src)
		}
		copy(dst[i:end], src[i:end])
	}
	return ctx.Err()
}
