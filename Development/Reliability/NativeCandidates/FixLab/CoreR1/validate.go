package corer1

import (
	"context"
	"path"
	"regexp"
	"sort"
	"strings"
)

func label(s string) bool { return len(s) > 0 && len(s) <= 256 && strings.TrimSpace(s) == s }
func safePath(s string) error {
	if len(s) == 0 || len(s) > 1024 || strings.HasPrefix(s, "/") {
		return fail("PATH", s, "invalid relative path")
	}
	parts := strings.Split(s, "/")
	if len(parts) > 32 {
		return fail("PATH", s, "depth")
	}
	for _, p := range parts {
		if p == "" || p == "." || p == ".." || len(p) > 255 || strings.TrimRight(p, " .") != p {
			return fail("PATH", s, "noncanonical component")
		}
		for _, c := range p {
			if c < 32 || c > 126 || strings.ContainsRune("\\:*?\"<>|", c) {
				return fail("PATH", s, "unsupported character")
			}
		}
		stem := strings.ToUpper(strings.Split(p, ".")[0])
		if stem == "CON" || stem == "PRN" || stem == "AUX" || stem == "NUL" || stem == "CONIN$" || stem == "CONOUT$" || len(stem) == 4 && (strings.HasPrefix(stem, "COM") || strings.HasPrefix(stem, "LPT")) && stem[3] >= '1' && stem[3] <= '9' {
			return fail("PATH", s, "reserved device")
		}
	}
	return nil
}

