package corer1

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strings"

	pakv11 "pmm.local/fixlab/pakv11"
)

// This profile is deliberately narrower than all possible PAK v11 files.
const MembershipProfile = "PAKV11_ASCII_COMPACT32_PHI_FDI_UNCOMPRESSED_V1"
const UniqueCurrentOwner = "UNIQUE_OWNER_ONLY_V1"

// ArchiveBytes is also constrained by PAKV11. All limits may only be reduced.
// These are input/work limits, not RSS guarantees or kernel-I/O deadlines.
type MembershipLimits struct {
	ArchiveBytes, TotalArchiveBytes int64
	Providers                       int
}

func (l MembershipLimits) checked() (MembershipLimits, error) {
	if l.ArchiveBytes == 0 {
		l.ArchiveBytes = 256 << 20
	}
	if l.TotalArchiveBytes == 0 {
		l.TotalArchiveBytes = 1 << 30
	}
	if l.Providers == 0 {
		l.Providers = 64
	}
	if l.ArchiveBytes < 1 || l.ArchiveBytes > 256<<20 || l.TotalArchiveBytes < 1 || l.TotalArchiveBytes > 1<<30 || l.Providers < 1 || l.Providers > 64 {
		return l, fail("LIMIT", "membership", "ceilings may only be reduced")
	}
	return l, nil
}

type MembershipRequest struct {
	ArchivesRoot              string
	DonorArchive              File
	CurrentProviderSet        PinnedJSON
	Profile, CurrentOwnership string
	Limits                    MembershipLimits
}
type EntryMembership struct {
	Role            string `json:"role"`
	File            File   `json:"file"`
	Archive         File   `json:"archive"`
	ProviderOrdinal int    `json:"providerOrdinal"` // -1 for donor; NOT a priority
	EntryPath       string `json:"entryPath"`
	ByteEqual       bool   `json:"byteEqual"`
}
type CheckedArchive struct {
	Role                 string `json:"role"`
	File                 File   `json:"file"`
	ProviderOrdinal      int    `json:"providerOrdinal"`
	Entries              int    `json:"entries"`
	MatchedDeclaredFiles int    `json:"matchedDeclaredFiles"`
}
type MembershipReport struct {
	Schema                          string            `json:"schema"`
	Status                          string            `json:"status"`
	Profile                         string            `json:"profile"`
	CurrentOwnership                string            `json:"currentOwnership"`
	Scope                           string            `json:"scope"`
	CaptureReportSHA256             string            `json:"captureReportSHA256"`
	PlanSHA256                      string            `json:"planSHA256"`
	ProviderSetSHA256               string            `json:"providerSetSHA256"`
	Archives                        []CheckedArchive  `json:"archives"`
	Entries                         []EntryMembership `json:"entries"`
	ArchiveBytesRead                int64             `json:"archiveBytesRead"`
	ListedEntriesMembershipVerified bool              `json:"listedEntriesMembershipVerified"`
	AllListedProvidersParsed        bool              `json:"allListedProvidersParsed"`
	UniqueCurrentOwners             bool              `json:"uniqueCurrentOwners"`
	ProviderOrderUsedAsPriority     bool              `json:"providerOrderUsedAsPriority"`
	UnlistedPathsOwnershipChecked   bool              `json:"unlistedPathsOwnershipChecked"`
	ExtractionProcessAuthenticated  bool              `json:"extractionProcessAuthenticated"`
	CompleteFilesystemInventory     bool              `json:"completeFilesystemInventory"`
	CompleteProviderUniverse        bool              `json:"completeProviderUniverse"`
	AtomicFilesystemSnapshot        bool              `json:"atomicFilesystemSnapshot"`
	BuildAuthenticated              bool              `json:"buildAuthenticated"`
	SchemaSemanticsVerified         bool              `json:"schemaSemanticsVerified"`
	TransformReady                  bool              `json:"transformReady"`
	BuildReady                      bool              `json:"buildReady"`
	Validated                       bool              `json:"validated"`
	Installed                       bool              `json:"installed"`
	Blockers                        []string          `json:"blockers"`
}

