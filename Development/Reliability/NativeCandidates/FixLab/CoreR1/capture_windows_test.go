//go:build windows && amd64

package corer1

import (
	"os"
	"path/filepath"
	"testing"
	"unsafe"
)

func TestCaptureWindowsABISizes(t *testing.T) {
	if unsafe.Sizeof(captureUnicode{}) != 16 || unsafe.Sizeof(captureObjectAttributes{}) != 48 || unsafe.Sizeof(captureIOStatus{}) != 16 {
		t.Fatal("unexpected Windows AMD64 ABI")
	}
}
func TestCaptureWindowsLeafDeniesWriteAndDelete(t *testing.T) {
	q, _ := captureFixture(t, false)
	r, e := openRoot(q.Roots.Donor)
	if e != nil {
		t.Fatal(e)
	}
	defer r.Close()
	f, e := r.Open("D/Body.uasset")
	if e != nil {
		t.Fatal(e)
	}
	defer f.Close()
	p := filepath.Join(q.Roots.Donor, "D/Body.uasset")
	if w, e := os.OpenFile(p, os.O_WRONLY, 0); e == nil {
		w.Close()
		t.Fatal("write-sharing not denied")
	}
	if e := os.Rename(p, p+".moved"); e == nil {
		t.Fatal("delete/rename sharing not denied")
	}
}
