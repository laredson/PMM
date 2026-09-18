package corer1

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

func hash(b []byte) string { h := sha256.Sum256(b); return hex.EncodeToString(h[:]) }
func pinned(v any) PinnedJSON {
	b, e := json.Marshal(v)
	if e != nil {
		panic(e)
	}
	return PinnedJSON{b, hash(b)}
}
func repin(b []byte) PinnedJSON { return PinnedJSON{b, hash(b)} }
func file(p string) File {
	return File{p, hash([]byte("SYNTHETIC FILE METADATA: " + p)), int64(len(p))}
}
func pair(p string) []File { return []File{file(p + ".uasset"), file(p + ".uexp")} }
func fixture() (Request, Recipe, Inventory, Inventory) {
	r := Recipe{Schema: "PMM_FIXLAB_RECIPE_V1", ID: "synthetic-core", Name: "Artificial metadata only", Version: 1, Status: "fixture", TargetBuild: "SYNTHETIC-BUILD", Signatures: []Signature{{"fixture-A", hash([]byte("provider-A")), "accepted-donor"}, {"fixture-B", hash([]byte("provider-B")), "accepted-donor"}}, NameSources: []string{"C/Names.uasset"}, Support: Support{[]string{"D/Mat"}, []string{"D/Skeleton.uasset", "D/Skeleton.uexp"}, []string{"/Excluded\\."}}, Relocate: []Relocate{{"body", "D/Body.uasset", "^C/Body[0-9]+\\.uasset$", &PostProcess{"StaleClass", "SafeClass", []int64{120}}, 2, 2}, {"hair", "D/Hair.uasset", "^C/Hair[0-9]+\\.uasset$", nil, 1, 1}}, Forbidden: []string{"/Blueprint/"}, MountPoint: "../../../", PathHashSeed: 0}
	d := Inventory{Schema: "PMM_R1_INVENTORY_V1", Role: "donor", ProviderSHA256: r.Signatures[0].SHA256, Build: "SYNTHETIC-DONOR", Files: []File{}}
	for _, p := range []string{"D/Body", "D/Hair", "D/Mat/Test", "D/Mat/Excluded", "D/MatExtra/Unselected", "D/Skeleton"} {
		d.Files = append(d.Files, pair(p)...)
	}
	c := Inventory{Schema: "PMM_R1_INVENTORY_V1", Role: "current", ProviderSHA256: hash([]byte("current-provider")), Build: r.TargetBuild, Files: []File{file("C/Names.uasset")}}
	for _, p := range []string{"C/Body1", "C/Body2", "C/Hair1"} {
		c.Files = append(c.Files, pair(p)...)
	}
	return Request{Recipe: pinned(r), DonorInventory: pinned(d), CurrentInventory: pinned(c)}, r, d, c
}
func mustPlan(t *testing.T, q Request) *Plan {
	t.Helper()
	p, e := PlanCore(context.Background(), q)
	if e != nil {
		t.Fatal(e)
	}
	return p
}
func wantError(t *testing.T, q Request, code string) {
	t.Helper()
	p, e := PlanCore(context.Background(), q)
	if p != nil || e == nil {
		t.Fatalf("want error %s, got %v %v", code, p, e)
	}
	var typed *Error
	if !errors.As(e, &typed) || typed.Code != code {
		t.Fatalf("want %s: %v", code, e)
	}
}
func claimFor(q Request, r Recipe, d, c Inventory) SchemaClaim {
	return SchemaClaim{"PMM_R1_SCHEMA_PROVENANCE_V1", q.Recipe.SHA256, "D/Body.uasset", d.Files[0].SHA256, d.Files[1].SHA256, c.ProviderSHA256, "cooked-ue4-522-ue5-1008", "/Script/Engine.SkeletalMesh", hash([]byte("not an actual schema")), "fixture-only", "fixture-revision", hash([]byte("not an actual review"))}
}

