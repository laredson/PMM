package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"pmm.local/supervision"
	"regexp"
	"runtime"
	"sort"
	"strings"
	"time"
)

type GameDetection struct {
	Protocol      string   `json:"protocol"`
	Found         bool     `json:"found"`
	Installations []string `json:"installations"`
	Selected      string   `json:"selected,omitempty"`
	Sources       []string `json:"sources,omitempty"`
}

func detectPalworld(root string) GameDetection {
	d := GameDetection{Protocol: "PMM_GAME_DETECTION_V1"}
	set := map[string]bool{}
	var candidates []string
	add := func(p string) {
		p = normalizePath(p)
		if p == "" || set[strings.ToLower(p)] {
			return
		}
		set[strings.ToLower(p)] = true
		candidates = append(candidates, p)
	}
	// Existing configured path has first priority.
	cfgPath := filepath.Join(root, "Data", "config.json")
	if b, e := os.ReadFile(cfgPath); e == nil {
		var cfg map[string]any
		if json.Unmarshal(b, &cfg) == nil {
			if s, ok := cfg["GamePath"].(string); ok {
				add(s)
			}
		}
	}
	for _, r := range steamRoots() {
		for _, lib := range steamLibraries(r) {
			add(filepath.Join(lib, "steamapps", "common", "Palworld"))
		}
	}
	for _, p := range candidates {
		if isPalworldRoot(p) {
			d.Installations = append(d.Installations, p)
		}
	}
	sort.Strings(d.Installations)
	d.Found = len(d.Installations) > 0
	if d.Found {
		d.Selected = d.Installations[0]
	}
	return d
}

func normalizePath(p string) string {
	p = strings.TrimSpace(strings.Trim(p, "\""))
	if p == "" {
		return ""
	}
	a, e := filepath.Abs(p)
	if e == nil {
		return filepath.Clean(a)
	}
	return filepath.Clean(p)
}
func isPalworldRoot(p string) bool {
	if !existsDir(p) {
		return false
	}
	checks := []string{filepath.Join(p, "Pal", "Content", "Paks"), filepath.Join(p, "Palworld.exe"), filepath.Join(p, "Pal", "Binaries", "Win64")}
	score := 0
	for _, c := range checks {
		if existsDir(c) || existsFile(c) {
			score++
		}
	}
	return score >= 2
}

func steamRoots() []string {
	set := map[string]bool{}
	var out []string
	add := func(p string) {
		p = normalizePath(p)
		if p != "" && existsDir(p) && !set[strings.ToLower(p)] {
			set[strings.ToLower(p)] = true
			out = append(out, p)
		}
	}
	if x := os.Getenv("ProgramFiles(x86)"); x != "" {
		add(filepath.Join(x, "Steam"))
	}
	if x := os.Getenv("ProgramFiles"); x != "" {
		add(filepath.Join(x, "Steam"))
	}
	if runtime.GOOS == "windows" {
		if reg, err := supervision.SystemExecutable("reg.exe"); err == nil {
			for _, key := range []string{`HKCU\Software\Valve\Steam`, `HKLM\SOFTWARE\WOW6432Node\Valve\Steam`, `HKLM\SOFTWARE\Valve\Steam`} {
				r := runProcess(ProcessRequest{Executable: reg, Arguments: []string{"query", key, "/v", "SteamPath"}, Timeout: 3 * time.Second, OutputLimit: 4096})
				if r.TimedOut || (r.StartError == "" && !r.OutputComplete) {
					fmt.Fprintln(os.Stderr, "Steam registry probe incomplete: "+r.RunError)
				}
				if r.ExitCode == 0 {
					for _, line := range strings.Split(r.Stdout, "\n") {
						upper := strings.ToUpper(line)
						if i := strings.Index(upper, "REG_SZ"); i >= 0 {
							add(strings.TrimSpace(line[i+len("REG_SZ"):]))
						}
					}
				}
			}
		}
	}
	for c := 'C'; c <= 'Z'; c++ {
		add(string(c) + `:\Steam`)
		add(string(c) + `:\SteamLibrary`)
		add(string(c) + `:\Program Files (x86)\Steam`)
	}
	sort.Strings(out)
	return out
}

func steamLibraries(root string) []string {
	set := map[string]bool{strings.ToLower(root): true}
	out := []string{root}
	p := filepath.Join(root, "steamapps", "libraryfolders.vdf")
	f, e := os.Open(p)
	if e != nil {
		return out
	}
	defer f.Close()
	re := regexp.MustCompile(`"path"\s+"([^"]+)"`)
	s := bufio.NewScanner(f)
	for s.Scan() {
		m := re.FindStringSubmatch(s.Text())
		if len(m) == 2 {
			q := strings.ReplaceAll(m[1], `\\`, `\`)
			q = normalizePath(q)
			if q != "" && !set[strings.ToLower(q)] {
				set[strings.ToLower(q)] = true
				out = append(out, q)
			}
		}
	}
	return out
}
