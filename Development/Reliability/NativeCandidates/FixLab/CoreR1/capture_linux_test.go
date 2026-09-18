//go:build linux

package corer1

import (
	"context"
	"os"
	"path/filepath"
	"syscall"
	"testing"
)

func TestCaptureLinuxLinksAndSpecialFiles(t *testing.T) {
	for _, kind := range []string{"leaf-link", "parent-link", "root-link", "hard-link", "fifo"} {
		t.Run(kind, func(t *testing.T) {
			q, _ := captureFixture(t, false)
			p := filepath.Join(q.Roots.Donor, "D/Body.uasset")
			switch kind {
			case "leaf-link":
				os.Rename(p, p+".old")
				if e := os.Symlink(p+".old", p); e != nil {
					t.Fatal(e)
				}
			case "parent-link":
				d := filepath.Join(q.Roots.Donor, "D")
				os.Rename(d, d+".old")
				os.Symlink(d+".old", d)
			case "root-link":
				os.Rename(q.Roots.Donor, q.Roots.Donor+".old")
				os.Symlink(q.Roots.Donor+".old", q.Roots.Donor)
			case "hard-link":
				if e := os.Link(p, p+".alias"); e != nil {
					t.Fatal(e)
				}
			case "fifo":
				os.Remove(p)
				if e := syscall.Mkfifo(p, 0600); e != nil {
					t.Fatal(e)
				}
			}
			captureError(t, q)
		})
	}
}
func TestCaptureLinuxConcurrentReplacementRejected(t *testing.T) {
	for _, change := range []string{"replace-same-bytes", "edit-after-read", "truncate", "parent-symlink"} {
		t.Run(change, func(t *testing.T) {
			q, _ := captureFixture(t, false)
			p := filepath.Join(q.Roots.Donor, "D/Body.uasset")
			b, _ := os.ReadFile(p)
			want := File{"D/Body.uasset", hash(b), int64(len(b))}
			r, e := openRoot(q.Roots.Donor)
			if e != nil {
				t.Fatal(e)
			}
			defer r.Close()
			start, done := make(chan struct{}), make(chan error)
			go func() {
				<-start
				var e error
				switch change {
				case "replace-same-bytes":
					e = os.Rename(p, p+".old")
					if e == nil {
						e = os.WriteFile(p, b, 0600)
					}
				case "edit-after-read":
					x := append([]byte{}, b...)
					x[0] ^= 1
					e = os.WriteFile(p, x, 0600)
				case "truncate":
					e = os.Truncate(p, 0)
				case "parent-symlink":
					d := filepath.Dir(p)
					e = os.Rename(d, d+".old")
					if e == nil {
						e = os.Symlink(d+".old", d)
					}
				}
				done <- e
			}()
			data, e := captureFile(context.Background(), r, want, true, 256<<20, func() {
				close(start)
				if x := <-done; x != nil {
					t.Fatal(x)
				}
			})
			if e == nil || data != nil {
				t.Fatal("accepted concurrent mutation")
			}
		})
	}
}
func TestCaptureLinuxAnchoredRootNotRedirected(t *testing.T) {
	q, _ := captureFixture(t, false)
	p := filepath.Join(q.Roots.Donor, "D/Body.uasset")
	b, _ := os.ReadFile(p)
	r, e := openRoot(q.Roots.Donor)
	if e != nil {
		t.Fatal(e)
	}
	defer r.Close()
	elsewhere := t.TempDir()
	put(t, elsewhere, "D/Body.uasset", []byte("DIFFERENT OUTSIDE BYTES"))
	if e = os.Rename(q.Roots.Donor, q.Roots.Donor+".old"); e != nil {
		t.Fatal(e)
	}
	if e = os.Symlink(elsewhere, q.Roots.Donor); e != nil {
		t.Fatal(e)
	}
	got, e := captureFile(context.Background(), r, File{"D/Body.uasset", hash(b), int64(len(b))}, true, 256<<20, nil)
	if e != nil || string(got) != string(b) {
		t.Fatal("held root redirected", e)
	}
}
