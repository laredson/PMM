package corer1

import (
	"bytes"
	"context"
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

func membershipFixture(t *testing.T, split bool, edit func(*[]pakv11.File, *[][]pakv11.File)) (CaptureRequest, MembershipRequest) {
	t.Helper()
	q, _ := captureFixture(t, false)
	var d, c Inventory
	json.Unmarshal(q.Plan.DonorInventory.Data, &d)
	json.Unmarshal(q.Plan.CurrentInventory.Data, &c)
	donor := []pakv11.File{}
	current := [][]pakv11.File{{}}
	if split {
		current = append(current, []pakv11.File{})
	}
	for _, f := range d.Files {
		b, e := os.ReadFile(filepath.Join(q.Roots.Donor, filepath.FromSlash(f.Path)))
		if e != nil {
			t.Fatal(e)
		}
		donor = append(donor, pakv11.File{Path: f.Path, Data: b})
	}
	for i, f := range c.Files {
		b, e := os.ReadFile(filepath.Join(q.Roots.Current, filepath.FromSlash(f.Path)))
		if e != nil {
			t.Fatal(e)
		}
		n := i % len(current)
		current[n] = append(current[n], pakv11.File{Path: f.Path, Data: b})
	}
	if edit != nil {
		edit(&donor, &current)
	}
	raw, e := pakv11.Build(context.Background(), donor, pakv11.Limits{})
	if e != nil {
		t.Fatal(e)
	}
	q.DonorArchive = put(t, q.Roots.Archives, "donor.pak", raw)
	providers := []File{}
	for i, files := range current {
		b, e := pakv11.Build(context.Background(), files, pakv11.Limits{})
		if e != nil {
			t.Fatal(e)
		}
		name := "current" + string(rune('A'+i)) + ".pak"
		providers = append(providers, put(t, q.Roots.Archives, name, b))
	}
	rebindMembership(t, &q, providers)
	return q, memberRequest(q)
}
func rebindMembership(t *testing.T, q *CaptureRequest, providers []File) {
	t.Helper()
	var d, c Inventory
	var r Recipe
	json.Unmarshal(q.Plan.DonorInventory.Data, &d)
	json.Unmarshal(q.Plan.CurrentInventory.Data, &c)
	json.Unmarshal(q.Plan.Recipe.Data, &r)
	r.Signatures[0].SHA256 = q.DonorArchive.SHA256
	d.ProviderSHA256 = q.DonorArchive.SHA256
	q.CurrentProviderSet = pinned(ProviderSet{"PMM_R1_PROVIDER_SET_V1", r.TargetBuild, providers})
	c.ProviderSHA256 = q.CurrentProviderSet.SHA256
	q.Plan.Recipe = pinned(r)
	q.Plan.DonorInventory = pinned(d)
	q.Plan.CurrentInventory = pinned(c)
}
func memberRequest(q CaptureRequest) MembershipRequest {
	return MembershipRequest{ArchivesRoot: q.Roots.Archives, DonorArchive: q.DonorArchive, CurrentProviderSet: q.CurrentProviderSet, Profile: MembershipProfile, CurrentOwnership: UniqueCurrentOwner}
}
func mustMembership(t *testing.T, c *CapturedInputs, q MembershipRequest) *MembershipEvidence {
	t.Helper()
	out, e := VerifyMembership(context.Background(), c, q)
	if e != nil || out == nil {
		t.Fatalf("membership: %v", e)
	}
	return out
}
func memberReport(t *testing.T, m *MembershipEvidence) MembershipReport {
	t.Helper()
	var r MembershipReport
	if e := json.Unmarshal(m.ReportJSON(), &r); e != nil {
		t.Fatal(e)
	}
	return r
}
func memberError(t *testing.T, c *CapturedInputs, q MembershipRequest, code string) {
	t.Helper()
	out, e := VerifyMembership(context.Background(), c, q)
	if out != nil || e == nil {
		t.Fatalf("wanted nil,error: %v %v", out, e)
	}
	if code != "" && !strings.Contains(e.Error(), code) {
		t.Fatalf("wanted %s got %v", code, e)
	}
}
func TestMembershipAllDeclaredFilesAndRealPakBytes(t *testing.T) {
	q, m := membershipFixture(t, false, nil)
	cap := mustCapture(t, q)
	out := mustMembership(t, cap, m)
	r := memberReport(t, out)
	if !r.ListedEntriesMembershipVerified || !r.AllListedProvidersParsed || !r.UniqueCurrentOwners || len(r.Entries) != 19 || len(r.Archives) != 2 {
		t.Fatal("scope")
	}
	for _, x := range r.Entries {
		b, ok := cap.Bytes(x.Role, x.File.Path)
		if !ok || !x.ByteEqual || hash(b) != x.File.SHA256 || int64(len(b)) != x.File.SizeBytes || x.EntryPath != x.File.Path {
			t.Fatal(x)
		}
	}
	if r.CaptureReportSHA256 != hash(cap.ReportJSON()) || r.PlanSHA256 != hash(cap.PlanJSON()) {
		t.Fatal("binding")
	}
}
func TestMembershipSplitProvidersUniqueOwnership(t *testing.T) {
	q, m := membershipFixture(t, true, nil)
	r := memberReport(t, mustMembership(t, mustCapture(t, q), m))
	if len(r.Archives) != 3 || len(r.Entries) != 19 {
		t.Fatal("counts")
	}
	seen := map[int]bool{}
	for _, e := range r.Entries {
		if e.Role == "current" {
			seen[e.ProviderOrdinal] = true
		}
	}
	if !seen[0] || !seen[1] {
		t.Fatal("missing provider")
	}
}
func TestMembershipDoesNotPromoteCaptureOrPlan(t *testing.T) {
	q, m := membershipFixture(t, false, nil)
	cap := mustCapture(t, q)
	a, b := cap.ReportJSON(), cap.PlanJSON()
	r := memberReport(t, mustMembership(t, cap, m))
	if r.TransformReady || r.BuildReady || r.Validated || r.Installed || r.SchemaSemanticsVerified || r.BuildAuthenticated || r.ExtractionProcessAuthenticated || r.CompleteProviderUniverse || r.CompleteFilesystemInventory || r.AtomicFilesystemSnapshot || r.UnlistedPathsOwnershipChecked || r.ProviderOrderUsedAsPriority {
		t.Fatal("overclaim")
	}
	if !bytes.Equal(a, cap.ReportJSON()) || !bytes.Equal(b, cap.PlanJSON()) || len(r.Blockers) == 0 {
		t.Fatal("capture/plan changed")
	}
}
func TestMembershipHashBoundNonPakStillRejected(t *testing.T) {
	q, _ := captureFixture(t, false)
	memberError(t, mustCapture(t, q), memberRequest(q), "PAK_PROFILE")
}
func TestMembershipMissingUnselectedAndSelectedEntries(t *testing.T) {
	for _, path := range []string{"D/Body.uasset", "D/Mat/Excluded.uexp", "D/MatExtra/Unselected.uasset", "C/Names.uasset", "C/Body1.uexp"} {
		t.Run(path, func(t *testing.T) {
			q, m := membershipFixture(t, false, func(d *[]pakv11.File, c *[][]pakv11.File) {
				filter := func(in []pakv11.File) []pakv11.File {
					var out []pakv11.File
					for _, f := range in {
						if f.Path != path {
							out = append(out, f)
						}
					}
					return out
				}
				*d = filter(*d)
				(*c)[0] = filter((*c)[0])
			})
			memberError(t, mustCapture(t, q), m, "MISSING_ENTRY")
		})
	}
}
func TestMembershipModifiedButInternallyValidPakRejected(t *testing.T) {
	q, m := membershipFixture(t, false, func(d *[]pakv11.File, c *[][]pakv11.File) { (*c)[0][0].Data = []byte("validly packed but WRONG bytes") })
	memberError(t, mustCapture(t, q), m, "MEMBERSHIP")
}
func TestMembershipDuplicateProvidersNeverSelectByHash(t *testing.T) {
	for _, mode := range []string{"identical", "different", "case"} {
		t.Run(mode, func(t *testing.T) {
			q, m := membershipFixture(t, false, func(d *[]pakv11.File, c *[][]pakv11.File) {
				f := (*c)[0][0]
				if mode == "different" {
					f.Data = []byte("other")
				}
				if mode == "case" {
					f.Path = strings.ToLower(f.Path)
				}
				*c = append(*c, []pakv11.File{f})
			})
			memberError(t, mustCapture(t, q), m, "AMBIGUOUS")
		})
	}
}
func TestMembershipSingleWrongCaseRejected(t *testing.T) {
	q, m := membershipFixture(t, false, func(d *[]pakv11.File, c *[][]pakv11.File) {
		for i := range (*c)[0] {
			(*c)[0][i].Path = strings.ToLower((*c)[0][i].Path)
		}
	})
	memberError(t, mustCapture(t, q), m, "PATH_CASE")
}
func TestMembershipParsesEvenProviderWithNoDeclaredEntries(t *testing.T) {
	q, _ := membershipFixture(t, false, nil)
	var s ProviderSet
	json.Unmarshal(q.CurrentProviderSet.Data, &s)
	s.Providers = append(s.Providers, put(t, q.Roots.Archives, "unused.pak", []byte("NOT A PAK")))
	rebindMembership(t, &q, s.Providers)
	memberError(t, mustCapture(t, q), memberRequest(q), "PAK_PROFILE")
}
func TestMembershipAllowsUnlistedEntriesWithoutCompletenessClaim(t *testing.T) {
	q, m := membershipFixture(t, false, func(d *[]pakv11.File, c *[][]pakv11.File) {
		*d = append(*d, pakv11.File{Path: "Extra/Donor.bin", Data: []byte{1, 2, 3}})
		*c = append(*c, []pakv11.File{{Path: "Extra/Current.bin", Data: []byte{4}}})
	})
	r := memberReport(t, mustMembership(t, mustCapture(t, q), m))
	if len(r.Entries) != 19 || r.Archives[2].MatchedDeclaredFiles != 0 || r.Archives[2].Entries != 1 || r.CompleteProviderUniverse {
		t.Fatal("unlisted scope")
	}
}
func TestMembershipSnapshotSurvivesAssetPathChanges(t *testing.T) {
	q, m := membershipFixture(t, false, nil)
	cap := mustCapture(t, q)
	if e := os.RemoveAll(q.Roots.Donor); e != nil {
		t.Fatal(e)
	}
	if e := os.RemoveAll(q.Roots.Current); e != nil {
		t.Fatal(e)
	}
	mustMembership(t, cap, m) // Only archive paths are re-opened, not asset folders.
}
func TestMembershipRechecksArchivesAfterCapture(t *testing.T) {
	for _, mode := range []string{"same-size", "short", "missing", "new-pin"} {
		t.Run(mode, func(t *testing.T) {
			q, m := membershipFixture(t, false, nil)
			cap := mustCapture(t, q)
			path := filepath.Join(q.Roots.Archives, q.DonorArchive.Path)
			switch mode {
			case "same-size":
				b, _ := os.ReadFile(path)
				b[53] ^= 1
				os.WriteFile(path, b, 0600)
			case "short":
				os.WriteFile(path, []byte("x"), 0600)
			case "missing":
				os.Remove(path)
			case "new-pin":
				m.DonorArchive = put(t, q.Roots.Archives, q.DonorArchive.Path, []byte("x"))
			}
			memberError(t, cap, m, "")
		})
	}
}
func TestMembershipProviderSetBindings(t *testing.T) {
	for _, mode := range []string{"wrong-pin", "changed-bytes", "omitted-provider", "order", "extra"} {
		t.Run(mode, func(t *testing.T) {
			q, m := membershipFixture(t, true, nil)
			cap := mustCapture(t, q)
			var s ProviderSet
			json.Unmarshal(m.CurrentProviderSet.Data, &s)
			switch mode {
			case "wrong-pin":
				m.CurrentProviderSet.SHA256 = strings.Repeat("0", 64)
			case "changed-bytes":
				m.CurrentProviderSet.Data = []byte("{}")
			case "omitted-provider":
				s.Providers = s.Providers[:1]
				m.CurrentProviderSet = pinned(s)
			case "order":
				s.Providers[0], s.Providers[1] = s.Providers[1], s.Providers[0]
				m.CurrentProviderSet = pinned(s)
			case "extra":
				s.Providers = append(s.Providers, m.DonorArchive)
				m.CurrentProviderSet = pinned(s)
			}
			memberError(t, cap, m, "")
		})
	}
}
func TestMembershipExplicitPolicyAndProfile(t *testing.T) {
	q, m := membershipFixture(t, false, nil)
	cap := mustCapture(t, q)
	for _, v := range []string{"", "PAK_ANY", "first-wins", "last-wins"} {
		x := m
		x.Profile = v
		memberError(t, cap, x, "UNSUPPORTED")
		x = m
		x.CurrentOwnership = v
		memberError(t, cap, x, "UNSUPPORTED")
	}
}
func TestMembershipLimitsBeforeFilesystem(t *testing.T) {
	q, m := membershipFixture(t, true, nil)
	cap := mustCapture(t, q)
	m.ArchivesRoot = "invalid-root"
	for _, lim := range []MembershipLimits{{ArchiveBytes: -1}, {ArchiveBytes: 257 << 20}, {TotalArchiveBytes: 2 << 30}, {Providers: 65}, {Providers: 1}, {ArchiveBytes: 1}, {TotalArchiveBytes: 1}} {
		x := m
		x.Limits = lim
		memberError(t, cap, x, "LIMIT")
	}
}
func TestMembershipNilSnapshotAndContext(t *testing.T) {
	q, m := membershipFixture(t, false, nil)
	cap := mustCapture(t, q)
	if v, e := VerifyMembership(nil, cap, m); v != nil || e == nil {
		t.Fatal("nil ctx")
	}
	memberError(t, nil, m, "SNAPSHOT")
	memberError(t, &CapturedInputs{}, m, "SNAPSHOT")
	var empty *MembershipEvidence
	if empty.ReportJSON() != nil {
		t.Fatal("nil evidence")
	}
}
func TestMembershipCancellationAtEveryBoundary(t *testing.T) {
	q, m := membershipFixture(t, true, nil)
	cap := mustCapture(t, q)
	probe := &cancellation{}
	if _, e := VerifyMembership(probe, cap, m); e != nil {
		t.Fatal(e)
	}
	for i := 1; i <= probe.calls; i++ {
		ctx := &cancellation{at: i}
		out, e := VerifyMembership(ctx, cap, m)
		if out != nil || !errors.Is(e, context.Canceled) {
			t.Fatalf("boundary %d: %v", i, e)
		}
	}
}
func TestMembershipDeterminismNoAliasesOrRequestMutation(t *testing.T) {
	q, m := membershipFixture(t, true, nil)
	cap := mustCapture(t, q)
	before := append([]byte{}, m.CurrentProviderSet.Data...)
	a := mustMembership(t, cap, m)
	b := mustMembership(t, cap, m)
	if !bytes.Equal(a.ReportJSON(), b.ReportJSON()) || !bytes.Equal(before, m.CurrentProviderSet.Data) {
		t.Fatal("nondeterministic/mutating")
	}
	got := a.ReportJSON()
	got[0] = '!'
	if a.ReportJSON()[0] != '{' {
		t.Fatal("alias")
	}
}
func TestMembershipConcurrentChecksShareImmutableCapture(t *testing.T) {
	q, m := membershipFixture(t, true, nil)
	cap := mustCapture(t, q)
	var wg sync.WaitGroup
	var outs [4][]byte
	var errs [4]error
	for i := range outs {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			v, e := VerifyMembership(context.Background(), cap, m)
			errs[i] = e
			if v != nil {
				outs[i] = v.ReportJSON()
			}
		}(i)
	}
	wg.Wait()
	for i := range outs {
		if errs[i] != nil || !bytes.Equal(outs[0], outs[i]) {
			t.Fatal(errs[i])
		}
	}
}
func TestMembershipCorruptIndexEvenWhenArchiveHashPinned(t *testing.T) {
	q, _ := membershipFixture(t, false, nil)
	b, _ := os.ReadFile(filepath.Join(q.Roots.Archives, q.DonorArchive.Path))
	b[len(b)-1] = 1
	q.DonorArchive = put(t, q.Roots.Archives, q.DonorArchive.Path, b)
	var s ProviderSet
	json.Unmarshal(q.CurrentProviderSet.Data, &s)
	rebindMembership(t, &q, s.Providers)
	memberError(t, mustCapture(t, q), memberRequest(q), "PAK_PROFILE")
}
func TestMembershipRetainedSnapshotAndReportBindingChecks(t *testing.T) {
	q, m := membershipFixture(t, false, nil)
	for _, mode := range []string{"data", "plan", "file-list"} {
		cap := mustCapture(t, q)
		switch mode {
		case "data":
			cap.data["donor:D/Body.uasset"][0] ^= 1
		case "plan":
			cap.planJSON[0] = '!'
		case "file-list":
			var r CaptureReport
			json.Unmarshal(cap.reportJSON, &r)
			r.Files = append(r.Files, r.Files[0])
			cap.reportJSON, _ = json.Marshal(r)
		}
		memberError(t, cap, m, "")
	}
}
func TestMembershipMultiBlockByteComparison(t *testing.T) {
	a := bytes.Repeat([]byte{0, 255, 2}, 1<<20)
	b := append([]byte{}, a...)
	ok, e := membershipEqual(context.Background(), a, b)
	if !ok || e != nil {
		t.Fatal(e)
	}
	b[len(b)-1] ^= 1
	ok, e = membershipEqual(context.Background(), a, b)
	if ok || e != nil {
		t.Fatal("last byte")
	}
	h, e := membershipDigest(context.Background(), a)
	if h != hash(a) || e != nil {
		t.Fatal("chunk digest")
	}
}
func TestMembershipFixtureExport(t *testing.T) {
	root := os.Getenv("PMM_R1_MEMBERSHIP_OUTPUT")
	if root == "" {
		t.Skip("synthetic export opt-in")
	}
	if _, e := os.Stat(root); !os.IsNotExist(e) {
		t.Fatal("output must be new")
	}
	for _, name := range []string{"single", "split", "extras"} {
		var edit func(*[]pakv11.File, *[][]pakv11.File)
		if name == "extras" {
			edit = func(d *[]pakv11.File, c *[][]pakv11.File) {
				*d = append(*d, pakv11.File{Path: "Extra/Empty.bin", Data: []byte{}})
				*c = append(*c, []pakv11.File{{Path: "Extra/Binary.bin", Data: []byte{0, 255, 7}}})
			}
		}
		q, m := membershipFixture(t, name == "split", edit)
		cap := mustCapture(t, q)
		ev := mustMembership(t, cap, m)
		dir := filepath.Join(root, name)
		if e := os.MkdirAll(dir, 0700); e != nil {
			t.Fatal(e)
		}
		write := func(path string, b []byte) {
			t.Helper()
			p := filepath.Join(dir, filepath.FromSlash(path))
			os.MkdirAll(filepath.Dir(p), 0700)
			if e := os.WriteFile(p, b, 0600); e != nil {
				t.Fatal(e)
			}
		}
		write("report.json", ev.ReportJSON())
		write("capture.json", cap.ReportJSON())
		write("plan.json", cap.PlanJSON())
		write("provider-set.json", q.CurrentProviderSet.Data)
		for _, row := range report(t, cap).Files {
			if row.Role == "archive" {
				b, e := os.ReadFile(filepath.Join(q.Roots.Archives, filepath.FromSlash(row.File.Path)))
				if e != nil {
					t.Fatal(e)
				}
				write("archives/"+row.File.Path, b)
			} else {
				b, _ := cap.Bytes(row.Role, row.File.Path)
				write("assets/"+row.Role+"/"+row.File.Path, b)
			}
		}
	}
}

