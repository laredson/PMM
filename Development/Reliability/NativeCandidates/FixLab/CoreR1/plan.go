package corer1

import (
	"context"
	"path"
	"regexp"
	"sort"
	"strings"
)

// PlanCore checks DECLARED inventories and enumerates work. It never authorizes
// execution. Invalid/missing planning inputs return nil,error. A valid plan still
// contains blocking requirements; no caller flag can mark it TRANSFORM_READY.
func PlanCore(ctx context.Context, req Request) (*Plan, error) {
	if ctx == nil {
		return nil, fail("CONTEXT", "request", "nil")
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	l, e := req.Limits.checked()
	if e != nil {
		return nil, e
	}
	if len(req.SchemaClaims) > l.Claims {
		return nil, fail("LIMIT", "claims", "count")
	}
	var r Recipe
	var d, c Inventory
	if e = decode(ctx, req.Recipe, l.RecipeBytes, "recipe", &r); e != nil {
		return nil, e
	}
	rs, ex, forbid, e := recipeCheck(r)
	if e != nil {
		return nil, e
	}
	if e = decode(ctx, req.DonorInventory, l.InventoryBytes, "donor inventory", &d); e != nil {
		return nil, e
	}
	if e = decode(ctx, req.CurrentInventory, l.InventoryBytes, "current inventory", &c); e != nil {
		return nil, e
	}
	dm, e := index(ctx, d, "donor", l)
	if e != nil {
		return nil, e
	}
	cm, e := index(ctx, c, "current", l)
	if e != nil {
		return nil, e
	}
	var accepted *Signature
	for _, s := range r.Signatures {
		if s.SHA256 == d.ProviderSHA256 {
			x := s
			accepted = &x
			break
		}
	}
	if accepted == nil {
		return nil, fail("DONOR", "inventory", "declared provider not allowed")
	}
	if c.Build != r.TargetBuild {
		return nil, fail("BUILD", "current inventory", "different build requires explicit compatibility review")
	}
	p := &Plan{Schema: "PMM_CORE_R1_PLAN_V1", Status: "PLAN_VALID", RecipeID: r.ID, RecipeSHA256: req.Recipe.SHA256, DonorInventorySHA256: req.DonorInventory.SHA256, CurrentInventorySHA256: req.CurrentInventory.SHA256, DeclaredDonor: *accepted, DeclaredCurrentProvider: c.ProviderSHA256, TargetBuild: r.TargetBuild, NameReferences: []File{}, Tasks: []Task{}, Groups: []Group{}, SupportFiles: []File{}, ExcludedSupport: []string{}, Outputs: []Output{}, SchemaClaims: []ClaimRecord{}, Requirements: []Requirement{}}
	for _, name := range r.NameSources {
		f, ok := cm[name]
		if !ok {
			return nil, fail("MISSING", name, "current name-hash reference header")
		}
		p.NameReferences = append(p.NameReferences, f)
	}
	selectedTargets := map[string]bool{}
	donorsWithPost := map[string]Family{}
	for i, g := range r.Relocate {
		if e = ctx.Err(); e != nil {
			return nil, e
		}
		donor, e := family(dm, g.DonorUasset)
		if e != nil {
			return nil, e
		}
		count := 0
		for _, f := range list(cm) {
			if e = ctx.Err(); e != nil {
				return nil, e
			}
			if !strings.HasSuffix(f.Path, ".uasset") || !fullMatch(rs[i], f.Path) {
				continue
			}
			if selectedTargets[f.Path] {
				return nil, fail("AMBIGUOUS", f.Path, "multiple target groups")
			}
			selectedTargets[f.Path] = true
			target, e := family(cm, f.Path)
			if e != nil {
				return nil, e
			}
			if len(p.Tasks) >= l.Outputs/2 {
				return nil, fail("LIMIT", "tasks", "plan output count")
			}
			p.Tasks = append(p.Tasks, Task{g.Name, cloneFamily(donor), target, clonePost(g.PostProcess)})
			count++
		}
		if count < g.MinimumCount {
			return nil, fail("MINIMUM", g.Name, "not enough current target families")
		}
		p.Groups = append(p.Groups, Group{g.Name, count, g.MinimumCount, g.KnownBaselineCount})
		if g.PostProcess != nil {
			donorsWithPost[g.DonorUasset] = donor
		}
	}
	if e = selectSupport(ctx, p, r, dm, ex); e != nil {
		return nil, e
	}
	used, files := map[string]string{}, map[string]bool{}
	add := func(out Output) error {
		if len(p.Outputs) >= l.Outputs {
			return fail("LIMIT", "outputs", "count")
		}
		if matches(forbid, out.Path) {
			return fail("FORBIDDEN", out.Path, "output excluded by recipe")
		}
		if e := addPath(used, files, out.Path); e != nil {
			return e
		}
		p.Outputs = append(p.Outputs, out)
		return nil
	}
	for _, f := range p.SupportFiles {
		if e = ctx.Err(); e != nil {
			return nil, e
		}
		if e = add(Output{f.Path, "COPY_SUPPORT", f.Path}); e != nil {
			return nil, e
		}
	}
	for _, t := range p.Tasks {
		if e = ctx.Err(); e != nil {
			return nil, e
		}
		stem := strings.TrimSuffix(t.Target.Header.Path, ".uasset")
		source := append([]File{t.Donor.Header, t.Donor.Export}, t.Donor.Sidecars...)
		for _, f := range source {
			if e = add(Output{stem + path.Ext(f.Path), "RELOCATE_REQUIRED", f.Path}); e != nil {
				return nil, e
			}
		}
	}
	for _, in := range req.SchemaClaims {
		var claim SchemaClaim
		if e = decode(ctx, in, l.ClaimBytes, "schema provenance", &claim); e != nil {
			return nil, e
		}
		if e = validateClaim(claim, req.Recipe.SHA256, c.ProviderSHA256, donorsWithPost); e != nil {
			return nil, e
		}
		for _, old := range p.SchemaClaims {
			if old.Claim.DonorUasset == claim.DonorUasset {
				return nil, fail("AMBIGUOUS", claim.DonorUasset, "duplicate provenance claims")
			}
		}
		p.SchemaClaims = append(p.SchemaClaims, ClaimRecord{in.SHA256, claim, "DECLARED_UNVERIFIED"})
	}
	p.require("DONOR_ARCHIVE_AND_EXTRACTION", "donor", "NOT_VERIFIED", "Hash the actual allowed archive and bind extracted bytes to it; inventory claims alone are not evidence.")
	p.require("CURRENT_PROVIDER_AND_BUILD", "current", "NOT_VERIFIED", "Establish provider-set provenance/build and hash each referenced file from an immutable snapshot.")
	p.require("NAME_SOURCE_BYTES", "name references", "NOT_VERIFIED", "Read the pinned headers and resolve exact raw name entries; do not synthesize current CRC values.")
	for _, t := range p.Tasks {
		s := t.Target.Header.Path
		p.require("RELOCATION_AND_NAME_PLAN", s, "NOT_IMPLEMENTED", "Full core relocation, exact slot mapping and internal-offset model are not established by a path match.")
		p.require("EXPECTED_OUTPUT_IDENTITIES", s, "MISSING", "Reviewed per-family input/output expectations must precede transformation; never auto-accept computed output hashes.")
		if len(t.Donor.Sidecars) > 0 || len(t.Target.Sidecars) > 0 {
			p.require("BULK_LAYOUT", s, "UNSUPPORTED", "Sidecars are inventoried, not interpreted or authorized to move.")
		}
	}
	for name := range donorsWithPost {
		state, detail := "MISSING", "Supply a reviewed schema, its actual bytes and per-export binding. Recipe offsets are assertions, not a parser."
		for _, claim := range p.SchemaClaims {
			if claim.Claim.DonorUasset == name {
				state = "DECLARED_UNVERIFIED"
				detail = "Provenance declaration is bound to this plan; referenced schema/review bytes and semantic correctness are not verified."
			}
		}
		p.require("POSTPROCESS_SCHEMA_PROVENANCE", name, state, detail)
	}
	p.require("CORE_EXECUTOR", "core R1", "NOT_IMPLEMENTED", "This planner does not call the primitives, validate game behavior, write a PAK, or install anything.")
	sort.Slice(p.NameReferences, func(i, j int) bool { return p.NameReferences[i].Path < p.NameReferences[j].Path })
	sort.Slice(p.Tasks, func(i, j int) bool {
		if p.Tasks[i].Group == p.Tasks[j].Group {
			return p.Tasks[i].Target.Header.Path < p.Tasks[j].Target.Header.Path
		}
		return p.Tasks[i].Group < p.Tasks[j].Group
	})
	sort.Slice(p.Groups, func(i, j int) bool { return p.Groups[i].Name < p.Groups[j].Name })
	sort.Slice(p.Outputs, func(i, j int) bool { return p.Outputs[i].Path < p.Outputs[j].Path })
	sort.Slice(p.SchemaClaims, func(i, j int) bool { return p.SchemaClaims[i].Claim.DonorUasset < p.SchemaClaims[j].Claim.DonorUasset })
	sort.Slice(p.Requirements, func(i, j int) bool {
		a, b := p.Requirements[i], p.Requirements[j]
		if a.Code == b.Code {
			return a.Subject < b.Subject
		}
		return a.Code < b.Code
	})
	if e = ctx.Err(); e != nil {
		return nil, e
	}
	return p, nil
}
func (p *Plan) require(code, subject, state, detail string) {
	p.Requirements = append(p.Requirements, Requirement{code, subject, state, detail})
}
func clonePost(in *PostProcess) *PostProcess {
	if in == nil {
		return nil
	}
	p := *in
	p.ExpectedSerializedOffsets = append([]int64{}, in.ExpectedSerializedOffsets...)
	return &p
}

func selectSupport(ctx context.Context, p *Plan, r Recipe, dm map[string]File, ex []*regexp.Regexp) error {
	selected := map[string]File{}
	explicit := map[string]bool{}
	for _, name := range r.Support.Files {
		if _, ok := dm[name]; !ok {
			return fail("MISSING", name, "explicit support file")
		}
		explicit[name] = true
	}
	roots := make([]int, len(r.Support.Roots))
	for _, f := range list(dm) {
		if e := ctx.Err(); e != nil {
			return e
		}
		want := explicit[f.Path]
		for _, root := range r.Support.Roots {
			if strings.HasPrefix(f.Path, root+"/") {
				want = true
			}
		}
		if !want {
			continue
		}
		if matches(ex, f.Path) {
			if explicit[f.Path] {
				return fail("RECIPE", f.Path, "explicit support is also excluded")
			}
			p.ExcludedSupport = append(p.ExcludedSupport, f.Path)
			continue
		}
		switch path.Ext(f.Path) {
		case ".uasset", ".uexp", ".ubulk", ".uptnl":
		default:
			return fail("SUPPORT", f.Path, "unsupported data extension")
		}
		selected[f.Path] = f
		for i, root := range r.Support.Roots {
			if strings.HasPrefix(f.Path, root+"/") {
				roots[i]++
			}
		}
	}
	for i, n := range roots {
		if n == 0 {
			return fail("MISSING", r.Support.Roots[i], "support root selects no files")
		}
	}
	for _, f := range list(selected) {
		base := strings.TrimSuffix(f.Path, path.Ext(f.Path))
		if _, e := family(selected, base+".uasset"); e != nil {
			return e
		}
	}
	p.SupportFiles = list(selected)
	sort.Strings(p.ExcludedSupport)
	return nil
}
func validateClaim(s SchemaClaim, recipe, current string, donors map[string]Family) error {
	if s.Schema != "PMM_R1_SCHEMA_PROVENANCE_V1" || s.Profile != "cooked-ue4-522-ue5-1008" || s.ClassPath != "/Script/Engine.SkeletalMesh" {
		return fail("CLAIM", "schema", "unsupported profile/class")
	}
	for _, h := range []string{s.RecipeSHA256, s.DonorHeaderSHA256, s.DonorExportSHA256, s.CurrentProviderSHA256, s.LayoutSHA256, s.ReviewRecordSHA256} {
		if !validHash(h) {
			return fail("CLAIM", "hash", "invalid")
		}
	}
	if !label(s.Origin) || !label(s.Revision) {
		return fail("CLAIM", "provenance", "origin/revision required")
	}
	f, ok := donors[s.DonorUasset]
	if !ok || s.RecipeSHA256 != recipe || s.CurrentProviderSHA256 != current || s.DonorHeaderSHA256 != f.Header.SHA256 || s.DonorExportSHA256 != f.Export.SHA256 {
		return fail("CLAIM", s.DonorUasset, "unrelated or mismatched binding")
	}
	return nil
}

func cloneFamily(f Family) Family { f.Sidecars = append([]File{}, f.Sidecars...); return f }
