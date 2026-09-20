package corer1

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	pakv11 "pmm.local/fixlab/pakv11"
)

const CandidateBundleProfile = "PMM_R1_ISOLATED_BUNDLE_V1"
const candidatePrefix = "PMM-candidate-"
const stagingPrefix = ".pmm-stage-"

// Boundaries MUST name the actual existing roots, not placeholders. The caller
// controls the parent and authenticates this policy. Unknown game locations
// cannot be inferred. No writes are made to any existing candidate or asset.
type PublicationRequest struct {
	Parent         string
	RepositoryRoot string
	GameRoot       string
	WorkspaceRoot  string
	MaxBundleBytes int64 // zero = 288 MiB; can only lower the ceiling
}
type CandidateManifest struct {
	Schema              string `json:"schema"`
	Profile             string `json:"profile"`
	CandidateName       string `json:"candidateName"`
	Files               []File `json:"files"`
	ExecutionPlanSHA256 string `json:"executionPlanSHA256"`
	RecipeSHA256        string `json:"recipeSHA256"`
	CandidateOnly       bool   `json:"candidateOnly"`
	GameAccepted        bool   `json:"gameAccepted"`
	Installed           bool   `json:"installed"`
}
type candidateCompletion struct {
	Schema         string `json:"schema"`
	CandidateName  string `json:"candidateName"`
	ManifestSHA256 string `json:"manifestSHA256"`
}

// Non-nil receipt + error means the commit point WAS crossed. Do not assume
// rollback, retry under the same name, or remove the published directory.
type PublicationReceipt struct {
	Schema                    string `json:"schema"`
	CandidateName             string `json:"candidateName"`
	ManifestSHA256            string `json:"manifestSHA256"`
	PAKSHA256                 string `json:"pakSHA256"`
	ReportSHA256              string `json:"reportSHA256"`
	Published                 bool   `json:"published"`
	ListedBytesVerified       bool   `json:"listedBytesVerified"`
	DirectorySyncCompleted    bool   `json:"directorySyncCompleted"`
	CrashDurabilityGuaranteed bool   `json:"crashDurabilityGuaranteed"`
	GameAccepted              bool   `json:"gameAccepted"`
	Installed                 bool   `json:"installed"`
}
type PublicationError struct {
	Committed   bool
	ResidueName string // relative name only; never a recursive deletion instruction
	Cause       error
}

func (e *PublicationError) Error() string {
	return fmt.Sprintf("candidate publication committed=%t residue=%q: %v", e.Committed, e.ResidueName, e.Cause)
}
func (e *PublicationError) Unwrap() error { return e.Cause }

// Hooks are private per-call fixture injection. No public overrides, global test
// switches, path normalization, or fallback to unsafe path-based writes.
type publicationHooks struct {
	event func(string) error
	token func() (string, error)
	write func(*os.File, []byte) (int, error)
}

func (h publicationHooks) at(s string) error {
	if h.event != nil {
		return h.event(s)
	}
	return nil
}
func candidateJSON(v any) ([]byte, error) {
	b, e := json.MarshalIndent(v, "", "  ")
	return append(b, '\n'), e
}
func candidateToken() (string, error) {
	var b [16]byte
	_, e := rand.Read(b[:])
	return hex.EncodeToString(b[:]), e
}
func candidateID(s string) bool {
	if len(s) != 32 {
		return false
	}
	for _, c := range s {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
			return false
		}
	}
	return true
}