func FuzzMembershipProviderBindings(f *testing.F) {
	donor := File{"donor.pak", hash([]byte("donor")), 100}
	current := File{"current.pak", hash([]byte("current")), 100}
	set := pinned(ProviderSet{"PMM_R1_PROVIDER_SET_V1", "SYNTHETIC", []File{current}})
	f.Add(set.Data)
	f.Add([]byte("{}"))
	f.Add([]byte(`{"providers":null}`))
	f.Fuzz(func(t *testing.T, b []byte) {
		if len(b) > 128<<10 {
			return
		}
		pj := pinned(Plan{Schema: "PMM_CORE_R1_PLAN_V1", Status: "PLAN_VALID", DeclaredDonor: Signature{SHA256: donor.SHA256}, DeclaredCurrentProvider: hash(b), TargetBuild: "SYNTHETIC"})
		file := File{"A.uasset", hash(nil), 0}
		r := CaptureReport{Schema: "PMM_R1_CAPTURE_REPORT_V1", PlanSHA256: pj.SHA256, ProviderSetSHA256: hash(b), ListedAssetBytesVerified: true, ListedArchiveBytesVerified: true, Files: []CapturedFile{{"archive", donor, false}, {"archive", current, false}, {"donor", file, true}, {"current", file, true}}}
		raw, _ := json.Marshal(r)
		c := &CapturedInputs{data: map[string][]byte{"donor:A.uasset": {}, "current:A.uasset": {}}, reportJSON: raw, planJSON: pj.Data}
		req := MembershipRequest{DonorArchive: donor, CurrentProviderSet: repin(b), Profile: MembershipProfile, CurrentOwnership: UniqueCurrentOwner}
		lim, _ := (MembershipLimits{}).checked()
		out, e := prepareMembership(context.Background(), c, req, lim)
		if e != nil && out != nil {
			t.Fatal("partial output")
		}
		if out != nil && !reflect.DeepEqual(out.providers.Providers, []File{current}) {
			t.Fatal("wrong binding")
		}
	})
}