func TestValidPlanIsNotTransformReady(t *testing.T) {
	q, _, _, _ := fixture()
	p := mustPlan(t, q)
	if p.Status != "PLAN_VALID" || p.TransformReady || p.BuildReady || p.Validated || p.Installed || p.InputBytesVerified {
		t.Fatal("false execution claim")
	}
	if len(p.Tasks) != 3 || len(p.Outputs) != 10 || len(p.SupportFiles) != 4 || len(p.Requirements) == 0 {
		t.Fatal("wrong plan counts")
	}
	for _, x := range p.Requirements {
		if x.State == "SATISFIED" {
			t.Fatal("unproved requirement")
		}
	}
}
func TestDonorSignaturesAreAlternatives(t *testing.T) {
	q, r, d, _ := fixture()
	for _, s := range r.Signatures {
		d.ProviderSHA256 = s.SHA256
		q.DonorInventory = pinned(d)
		p := mustPlan(t, q)
		if p.DeclaredDonor.SHA256 != s.SHA256 {
			t.Fatal("wrong alternative")
		}
	}
	d.ProviderSHA256 = hash([]byte("other"))
	q.DonorInventory = pinned(d)
	wantError(t, q, "DONOR")
}
func TestMinimumAndBaselineAdvisory(t *testing.T) {
	q, r, d, c := fixture()
	c.Files = append(c.Files, pair("C/Body3")...)
	q.CurrentInventory = pinned(c)
	p := mustPlan(t, q)
	if p.Groups[0].Count != 3 || p.Groups[0].Baseline != 2 {
		t.Fatal("baseline treated as ceiling")
	}
	r.Relocate[0].MinimumCount = 4
	r.Relocate[0].KnownBaselineCount = 4
	q.Recipe = pinned(r)
	q.DonorInventory = pinned(d)
	wantError(t, q, "MINIMUM")
}
func TestCurrentBuildMismatch(t *testing.T) {
	q, _, _, c := fixture()
	c.Build = "newer-unreviewed-build"
	q.CurrentInventory = pinned(c)
	wantError(t, q, "BUILD")
}
func TestMissingRequiredFiles(t *testing.T) {
	for _, name := range []string{"D/Body.uasset", "D/Body.uexp", "D/Skeleton.uasset", "C/Names.uasset", "C/Body1.uexp"} {
		t.Run(name, func(t *testing.T) {
			q, _, d, c := fixture()
			for _, i := range []*Inventory{&d, &c} {
				v := []File{}
				for _, f := range i.Files {
					if f.Path != name {
						v = append(v, f)
					}
				}
				i.Files = v
			}
			q.DonorInventory = pinned(d)
			q.CurrentInventory = pinned(c)
			wantError(t, q, "MISSING")
		})
	}
}
func TestAmbiguousGroups(t *testing.T) {
	q, r, _, _ := fixture()
	r.Relocate[1].TargetRegex = r.Relocate[0].TargetRegex
	q.Recipe = pinned(r)
	wantError(t, q, "AMBIGUOUS")
}
func TestSupportBoundaryAndExclusions(t *testing.T) {
	q, _, _, _ := fixture()
	p := mustPlan(t, q)
	if len(p.ExcludedSupport) != 2 {
		t.Fatal("excluded files")
	}
	for _, f := range p.SupportFiles {
		if strings.Contains(f.Path, "MatExtra") || strings.Contains(f.Path, "Excluded") {
			t.Fatal("root boundary/exclusion")
		}
	}
}
func TestSupportConflictAndEmptyRoot(t *testing.T) {
	q, r, _, _ := fixture()
	r.Support.Files = append(r.Support.Files, "D/Mat/Excluded.uasset")
	q.Recipe = pinned(r)
	wantError(t, q, "RECIPE")
	q, r, _, _ = fixture()
	r.Support.Roots = []string{"D/Missing"}
	q.Recipe = pinned(r)
	wantError(t, q, "MISSING")
}
func TestSupportFamilyCompleteness(t *testing.T) {
	q, r, _, _ := fixture()
	r.Support.Excludes = []string{"/Test\\.uexp$"}
	q.Recipe = pinned(r)
	wantError(t, q, "MISSING")
}
func TestSelectedExecutablesRejected(t *testing.T) {
	q, _, d, _ := fixture()
	d.Files = append(d.Files, file("D/Mat/tool.exe"))
	q.DonorInventory = pinned(d)
	wantError(t, q, "SUPPORT")
}
func TestForbiddenAndOutputCollisions(t *testing.T) {
	q, r, _, _ := fixture()
	r.Forbidden = append(r.Forbidden, "/Body1\\.uexp$")
	q.Recipe = pinned(r)
	wantError(t, q, "FORBIDDEN")
	q, r, d, _ := fixture()
	d.Files = append(d.Files, pair("C/Body1")...)
	r.Support.Files = append(r.Support.Files, "C/Body1.uasset", "C/Body1.uexp")
	q.Recipe = pinned(r)
	q.DonorInventory = pinned(d)
	wantError(t, q, "COLLISION")
}
func TestSidecarsRemainBlocked(t *testing.T) {
	q, _, d, c := fixture()
	d.Files = append(d.Files, file("D/Body.ubulk"))
	c.Files = append(c.Files, file("C/Body2.uptnl"))
	q.DonorInventory = pinned(d)
	q.CurrentInventory = pinned(c)
	p := mustPlan(t, q)
	if len(p.Outputs) != 12 {
		t.Fatal("missing planned bulk")
	}
	n := 0
	for _, r := range p.Requirements {
		if r.Code == "BULK_LAYOUT" {
			n++
		}
	}
	if n != 2 || p.TransformReady {
		t.Fatal("bulk not guarded")
	}
	p.Tasks[0].Donor.Sidecars[0].Path = "changed"
	if p.Tasks[1].Donor.Sidecars[0].Path == "changed" {
		t.Fatal("result aliases another task")
	}
}
func TestInventoryPathRules(t *testing.T) {
	for _, s := range []string{"../x", "/absolute", "C:/x", "a\\x", "a//x", "a/./x", "a/CON.txt", "a/NUL", "a/file:stream", "a/trailing.", "a/trailing ", "a/\u00e9", "a/COM9.bin", "a/CONOUT$", "a/" + strings.Repeat("x", 256), strings.Repeat("a/", 32) + "f"} {
		t.Run(s, func(t *testing.T) {
			q, _, d, _ := fixture()
			d.Files = append(d.Files, file(s))
			q.DonorInventory = pinned(d)
			wantError(t, q, "PATH")
		})
	}
}
func TestInventoryCollisions(t *testing.T) {
	for _, s := range []string{"D/Body.uasset", "d/Other", "D/Mat", "D/Body.uasset/child"} {
		q, _, d, _ := fixture()
		d.Files = append(d.Files, file(s))
		q.DonorInventory = pinned(d)
		wantError(t, q, "COLLISION")
	}
}
func TestMissingAndBadPins(t *testing.T) {
	for i := 0; i < 3; i++ {
		q, _, _, _ := fixture()
		p := []*PinnedJSON{&q.Recipe, &q.DonorInventory, &q.CurrentInventory}[i]
		p.SHA256 = ""
		wantError(t, q, "PIN")
		q, _, _, _ = fixture()
		p = []*PinnedJSON{&q.Recipe, &q.DonorInventory, &q.CurrentInventory}[i]
		p.SHA256 = hash([]byte("wrong"))
		wantError(t, q, "PIN")
	}
}
func TestJSONStrictness(t *testing.T) {
	q, _, _, _ := fixture()
	base := q.Recipe.Data
	cases := [][]byte{append(base, base...), bytes.Replace(base, []byte(`"version":1`), []byte(`"version":1,"version":1`), 1), bytes.Replace(base, []byte(`"version":1`), []byte(`"Version":1`), 1), bytes.Replace(base, []byte(`"version":1,`), nil, 1), bytes.Replace(base, []byte(`"version":1`), []byte(`"version":null`), 1), bytes.Replace(base, []byte(`"version":1`), []byte(`"version":1,"transformReady":true`), 1), bytes.Replace(base, []byte(`"name":"body"`), []byte(`"name":"\ud800"`), 1)}
	for _, b := range cases {
		x := q
		x.Recipe = repin(b)
		wantError(t, x, "JSON")
	}
}
func TestInventoryMetadataValidation(t *testing.T) {
	q, _, d, _ := fixture()
	d.Files[0].SizeBytes = -1
	q.DonorInventory = pinned(d)
	wantError(t, q, "INVENTORY")
	d.Files[0].SizeBytes = 1
	d.Files[0].SHA256 = strings.Repeat("A", 64)
	q.DonorInventory = pinned(d)
	wantError(t, q, "INVENTORY")
	q, _, d, _ = fixture()
	d.Role = "current"
	q.DonorInventory = pinned(d)
	wantError(t, q, "INVENTORY")
}
func TestUnsupportedRecipeContracts(t *testing.T) {
	mutations := []func(*Recipe){func(r *Recipe) { r.PathHashSeed = 1 }, func(r *Recipe) { r.Version = 2 }, func(r *Recipe) { r.MountPoint = "/" }, func(r *Recipe) { r.Relocate[1].Name = "body" }, func(r *Recipe) { r.Relocate[0].PostProcess.ExpectedSerializedOffsets = []int64{120, 124} }, func(r *Recipe) { r.Signatures = append(r.Signatures, r.Signatures[0]) }, func(r *Recipe) { r.Relocate[0].TargetRegex = "[" }, func(r *Recipe) { r.Relocate[0].KnownBaselineCount = 1 }}
	for _, m := range mutations {
		q, r, _, _ := fixture()
		m(&r)
		q.Recipe = pinned(r)
		wantError(t, q, "RECIPE")
	}
}
func TestFullRegexMatching(t *testing.T) {
	q, r, _, c := fixture()
	r.Relocate[0].TargetRegex = "C/Body[0-9]+\\.uasset"
	c.Files = append(c.Files, pair("prefix/C/Body3")...)
	q.Recipe = pinned(r)
	q.CurrentInventory = pinned(c)
	p := mustPlan(t, q)
	if p.Groups[0].Count != 2 {
		t.Fatal("substring became a destination")
	}
}
func TestMissingSchemaIsARequirement(t *testing.T) {
	q, _, _, _ := fixture()
	p := mustPlan(t, q)
	n := 0
	for _, r := range p.Requirements {
		if r.Code == "POSTPROCESS_SCHEMA_PROVENANCE" {
			n++
			if r.State != "MISSING" {
				t.Fatal(r)
			}
		}
	}
	if n != 1 {
		t.Fatal("schema requirement must be per distinct donor")
	}
}
func TestSchemaClaimCannotAuthorize(t *testing.T) {
	q, r, d, c := fixture()
	claim := claimFor(q, r, d, c)
	q.SchemaClaims = []PinnedJSON{pinned(claim)}
	p := mustPlan(t, q)
	if p.TransformReady || p.InputBytesVerified || len(p.SchemaClaims) != 1 || p.SchemaClaims[0].State != "DECLARED_UNVERIFIED" {
		t.Fatal("provenance accepted as proof")
	}
	found := false
	for _, r := range p.Requirements {
		if r.Code == "POSTPROCESS_SCHEMA_PROVENANCE" {
			found = r.State == "DECLARED_UNVERIFIED"
		}
	}
	if !found {
		t.Fatal("lost requirement")
	}
}
func TestSchemaBindingsAndDuplicates(t *testing.T) {
	for _, m := range []func(*SchemaClaim){func(s *SchemaClaim) { s.DonorHeaderSHA256 = hash([]byte("wrong")) }, func(s *SchemaClaim) { s.CurrentProviderSHA256 = hash([]byte("wrong")) }, func(s *SchemaClaim) { s.RecipeSHA256 = hash([]byte("wrong")) }, func(s *SchemaClaim) { s.DonorUasset = "D/Hair.uasset" }, func(s *SchemaClaim) { s.Profile = "auto" }, func(s *SchemaClaim) { s.Origin = "" }} {
		q, r, d, c := fixture()
		s := claimFor(q, r, d, c)
		m(&s)
		q.SchemaClaims = []PinnedJSON{pinned(s)}
		wantError(t, q, "CLAIM")
	}
	q, r, d, c := fixture()
	s := pinned(claimFor(q, r, d, c))
	q.SchemaClaims = []PinnedJSON{s, s}
	wantError(t, q, "AMBIGUOUS")
}
func TestProvenanceHasNoApprovalField(t *testing.T) {
	q, r, d, c := fixture()
	b := pinned(claimFor(q, r, d, c)).Data
	b = append([]byte(`{"approved":true,`), b[1:]...)
	q.SchemaClaims = []PinnedJSON{repin(b)}
	wantError(t, q, "JSON")
}
func TestLimits(t *testing.T) {
	for _, l := range []Limits{{Files: 1}, {Outputs: 1}, {RecipeBytes: 1}, {InventoryBytes: 1}, {Claims: 65}, {Files: -1}, {RecipeBytes: ceilings.RecipeBytes + 1}} {
		q, _, _, _ := fixture()
		q.Limits = l
		wantError(t, q, "LIMIT")
	}
}
func TestDeterminismAndNoInputMutation(t *testing.T) {
	q, r, d, c := fixture()
	before := append([]byte{}, q.Recipe.Data...)
	p1 := mustPlan(t, q)
	for i, j := 0, len(d.Files)-1; i < j; i, j = i+1, j-1 {
		d.Files[i], d.Files[j] = d.Files[j], d.Files[i]
	}
	for i, j := 0, len(c.Files)-1; i < j; i, j = i+1, j-1 {
		c.Files[i], c.Files[j] = c.Files[j], c.Files[i]
	}
	r.Relocate[0], r.Relocate[1] = r.Relocate[1], r.Relocate[0]
	q2 := q
	q2.Recipe = pinned(r)
	q2.DonorInventory = pinned(d)
	q2.CurrentInventory = pinned(c)
	p2 := mustPlan(t, q2)
	p2.RecipeSHA256 = p1.RecipeSHA256
	p2.DonorInventorySHA256 = p1.DonorInventorySHA256
	p2.CurrentInventorySHA256 = p1.CurrentInventorySHA256
	if !reflect.DeepEqual(p1, p2) {
		t.Fatal("ordering changed semantic plan")
	}
	p1.Tasks[0].PostProcess.ExpectedSerializedOffsets[0] = 0
	p3 := mustPlan(t, q)
	if p3.Tasks[0].PostProcess.ExpectedSerializedOffsets[0] != 120 || !bytes.Equal(q.Recipe.Data, before) {
		t.Fatal("mutation/alias")
	}
	a, b := pinned(p2).Data, pinned(mustPlan(t, q)).Data
	if !bytes.Equal(a, b) {
		t.Fatal("not deterministic")
	}
}

