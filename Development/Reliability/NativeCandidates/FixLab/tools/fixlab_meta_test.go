package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDigestKnownBytes(t *testing.T) {
	if digest([]byte("abc")) != "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" {
		t.Fatal("digest")
	}
}
func TestMissingInput(t *testing.T) {
	if _, e := inspect(filepath.Join(t.TempDir(), "missing.exe")); e == nil {
		t.Fatal("accepted absent input")
	}
}
func TestNonPEInputs(t *testing.T) {
	for _, b := range [][]byte{nil, []byte("not executable"), []byte("MZ")} {
		p := filepath.Join(t.TempDir(), "fixture.exe")
		if e := os.WriteFile(p, b, 0600); e != nil {
			t.Fatal(e)
		}
		if _, e := inspect(p); e == nil {
			t.Fatal("accepted malformed input")
		}
	}
}
func TestDirectoryRejected(t *testing.T) {
	if _, e := inspect(t.TempDir()); e == nil {
		t.Fatal("accepted directory")
	}
}
func TestOversizedInputRejected(t *testing.T) {
	p := filepath.Join(t.TempDir(), "oversize.exe")
	f, e := os.Create(p)
	if e != nil {
		t.Fatal(e)
	}
	if e = f.Truncate(129 << 20); e != nil {
		f.Close()
		t.Fatal(e)
	}
	f.Close()
	if _, e := inspect(p); e == nil {
		t.Fatal("accepted oversized file")
	}
}
