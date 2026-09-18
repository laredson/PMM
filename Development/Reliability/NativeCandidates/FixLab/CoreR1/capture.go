package corer1

import (
	"context"
	"encoding/json"
	"errors"
	"sort"
	"strings"
)

// Roots are caller-selected, existing, canonical absolute directories. Inventory
// paths remain relative. ArchiveRoot contains the donor and current provider PAKs.
type CaptureRoots struct{ Donor, Current, Archives, Schemas string }
type CaptureLimits struct {
	FileBytes, SnapshotBytes, ArchiveBytes, TotalArchiveBytes int64
	Providers                                                 int
}

var captureCeilings = CaptureLimits{256 << 20, 512 << 20, 64 << 30, 128 << 30, 64}

func (l CaptureLimits) checked() (CaptureLimits, error) {
	v := []*int64{&l.FileBytes, &l.SnapshotBytes, &l.ArchiveBytes, &l.TotalArchiveBytes}
	max := []int64{captureCeilings.FileBytes, captureCeilings.SnapshotBytes, captureCeilings.ArchiveBytes, captureCeilings.TotalArchiveBytes}
	for i, p := range v {
		if *p == 0 {
			*p = max[i]
		}
		if *p < 1 || *p > max[i] {
			return l, fail("LIMIT", "capture", "ceilings may only be reduced")
		}
	}
	if l.Providers == 0 {
		l.Providers = captureCeilings.Providers
	}
	if l.Providers < 1 || l.Providers > captureCeilings.Providers {
		return l, fail("LIMIT", "providers", "count ceiling")
	}
	return l, nil
}

// The hash of these exact JSON bytes is CurrentInventory.ProviderSHA256.
// It binds a listed provider set, NOT an extraction proof or authenticated build.
type ProviderSet struct {
	Schema    string `json:"schema"`
	Build     string `json:"build"`
	Providers []File `json:"providers"`
}
type DossierFiles struct {
	ClaimSHA256    string
	Layout, Review File
}
type CaptureRequest struct {
	Plan               Request
	Roots              CaptureRoots
	DonorArchive       File
	CurrentProviderSet PinnedJSON
	Dossiers           []DossierFiles
	Limits             CaptureLimits
}
type CapturedFile struct {
	Role     string `json:"role"`
	File     File   `json:"file"`
	Retained bool   `json:"retainedInMemory"`
}
type DossierResult struct {
	ClaimSHA256             string `json:"claimSHA256"`
	Layout                  File   `json:"layout"`
	Review                  File   `json:"review"`
	State                   string `json:"state"`
	LayoutProfile           string `json:"layoutProfile"`
	FieldCount              int    `json:"fieldCount"`
	BytesVerified           bool   `json:"bytesVerified"`
	BindingsChecked         bool   `json:"bindingsChecked"`
	LayoutSemanticsVerified bool   `json:"layoutSemanticsVerified"`
	ReviewerAuthenticated   bool   `json:"reviewerAuthenticated"`
}
type CaptureReport struct {
	Schema                       string          `json:"schema"`
	Status                       string          `json:"status"`
	PlanSHA256                   string          `json:"planSHA256"`
	ProviderSetSHA256            string          `json:"providerSetSHA256"`
	Files                        []CapturedFile  `json:"files"`
	Dossiers                     []DossierResult `json:"dossiers"`
	SnapshotBytes                int64           `json:"snapshotBytes"`
	ArchiveBytesRead             int64           `json:"archiveBytesRead"`
	ListedAssetBytesVerified     bool            `json:"listedAssetBytesVerified"`
	ListedArchiveBytesVerified   bool            `json:"listedArchiveBytesVerified"`
	CompleteFilesystemInventory  bool            `json:"completeFilesystemInventory"`
	AtomicFilesystemSnapshot     bool            `json:"atomicFilesystemSnapshot"`
	ExtractionMembershipVerified bool            `json:"extractionMembershipVerified"`
	BuildAuthenticated           bool            `json:"buildAuthenticated"`
	TransformReady               bool            `json:"transformReady"`
	BuildReady                   bool            `json:"buildReady"`
	Validated                    bool            `json:"validated"`
	Installed                    bool            `json:"installed"`
	Blockers                     []string        `json:"blockers"`
}

// CapturedInputs owns byte copies. Accessors never expose its backing buffers.
// This object is not an authorization token for transforms or a filesystem view.
type CapturedInputs struct {
	data                 map[string][]byte
	reportJSON, planJSON []byte
}