// Includes implicit directories: A/x and a/y conflict on Windows too.
func addPath(used map[string]string, files map[string]bool, s string) error {
	if err := safePath(s); err != nil {
		return err
	}
	parts := strings.Split(s, "/")
	for i := range parts {
		p := strings.Join(parts[:i+1], "/")
		key := strings.ToLower(p)
		old, exists := used[key]
		last := i == len(parts)-1
		if exists && (old != p || files[key] || last) {
			return fail("COLLISION", s, "duplicate, case or file/directory collision")
		}
		used[key] = p
		if last {
			files[key] = true
		}
	}
	return nil
}
func index(ctx context.Context, i Inventory, role string, l Limits) (map[string]File, error) {
	if i.Schema != "PMM_R1_INVENTORY_V1" || i.Role != role || !validHash(i.ProviderSHA256) || !label(i.Build) {
		return nil, fail("INVENTORY", role, "schema/role/provider/build")
	}
	if len(i.Files) == 0 || len(i.Files) > l.Files {
		return nil, fail("LIMIT", role, "file count")
	}
	m := map[string]File{}
	used, files := map[string]string{}, map[string]bool{}
	for _, f := range i.Files {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		if !validHash(f.SHA256) || f.SizeBytes < 0 {
			return nil, fail("INVENTORY", f.Path, "hash or size")
		}
		if err := addPath(used, files, f.Path); err != nil {
			return nil, err
		}
		m[f.Path] = f
	}
	return m, nil
}
func family(m map[string]File, p string) (Family, error) {
	if !strings.HasSuffix(p, ".uasset") {
		return Family{}, fail("FAMILY", p, "expected lowercase .uasset")
	}
	h, ok := m[p]
	if !ok {
		return Family{}, fail("MISSING", p, "header")
	}
	e, ok := m[strings.TrimSuffix(p, ".uasset")+".uexp"]
	if !ok {
		return Family{}, fail("MISSING", p, ".uexp sidecar")
	}
	f := Family{h, e, []File{}}
	for _, ext := range []string{".ubulk", ".uptnl"} {
		if b, ok := m[strings.TrimSuffix(p, ".uasset")+ext]; ok {
			f.Sidecars = append(f.Sidecars, b)
		}
	}
	return f, nil
}
func list(m map[string]File) []File {
	out := make([]File, 0, len(m))
	for _, f := range m {
		out = append(out, f)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Path < out[j].Path })
	return out
}
func patterns(in []string) ([]*regexp.Regexp, error) {
	if len(in) > 32 {
		return nil, fail("LIMIT", "regex", "too many rules")
	}
	out := []*regexp.Regexp{}
	seen := map[string]bool{}
	for _, s := range in {
		if len(s) == 0 || len(s) > 512 || seen[s] {
			return nil, fail("RECIPE", "regex", "length or duplicate")
		}
		seen[s] = true
		r, e := regexp.Compile(s)
		if e != nil {
			return nil, fail("RECIPE", "regex", e.Error())
		}
		out = append(out, r)
	}
	return out, nil
}
func matches(rs []*regexp.Regexp, s string) bool {
	for _, r := range rs {
		if r.MatchString(s) {
			return true
		}
	}
	return false
}
func fullMatch(r *regexp.Regexp, s string) bool {
	v := r.FindStringIndex(s)
	return v != nil && v[0] == 0 && v[1] == len(s)
}
func uniquePaths(paths []string, max int, headers bool) error {
	if len(paths) > max {
		return fail("LIMIT", "recipe", "paths")
	}
	seen := map[string]bool{}
	for _, s := range paths {
		if err := safePath(s); err != nil {
			return err
		}
		key := strings.ToLower(s)
		if seen[key] {
			return fail("RECIPE", s, "duplicate path")
		}
		seen[key] = true
		if headers && !strings.HasSuffix(s, ".uasset") {
			return fail("RECIPE", s, "expected .uasset")
		}
	}
	return nil
}
func recipeCheck(r Recipe) ([]*regexp.Regexp, []*regexp.Regexp, []*regexp.Regexp, error) {
	if r.Schema != "PMM_FIXLAB_RECIPE_V1" || r.Version != 1 || r.MountPoint != "../../../" || r.PathHashSeed != 0 {
		return nil, nil, nil, fail("RECIPE", r.ID, "unsupported schema/version/PAK profile")
	}
	for _, s := range []string{r.ID, r.Name, r.Status, r.TargetBuild} {
		if !label(s) {
			return nil, nil, nil, fail("RECIPE", "identity", "empty or long label")
		}
	}
	if len(r.Signatures) < 1 || len(r.Signatures) > 16 || len(r.Relocate) < 1 || len(r.Relocate) > 32 || len(r.NameSources) == 0 {
		return nil, nil, nil, fail("LIMIT", "recipe", "signatures/groups/name sources")
	}
	seen := map[string]bool{}
	for _, s := range r.Signatures {
		if !validHash(s.SHA256) || !label(s.Name) || s.Role != "accepted-donor" || seen[s.SHA256] {
			return nil, nil, nil, fail("RECIPE", "signature", "invalid or duplicate")
		}
		seen[s.SHA256] = true
	}
	for _, v := range []struct {
		p       []string
		max     int
		headers bool
	}{{r.NameSources, 64, true}, {r.Support.Roots, 64, false}, {r.Support.Files, 1024, false}} {
		if e := uniquePaths(v.p, v.max, v.headers); e != nil {
			return nil, nil, nil, e
		}
	}
	rs := []*regexp.Regexp{}
	groups := map[string]bool{}
	for _, g := range r.Relocate {
		if !label(g.Name) || groups[g.Name] || g.MinimumCount < 1 || g.MinimumCount > 16384 || g.KnownBaselineCount < g.MinimumCount || g.KnownBaselineCount > 16384 {
			return nil, nil, nil, fail("RECIPE", g.Name, "group identity/minimum/baseline")
		}
		groups[g.Name] = true
		if e := safePath(g.DonorUasset); e != nil {
			return nil, nil, nil, e
		}
		if path.Ext(g.DonorUasset) != ".uasset" {
			return nil, nil, nil, fail("RECIPE", g.Name, "donor extension")
		}
		_, e := patterns([]string{g.TargetRegex})
		if e != nil {
			return nil, nil, nil, e
		}
		whole, e := regexp.Compile(`\A(?:` + g.TargetRegex + `)\z`)
		if e != nil {
			return nil, nil, nil, fail("RECIPE", g.Name, e.Error())
		}
		rs = append(rs, whole)
		if g.PostProcess != nil {
			p := g.PostProcess
			if !label(p.StaleClass) || !label(p.SafeClass) || p.StaleClass == p.SafeClass || len(p.ExpectedSerializedOffsets) != 1 || p.ExpectedSerializedOffsets[0] < 0 || p.ExpectedSerializedOffsets[0] > 256<<20 {
				return nil, nil, nil, fail("RECIPE", g.Name, "unsupported postProcess contract")
			}
		}
	}
	ex, e := patterns(r.Support.Excludes)
	if e != nil {
		return nil, nil, nil, e
	}
	forbid, e := patterns(r.Forbidden)
	return rs, ex, forbid, e
}
