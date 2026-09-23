package main

import (
	"archive/zip"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func TestCleanRelPathRejectsTraversal(t *testing.T) {
	bad := []string{"../evil", "..\\evil", "folder/..\\evil", "../../evil", "/absolute", "C:/absolute", "safe.txt:ads", "CON", "CON .txt", "nul.txt", "NUL .log", "COM1.log", "COM1 .log", "LPT9", "trailing. ", "trailing.", "bad?.txt"}
	for _, p := range bad {
		if _, err := cleanRelPath(p); err == nil {
			t.Fatalf("expected unsafe path rejection for %q", p)
		}
	}
}

func TestZipRoundTrip(t *testing.T) {
	root := t.TempDir()
	src := filepath.Join(root, "src")
	dst := filepath.Join(root, "dst")
	zipPath := filepath.Join(root, "a.zip")
	if err := os.MkdirAll(filepath.Join(src, "nested"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(src, "nested", "hello.txt"), []byte("hello"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := createZipFromDirectory(src, zipPath); err != nil {
		t.Fatal(err)
	}
	if err := extractZipSafe(zipPath, dst); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(filepath.Join(dst, "nested", "hello.txt"))
	if err != nil {
		t.Fatal(err)
	}
	if string(b) != "hello" {
		t.Fatalf("unexpected content %q", string(b))
	}
}

func TestZipManyFilesDoesNotLeakDescriptors(t *testing.T) {
	root := t.TempDir()
	src := filepath.Join(root, "src")
	zipPath := filepath.Join(root, "many.zip")
	if err := os.MkdirAll(src, 0755); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 256; i++ {
		name := filepath.Join(src, fmt.Sprintf("f-%03d.txt", i))
		if err := os.WriteFile(name, []byte("small payload"), 0644); err != nil {
			t.Fatal(err)
		}
	}
	if err := createZipFromDirectory(src, zipPath); err != nil {
		t.Fatal(err)
	}
	zr, err := zip.OpenReader(zipPath)
	if err != nil {
		t.Fatal(err)
	}
	defer zr.Close()
	if len(zr.File) != 256 {
		t.Fatalf("expected 256 entries, got %d", len(zr.File))
	}
}

func TestZipRejectsSymlink(t *testing.T) {
	root := t.TempDir()
	src := filepath.Join(root, "src")
	if err := os.MkdirAll(src, 0755); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(root, "outside.txt")
	if err := os.WriteFile(target, []byte("secret"), 0644); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(src, "link.txt")
	if err := os.Symlink(target, link); err != nil {
		t.Skipf("symlinks unavailable in this environment: %v", err)
	}
	if err := createZipFromDirectory(src, filepath.Join(root, "symlink.zip")); err == nil {
		t.Fatal("expected symlink to be rejected")
	}
}

func TestZipCreateRejectsOutputInsideSource(t *testing.T) {
	root := t.TempDir()
	src := filepath.Join(root, "src")
	if err := os.MkdirAll(src, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(src, "payload.txt"), []byte("x"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := createZipFromDirectory(src, filepath.Join(src, "self.zip")); err == nil {
		t.Fatal("expected archive output inside source to be rejected")
	}
}

func TestZipExtractRejectsSymlinkEntry(t *testing.T) {
	root := t.TempDir()
	zipPath := filepath.Join(root, "symlink-entry.zip")
	f, err := os.Create(zipPath)
	if err != nil {
		t.Fatal(err)
	}
	zw := zip.NewWriter(f)
	h := &zip.FileHeader{Name: "link.txt", Method: zip.Store}
	h.SetMode(os.ModeSymlink | 0777)
	w, err := zw.CreateHeader(h)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := w.Write([]byte("../outside.txt")); err != nil {
		t.Fatal(err)
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
	if err := extractZipSafe(zipPath, filepath.Join(root, "out")); err == nil {
		t.Fatal("expected symlink ZIP entry to be rejected")
	}
}

func TestZipExtractRejectsCaseCollidingFiles(t *testing.T) {
	root := t.TempDir()
	zipPath := filepath.Join(root, "duplicate.zip")
	f, err := os.Create(zipPath)
	if err != nil {
		t.Fatal(err)
	}
	zw := zip.NewWriter(f)
	for _, name := range []string{"Folder/File.txt", "folder/file.TXT"} {
		w, err := zw.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := w.Write([]byte(name)); err != nil {
			t.Fatal(err)
		}
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
	if err := extractZipSafe(zipPath, filepath.Join(root, "out")); err == nil {
		t.Fatal("expected duplicate/case-colliding ZIP entries to be rejected")
	}
}


func TestStartupDependencyInspectionIsReadOnly(t *testing.T) {
	root := t.TempDir()
	engine := filepath.Join(root, "Engine")
	if err := os.MkdirAll(engine, 0755); err != nil {
		t.Fatal(err)
	}
	repak := filepath.Join(engine, "repak.exe")
	oodle := filepath.Join(engine, "oo2core_9_win64.dll")
	if err := os.WriteFile(repak, []byte("invalid repak"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(oodle, []byte("unexpected oodle"), 0644); err != nil {
		t.Fatal(err)
	}
	const impossibleHash = "0000000000000000000000000000000000000000000000000000000000000000"
	m := ReleaseManifest{
		RepakSha256:                  impossibleHash,
		MappingsSha256:               impossibleHash,
		OodleExpectedSha256:          impossibleHash,
		StandardPackageDotnetBundled: true,
		DotnetRuntimeContract:        "8.0.30",
		DotnetRuntimeInventory:       "Engine/dotnet/runtime-8.0.30-win-x64.sha256.txt",
		DotnetRuntimeInventorySha256: impossibleHash,
		ManagedRuntimeSha256: map[string]string{
			"Engine/PMMCore/pmmcore.dll":                impossibleHash,
			"Engine/AssetReader/PMM.AssetReader.dll": impossibleHash,
		},
	}
	beforeRepak, err := os.ReadFile(repak)
	if err != nil {
		t.Fatal(err)
	}
	beforeOodle, err := os.ReadFile(oodle)
	if err != nil {
		t.Fatal(err)
	}

	status := inspectStartupDependencies(root, m)
	if status.Ready {
		t.Fatal("invalid startup dependencies must be reported as degraded")
	}

	afterRepak, err := os.ReadFile(repak)
	if err != nil {
		t.Fatal(err)
	}
	afterOodle, err := os.ReadFile(oodle)
	if err != nil {
		t.Fatal(err)
	}
	if string(beforeRepak) != string(afterRepak) {
		t.Fatal("startup inspection modified repak.exe")
	}
	if string(beforeOodle) != string(afterOodle) {
		t.Fatal("startup inspection modified Oodle runtime")
	}
	if _, err := os.Stat(filepath.Join(root, "Resources", "Mappings", "Mappings.usmap")); !os.IsNotExist(err) {
		t.Fatal("startup inspection created or changed mappings")
	}
	if _, err := os.Stat(filepath.Join(root, "Workspace")); !os.IsNotExist(err) {
		t.Fatal("startup inspection must not create Workspace state")
	}
}
