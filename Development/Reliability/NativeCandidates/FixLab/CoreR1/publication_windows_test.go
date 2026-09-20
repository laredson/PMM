//go:build windows && amd64

package corer1

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"testing"
	"unsafe"
)

func publicationWindowsSID(t *testing.T) string {
	t.Helper()
	token, e := syscall.OpenCurrentProcessToken()
	if e != nil {
		t.Fatal(e)
	}
	defer token.Close()
	user, e := token.GetTokenUser()
	if e != nil {
		t.Fatal(e)
	}
	sid, e := user.User.Sid.String()
	if e != nil {
		t.Fatal(e)
	}
	return sid
}

// Query the actual persisted DACL, not only the descriptor supplied at creation.
func publicationWindowsDACL(t *testing.T, f *os.File) string {
	t.Helper()
	advapi := syscall.NewLazyDLL("advapi32.dll")
	var sd, dacl uintptr
	status, _, _ := advapi.NewProc("GetSecurityInfo").Call(f.Fd(), 1, 4, 0, 0, uintptr(unsafe.Pointer(&dacl)), 0, uintptr(unsafe.Pointer(&sd)))
	runtime.KeepAlive(f)
	if status != 0 {
		t.Fatal("GetSecurityInfo", status)
	}
	defer candidateFree.Call(sd)
	var out *uint16
	var length uint32
	ok, _, e := advapi.NewProc("ConvertSecurityDescriptorToStringSecurityDescriptorW").Call(sd, 1, 4, uintptr(unsafe.Pointer(&out)), uintptr(unsafe.Pointer(&length)))
	if ok == 0 {
		t.Fatal(e)
	}
	defer candidateFree.Call(uintptr(unsafe.Pointer(out)))
	return syscall.UTF16ToString(unsafe.Slice(out, int(length)))
}

func TestPublicationWindowsOnDiskDACL(t *testing.T) {
	r, q := publicationFixture(t)
	p := published(t, r, q)
	dir := filepath.Join(q.Parent, p.CandidateName)
	root, e := os.Open(dir)
	if e != nil {
		t.Fatal(e)
	}
	defer root.Close()
	sid := publicationWindowsSID(t)
	check := func(f *os.File, directory bool) {
		sddl := publicationWindowsDACL(t, f)
		if strings.Count(sddl, "(") != 2 || strings.Count(sddl, "(A;") != 2 || !strings.Contains(sddl, ";FA;;;SY)") || !strings.Contains(sddl, ";FA;;;"+sid+")") {
			t.Fatal("unexpected access list", sddl)
		}
		if directory && (!strings.HasPrefix(sddl, "D:P") || strings.Count(sddl, "OICI") != 2) {
			t.Fatal("directory ACL not protected/inheritable", sddl)
		}
		if !directory && strings.Count(sddl, ";ID;") != 2 {
			t.Fatal("file ACL not inherited", sddl)
		}
	}
	check(root, true)
	for _, name := range []string{"candidate.pak", "execution.json", "MANIFEST.json", "COMPLETE.json"} {
		f, e := os.Open(filepath.Join(dir, name))
		if e != nil {
			t.Fatal(e)
		}
		check(f, false)
		if e := f.Close(); e != nil {
			t.Fatal(e)
		}
	}
}

func publicationWindowsSetDACL(t *testing.T, path, sddl string) {
	t.Helper()
	text, e := syscall.UTF16PtrFromString(sddl)
	if e != nil {
		t.Fatal(e)
	}
	var sd uintptr
	ok, _, e := candidateSDDL.Call(uintptr(unsafe.Pointer(text)), 1, uintptr(unsafe.Pointer(&sd)), 0)
	runtime.KeepAlive(text)
	if ok == 0 {
		t.Fatal(e)
	}
	defer candidateFree.Call(sd)
	advapi := syscall.NewLazyDLL("advapi32.dll")
	var present, defaulted int32
	var dacl uintptr
	ok, _, e = advapi.NewProc("GetSecurityDescriptorDacl").Call(sd, uintptr(unsafe.Pointer(&present)), uintptr(unsafe.Pointer(&dacl)), uintptr(unsafe.Pointer(&defaulted)))
	if ok == 0 || present == 0 || dacl == 0 {
		t.Fatal("DACL", e)
	}
	p, e := syscall.UTF16PtrFromString(path)
	if e != nil {
		t.Fatal(e)
	}
	status, _, _ := advapi.NewProc("SetNamedSecurityInfoW").Call(uintptr(unsafe.Pointer(p)), 1, 0x80000004, 0, 0, dacl, 0)
	runtime.KeepAlive(p)
	if status != 0 {
		t.Fatal("SetNamedSecurityInfo", status)
	}
}

