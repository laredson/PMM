//go:build linux && amd64

package corer1

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPublicationLinuxPermissionsAndSymlinks(t *testing.T) {
	r, q := publicationFixture(t)
	p := published(t, r, q)
	dir := filepath.Join(q.Parent, p.CandidateName)
	s, _ := os.Stat(dir)
	if s.Mode().Perm() != 0700 {
		t.Fatal(s.Mode())
	}
	for _, n := range []string{"candidate.pak", "execution.json", "MANIFEST.json", "COMPLETE.json"} {
		s, _ := os.Stat(filepath.Join(dir, n))
		if s.Mode().Perm() != 0600 {
			t.Fatal(s.Mode())
		}
	}
	alias := filepath.Join(t.TempDir(), "alias")
	if e := os.Symlink(q.Parent, alias); e != nil {
		t.Fatal(e)
	}
	bad := q
	bad.Parent = alias
	if p, e := PublishCandidate(context.Background(), r, bad); p != nil || e == nil {
		t.Fatal("symlink parent")
	}
	os.Remove(filepath.Join(dir, "candidate.pak"))
	os.Symlink(filepath.Join(dir, "execution.json"), filepath.Join(dir, "candidate.pak"))
	if _, e := InspectCandidate(context.Background(), dir, p.ManifestSHA256); e == nil {
		t.Fatal("symlink file")
	}
}
func TestPublicationLinuxCorruptionDuringWriteRejected(t *testing.T) {
	r, q := publicationFixture(t)
	var stage string
	p, e := publishCandidate(context.Background(), r, q, publicationHooks{event: func(s string) error {
		if strings.HasPrefix(s, "created:") {
			stage = strings.TrimPrefix(s, "created:")
		}
		if s == "readback:candidate.pak" {
			return os.WriteFile(filepath.Join(q.Parent, stage, "candidate.pak"), []byte("corrupt"), 0600)
		}
		return nil
	}})
	if p != nil || e == nil {
		t.Fatal(p, e)
	}
	emptyCandidateParent(t, q.Parent)
}
func TestPublicationLinuxForeignReplacementNotDeleted(t *testing.T) {
	r, q := publicationFixture(t)
	var stage string
	p, e := publishCandidate(context.Background(), r, q, publicationHooks{event: func(s string) error {
		if strings.HasPrefix(s, "created:") {
			stage = strings.TrimPrefix(s, "created:")
		}
		if s == "before-commit" {
			f := filepath.Join(q.Parent, stage, "candidate.pak")
			if e := os.Rename(f, f+".moved"); e != nil {
				return e
			}
			return os.WriteFile(f, []byte("foreign"), 0600)
		}
		return nil
	}})
	var pe *PublicationError
	if p != nil || !errors.As(e, &pe) || pe.ResidueName == "" {
		t.Fatal(p, e)
	}
	b, _ := os.ReadFile(filepath.Join(q.Parent, stage, "candidate.pak"))
	if string(b) != "foreign" {
		t.Fatal("foreign removed")
	}
}
func TestPublicationLinuxEmptyDestinationNeverReplaced(t *testing.T) {
	r, q := publicationFixture(t)
	id := strings.Repeat("b", 32)
	target := filepath.Join(q.Parent, candidatePrefix+id)
	os.Mkdir(target, 0700)
	before, _ := os.Stat(target)
	p, e := publishCandidate(context.Background(), r, q, publicationHooks{token: func() (string, error) { return id, nil }})
	after, _ := os.Stat(target)
	if p != nil || e == nil || !os.SameFile(before, after) {
		t.Fatal("empty destination replaced")
	}
}
func TestPublicationLinuxUnexpectedFileSurvivesRollback(t *testing.T) {
	r, q := publicationFixture(t)
	var stage string
	p, e := publishCandidate(context.Background(), r, q, publicationHooks{event: func(s string) error {
		if strings.HasPrefix(s, "created:") {
			stage = strings.TrimPrefix(s, "created:")
		}
		if s == "before-commit" {
			os.WriteFile(filepath.Join(q.Parent, stage, "foreign"), []byte("keep"), 0600)
			return errors.New("stop")
		}
		return nil
	}})
	if p != nil || e == nil {
		t.Fatal(p, e)
	}
	b, _ := os.ReadFile(filepath.Join(q.Parent, stage, "foreign"))
	if string(b) != "keep" {
		t.Fatal("foreign removed")
	}
}
