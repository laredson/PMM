package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

type SecurityStatus struct {
	Protocol                    string `json:"protocol"`
	RuntimeVersion              string `json:"runtime_version"`
	RuntimeExecutable           string `json:"runtime_executable"`
	Root                        string `json:"root"`
	OS                          string `json:"os"`
	Architecture                string `json:"architecture"`
	PowerShell                  string `json:"powershell,omitempty"`
	PowerShellAvailable         bool   `json:"powershell_available"`
	PowerShellLanguageMode      string `json:"powershell_language_mode,omitempty"`
	PowerShellProbeError        string `json:"powershell_probe_error,omitempty"`
	RuntimeRequiresPowerShell   bool   `json:"runtime_requires_powershell"`
	RuntimeRequiresFullLanguage bool   `json:"runtime_requires_full_language"`
	Note                        string `json:"note"`
}

type RuntimeDoctor struct {
	Protocol       string              `json:"protocol"`
	RuntimeVersion string              `json:"runtime_version"`
	BuildID        string              `json:"build_id"`
	Root           string              `json:"root"`
	Security       SecurityStatus      `json:"security"`
	Dependencies   DependencyStatus    `json:"dependencies"`
	Knowledge      KnowledgeValidation `json:"knowledge"`
	Game           GameDetection       `json:"game"`
	RequiredFiles  map[string]bool     `json:"required_files"`
}

func runtimeSecurity(root string) SecurityStatus {
	exe, _ := os.Executable()
	s := SecurityStatus{Protocol: "PMM_RUNTIME_SECURITY_V1", RuntimeVersion: runtimeVersion, RuntimeExecutable: exe, Root: root, OS: runtime.GOOS, Architecture: runtime.GOARCH, RuntimeRequiresPowerShell: false, RuntimeRequiresFullLanguage: false, Note: "PMMRuntime native capabilities do not request or force PowerShell FullLanguage. PowerShell is probed only to report the environment while the legacy UI remains available during migration."}
	shell := findPowerShell()
	s.PowerShell = shell
	s.PowerShellAvailable = shell != ""
	if shell != "" {
		cmd := exec.Command(shell, "-NoProfile", "-NonInteractive", "-Command", "$ExecutionContext.SessionState.LanguageMode")
		configureProcess(cmd)
		cmd.Dir = root
		b, e := cmd.CombinedOutput()
		if e != nil {
			s.PowerShellProbeError = strings.TrimSpace(string(b))
			if s.PowerShellProbeError == "" {
				s.PowerShellProbeError = e.Error()
			}
		} else {
			s.PowerShellLanguageMode = strings.TrimSpace(string(b))
		}
	}
	return s
}

func runtimeDoctor(root string) RuntimeDoctor {
	m, _ := loadReleaseManifest(root)
	deps := inspectDependencies(root, m)
	req := []string{"PMM.exe", "Engine/PMMRuntime.exe", "CKL/Stable/package-rules.json", "CKL/Catalog/case-index.json", "Engine/repak.exe", "Engine/PMMCore/pmmcore.dll", "Engine/AssetReader/PMM.AssetReader.dll", "Resources/Mappings/Mappings.usmap"}
	files := map[string]bool{}
	for _, r := range req {
		p := filepath.Join(root, filepath.FromSlash(r))
		files[r] = existsFile(p)
	}
	return RuntimeDoctor{Protocol: "PMM_RUNTIME_DOCTOR_V1", RuntimeVersion: runtimeVersion, BuildID: readTrim(filepath.Join(root, "Resources", "Metadata", "BUILD_ID.txt")), Root: root, Security: runtimeSecurity(root), Dependencies: deps, Knowledge: validateKnowledge(root), Game: detectPalworld(root), RequiredFiles: files}
}

func findPowerShell() string {
	if p := findExecutable("pwsh.exe"); p != "" {
		return p
	}
	if w := os.Getenv("WINDIR"); w != "" {
		p := filepath.Join(w, "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
		if existsFile(p) {
			return p
		}
	}
	return findExecutable("powershell.exe")
}

func printJSON(v any) { b, _ := json.MarshalIndent(v, "", "  "); os.Stdout.Write(append(b, '\n')) }

var _ = time.Second