func TestPublicationWindowsReadOnlyParentDenied(t *testing.T) {
	r, q := publicationFixture(t)
	f, e := os.Open(q.Parent)
	if e != nil {
		t.Fatal(e)
	}
	original := publicationWindowsDACL(t, f)
	if e = f.Close(); e != nil {
		t.Fatal(e)
	}
	// Only this newly-created temporary fixture is affected. Owner can restore
	// its DACL; no privilege is enabled and no game/user directory is changed.
	defer publicationWindowsSetDACL(t, q.Parent, original)
	publicationWindowsSetDACL(t, q.Parent, "D:P(A;;FA;;;SY)(A;;FRFX;;;"+publicationWindowsSID(t)+")")
	p, e := PublishCandidate(context.Background(), r, q)
	if p != nil || e == nil || !strings.Contains(e.Error(), "0xc0000022") {
		t.Fatal("expected real access denied", p, e)
	}
	emptyCandidateParent(t, q.Parent)
}

func TestPublicationWindowsJunctionParentRejected(t *testing.T) {
	r, q := publicationFixture(t)
	target := q.Parent
	link := filepath.Join(filepath.Dir(target), "junction")
	// mklink /J uses only this test's generated temporary paths, needs no
	// elevation, and changes no developer-mode or security policy.
	cmd := exec.Command(filepath.Join(os.Getenv("SystemRoot"), "System32", "cmd.exe"), "/d", "/c", "mklink", "/J", link, target)
	if output, e := cmd.CombinedOutput(); e != nil {
		t.Fatalf("junction fixture: %v %s", e, output)
	}
	defer func() {
		if e := os.Remove(link); e != nil {
			t.Error("remove junction itself", e)
		}
	}()
	q.Parent = link
	if p, e := PublishCandidate(context.Background(), r, q); p != nil || e == nil || !strings.Contains(e.Error(), "reparse") {
		t.Fatal("junction accepted", p, e)
	}
	emptyCandidateParent(t, target)
}

func TestPublicationWindowsUnicodeBundleRoundTrip(t *testing.T) {
	r, q := publicationFixture(t)
	q.Parent = filepath.Join(q.Parent, "publicación 空格")
	if e := os.Mkdir(q.Parent, 0700); e != nil {
		t.Fatal(e)
	}
	p := published(t, r, q)
	if _, e := InspectCandidate(context.Background(), filepath.Join(q.Parent, p.CandidateName), p.ManifestSHA256); e != nil {
		t.Fatal(e)
	}
}

func TestPublicationWindowsEmptyDestinationNotReplaced(t *testing.T) {
	r, q := publicationFixture(t)
	id := strings.Repeat("d", 32)
	dest := filepath.Join(q.Parent, candidatePrefix+id)
	if e := os.Mkdir(dest, 0700); e != nil {
		t.Fatal(e)
	}
	before, e := openRoot(dest)
	if e != nil {
		t.Fatal(e)
	}
	defer before.Close()
	want, e := stamp(before.file, true)
	if e != nil {
		t.Fatal(e)
	}
	p, e := publishCandidate(context.Background(), r, q, publicationHooks{token: func() (string, error) { return id, nil }})
	if p != nil || e == nil {
		t.Fatal("empty destination replaced", p, e)
	}
	after, e := openRoot(dest)
	if e != nil {
		t.Fatal(e)
	}
	defer after.Close()
	got, e := stamp(after.file, true)
	if e != nil || got.id != want.id || got.volume != want.volume {
		t.Fatal("destination identity", e)
	}
	entries, e := os.ReadDir(q.Parent)
	if e != nil || len(entries) != 1 {
		t.Fatal("rollback residue", entries, e)
	}
	emptyCandidateParent(t, dest)
}

func TestPublicationWindowsSealedLeafRenameDenied(t *testing.T) {
	r, q := publicationFixture(t)
	var stage string
	boom := errors.New("abort after denied rename")
	p, e := publishCandidate(context.Background(), r, q, publicationHooks{event: func(event string) error {
		if strings.HasPrefix(event, "created:") {
			stage = strings.TrimPrefix(event, "created:")
		}
		if event != "sealed-before-commit" {
			return nil
		}
		path := filepath.Join(q.Parent, stage, "candidate.pak")
		// The held writable stage also blocks this independent leaf rename.
		anchor, e := openRoot(filepath.Dir(path))
		if e != nil {
			t.Fatal(e)
		}
		original, e := candidateNt(anchor.file, "candidate.pak", false, false, true, 0)
		if e != nil {
			anchor.Close()
			t.Fatal(e)
		}
		e = candidateRenameRelative(anchor.file, original, "displaced-original")
		closeError := errors.Join(original.Close(), anchor.Close())
		if e == nil || closeError != nil {
			t.Fatal(e, closeError)
		}
		return boom
	}})
	var pe *PublicationError
	if p != nil || !errors.Is(e, boom) || !errors.As(e, &pe) || pe.Committed || pe.ResidueName != "" {
		t.Fatal(p, e)
	}
	emptyCandidateParent(t, q.Parent)
}