func TestMembershipEmptyAndBinaryCapturedEntries(t *testing.T) {
	emptyPath, binaryPath := "D/Body.uasset", "C/Names.uasset"
	binaryData := []byte{0, 255, 1, 0, 128, 254}
	q, m := membershipFixture(t, false, func(d *[]pakv11.File, c *[][]pakv11.File) {
		for i := range *d {
			if (*d)[i].Path == emptyPath {
				(*d)[i].Data = []byte{}
			}
		}
		for i := range (*c)[0] {
			if (*c)[0][i].Path == binaryPath {
				(*c)[0][i].Data = binaryData
			}
		}
	})
	var d, c Inventory
	json.Unmarshal(q.Plan.DonorInventory.Data, &d)
	json.Unmarshal(q.Plan.CurrentInventory.Data, &c)
	for i := range d.Files {
		if d.Files[i].Path == emptyPath {
			d.Files[i] = put(t, q.Roots.Donor, emptyPath, []byte{})
		}
	}
	for i := range c.Files {
		if c.Files[i].Path == binaryPath {
			c.Files[i] = put(t, q.Roots.Current, binaryPath, binaryData)
		}
	}
	q.Plan.DonorInventory = pinned(d)
	q.Plan.CurrentInventory = pinned(c)
	r := memberReport(t, mustMembership(t, mustCapture(t, q), m))
	if len(r.Entries) != 19 {
		t.Fatal("dropped zero-length file")
	}
}
