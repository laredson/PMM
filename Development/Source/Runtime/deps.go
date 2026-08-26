package main

import (
	"archive/zip"
	"bufio"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

type DependencyStatus struct {
	Protocol           string   `json:"protocol"`
	Ready              bool     `json:"ready"`
	Dotnet             string   `json:"dotnet"`
	DotnetOK           bool     `json:"dotnet_ok"`
	RuntimeInventoryOK bool     `json:"runtime_inventory_ok"`
	RepakOK            bool     `json:"repak_ok"`
	MappingsOK         bool     `json:"mappings_ok"`
	ManagedPayloadOK   bool     `json:"managed_payload_ok"`
	PMMCoreOK          bool     `json:"pmmcore_ok"`
	AssetReaderOK      bool     `json:"asset_reader_ok"`
	OodleRemoved       bool     `json:"oodle_removed"`
	Notes              []string `json:"notes,omitempty"`
}

func ensureDependencies(root string, ifNeeded, refreshMappings bool) (DependencyStatus, error) {
	m, err := loadReleaseManifest(root)
	if err != nil {
		return DependencyStatus{}, err
	}
	if m.SourceTreeRequiresReleaseBuild {
		return DependencyStatus{}, fmt.Errorf("this is a release-builder source tree, not an end-user package")
	}
	tools := filepath.Join(root, "Engine")
	mappingsDir := filepath.Join(root, "Resources", "Mappings")
	_ = os.MkdirAll(tools, 0755)
	_ = os.MkdirAll(mappingsDir, 0755)

	status := inspectDependencies(root, m)
	status.OodleRemoved = repairOodle(root, m)
	if ifNeeded && status.Ready {
		saveDotnetSelection(root, m, status.Dotnet)
		logLine(root, "Dependencies", "Dependencies verified by PMMRuntime; startup setup skipped with no network access.")
		return status, nil
	}

	// Repair repak from verified nearby copy before network.
	repak := filepath.Join(root, "Engine", "repak.exe")
	if existsFile(repak) && !hashMatches(repak, m.RepakSha256) {
		_ = os.Remove(repak)
	}
	if !hashMatches(repak, m.RepakSha256) {
		if near := findNearbyVerified(root, "Engine/repak.exe", m.RepakSha256); near != "" {
			if err := copyFile(near, repak); err == nil {
				logLine(root, "Dependencies", "Reused verified nearby repak.exe: "+near)
			}
		}
	}
	if !hashMatches(repak, m.RepakSha256) {
		logLine(root, "Dependencies", "Repairing pinned repak "+m.RepakVersion+" from upstream...")
		url := "https://github.com/trumank/repak/releases/download/v" + m.RepakVersion + "/repak_cli-x86_64-pc-windows-msvc.zip"
		tmp, err := downloadTemp(url, "pmm-repak-*.zip", 120*time.Second)
		if err != nil {
			return status, err
		}
		defer os.Remove(tmp)
		stage, err := os.MkdirTemp("", "pmm-repak-stage-")
		if err != nil {
			return status, err
		}
		defer os.RemoveAll(stage)
		if err := extractZipSafe(tmp, stage); err != nil {
			return status, err
		}
		var found string
		_ = filepath.Walk(stage, func(p string, info os.FileInfo, e error) error {
			if e == nil && info != nil && !info.IsDir() && strings.EqualFold(info.Name(), "repak.exe") && found == "" {
				found = p
			}
			return nil
		})
		if found == "" || !hashMatches(found, m.RepakSha256) {
			return status, fmt.Errorf("downloaded repak.exe does not match release pin")
		}
		if err := copyFile(found, repak); err != nil {
			return status, err
		}
	}

	// Mapping repair/refresh.
	mapping := filepath.Join(root, "Resources", "Mappings", "Mappings.usmap")
	mappingGood := hashMatches(mapping, m.MappingsSha256) && fileSize(mapping) > 1024
	if refreshMappings || !mappingGood {
		if !refreshMappings {
			if near := findNearbyVerified(root, "Resources/Mappings/Mappings.usmap", m.MappingsSha256); near != "" && fileSize(near) > 1024 {
				_ = copyFile(near, mapping)
				mappingGood = true
				logLine(root, "Dependencies", "Reused verified nearby Mappings.usmap: "+near)
			}
		}
		if refreshMappings || !mappingGood {
			tmp, err := downloadTemp("https://raw.githubusercontent.com/PalworldModding/UsefulFiles/master/Mappings.usmap", "pmm-mappings-*.usmap", 120*time.Second)
			if err != nil {
				return status, err
			}
			defer os.Remove(tmp)
			if fileSize(tmp) <= 1024 {
				return status, fmt.Errorf("downloaded mappings file is unexpectedly small")
			}
			if m.MappingsSha256 != "" && !hashMatches(tmp, m.MappingsSha256) {
				return status, fmt.Errorf("upstream mappings differ from the release-pinned mapping; not installed")
			}
			if err := copyFile(tmp, mapping); err != nil {
				return status, err
			}
		}
	}

	// Runtime repair. Public package requires its pinned bundled runtime.
	runtimeDir := filepath.Join(root, "Engine", "dotnet", m.DotnetRuntimeContract)
	if m.StandardPackageDotnetBundled && !testRuntimeInventory(root, m, runtimeDir) {
		if m.DotnetRuntimeArchiveURL == "" || m.DotnetRuntimeArchiveSha512 == "" {
			return status, fmt.Errorf("bundled runtime invalid and no pinned repair archive is declared")
		}
		logLine(root, "Dependencies", "Installing/repairing portable .NET Runtime "+m.DotnetRuntimeContract+" from pinned Microsoft package...")
		tmp, err := downloadTemp(m.DotnetRuntimeArchiveURL, "pmm-dotnet-*.zip", 120*time.Second)
		if err != nil {
			return status, err
		}
		defer os.Remove(tmp)
		if !strings.EqualFold(fileSHA512(tmp), m.DotnetRuntimeArchiveSha512) {
			return status, fmt.Errorf("portable .NET Runtime SHA-512 mismatch")
		}
		stage, err := os.MkdirTemp("", "pmm-dotnet-stage-")
		if err != nil {
			return status, err
		}
		defer os.RemoveAll(stage)
		if err := extractZipSafe(tmp, stage); err != nil {
			return status, err
		}
		_ = os.RemoveAll(runtimeDir)
		if err := os.MkdirAll(filepath.Dir(runtimeDir), 0755); err != nil {
			return status, err
		}
		if err := moveDirectory(stage, runtimeDir); err != nil {
			return status, err
		}
		if !testRuntimeInventory(root, m, runtimeDir) {
			return status, fmt.Errorf("repaired .NET runtime failed inventory verification")
		}
	}

	// Repair managed files from verified sibling releases only. Never rebuild on end-user machines.
	for rel, expected := range m.ManagedRuntimeSha256 {
		target := filepath.Join(root, filepath.FromSlash(rel))
		if hashMatches(target, expected) {
			continue
		}
		if near := findNearbyVerified(root, rel, expected); near != "" {
			if err := copyFile(near, target); err == nil {
				logLine(root, "Dependencies", "Repaired managed PMM payload from verified nearby copy: "+rel)
			}
		}
	}

	status = inspectDependencies(root, m)
	if !status.Ready {
		return status, fmt.Errorf("dependency verification failed after repair")
	}
	saveDotnetSelection(root, m, status.Dotnet)
	logLine(root, "Dependencies", "PMMRuntime dependency preparation complete.")
	return status, nil
}

func inspectDependencies(root string, m ReleaseManifest) DependencyStatus {
	s := DependencyStatus{Protocol: "PMM_RUNTIME_DEPENDENCIES_V1"}
	runtimeDir := filepath.Join(root, "Engine", "dotnet", m.DotnetRuntimeContract)
	bundled := filepath.Join(runtimeDir, "dotnet.exe")
	s.RuntimeInventoryOK = testRuntimeInventory(root, m, runtimeDir)
	if s.RuntimeInventoryOK && testExactRuntimeHost(root, bundled, m.DotnetRuntimeContract) {
		s.Dotnet = bundled
		s.DotnetOK = true
	}
	if !m.StandardPackageDotnetBundled && !s.DotnetOK {
		if p := findSystemDotnet(); p != "" && testExactRuntimeHost(root, p, m.DotnetRuntimeContract) {
			s.Dotnet = p
			s.DotnetOK = true
		}
	}
	s.RepakOK = hashMatches(filepath.Join(root, "Engine", "repak.exe"), m.RepakSha256)
	s.MappingsOK = fileSize(filepath.Join(root, "Resources", "Mappings", "Mappings.usmap")) > 1024 && hashMatches(filepath.Join(root, "Resources", "Mappings", "Mappings.usmap"), m.MappingsSha256)
	s.ManagedPayloadOK = true
	for rel, h := range m.ManagedRuntimeSha256 {
		if !hashMatches(filepath.Join(root, filepath.FromSlash(rel)), h) {
			s.ManagedPayloadOK = false
			break
		}
	}
	if s.DotnetOK && s.ManagedPayloadOK {
		core := filepath.Join(root, "Engine", "PMMCore", "pmmcore.dll")
		rc, out, _ := commandOutput(60*time.Second, root, s.Dotnet, core, "self-test")
		s.PMMCoreOK = rc == 0 && regexp.MustCompile(`(?m)^PMMCORE_SELFTEST_OK\s+`+regexp.QuoteMeta(m.PMMCoreVersion)+`\s*$`).MatchString(out)
		reader := filepath.Join(root, "Engine", "AssetReader", "PMM.AssetReader.dll")
		rc, _, _ = commandOutput(60*time.Second, root, s.Dotnet, reader, "self-test-deps")
		s.AssetReaderOK = rc == 0
	}
	s.Ready = s.DotnetOK && s.RepakOK && s.MappingsOK && s.ManagedPayloadOK && s.PMMCoreOK && s.AssetReaderOK
	return s
}

func repairOodle(root string, m ReleaseManifest) bool {
	p := filepath.Join(root, "Engine", "oo2core_9_win64.dll")
	if !existsFile(p) || m.OodleExpectedSha256 == "" {
		return false
	}
	if !hashMatches(p, m.OodleExpectedSha256) {
		actual := fileSHA256(p)
		if os.Remove(p) == nil {
			logLine(root, "Dependencies", "Removed unexpected Oodle runtime hash; repak may reacquire its pinned runtime on demand. Found: "+actual)
			return true
		}
	}
	return false
}

func testExactRuntimeHost(root, exe, version string) bool {
	if !existsFile(exe) {
		return false
	}
	rc, out, _ := commandOutput(30*time.Second, root, exe, "--list-runtimes")
	if rc != 0 {
		return false
	}
	re := regexp.MustCompile(`(?m)^Microsoft\.NETCore\.App\s+` + regexp.QuoteMeta(version) + `\s+\[`)
	return re.MatchString(out)
}
func findSystemDotnet() string {
	if e := os.Getenv("PMM_DOTNET"); e != "" && existsFile(e) {
		return e
	}
	return findExecutable("dotnet.exe")
}
func hashMatches(p, want string) bool {
	if want == "" {
		return existsFile(p)
	}
	return strings.EqualFold(fileSHA256(p), strings.TrimSpace(want))
}
func fileSize(p string) int64 {
	st, e := os.Stat(p)
	if e != nil {
		return 0
	}
	return st.Size()
}

func testRuntimeInventory(root string, m ReleaseManifest, runtimeDir string) bool {
	inv := filepath.Join(root, filepath.FromSlash(m.DotnetRuntimeInventory))
	if !existsDir(runtimeDir) || !existsFile(inv) {
		return !m.StandardPackageDotnetBundled
	}
	if m.DotnetRuntimeInventorySha256 != "" && !hashMatches(inv, m.DotnetRuntimeInventorySha256) {
		return false
	}
	f, e := os.Open(inv)
	if e != nil {
		return false
	}
	defer f.Close()
	expected := map[string]string{}
	scan := bufio.NewScanner(f)
	re := regexp.MustCompile(`^([0-9a-fA-F]{64})\s{2}(.+)$`)
	for scan.Scan() {
		line := strings.TrimSpace(scan.Text())
		if line == "" {
			continue
		}
		mch := re.FindStringSubmatch(line)
		if len(mch) != 3 {
			return false
		}
		rel, e := cleanRelPath(mch[2])
		if e != nil {
			return false
		}
		expected[strings.ToLower(filepath.Clean(rel))] = strings.ToLower(mch[1])
		if !hashMatches(filepath.Join(runtimeDir, rel), mch[1]) {
			return false
		}
	}
	if len(expected) < 20 {
		return false
	}
	actual := 0
	_ = filepath.Walk(runtimeDir, func(p string, info os.FileInfo, e error) error {
		if e == nil && info != nil && !info.IsDir() {
			actual++
			rel, _ := filepath.Rel(runtimeDir, p)
			if _, ok := expected[strings.ToLower(filepath.Clean(rel))]; !ok {
				actual = -999999
			}
		}
		return nil
	})
	return actual == len(expected)
}

func saveDotnetSelection(root string, m ReleaseManifest, dotnet string) {
	marker := filepath.Join(root, "Workspace", "State", "dotnet-host.txt")
	bundled := filepath.Join(root, "Tools", "dotnet", m.DotnetRuntimeContract, "dotnet.exe")
	if samePath(dotnet, bundled) {
		_ = os.Remove(marker)
	} else if dotnet != "" {
		_ = os.WriteFile(marker, []byte(dotnet+"\n"), 0644)
	}
}

func nearbyRoots(root string) []string {
	parent := filepath.Dir(root)
	entries, e := os.ReadDir(parent)
	if e != nil {
		return nil
	}
	set := map[string]bool{}
	var out []string
	for _, d := range entries {
		if !d.IsDir() {
			continue
		}
		p := filepath.Join(parent, d.Name())
		if samePath(p, root) {
			continue
		}
		if !set[p] {
			out = append(out, p)
			set[p] = true
		}
		children, _ := os.ReadDir(p)
		for _, c := range children {
			if !c.IsDir() {
				continue
			}
			n := strings.ToLower(c.Name())
			if strings.Contains(n, "palmodmerger") || strings.Contains(n, "palworld") && strings.Contains(n, "merger") {
				q := filepath.Join(p, c.Name())
				if !set[q] {
					out = append(out, q)
					set[q] = true
				}
			}
		}
	}
	sort.Strings(out)
	return out
}
func findNearbyVerified(root, rel, want string) string {
	clean, e := cleanRelPath(rel)
	if e != nil {
		return ""
	}
	for _, r := range nearbyRoots(root) {
		p := filepath.Join(r, clean)
		if hashMatches(p, want) {
			return p
		}
	}
	return ""
}

func copyFile(src, dst string) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return err
	}
	in, e := os.Open(src)
	if e != nil {
		return e
	}
	defer in.Close()
	out, e := os.Create(dst)
	if e != nil {
		return e
	}
	_, ce := io.Copy(out, in)
	closeErr := out.Close()
	if ce != nil {
		return ce
	}
	return closeErr
}
func moveDirectory(src, dst string) error {
	if err := os.Rename(src, dst); err == nil {
		return nil
	}
	if err := copyTree(src, dst); err != nil {
		return err
	}
	return os.RemoveAll(src)
}
func copyTree(src, dst string) error {
	return filepath.Walk(src, func(p string, info os.FileInfo, e error) error {
		if e != nil {
			return e
		}
		rel, _ := filepath.Rel(src, p)
		t := filepath.Join(dst, rel)
		if info.IsDir() {
			return os.MkdirAll(t, info.Mode())
		}
		return copyFile(p, t)
	})
}

func downloadTemp(url, pattern string, timeout time.Duration) (string, error) {
	f, e := os.CreateTemp("", pattern)
	if e != nil {
		return "", e
	}
	p := f.Name()
	f.Close()
	client := &http.Client{Timeout: timeout}
	resp, e := client.Get(url)
	if e != nil {
		os.Remove(p)
		return "", e
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		os.Remove(p)
		return "", fmt.Errorf("download HTTP %s", resp.Status)
	}
	out, e := os.Create(p)
	if e != nil {
		os.Remove(p)
		return "", e
	}
	_, ce := io.Copy(out, resp.Body)
	cl := out.Close()
	if ce != nil {
		os.Remove(p)
		return "", ce
	}
	if cl != nil {
		os.Remove(p)
		return "", cl
	}
	return p, nil
}

// Keep archive/zip imported in this file's dependency surface explicit for the build audit.
var _ = zip.Store