func TestPublicationWindowsSealRestoreRejectsForeignIdentity(t *testing.T) {
	// Unit-level ownership check without the production stage's deny-delete lock.
	// A broader sharing policy here deliberately permits the replacement.
	dir := t.TempDir()
	root, e := openRoot(dir)
	if e != nil {
		t.Fatal(e)
	}
	defer root.Close()
	f, e := candidateCreate(root.file, "owned")
	if e != nil {
		t.Fatal(e)
	}
	files := []*os.File{f}
	restore, e := candidateSeal(root.file, []string{"owned"}, files)
	if e != nil || restore == nil || files[0] != nil {
		t.Fatal("seal", e)
	}
	if e := os.Rename(filepath.Join(dir, "owned"), filepath.Join(dir, "displaced")); e != nil {
		t.Fatal(e)
	}
	if e := os.WriteFile(filepath.Join(dir, "owned"), []byte("foreign"), 0600); e != nil {
		t.Fatal(e)
	}
	if e := restore(); e == nil || files[0] != nil {
		if files[0] != nil {
			files[0].Close()
		}
		t.Fatal("foreign ownership accepted", e)
	}
	data, e := os.ReadFile(filepath.Join(dir, "owned"))
	if e != nil || string(data) != "foreign" {
		t.Fatal("foreign changed", e)
	}
}

func TestPublicationWindowsSealedSharingViolationNamesResidue(t *testing.T) {
	r, q := publicationFixture(t)
	var stage string
	var held *os.File
	defer func() {
		if held != nil {
			held.Close()
		}
	}()
	p, e := publishCandidate(context.Background(), r, q, publicationHooks{event: func(event string) error {
		if strings.HasPrefix(event, "created:") {
			stage = strings.TrimPrefix(event, "created:")
		}
		if event != "sealed-before-commit" {
			return nil
		}
		path, e := syscall.UTF16PtrFromString(filepath.Join(q.Parent, stage, "candidate.pak"))
		if e != nil {
			t.Fatal(e)
		}
		h, e := syscall.CreateFile(path, syscall.GENERIC_READ, syscall.FILE_SHARE_READ, nil, syscall.OPEN_EXISTING, 0, 0)
		if e != nil {
			t.Fatal(e)
		}
		held = os.NewFile(uintptr(h), "test-sharing-lock")
		return nil // Real rename and identity-safe rollback encounter the lock.
	}})
	var pe *PublicationError
	if p != nil || !errors.As(e, &pe) || pe.Committed || pe.ResidueName != stage {
		t.Fatal(p, e)
	}
	if _, e := os.Stat(filepath.Join(q.Parent, stage, "candidate.pak")); e != nil {
		t.Fatal(e)
	}
}

func TestPublicationWindowsInspectionRejectsHardlink(t *testing.T) {
	r, q := publicationFixture(t)
	p := published(t, r, q)
	dir := filepath.Join(q.Parent, p.CandidateName)
	if e := os.Link(filepath.Join(dir, "candidate.pak"), filepath.Join(q.Parent, "second-link")); e != nil {
		t.Fatal(e)
	}
	if receipt, e := InspectCandidate(context.Background(), dir, p.ManifestSHA256); receipt != nil || e == nil {
		t.Fatal("hardlink accepted")
	}
}

func TestPublicationWindowsAnchoredParentAndEmptyRename(t *testing.T) {
	path := filepath.Join(t.TempDir(), "parent with spaces ñ")
	if e := os.Mkdir(path, 0700); e != nil {
		t.Fatal(e)
	}
	root, e := openRoot(path)
	if e != nil {
		t.Fatal(e)
	}
	defer root.Close()
	parent, e := candidateParent(root, path)
	if e != nil {
		t.Fatal("parent", e)
	}
	defer parent.Close()
	stage, created, e := candidateMkdir(parent, "stage")
	if e != nil || !created {
		t.Fatal("mkdir", e)
	}
	defer stage.Close()
	committed, e := candidateCommit(parent, stage, "stage", "final")
	if !committed || e != nil {
		t.Fatal("rename", e)
	}
	if _, e := os.Stat(filepath.Join(path, "final")); e != nil {
		t.Fatal(e)
	}
}

func TestPublicationWindowsRenameABISizes(t *testing.T) {
	if unsafe.Offsetof(candidateRenameInfo{}.Root) != 8 || unsafe.Offsetof(candidateRenameInfo{}.Length) != 16 || unsafe.Offsetof(candidateRenameInfo{}.Name) != 20 {
		t.Fatal("rename ABI")
	}
}
func TestPublicationWindowsProtectedSecurityDescriptor(t *testing.T) {
	sd, e := candidateSecurity()
	if e != nil || sd == 0 {
		t.Fatal(e)
	}
	candidateFree.Call(sd)
}