type cancellation struct{ calls, at int }

func (c *cancellation) Deadline() (time.Time, bool) { return time.Time{}, false }
func (c *cancellation) Done() <-chan struct{}       { return nil }
func (c *cancellation) Value(any) any               { return nil }
func (c *cancellation) Err() error {
	c.calls++
	if c.at > 0 && c.calls >= c.at {
		return context.Canceled
	}
	return nil
}
func TestNilAndCancellationEveryBoundary(t *testing.T) {
	q, _, _, _ := fixture()
	if p, e := PlanCore(nil, q); p != nil || e == nil {
		t.Fatal("nil context")
	}
	probe := &cancellation{}
	if _, e := PlanCore(probe, q); e != nil {
		t.Fatal(e)
	}
	for i := 1; i <= probe.calls; i++ {
		p, e := PlanCore(&cancellation{at: i}, q)
		if p != nil || !errors.Is(e, context.Canceled) {
			t.Fatalf("boundary %d: %v", i, e)
		}
	}
}
func TestEveryRecipeTruncation(t *testing.T) {
	q, _, _, _ := fixture()
	for i := 0; i < len(q.Recipe.Data); i++ {
		x := q
		x.Recipe = repin(q.Recipe.Data[:i])
		if p, e := PlanCore(context.Background(), x); p != nil || e == nil {
			t.Fatalf("accepted truncation %d", i)
		}
	}
}