// Evidence describes a byte relationship, never an authorization to run repairs.
// There is no public constructor from caller-controlled JSON.
type MembershipEvidence struct{ reportJSON []byte }

func (m *MembershipEvidence) ReportJSON() []byte {
	if m == nil {
		return nil
	}
	return append([]byte{}, m.reportJSON...)
}

type membershipInputs struct {
	report    CaptureReport
	plan      Plan
	providers ProviderSet
	wanted    map[string]map[string]File // role -> lowercase path -> exact descriptor
}

func membershipDigest(ctx context.Context, b []byte) (string, error) {
	h := sha256.New()
	for len(b) > 0 {
		if e := ctx.Err(); e != nil {
			return "", e
		}
		n := len(b)
		if n > 1<<20 {
			n = 1 << 20
		}
		h.Write(b[:n])
		b = b[n:]
	}
	return hex.EncodeToString(h.Sum(nil)), ctx.Err()
}
func membershipEqual(ctx context.Context, a, b []byte) (bool, error) {
	if len(a) != len(b) {
		return false, nil
	}
	for len(a) > 0 {
		if e := ctx.Err(); e != nil {
			return false, e
		}
		n := len(a)
		if n > 1<<20 {
			n = 1 << 20
		}
		if !bytes.Equal(a[:n], b[:n]) {
			return false, nil
		}
		a, b = a[n:], b[n:]
	}
	return true, ctx.Err()
}

