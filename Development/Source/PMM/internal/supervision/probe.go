package supervision

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const ProbeTimeout = 5 * time.Second
const ProbeLimit int64 = 4096
const ProbeCommand = "'PMM_PS_PROBE_V1|{0}.{1}|{2}|{3}' -f $PSVersionTable.PSVersion.Major,$PSVersionTable.PSVersion.Minor,$PSVersionTable.PSEdition,$ExecutionContext.SessionState.LanguageMode"

type ProbeResult struct {
	Path         string `json:"path"`
	Version      string `json:"version"`
	LanguageMode string `json:"language_mode"`
	Compatible   bool   `json:"compatible"`
	Status       string `json:"status"`
	Error        string `json:"error,omitempty"`
}

func SystemExecutable(name string) (string, error) {
	dir, e := systemDirectory()
	if e != nil {
		return "", e
	}
	var p string
	switch name {
	case "powershell.exe":
		p = filepath.Join(dir, "WindowsPowerShell", "v1.0", name)
	case "reg.exe":
		p = filepath.Join(dir, name)
	default:
		return "", errors.New("unsupported system tool")
	}
	if !filepath.IsAbs(p) {
		return "", errors.New("system directory is not absolute")
	}
	st, e := os.Stat(p)
	if e != nil {
		return "", e
	}
	if !st.Mode().IsRegular() {
		return "", errors.New("system tool is not a regular file")
	}
	return p, nil
}

func Probe(root string) ProbeResult {
	path, e := SystemExecutable("powershell.exe")
	if e != nil {
		return ProbeResult{Status: "UNAVAILABLE", Error: e.Error()}
	}
	ctx, cancel := context.WithTimeout(context.Background(), ProbeTimeout)
	defer cancel()
	cmd := exec.Command(path, "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", ProbeCommand)
	cmd.Dir = root
	configureProbe(cmd)
	return probeCommand(ctx, cmd)
}
func probeCommand(ctx context.Context, cmd *exec.Cmd) ProbeResult {
	p := ProbeResult{Path: cmd.Path}
	r := Run(ctx, cmd, Options{Stdout: Output{Limit: ProbeLimit}, Stderr: Output{Limit: ProbeLimit}, DrainTimeout: 250 * time.Millisecond})
	switch {
	case r.TimedOut:
		p.Status = "TIMEOUT"
	case r.Cancelled:
		p.Status = "CANCELLED"
	case !r.Started:
		p.Status = "START_FAILED"
	case !r.OutputComplete:
		p.Status = "OUTPUT_INCOMPLETE"
	case r.ExitCode != 0:
		p.Status = "PROCESS_FAILED"
	default:
		p = parseProbe(r.Stdout.Text, r.Stderr.Text)
		p.Path = cmd.Path
		return p
	}
	p.Error = r.Error
	return p
}
func parseProbe(stdout, stderr string) ProbeResult {
	p := ProbeResult{Status: "INVALID_RESPONSE"}
	// No acceptance of a useful prefix, stderr errors, or multiple records.
	line := strings.TrimSuffix(strings.TrimSuffix(stdout, "\n"), "\r")
	fields := strings.Split(line, "|")
	if stderr != "" || len(fields) != 4 || fields[0] != "PMM_PS_PROBE_V1" || strings.ContainsAny(line, "\r\n\x00") {
		p.Error = "expected one complete PS version/edition/mode record without stderr"
		return p
	}
	p.Version = fields[1]
	if fields[1] != "5.1" || fields[2] != "Desktop" {
		p.Status = "UNSUPPORTED_VERSION"
		p.Error = fmt.Sprintf("requires Windows PowerShell 5.1 Desktop; reported %s/%s", fields[1], fields[2])
		return p
	}
	switch fields[3] {
	case "FullLanguage", "ConstrainedLanguage", "RestrictedLanguage", "NoLanguage":
		p.LanguageMode = fields[3]
	default:
		p.Error = "unrecognized LanguageMode"
		return p
	}
	p.Compatible = true
	p.Status = "OK"
	return p
}
