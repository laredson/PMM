package pmmdlt1

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

// Explicit opt-in: inspect packaged deltas only, never source/game assets.
// Pinning in this TEST is via the independently generated aggregate digest;
// production callers must never self-pin an arbitrary patch to authenticate it.
func TestPackagedCorpusAgainstIndependentParser(t *testing.T) {
	root := os.Getenv("PMM_FIXLAB_PACKAGE")
	if root == "" {
		t.Skip("set PMM_FIXLAB_PACKAGE for read-only corpus validation")
	}
	if !filepath.IsAbs(root) {
		t.Fatal("package root must be absolute")
	}
	b, e := os.ReadFile("evidence/corpus-summary.json")
	if e != nil {
		t.Fatal(e)
	}
	var expected struct {
		Count      int    `json:"uniquePayloads"`
		Operations int    `json:"operations"`
		Digest     string `json:"metadataSha256"`
	}
	if e = json.Unmarshal(b, &expected); e != nil {
		t.Fatal(e)
	}
	const rel = "CKL/FixLab/Cases/FIXLAB-CASE-001-GAWR-GURA/payload-v2"
	dir := root
	for _, part := range strings.Split(rel, "/") {
		dir = filepath.Join(dir, part)
		s, e := os.Lstat(dir)
		if e != nil || s.Mode()&os.ModeSymlink != 0 {
			t.Fatal("unsafe directory", e)
		}
	}
	files, e := filepath.Glob(filepath.Join(dir, "*.pmmdlt"))
	if e != nil {
		t.Fatal(e)
	}
	sort.Strings(files)
	if len(files) != expected.Count || len(files) != 137 {
		t.Fatal("unexpected corpus size", len(files))
	}
	aggregate := sha256.New()
	operations := 0
	for _, path := range files {
		s, e := os.Lstat(path)
		if e != nil || !s.Mode().IsRegular() || s.Size() > 16<<20 {
			t.Fatal("bad payload", e)
		}
		data, e := os.ReadFile(path)
		if e != nil {
			t.Fatal(e)
		}
		i, e := Inspect(context.Background(), data, pin(data), Limits{})
		if e != nil {
			t.Fatal(path, e)
		}
		bounds := []string{}
		for _, u := range i.References {
			bounds = append(bounds, fmt.Sprintf("%d:%d", u.Index, u.MinimumBytes))
		}
		line := fmt.Sprintf("%s/%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\n",
			rel, filepath.Base(path), i.PatchSHA256, i.PatchBytes, i.DecodedBytes, i.OutputBytes,
			i.Operations, i.CopyOperations, i.LiteralOperations, i.CopyBytes, i.LiteralBytes, strings.Join(bounds, ","))
		_, _ = aggregate.Write([]byte(line))
		operations += int(i.Operations)
	}
	if operations != expected.Operations || hex.EncodeToString(aggregate.Sum(nil)) != expected.Digest {
		t.Fatal("independent metadata mismatch")
	}
	t.Logf("137 payloads, %d operations; all metadata agrees with independent Python parser. No asset transformation.", operations)
}