// PublishCandidate persists only the verified MemoryResult, never an imported
// execution JSON or arbitrary directory. The four-file bundle is NOT a deploy.
// Cancellation is honored before the platform commit. After a successful commit,
// wins cancellation and any subsequent I/O error is returned with a receipt.
func PublishCandidate(ctx context.Context, r *MemoryResult, q PublicationRequest) (*PublicationReceipt, error) {
	return publishCandidate(ctx, r, q, publicationHooks{})
}
func validateCandidateMemory(ctx context.Context, r *MemoryResult) (ExecutionReport, error) {
	var report ExecutionReport
	if ctx == nil {
		return report, fail("CONTEXT", "publication", "nil")
	}
	if e := ctx.Err(); e != nil {
		return report, e
	}
	if r == nil || len(r.report) == 0 || len(r.report) > 32<<20 || len(r.pak) == 0 || len(r.pak) > 256<<20 || len(r.files) == 0 || len(r.files) > 1024 {
		return report, fail("RESULT", "publication", "missing or oversized private result")
	}
	if e := json.Unmarshal(r.report, &report); e != nil {
		return report, e
	}
	if report.Schema != "PMM_R1_BOUNDED_EXECUTION_REPORT_V1" || report.Status != "MEMORY_OUTPUTS_VERIFIED_NOT_GAME_ACCEPTED" || !report.OutputPinsChecked || !report.PAKReadbackByteEqual || report.CoreR1Complete || report.TransformReady || report.BuildReady || report.Validated || report.Installed || report.SchemaSemanticsVerified || report.ReviewerAuthenticated || len(report.Outputs) != len(r.files) {
		return report, fail("RESULT", "publication", "unverified result or readiness escalation")
	}
	for _, s := range []string{report.ExecutionPlanSHA256, report.ReviewSHA256, report.CaptureSHA256, report.MembershipSHA256, report.RecipeSHA256, report.PAKSHA256} {
		if !validHash(s) {
			return report, fail("PIN", "publication", "missing evidence hash")
		}
	}
	digest, e := membershipDigest(ctx, r.pak)
	if e != nil {
		return report, e
	}
	if report.PAKBytes != len(r.pak) || digest != report.PAKSHA256 {
		return report, fail("PIN", "publication", "PAK bytes")
	}
	files := make([]pakv11.File, 0, len(r.files))
	seen := map[string]bool{}
	var total int64
	for _, f := range report.Outputs {
		if e := ctx.Err(); e != nil {
			return report, e
		}
		if e := safePath(f.Path); e != nil {
			return report, e
		}
		data, ok := r.files[f.Path]
		if !ok || seen[f.Path] || !validHash(f.SHA256) || f.SizeBytes < 0 || f.SizeBytes > 64<<20 || int64(len(data)) != f.SizeBytes || f.SizeBytes > (128<<20)-total {
			return report, fail("RESULT", f.Path, "output coverage/size")
		}
		total += f.SizeBytes
		seen[f.Path] = true
		d, e := membershipDigest(ctx, data)
		if e != nil {
			return report, e
		}
		if d != f.SHA256 {
			return report, fail("PIN", f.Path, "output bytes")
		}
		files = append(files, pakv11.File{Path: f.Path, Data: data})
	}
	if _, e = pakv11.Verify(ctx, r.pak, files, pakv11.Limits{}); e != nil {
		return report, e
	}
	return report, ctx.Err()
}

