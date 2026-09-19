//go:build linux

package corer1

import (
	"os"
	"path/filepath"
	"syscall"
	"testing"
)

func TestMembershipArchiveSubstitutionLinksAndFIFO(t *testing.T) {
	for _, kind := range []string{"symlink", "hardlink", "fifo"} {
		t.Run(kind, func(t *testing.T) {
			q, m := membershipFixture(t, false, nil)
			cap := mustCapture(t, q)
			path := filepath.Join(q.Roots.Archives, q.DonorArchive.Path)
			save := path + ".saved"
			if e := os.Rename(path, save); e != nil {
				t.Fatal(e)
			}
			var e error
			switch kind {
			case "symlink":
				e = os.Symlink(save, path)
			case "hardlink":
				e = os.Link(save, path)
			case "fifo":
				e = syscall.Mkfifo(path, 0600)
			}
			if e != nil {
				t.Fatal(e)
			}
			memberError(t, cap, m, "")
		})
	}
}
