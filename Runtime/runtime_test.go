package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCleanRelPathRejectsTraversal(t *testing.T) {
	bad := []string{"../evil", "../../evil", "/absolute"}
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