func publicationBoundary(q PublicationRequest) (*anchoredRoot, error) {
	if e := cleanAbsolute(q.Parent); e != nil {
		return nil, e
	}
	roots := []string{q.RepositoryRoot, q.GameRoot, q.WorkspaceRoot}
	for _, s := range roots {
		if e := cleanAbsolute(s); e != nil {
			return nil, fail("BOUNDARY", "publication", "all three actual protected roots are required")
		}
	}
	parent, e := openRoot(q.Parent)
	if e != nil {
		return nil, e
	}
	var err error
	for _, s := range roots {
		guard, e := openRoot(s)
		if e != nil {
			err = e
			break
		}
		st, se := stamp(guard.file, true)
		ce := guard.Close()
		if se != nil || ce != nil {
			err = errors.Join(se, ce)
			break
		}
		for _, ancestor := range parent.chain {
			a, e := stamp(ancestor, true)
			if e != nil {
				err = e
				break
			}
			if a.volume == st.volume && a.id == st.id {
				err = fail("BOUNDARY", "publication", "parent is inside a protected root")
				break
			}
		}
		if err != nil {
			break
		}
	}
	if err != nil {
		return nil, errors.Join(err, parent.Close())
	}
	return parent, nil
}
func candidateSame(parent *os.File, name string, f *os.File, dir bool) error {
	a, e := stamp(f, dir)
	if e != nil {
		return e
	}
	lookup, e := candidateLookup(parent, name, dir)
	if e != nil {
		return e
	}
	b, se := stamp(lookup, dir)
	ce := lookup.Close()
	if se != nil || ce != nil {
		return errors.Join(se, ce)
	}
	if a.volume != b.volume || a.id != b.id {
		return fail("CHANGED", name, "directory entry identity differs")
	}
	return nil
}
func candidateWrite(ctx context.Context, f *os.File, b []byte, h publicationHooks) error {
	for len(b) > 0 {
		if e := ctx.Err(); e != nil {
			return e
		}
		n := len(b)
		if n > 32768 {
			n = 32768
		}
		var wrote int
		var e error
		if h.write != nil {
			wrote, e = h.write(f, b[:n])
		} else {
			wrote, e = f.Write(b[:n])
		}
		if e != nil {
			return e
		}
		if wrote != n {
			return io.ErrShortWrite
		}
		b = b[n:]
	}
	return ctx.Err()
}
func candidateReadback(ctx context.Context, f *os.File, want File) error {
	before, e := stamp(f, false)
	if e != nil {
		return e
	}
	if before.size != want.SizeBytes {
		return fail("SIZE", want.Path, "written length")
	}
	if _, e = f.Seek(0, io.SeekStart); e != nil {
		return e
	}
	_, digest, e := exactRead(ctx, f, want.SizeBytes, false)
	if e != nil {
		return e
	}
	after, e := stamp(f, false)
	if e != nil {
		return e
	}
	if before != after {
		return fail("CHANGED", want.Path, "readback metadata")
	}
	if digest != want.SHA256 {
		return fail("PIN", want.Path, "readback bytes")
	}
	return nil
}
func publishCandidate(ctx context.Context, r *MemoryResult, q PublicationRequest, h publicationHooks) (receipt *PublicationReceipt, err error) {
	report, e := validateCandidateMemory(ctx, r)
	if e != nil {
		return nil, e
	}
	cap := q.MaxBundleBytes
	if cap == 0 {
		cap = 288 << 20
	}
	if cap < 1 || cap > 288<<20 {
		return nil, fail("LIMIT", "publication", "byte ceiling")
	}
	tokFn := h.token
	if tokFn == nil {
		tokFn = candidateToken
	}
	id, e := tokFn()
	if e != nil {
		return nil, e
	}
	if !candidateID(id) {
		return nil, fail("TOKEN", "publication", "invalid random identifier")
	}
	name := candidatePrefix + id
	stageName, completionName := candidateLayout(id, name)
	manifest := CandidateManifest{Schema: "PMM_R1_CANDIDATE_MANIFEST_V1", Profile: CandidateBundleProfile, CandidateName: name, Files: []File{{"candidate.pak", report.PAKSHA256, int64(len(r.pak))}, {"execution.json", bytesDigest(r.report), int64(len(r.report))}}, ExecutionPlanSHA256: report.ExecutionPlanSHA256, RecipeSHA256: report.RecipeSHA256, CandidateOnly: true}
	mb, e := candidateJSON(manifest)
	if e != nil {
		return nil, e
	}
	cb, e := candidateJSON(candidateCompletion{"PMM_R1_CANDIDATE_COMPLETE_V1", name, bytesDigest(mb)})
	if e != nil {
		return nil, e
	}
	payload := [][]byte{r.pak, r.report, mb, cb}
	logicalNames := []string{"candidate.pak", "execution.json", "MANIFEST.json", "COMPLETE.json"}
	diskNames := []string{"candidate.pak", "execution.json", "MANIFEST.json", completionName}
	var total int64
	for _, b := range payload {
		total += int64(len(b))
	}
	if total > cap {
		return nil, fail("LIMIT", "publication", "bundle exceeds budget")
	}
	root, e := publicationBoundary(q)
	if e != nil {
		return nil, e
	}
	// Retain directory anchors through commit and leaf ownership across sealing.
	// Rollback deletes ONLY objects we created,
	// with identity checks, never RemoveAll or traversal of foreign contents.
	var parent, stage *os.File
	var files []*os.File
	var restore func() error
	created := false
	committed := false
	residue := ""
	defer func() {
		var cleanup []error
		if !committed && created && stage != nil {
			if restore != nil {
				cleanup = append(cleanup, restore())
			}
			for i := len(files) - 1; i >= 0; i-- {
				if files[i] == nil {
					cleanup = append(cleanup, fail("CHANGED", logicalNames[i], "owned rollback handle unavailable"))
					continue
				}
				de := h.at("cleanup:" + logicalNames[i])
				if de == nil {
					de = candidateRemove(stage, diskNames[i], files[i], false)
				}
				cleanup = append(cleanup, de, files[i].Close())
				files[i] = nil
			}
			de := h.at("cleanup:stage")
			if de == nil {
				de = candidateRemove(parent, stageName, stage, true)
			}
			cleanup = append(cleanup, de)
		}
		for _, f := range files {
			if f != nil {
				cleanup = append(cleanup, f.Close())
			}
		}
		if stage != nil {
			cleanup = append(cleanup, stage.Close())
		}
		if parent != nil {
			cleanup = append(cleanup, parent.Close())
		}
		cleanup = append(cleanup, root.Close())
		ce := errors.Join(cleanup...)
		if !committed && created && (stage == nil || ce != nil) {
			residue = stageName
		}
		err = errors.Join(err, ce)
		if err != nil {
			err = &PublicationError{Committed: committed, ResidueName: residue, Cause: err}
		}
	}()
	if e = ctx.Err(); e != nil {
		return nil, e
	}
	parent, e = candidateParent(root, q.Parent)
	if e != nil {
		return nil, e
	}
	stage, created, e = candidateMkdir(parent, stageName)
	if e != nil {
		return nil, e
	}
	if e = h.at("created:" + stageName); e != nil {
		return nil, e
	}
	for i, b := range payload {
		if e = ctx.Err(); e != nil {
			return nil, e
		}
		f, e := candidateCreate(stage, diskNames[i])
		if e != nil {
			return nil, e
		}
		files = append(files, f)
		if e = h.at("write:" + logicalNames[i]); e != nil {
			return nil, e
		}
		if e = candidateWrite(ctx, f, b, h); e != nil {
			return nil, e
		}
		if e = h.at("sync:" + logicalNames[i]); e != nil {
			return nil, e
		}
		if e = f.Sync(); e != nil {
			return nil, e
		}
		if e = h.at("readback:" + logicalNames[i]); e != nil {
			return nil, e
		}
		if e = candidateReadback(ctx, f, File{logicalNames[i], bytesDigest(b), int64(len(b))}); e != nil {
			return nil, e
		}
	}
	if e = h.at("before-commit"); e != nil {
		return nil, e
	}
	for i, f := range files {
		if e = candidateSame(stage, diskNames[i], f, false); e != nil {
			return nil, e
		}
		if e = candidateReadback(ctx, f, File{logicalNames[i], bytesDigest(payload[i]), int64(len(payload[i]))}); e != nil {
			return nil, e
		}
	}
	if e = candidateSame(parent, stageName, stage, true); e != nil {
		return nil, e
	}
	if _, e = candidateSyncDir(stage); e != nil {
		return nil, e
	}
	// Apply the platform seal immediately before commit. Linux keeps the leaves
	// open across directory rename. Windows keeps verified data leaves pinned and
	// commits by renaming the completion marker. Restore is identity-limited.
	restore, e = candidateSeal(stage, diskNames, files)
	if e != nil {
		return nil, e
	}
	if e = h.at("sealed-before-commit"); e != nil {
		return nil, e
	}
	if e = ctx.Err(); e != nil {
		return nil, e
	}
	committed, e = candidateCommit(parent, stage, stageName, name, completionName, files[len(files)-1])
	if !committed {
		return nil, e
	}
	receipt = &PublicationReceipt{Schema: "PMM_R1_CANDIDATE_RECEIPT_V1", CandidateName: name, ManifestSHA256: bytesDigest(mb), PAKSHA256: report.PAKSHA256, ReportSHA256: bytesDigest(r.report), Published: true, ListedBytesVerified: e == nil}
	if e != nil {
		return receipt, e
	}
	if e = h.at("after-commit"); e != nil {
		return receipt, e
	}
	if e = h.at("parent-sync"); e != nil {
		return receipt, e
	}
	receipt.DirectorySyncCompleted, e = candidateSyncDir(parent)
	return receipt, e
}

