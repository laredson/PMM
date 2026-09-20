//go:build windows && amd64

package corer1

import (
	"testing"
	"unsafe"
)

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