// Validate the retained CaptureCore result and all request bindings before I/O.
// The capture report is internally generated; it is not an import format.
func prepareMembership(ctx context.Context, c *CapturedInputs, q MembershipRequest, l MembershipLimits) (*membershipInputs, error) {
	if c == nil || len(c.reportJSON) == 0 || len(c.planJSON) == 0 || c.data == nil {
		return nil, fail("SNAPSHOT", "membership", "CaptureCore result required")
	}
	x := &membershipInputs{wanted: map[string]map[string]File{"donor": {}, "current": {}}}
	if e := json.Unmarshal(c.reportJSON, &x.report); e != nil {
		return nil, e
	}
	if e := json.Unmarshal(c.planJSON, &x.plan); e != nil {
		return nil, e
	}
	r, p := x.report, x.plan
	if r.Schema != "PMM_R1_CAPTURE_REPORT_V1" || !r.ListedAssetBytesVerified || !r.ListedArchiveBytesVerified || p.Schema != "PMM_CORE_R1_PLAN_V1" || p.Status != "PLAN_VALID" || r.PlanSHA256 != bytesDigest(c.planJSON) || r.ProviderSetSHA256 != p.DeclaredCurrentProvider {
		return nil, fail("SNAPSHOT", "membership", "incomplete or inconsistent capture")
	}
	if q.Profile != MembershipProfile || q.CurrentOwnership != UniqueCurrentOwner {
		return nil, fail("UNSUPPORTED", "membership", "explicit profile and unique-owner policy required")
	}
	if q.CurrentProviderSet.SHA256 != r.ProviderSetSHA256 {
		return nil, fail("BINDING", "provider set", "not the captured provider set")
	}
	if e := decode(ctx, q.CurrentProviderSet, 128<<10, "provider set", &x.providers); e != nil {
		return nil, e
	}
	if len(x.providers.Providers) > l.Providers {
		return nil, fail("LIMIT", "providers", "membership count")
	}
	if x.providers.Schema != "PMM_R1_PROVIDER_SET_V1" || x.providers.Build != p.TargetBuild || len(x.providers.Providers) < 1 || len(x.providers.Providers) > l.Providers {
		return nil, fail("PROVIDERS", "set", "schema/build/count")
	}
	if q.DonorArchive.SHA256 != p.DeclaredDonor.SHA256 {
		return nil, fail("BINDING", "donor", "not the captured allowed donor")
	}
	archives := append([]File{q.DonorArchive}, x.providers.Providers...)
	expectedArchives := map[string]File{}
	used, paths := map[string]string{}, map[string]bool{}
	var total int64
	for _, f := range archives {
		if e := ctx.Err(); e != nil {
			return nil, e
		}
		if e := addPath(used, paths, f.Path); e != nil {
			return nil, e
		}
		if !strings.HasSuffix(f.Path, ".pak") || !validHash(f.SHA256) || f.SizeBytes < 0 || f.SizeBytes > l.ArchiveBytes || f.SizeBytes > l.TotalArchiveBytes-total {
			return nil, fail("LIMIT", f.Path, "archive descriptor/profile/aggregate")
		}
		total += f.SizeBytes
		expectedArchives[f.Path] = f
	}
	gotArchives := map[string]File{}
	for _, row := range r.Files {
		if e := ctx.Err(); e != nil {
			return nil, e
		}
		if row.Role == "archive" {
			if _, ok := gotArchives[row.File.Path]; ok {
				return nil, fail("SNAPSHOT", "archives", "duplicate")
			}
			gotArchives[row.File.Path] = row.File
			continue
		}
		if row.Role == "schema" {
			continue
		} // 5B dossier evidence is neither changed nor promoted.
		want, ok := x.wanted[row.Role]
		if !ok {
			return nil, fail("SNAPSHOT", row.Role, "unknown role")
		}
		f := row.File
		if e := safePath(f.Path); e != nil {
			return nil, e
		}
		if !row.Retained || f.SizeBytes < 0 || f.SizeBytes > 64<<20 || !validHash(f.SHA256) {
			return nil, fail("LIMIT", f.Path, "asset outside retained PAK profile")
		}
		key := strings.ToLower(f.Path)
		if _, ok := want[key]; ok {
			return nil, fail("SNAPSHOT", f.Path, "duplicate/case collision")
		}
		if len(want) >= 16384 {
			return nil, fail("LIMIT", "membership entries", "role count")
		}
		b, ok := c.data[row.Role+":"+f.Path]
		if !ok || int64(len(b)) != f.SizeBytes {
			return nil, fail("SNAPSHOT", f.Path, "missing bytes or wrong size")
		}
		h, e := membershipDigest(ctx, b)
		if e != nil {
			return nil, e
		}
		if h != f.SHA256 {
			return nil, fail("SNAPSHOT", f.Path, "retained hash mismatch")
		}
		want[key] = f
	}
	if len(gotArchives) != len(expectedArchives) || len(x.wanted["donor"]) == 0 || len(x.wanted["current"]) == 0 {
		return nil, fail("BINDING", "capture", "archive set or asset coverage")
	}
	for path, want := range expectedArchives {
		if gotArchives[path] != want {
			return nil, fail("BINDING", path, "archive descriptor differs from capture")
		}
	}
	return x, nil
}

