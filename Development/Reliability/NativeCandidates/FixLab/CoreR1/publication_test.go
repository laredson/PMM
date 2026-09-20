package corer1

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"sync"
	"testing"
)

func publicationFixture(t *testing.T) (*MemoryResult, PublicationRequest) {
	t.Helper()
	_, c, m, q, _ := executorFixture(t, 0)
	r := executeOK(t, c, m, q)
	base := t.TempDir()
	p := PublicationRequest{Parent: filepath.Join(base, "out"), RepositoryRoot: filepath.Join(base, "repo"), GameRoot: filepath.Join(base, "game"), WorkspaceRoot: filepath.Join(base, "workspace")}
	for _, d := range []string{p.Parent, p.RepositoryRoot, p.GameRoot, p.WorkspaceRoot} {
		if e := os.Mkdir(d, 0700); e != nil {
			t.Fatal(e)
		}
	}
	return r, p
}
func published(t *testing.T, r *MemoryResult, q PublicationRequest) *PublicationReceipt {
	t.Helper()
	receipt, e := PublishCandidate(context.Background(), r, q)
	if e != nil || receipt == nil || !receipt.Published || !receipt.ListedBytesVerified || receipt.Installed || receipt.GameAccepted || receipt.CrashDurabilityGuaranteed {
		t.Fatalf("publish: %+v %v", receipt, e)
	}
	return receipt
}
func emptyCandidateParent(t *testing.T, parent string) {
	t.Helper()
	fs, e := os.ReadDir(parent)
	if e != nil || len(fs) != 0 {
		t.Fatalf("parent not empty: %v %v", fs, e)
	}
}
func TestPublicationFullPipelineAndInspect(t *testing.T) {
	r, q := publicationFixture(t)
	before := r.ReportJSON()
	p := published(t, r, q)
	dir := filepath.Join(q.Parent, p.CandidateName)
	fs, e := os.ReadDir(dir)
	if e != nil || len(fs) != 4 {
		t.Fatal(fs, e)
	}
	for _, f := range fs {
		if f.IsDir() {
			t.Fatal("unexpected extraction")
		}
	}
	pak, e := os.ReadFile(filepath.Join(dir, "candidate.pak"))
	if e != nil || !bytes.Equal(pak, r.PAKBytes()) {
		t.Fatal(e)
	}
	doc, _ := os.ReadFile(filepath.Join(dir, "execution.json"))
	if !bytes.Equal(doc, before) || !bytes.Equal(r.ReportJSON(), before) {
		t.Fatal("report changed")
	}
	inspected, e := InspectCandidate(context.Background(), dir, p.ManifestSHA256)
	if e != nil || !inspected.ListedBytesVerified || inspected.PAKSHA256 != p.PAKSHA256 || inspected.Installed {
		t.Fatal(inspected, e)
	}
}
func TestPublicationRequiresPrivateResult(t *testing.T) {
	_, q := publicationFixture(t)
	for _, r := range []*MemoryResult{nil, {}, {report: []byte(`{}`)}} {
		if p, e := PublishCandidate(context.Background(), r, q); p != nil || e == nil {
			t.Fatal("accepted empty")
		}
	}
	emptyCandidateParent(t, q.Parent)
}
func TestPublicationMemoryTamperRejectedBeforeIO(t *testing.T) {
	for _, what := range []string{"pak", "report", "output", "omitted", "readiness"} {
		t.Run(what, func(t *testing.T) {
			r, q := publicationFixture(t)
			switch what {
			case "pak":
				r.pak[0] ^= 1
			case "report":
				r.report = []byte("{")
			case "output":
				r.files["C/Body1.uasset"][0] ^= 1
			case "omitted":
				delete(r.files, "C/Body1.uasset")
			case "readiness":
				var x ExecutionReport
				json.Unmarshal(r.report, &x)
				x.Installed = true
				r.report, _ = json.Marshal(x)
			}
			if p, e := PublishCandidate(context.Background(), r, q); p != nil || e == nil {
				t.Fatal("accepted corrupted result")
			}
			emptyCandidateParent(t, q.Parent)
		})
	}
}
func TestPublicationProtectedRoots(t *testing.T) {
	r, q := publicationFixture(t)
	for _, d := range []string{q.RepositoryRoot, q.GameRoot, q.WorkspaceRoot} {
		child := filepath.Join(d, "sub")
		os.Mkdir(child, 0700)
		for _, root := range []string{d, child} {
			z := q
			z.Parent = root
			if p, e := PublishCandidate(context.Background(), r, z); p != nil || e == nil || !strings.Contains(e.Error(), "BOUNDARY") {
				t.Fatal(p, e)
			}
		}
	}
	emptyCandidateParent(t, q.Parent)
}
func TestPublicationMandatoryCanonicalBoundaries(t *testing.T) {
	r, q := publicationFixture(t)
	for _, mutate := range []func(*PublicationRequest){func(q *PublicationRequest) { q.GameRoot = "" }, func(q *PublicationRequest) { q.Parent = "relative" }, func(q *PublicationRequest) { q.RepositoryRoot = "missing" }, func(q *PublicationRequest) { q.Parent += string(os.PathSeparator) + ".." }} {
		z := q
		mutate(&z)
		if p, e := PublishCandidate(context.Background(), r, z); p != nil || e == nil {
			t.Fatal("accepted boundary")
		}
	}
	emptyCandidateParent(t, q.Parent)
}
func TestPublicationByteLimitsBeforeIO(t *testing.T) {
	r, q := publicationFixture(t)
	for _, cap := range []int64{-1, 1, 289 << 20} {
		z := q
		z.MaxBundleBytes = cap
		if p, e := PublishCandidate(context.Background(), r, z); p != nil || e == nil {
			t.Fatal(p, e)
		}
	}
	emptyCandidateParent(t, q.Parent)
}
func TestPublicationRepeatedCallsDoNotOverwrite(t *testing.T) {
	r, q := publicationFixture(t)
	a := published(t, r, q)
	b := published(t, r, q)
	if a.CandidateName == b.CandidateName || a.PAKSHA256 != b.PAKSHA256 || a.ReportSHA256 != b.ReportSHA256 {
		t.Fatal("identity")
	}
}
func TestPublicationNameCollisionPreservesExisting(t *testing.T) {
	for _, prefix := range []string{candidatePrefix, stagingPrefix} {
		t.Run(prefix, func(t *testing.T) {
			r, q := publicationFixture(t)
			id := strings.Repeat("a", 32)
			existing := filepath.Join(q.Parent, prefix+id)
			os.Mkdir(existing, 0700)
			os.WriteFile(filepath.Join(existing, "foreign"), []byte("keep"), 0600)
			p, e := publishCandidate(context.Background(), r, q, publicationHooks{token: func() (string, error) { return id, nil }})
			if p != nil || e == nil {
				t.Fatal("overwrote")
			}
			b, _ := os.ReadFile(filepath.Join(existing, "foreign"))
			if string(b) != "keep" {
				t.Fatal("existing destroyed")
			}
			fs, _ := os.ReadDir(q.Parent)
			if len(fs) != 1 {
				t.Fatal("residue", fs)
			}
		})
	}
}
func TestPublicationTokenFailureBeforeIO(t *testing.T) {
	r, q := publicationFixture(t)
	for _, f := range []func() (string, error){func() (string, error) { return "", errors.New("random failed") }, func() (string, error) { return "../../escape", nil }} {
		if p, e := publishCandidate(context.Background(), r, q, publicationHooks{token: f}); p != nil || e == nil {
			t.Fatal(p, e)
		}
	}
	emptyCandidateParent(t, q.Parent)
}
func TestPublicationRollbackAtEveryPrecommitPhase(t *testing.T) {
	r, q := publicationFixture(t)
	boom := errors.New("injected disk/flush/read failure")
	phases := []string{"created", "before-commit", "sealed-before-commit"}
	for _, name := range []string{"candidate.pak", "execution.json", "MANIFEST.json", "COMPLETE.json"} {
		for _, phase := range []string{"write:", "sync:", "readback:"} {
			phases = append(phases, phase+name)
		}
	}
	for _, phase := range phases {
		t.Run(phase, func(t *testing.T) {
			p, e := publishCandidate(context.Background(), r, q, publicationHooks{event: func(s string) error {
				if s == phase || (phase == "created" && strings.HasPrefix(s, "created:")) {
					return boom
				}
				return nil
			}})
			var pe *PublicationError
			if p != nil || !errors.Is(e, boom) || !errors.As(e, &pe) || pe.Committed || pe.ResidueName != "" {
				t.Fatal(p, e)
			}
			emptyCandidateParent(t, q.Parent)
		})
	}
}
func TestPublicationShortWriteAndDiskFull(t *testing.T) {
	r, q := publicationFixture(t)
	full := errors.New("injected ENOSPC")
	for _, write := range []func(*os.File, []byte) (int, error){func(f *os.File, b []byte) (int, error) { return 0, full }, func(f *os.File, b []byte) (int, error) { n, _ := f.Write(b[:len(b)/2]); return n, nil }} {
		p, e := publishCandidate(context.Background(), r, q, publicationHooks{write: write})
		if p != nil || e == nil || !(errors.Is(e, full) || errors.Is(e, io.ErrShortWrite)) {
			t.Fatal(p, e)
		}
		emptyCandidateParent(t, q.Parent)
	}
}
func TestPublicationCancellationBeforeAndAfterCommit(t *testing.T) {
	r, q := publicationFixture(t)
	if p, e := PublishCandidate(nil, r, q); p != nil || e == nil {
		t.Fatal("nil context")
	}
	for _, phase := range []string{"created", "write:candidate.pak", "readback:execution.json", "before-commit", "sealed-before-commit", "after-commit"} {
		t.Run(phase, func(t *testing.T) {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			p, e := publishCandidate(ctx, r, q, publicationHooks{event: func(s string) error {
				if s == phase || (phase == "created" && strings.HasPrefix(s, "created:")) {
					cancel()
				}
				return nil
			}})
			if phase == "after-commit" {
				if e != nil || p == nil || !p.Published {
					t.Fatal("committed result lost", p, e)
				}
			} else {
				if p != nil || !errors.Is(e, context.Canceled) {
					t.Fatal(p, e)
				}
				emptyCandidateParent(t, q.Parent)
			}
		})
	}
}
func TestPublicationPostCommitErrorReturnsCommittedReceipt(t *testing.T) {
	for _, phase := range []string{"after-commit", "parent-sync"} {
		t.Run(phase, func(t *testing.T) {
			r, q := publicationFixture(t)
			boom := errors.New("post-commit failure")
			p, e := publishCandidate(context.Background(), r, q, publicationHooks{event: func(s string) error {
				if s == phase {
					return boom
				}
				return nil
			}})
			var pe *PublicationError
			if p == nil || !p.Published || !errors.As(e, &pe) || !pe.Committed || !errors.Is(e, boom) {
				t.Fatal(p, e)
			}
			if _, e := InspectCandidate(context.Background(), filepath.Join(q.Parent, p.CandidateName), p.ManifestSHA256); e != nil {
				t.Fatal(e)
			}
		})
	}
}
func TestPublicationCleanupFailureNamesResidue(t *testing.T) {
	r, q := publicationFixture(t)
	boom := errors.New("injected cleanup failure")
	p, e := publishCandidate(context.Background(), r, q, publicationHooks{event: func(s string) error {
		if s == "before-commit" || s == "cleanup:candidate.pak" {
			return boom
		}
		return nil
	}})
	var pe *PublicationError
	if p != nil || !errors.As(e, &pe) || pe.Committed || !strings.HasPrefix(pe.ResidueName, stagingPrefix) {
		t.Fatal(p, e)
	}
	fs, _ := os.ReadDir(q.Parent)
	if len(fs) != 1 {
		t.Fatal(fs)
	}
	if _, e := InspectCandidate(context.Background(), filepath.Join(q.Parent, pe.ResidueName), strings.Repeat("a", 64)); e == nil {
		t.Fatal("accepted residue")
	}
}
func TestPublicationConcurrentIndependentCandidates(t *testing.T) {
	r, q := publicationFixture(t)
	var wg sync.WaitGroup
	var mu sync.Mutex
	names := map[string]bool{}
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			p, e := PublishCandidate(context.Background(), r, q)
			if e != nil {
				t.Error(e)
				return
			}
			mu.Lock()
			defer mu.Unlock()
			if names[p.CandidateName] {
				t.Error("duplicate")
			}
			names[p.CandidateName] = true
		}()
	}
	wg.Wait()
	if len(names) != 4 {
		t.Fatal(names)
	}
}
func TestCandidateInspectionMissingAlteredAndWrongPin(t *testing.T) {
	for _, what := range []string{"missing", "pak", "report", "manifest", "complete", "wrong-pin"} {
		t.Run(what, func(t *testing.T) {
			r, q := publicationFixture(t)
			p := published(t, r, q)
			dir := filepath.Join(q.Parent, p.CandidateName)
			pin := p.ManifestSHA256
			switch what {
			case "missing":
				os.Remove(filepath.Join(dir, "COMPLETE.json"))
			case "pak":
				os.WriteFile(filepath.Join(dir, "candidate.pak"), []byte("bad"), 0600)
			case "report":
				os.WriteFile(filepath.Join(dir, "execution.json"), []byte("{}"), 0600)
			case "manifest":
				os.WriteFile(filepath.Join(dir, "MANIFEST.json"), []byte("{}"), 0600)
			case "complete":
				os.WriteFile(filepath.Join(dir, "COMPLETE.json"), []byte("{}"), 0600)
			case "wrong-pin":
				pin = strings.Repeat("0", 64)
			}
			if result, e := InspectCandidate(context.Background(), dir, pin); result != nil || e == nil {
				t.Fatal("accepted altered", what)
			}
		})
	}
}
func TestCandidateInspectionDoesNotProcessUnlistedFiles(t *testing.T) {
	r, q := publicationFixture(t)
	p := published(t, r, q)
	dir := filepath.Join(q.Parent, p.CandidateName)
	os.WriteFile(filepath.Join(dir, "unlisted.exe"), []byte("not an executable, fixture"), 0600)
	check, e := InspectCandidate(context.Background(), dir, p.ManifestSHA256)
	if e != nil || !check.ListedBytesVerified || check.GameAccepted || check.Installed {
		t.Fatal(check, e)
	}
}
func TestCandidateInspectionContextAndName(t *testing.T) {
	r, q := publicationFixture(t)
	p := published(t, r, q)
	dir := filepath.Join(q.Parent, p.CandidateName)
	if v, e := InspectCandidate(nil, dir, p.ManifestSHA256); v != nil || e == nil {
		t.Fatal("nil")
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if v, e := InspectCandidate(ctx, dir, p.ManifestSHA256); v != nil || !errors.Is(e, context.Canceled) {
		t.Fatal(e)
	}
	if v, e := InspectCandidate(context.Background(), dir, ""); v != nil || e == nil {
		t.Fatal("missing pin")
	}
}

// Subprocess entry point only. It deliberately skips defers to model an abrupt
// process exit, NOT sudden power loss or a kernel/filesystem crash.
func TestPublicationCrashHelper(t *testing.T) {
	phase := os.Getenv("PMM_TEST_CANDIDATE_CRASH")
	if phase == "" {
		t.Skip("subprocess helper only")
	}
	r, q := publicationFixture(t)
	q.Parent = os.Getenv("PMM_TEST_CANDIDATE_PARENT")
	_, e := publishCandidate(context.Background(), r, q, publicationHooks{token: func() (string, error) { return strings.Repeat("c", 32), nil }, event: func(s string) error {
		if s == phase {
			os.Exit(23)
		}
		return nil
	}})
	t.Fatalf("crash point not reached: %v", e)
}
func TestPublicationAbruptExitRecovery(t *testing.T) {
	for _, phase := range []string{"before-commit", "sealed-before-commit", "after-commit"} {
		t.Run(phase, func(t *testing.T) {
			parent := t.TempDir()
			cmd := exec.Command(os.Args[0], "-test.run=^TestPublicationCrashHelper$")
			childTemp := t.TempDir()
			cmd.Env = append(os.Environ(), "PMM_TEST_CANDIDATE_CRASH="+phase, "PMM_TEST_CANDIDATE_PARENT="+parent, "TMPDIR="+childTemp, "TMP="+childTemp, "TEMP="+childTemp)
			b, e := cmd.CombinedOutput()
			var ex *exec.ExitError
			if !errors.As(e, &ex) || ex.ExitCode() != 23 {
				t.Fatal(string(b), e)
			}
			prefix := stagingPrefix
			if phase == "after-commit" {
				prefix = candidatePrefix
			}
			dir := filepath.Join(parent, prefix+strings.Repeat("c", 32))
			mb, e := os.ReadFile(filepath.Join(dir, "MANIFEST.json"))
			if e != nil {
				t.Fatal(e)
			}
			p, e := InspectCandidate(context.Background(), dir, bytesDigest(mb)) // test knows its own synthetic manifest
			if phase != "after-commit" {
				if p != nil || e == nil {
					t.Fatal("staging accepted")
				}
			} else if e != nil || p == nil || !p.ListedBytesVerified {
				t.Fatal(p, e)
			}
		})
	}
}
func TestPublicationFixtureExport(t *testing.T) {
	base := os.Getenv("PMM_R1_PUBLICATION_OUTPUT")
	if base == "" {
		t.Skip("opt-in bundle fixtures")
	}
	if e := os.Mkdir(base, 0700); e != nil {
		t.Fatal(e)
	}
	for i, v := range executorVectors(t) {
		_, c, m, x, want := executorFixture(t, i)
		r := executeOK(t, c, m, x)
		_, q := publicationFixture(t)
		out := filepath.Join(base, v.ID)
		os.Mkdir(out, 0700)
		q.Parent = out
		p := published(t, r, q)
		data, _ := candidateJSON(p)
		os.WriteFile(filepath.Join(out, "receipt.json"), data, 0600)
		for path, b := range want {
			put(t, filepath.Join(out, "expected"), path, b)
		}
		if runtime.GOOS == "linux" && !p.DirectorySyncCompleted {
			t.Fatal("directory sync absent")
		}
		if !reflect.DeepEqual(r.ReportJSON(), executeOK(t, c, m, x).ReportJSON()) {
			t.Fatal("memory mutated")
		}
	}
}

func TestPublicationActualCloseErrorRemainsCommitted(t *testing.T) {
	r, q := publicationFixture(t)
	var first *os.File
	p, e := publishCandidate(context.Background(), r, q, publicationHooks{write: func(f *os.File, b []byte) (int, error) {
		if first == nil {
			first = f
		}
		return f.Write(b)
	}, event: func(s string) error {
		if s == "parent-sync" {
			return first.Close()
		}
		return nil
	}})
	var pe *PublicationError
	if p == nil || !p.Published || !errors.As(e, &pe) || !pe.Committed {
		t.Fatal(p, e)
	}
	if _, e = InspectCandidate(context.Background(), filepath.Join(q.Parent, p.CandidateName), p.ManifestSHA256); e != nil {
		t.Fatal(e)
	}
}