func FuzzPinnedRecipe(f *testing.F) {
	q, _, _, _ := fixture()
	f.Add(q.Recipe.Data)
	f.Add([]byte(`{}`))
	f.Fuzz(func(t *testing.T, b []byte) {
		if len(b) > 16384 {
			t.Skip()
		}
		x := q
		x.Recipe = repin(b)
		p, e := PlanCore(context.Background(), x)
		if e != nil && p != nil {
			t.Fatal("partial plan")
		}
		if p != nil && (p.TransformReady || p.Validated || p.Installed || p.InputBytesVerified) {
			t.Fatal("false ready")
		}
	})
}

func TestPlanFixtureExport(t *testing.T) {
	dir := os.Getenv("PMM_R1_PLAN_OUTPUT")
	if dir == "" {
		t.Skip("no synthetic export requested")
	}
	if _, e := os.Stat(dir); !os.IsNotExist(e) {
		t.Fatal("output must not exist")
	}
	if e := os.MkdirAll(dir, 0700); e != nil {
		t.Fatal(e)
	}
	for _, id := range []string{"basic", "alternative", "provenance", "bulk"} {
		q, r, d, c := fixture()
		if id == "alternative" {
			d.ProviderSHA256 = r.Signatures[1].SHA256
			q.DonorInventory = pinned(d)
		}
		if id == "provenance" {
			q.SchemaClaims = []PinnedJSON{pinned(claimFor(q, r, d, c))}
		}
		if id == "bulk" {
			d.Files = append(d.Files, file("D/Body.ubulk"))
			q.DonorInventory = pinned(d)
		}
		p := mustPlan(t, q)
		dest := filepath.Join(dir, id)
		if e := os.Mkdir(dest, 0700); e != nil {
			t.Fatal(e)
		}
		for name, data := range map[string][]byte{"recipe.json": q.Recipe.Data, "donor.json": q.DonorInventory.Data, "current.json": q.CurrentInventory.Data, "plan.json": pinned(p).Data} {
			if e := os.WriteFile(filepath.Join(dest, name), data, 0600); e != nil {
				t.Fatal(e)
			}
		}
	}
}