// VerifyMembership reopens ONLY provider archives via the bounded 5B capture path,
// rechecks their exact size/hash, parses the existing narrow PAKV11 profile, and
// compares entries with private snapshots. It never reopens donor/current assets.
// Every listed current provider is parsed. Multiple owners of a listed path are
// rejected EVEN if bytes match. No priority/order/hash-based fallback is used.
func VerifyMembership(ctx context.Context, c *CapturedInputs, q MembershipRequest) (out *MembershipEvidence, err error) {
	if ctx == nil {
		return nil, fail("CONTEXT", "membership", "nil")
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	l, e := q.Limits.checked()
	if e != nil {
		return nil, e
	}
	x, e := prepareMembership(ctx, c, q, l)
	if e != nil {
		return nil, e
	}
	root, e := openRoot(q.ArchivesRoot)
	if e != nil {
		return nil, e
	}
	defer func() {
		err = errors.Join(err, root.Close(), ctx.Err())
		if err != nil {
			out = nil
		}
	}()
	rep := MembershipReport{
		Schema: "PMM_R1_MEMBERSHIP_REPORT_V1", Status: "LISTED_ENTRIES_VERIFIED_NOT_TRANSFORM_READY", Profile: q.Profile, CurrentOwnership: q.CurrentOwnership,
		Scope: "ALL_DECLARED_DONOR_AND_CURRENT_FILES_IN_LISTED_PROVIDERS_ONLY", CaptureReportSHA256: bytesDigest(c.reportJSON), PlanSHA256: x.report.PlanSHA256, ProviderSetSHA256: x.report.ProviderSetSHA256,
		Archives: []CheckedArchive{}, Entries: []EntryMembership{}, Blockers: []string{"COMPLETE_PROVIDER_UNIVERSE_UNPROVED", "BUILD_PROVENANCE_UNAUTHENTICATED", "REAL_SCHEMA_SEMANTICS_UNVERIFIED", "OPAQUE_RELOCATION_UNSUPPORTED", "CORE_EXECUTOR_NOT_IMPLEMENTED"},
	}
	owners := map[string]bool{}
	archives := append([]File{q.DonorArchive}, x.providers.Providers...)
	for i, f := range archives {
		if e = ctx.Err(); e != nil {
			return nil, e
		}
		b, e := captureFile(ctx, root, f, true, l.ArchiveBytes, nil)
		if e != nil {
			return nil, e
		}
		actual, e := pakv11.Read(ctx, b, pakv11.Limits{ArchiveBytes: uint64(l.ArchiveBytes)})
		if e != nil {
			if ctx.Err() != nil {
				return nil, ctx.Err()
			}
			return nil, fmt.Errorf("PAK_PROFILE: %s: %w", f.Path, e)
		}
		role, ordinal := "current", i-1
		if i == 0 {
			role, ordinal = "donor", -1
		}
		matched := 0
		for _, entry := range actual {
			if e = ctx.Err(); e != nil {
				return nil, e
			}
			want, ok := x.wanted[role][strings.ToLower(entry.Path)]
			if !ok {
				continue
			}
			key := role + ":" + want.Path
			// Count ownership independently of content: matching one copy is not resolution.
			if owners[key] {
				return nil, fail("AMBIGUOUS", want.Path, "multiple listed providers; no precedence supported")
			}
			if entry.Path != want.Path {
				return nil, fail("PATH_CASE", want.Path, "PAK entry casing differs")
			}
			equal, e := membershipEqual(ctx, entry.Data, c.data[key])
			if e != nil {
				return nil, e
			}
			if !equal || int64(len(entry.Data)) != want.SizeBytes {
				return nil, fail("MEMBERSHIP", want.Path, "archive entry differs from captured bytes")
			}
			owners[key] = true
			matched++
			rep.Entries = append(rep.Entries, EntryMembership{role, want, f, ordinal, entry.Path, true})
		}
		rep.Archives = append(rep.Archives, CheckedArchive{role, f, ordinal, len(actual), matched})
		rep.ArchiveBytesRead += f.SizeBytes
		// Neither b nor actual is retained in the result. Process one archive at a time.
	}
	for _, role := range []string{"donor", "current"} {
		keys := make([]string, 0, len(x.wanted[role]))
		for _, f := range x.wanted[role] {
			keys = append(keys, f.Path)
		}
		sort.Strings(keys)
		for _, path := range keys {
			if e = ctx.Err(); e != nil {
				return nil, e
			}
			if !owners[role+":"+path] {
				return nil, fail("MISSING_ENTRY", path, "no owner in listed providers")
			}
		}
	}
	sort.Slice(rep.Entries, func(i, j int) bool {
		a, b := rep.Entries[i], rep.Entries[j]
		if a.Role == b.Role {
			return a.File.Path < b.File.Path
		}
		return a.Role < b.Role
	})
	rep.ListedEntriesMembershipVerified = true
	rep.AllListedProvidersParsed = true
	rep.UniqueCurrentOwners = true
	raw, e := json.MarshalIndent(rep, "", "  ")
	if e != nil {
		return nil, e
	}
	if e = ctx.Err(); e != nil {
		return nil, e
	}
	return &MembershipEvidence{raw}, nil
}