// InspectCandidate checks a finished bundle against an independently retained
// manifest pin. It returns no MemoryResult, never promotes staging, and does not
// authenticate the plan/schema or inspect/execute extra unlisted files.
func InspectCandidate(ctx context.Context, path, manifestSHA256 string) (out *PublicationReceipt, err error) {
	if ctx == nil {
		return nil, fail("CONTEXT", "inspect", "nil")
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	name := filepath.Base(path)
	if !strings.HasPrefix(name, candidatePrefix) || !candidateID(strings.TrimPrefix(name, candidatePrefix)) || !validHash(manifestSHA256) {
		return nil, fail("CANDIDATE", "inspect", "final name and external manifest pin required")
	}
	root, e := openRoot(path)
	if e != nil {
		return nil, e
	}
	defer func() {
		err = errors.Join(err, root.Close())
		if err != nil {
			out = nil
		}
	}()
	read := func(name string, pin string, max int64) ([]byte, error) {
		f, e := root.Open(name)
		if e != nil {
			return nil, e
		}
		st, se := stamp(f.file, false)
		ce := f.Close()
		if se != nil || ce != nil {
			return nil, errors.Join(se, ce)
		}
		return captureFile(ctx, root, File{name, pin, st.size}, true, max, nil)
	}
	mb, e := read("MANIFEST.json", manifestSHA256, 1<<20)
	if e != nil {
		return nil, e
	}
	var m CandidateManifest
	if e = decode(ctx, PinnedJSON{mb, manifestSHA256}, 1<<20, "candidate manifest", &m); e != nil {
		return nil, e
	}
	if m.Schema != "PMM_R1_CANDIDATE_MANIFEST_V1" || m.Profile != CandidateBundleProfile || m.CandidateName != name || !m.CandidateOnly || m.GameAccepted || m.Installed || len(m.Files) != 2 || m.Files[0].Path != "candidate.pak" || m.Files[1].Path != "execution.json" {
		return nil, fail("CANDIDATE", "inspect", "manifest contract")
	}
	cb, e := candidateJSON(candidateCompletion{"PMM_R1_CANDIDATE_COMPLETE_V1", name, manifestSHA256})
	if e != nil {
		return nil, e
	}
	if _, e = read("COMPLETE.json", bytesDigest(cb), 4096); e != nil {
		return nil, e
	}
	blobs := make([][]byte, 2)
	for i, f := range m.Files {
		limit := int64(256 << 20)
		if i == 1 {
			limit = 32 << 20
		}
		blobs[i], e = captureFile(ctx, root, f, true, limit, nil)
		if e != nil {
			return nil, e
		}
	}
	entries, e := pakv11.Read(ctx, blobs[0], pakv11.Limits{})
	if e != nil {
		return nil, e
	}
	r := &MemoryResult{files: map[string][]byte{}, pak: blobs[0], report: blobs[1]}
	for _, f := range entries {
		r.files[f.Path] = f.Data
	}
	report, e := validateCandidateMemory(ctx, r)
	if e != nil {
		return nil, e
	}
	if report.ExecutionPlanSHA256 != m.ExecutionPlanSHA256 || report.RecipeSHA256 != m.RecipeSHA256 {
		return nil, fail("BINDING", "inspect", "execution identity")
	}
	return &PublicationReceipt{Schema: "PMM_R1_CANDIDATE_RECEIPT_V1", CandidateName: name, ManifestSHA256: manifestSHA256, PAKSHA256: report.PAKSHA256, ReportSHA256: bytesDigest(r.report), Published: true, ListedBytesVerified: true}, nil
}