// Reads only the actual recipe JSON. ALL inventory file identities are artificial
// metadata; the archive identity is a DECLARATION copied from that recipe.
func TestPackagedRecipeWithSimulatedInventories(t *testing.T) {
	root := os.Getenv("PMM_R1_PACKAGE")
	if root == "" {
		t.Skip("no packaged recipe requested")
	}
	data, e := os.ReadFile(filepath.Join(root, "CKL/FixLab/Cases/FIXLAB-CASE-001-GAWR-GURA/recipe-core-r1.json"))
	if e != nil {
		t.Fatal(e)
	}
	const pin = "3f08c8da1dbc799b0c47a8a00d88819280e14ad7e21dce9f0622c7974a0c4f9c"
	if hash(data) != pin {
		t.Fatal("packaged recipe changed")
	}
	var r Recipe
	if e = json.Unmarshal(data, &r); e != nil {
		t.Fatal(e)
	}
	d := Inventory{Schema: "PMM_R1_INVENTORY_V1", Role: "donor", Build: "SIMULATED", Files: []File{}}
	c := Inventory{Schema: "PMM_R1_INVENTORY_V1", Role: "current", ProviderSHA256: hash([]byte("SIMULATED-current-provider")), Build: r.TargetBuild, Files: []File{}}
	for _, p := range r.NameSources {
		c.Files = append(c.Files, file(p))
	}
	seen := map[string]bool{}
	for _, g := range r.Relocate {
		if !seen[g.DonorUasset] {
			seen[g.DonorUasset] = true
			d.Files = append(d.Files, pair(strings.TrimSuffix(g.DonorUasset, ".uasset"))...)
		}
		for i := 0; i < g.MinimumCount; i++ {
			var p string
			switch g.Name {
			case "body":
				p = fmt.Sprintf("Pal/Content/Pal/Model/Character/Player/Outfit/Test%d/SK_Player_Female_Outfit_Test%d", i, i)
			case "head":
				p = fmt.Sprintf("Pal/Content/Pal/Model/Character/Player/Head/Head%d/SK_Player_Female_Head%d", i, i)
			case "hair":
				p = fmt.Sprintf("Pal/Content/Pal/Model/Character/Player/Hair/Hair%d/SK_Player_Hair%d", i, i)
			default:
				t.Fatal("unexpected group")
			}
			c.Files = append(c.Files, pair(p)...)
		}
	}
	for _, p := range r.Support.Files {
		d.Files = append(d.Files, file(p))
	}
	for _, p := range r.Support.Roots {
		d.Files = append(d.Files, pair(p+"/Synthetic")...)
	}
	for _, s := range r.Signatures {
		d.ProviderSHA256 = s.SHA256
		q := Request{Recipe: PinnedJSON{data, pin}, DonorInventory: pinned(d), CurrentInventory: pinned(c)}
		p := mustPlan(t, q)
		if len(p.Tasks) != 93 || len(p.NameReferences) != 4 || len(p.Outputs) != 190 || p.TransformReady || p.InputBytesVerified {
			t.Fatal("wrong declared contract plan")
		}
	}
}

func TestTargetAlternativeMatchesWholePath(t *testing.T) {
	q, r, _, _ := fixture()
	r.Relocate[0].TargetRegex = `C/Body|C/Body[0-9]+\.uasset`
	q.Recipe = pinned(r)
	p := mustPlan(t, q)
	if p.Groups[0].Count != 2 {
		t.Fatal("short alternative hid full match")
	}
}