func (c *CapturedInputs) Bytes(role, path string) ([]byte, bool) {
	b, ok := c.data[role+":"+path]
	if !ok {
		return nil, false
	}
	return append([]byte{}, b...), true
}
func (c *CapturedInputs) ReportJSON() []byte { return append([]byte{}, c.reportJSON...) }
func (c *CapturedInputs) PlanJSON() []byte   { return append([]byte{}, c.planJSON...) }

// CaptureCore leaves the planner unmodified. It verifies all DECLARED inventory
// entries, provider archive bytes, and referenced schema documents. It does not
// extract archives or prove file membership, semantic layouts, or game behavior.
// Caller must keep request documents immutable during this call.
func CaptureCore(ctx context.Context, q CaptureRequest) (out *CapturedInputs, err error) {
	if ctx == nil {
		return nil, fail("CONTEXT", "capture", "nil context")
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	l, e := q.Limits.checked()
	if e != nil {
		return nil, e
	}
	p, e := PlanCore(ctx, q.Plan)
	if e != nil {
		return nil, e
	}
	pl, e := q.Plan.Limits.checked()
	if e != nil {
		return nil, e
	}
	var d, c Inventory
	var providers ProviderSet
	if e = decode(ctx, q.Plan.DonorInventory, pl.InventoryBytes, "donor inventory", &d); e != nil {
		return nil, e
	}
	if e = decode(ctx, q.Plan.CurrentInventory, pl.InventoryBytes, "current inventory", &c); e != nil {
		return nil, e
	}
	if q.CurrentProviderSet.SHA256 != c.ProviderSHA256 {
		return nil, fail("BINDING", "provider set", "inventory hash differs")
	}
	if e = decode(ctx, q.CurrentProviderSet, 128<<10, "provider set", &providers); e != nil {
		return nil, e
	}
	if providers.Schema != "PMM_R1_PROVIDER_SET_V1" || providers.Build != p.TargetBuild || len(providers.Providers) < 1 || len(providers.Providers) > l.Providers {
		return nil, fail("PROVIDERS", "set", "schema/build/count")
	}
	if q.DonorArchive.SHA256 != d.ProviderSHA256 {
		return nil, fail("BINDING", "donor archive", "not the accepted inventory provider")
	}
	archives := append([]File{q.DonorArchive}, providers.Providers...)
	used, paths := map[string]string{}, map[string]bool{}
	var archiveTotal, snapshotTotal int64
	for _, f := range archives {
		if e = addPath(used, paths, f.Path); e != nil {
			return nil, e
		}
		if !strings.HasSuffix(f.Path, ".pak") || !validHash(f.SHA256) || f.SizeBytes < 0 || f.SizeBytes > l.ArchiveBytes || f.SizeBytes > l.TotalArchiveBytes-archiveTotal {
			return nil, fail("LIMIT", f.Path, "invalid archive pin/type/size or aggregate")
		}
		archiveTotal += f.SizeBytes
	}
	for _, inv := range []Inventory{d, c} {
		for _, f := range inv.Files {
			if e = ctx.Err(); e != nil {
				return nil, e
			}
			if f.SizeBytes < 0 || f.SizeBytes > l.FileBytes || f.SizeBytes > l.SnapshotBytes-snapshotTotal {
				return nil, fail("LIMIT", f.Path, "snapshot size")
			}
			snapshotTotal += f.SizeBytes
		}
	}
	if len(q.Dossiers) != len(p.SchemaClaims) {
		return nil, fail("DOSSIER", "count", "each claim requires exactly one layout/review pair")
	}
	byClaim := map[string]DossierFiles{}
	docPins := map[string]File{}
	docUsed, docPaths := map[string]string{}, map[string]bool{}
	for _, x := range q.Dossiers {
		if !validHash(x.ClaimSHA256) {
			return nil, fail("PIN", "dossier", "claim hash")
		}
		if _, ok := byClaim[x.ClaimSHA256]; ok {
			return nil, fail("DOSSIER", "claim", "duplicate")
		}
		byClaim[x.ClaimSHA256] = x
		for _, f := range []File{x.Layout, x.Review} {
			if !strings.HasSuffix(f.Path, ".json") || !validHash(f.SHA256) || f.SizeBytes <= 0 || f.SizeBytes > 128<<10 {
				return nil, fail("DOSSIER", f.Path, "expected bounded JSON document")
			}
			if old, ok := docPins[f.Path]; ok {
				if old != f {
					return nil, fail("DOSSIER", f.Path, "conflicting document pin")
				}
				continue
			}
			if e = addPath(docUsed, docPaths, f.Path); e != nil {
				return nil, e
			}
			if f.SizeBytes > l.SnapshotBytes-snapshotTotal {
				return nil, fail("LIMIT", "dossiers", "snapshot aggregate")
			}
			snapshotTotal += f.SizeBytes
			docPins[f.Path] = f
		}
	}
	for _, claim := range p.SchemaClaims {
		x, ok := byClaim[claim.SHA256]
		if !ok || x.Layout.SHA256 != claim.Claim.LayoutSHA256 || x.Review.SHA256 != claim.Claim.ReviewRecordSHA256 {
			return nil, fail("BINDING", "dossier", "claim/layout/review mismatch")
		}
	}
	// All metadata, capacities and document bindings are checked BEFORE filesystem I/O.
	roots := map[string]*anchoredRoot{}
	defer func() {
		for _, r := range roots {
			err = errors.Join(err, r.Close())
		}
		if err != nil {
			out = nil
		}
	}()
	for _, item := range []struct{ role, path string }{{"donor", q.Roots.Donor}, {"current", q.Roots.Current}, {"archives", q.Roots.Archives}} {
		r, e := openRoot(item.path)
		if e != nil {
			return nil, e
		}
		roots[item.role] = r
	}
	if len(docPins) > 0 {
		r, e := openRoot(q.Roots.Schemas)
		if e != nil {
			return nil, e
		}
		roots["schema"] = r
	}
	result := &CapturedInputs{data: map[string][]byte{}}
	rep := CaptureReport{Schema: "PMM_R1_CAPTURE_REPORT_V1", Status: "SNAPSHOT_BYTES_VERIFIED_NOT_TRANSFORM_READY", ProviderSetSHA256: q.CurrentProviderSet.SHA256, Files: []CapturedFile{}, Dossiers: []DossierResult{}, SnapshotBytes: snapshotTotal, ArchiveBytesRead: archiveTotal, Blockers: []string{"ARCHIVE_ENTRY_MEMBERSHIP_UNPROVED", "BUILD_PROVENANCE_UNAUTHENTICATED", "REAL_SCHEMA_SEMANTICS_UNVERIFIED", "OPAQUE_RELOCATION_UNSUPPORTED", "CORE_EXECUTOR_NOT_IMPLEMENTED"}}
	// Archives are STREAMED, not retained. Metadata is evidence of this read, not a
	// guarantee that paths still contain the same bytes after their handles close.
	for _, f := range archives {
		if _, e = captureFile(ctx, roots["archives"], f, false, l.ArchiveBytes, nil); e != nil {
			return nil, e
		}
		rep.Files = append(rep.Files, CapturedFile{"archive", f, false})
	}
	for _, inv := range []Inventory{d, c} {
		fs := append([]File{}, inv.Files...)
		sort.Slice(fs, func(i, j int) bool { return fs[i].Path < fs[j].Path })
		for _, f := range fs {
			b, e := captureFile(ctx, roots[inv.Role], f, true, l.FileBytes, nil)
			if e != nil {
				return nil, e
			}
			result.data[inv.Role+":"+f.Path] = b
			rep.Files = append(rep.Files, CapturedFile{inv.Role, f, true})
		}
	}
	keys := make([]string, 0, len(docPins))
	for k := range docPins {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, path := range keys {
		f := docPins[path]
		b, e := captureFile(ctx, roots["schema"], f, true, 128<<10, nil)
		if e != nil {
			return nil, e
		}
		result.data["schema:"+path] = b
		rep.Files = append(rep.Files, CapturedFile{"schema", f, true})
	}
	for _, claim := range p.SchemaClaims {
		x := byClaim[claim.SHA256]
		dr, e := verifyDossier(ctx, claim, x, result.data["schema:"+x.Layout.Path], result.data["schema:"+x.Review.Path])
		if e != nil {
			return nil, e
		}
		rep.Dossiers = append(rep.Dossiers, dr)
	}
	rep.ListedAssetBytesVerified = true
	rep.ListedArchiveBytesVerified = true
	result.planJSON, e = json.Marshal(p)
	if e != nil {
		return nil, e
	}
	rep.PlanSHA256 = bytesDigest(result.planJSON)
	sort.Slice(rep.Files, func(i, j int) bool {
		a, b := rep.Files[i], rep.Files[j]
		if a.Role == b.Role {
			return a.File.Path < b.File.Path
		}
		return a.Role < b.Role
	})
	result.reportJSON, e = json.MarshalIndent(rep, "", "  ")
	if e != nil {
		return nil, e
	}
	if e = ctx.Err(); e != nil {
		return nil, e
	}
	// Close errors must also suppress the object. Close explicitly before success.
	for name, r := range roots {
		e = r.Close()
		delete(roots, name)
		if e != nil {
			return nil, e
		}
	}
	return result, nil
}
