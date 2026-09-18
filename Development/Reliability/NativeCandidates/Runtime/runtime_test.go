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
