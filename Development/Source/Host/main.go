package main

import (
	"archive/zip"
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

const hostVersion = "1.2.1"

var (
	user32          = syscall.NewLazyDLL("user32.dll")
	procMessageBoxW = user32.NewProc("MessageBoxW")
)

type Host struct {
	Root       string
	SessionID  string
	SessionDir string
	HostLog    string
	OutLog     string
	ErrLog     string
	StateFile  string
}

type SecurityStatus struct {
	Protocol            string `json:"protocol"`
	HostVersion         string `json:"host_version"`
	Executable          string `json:"executable"`
	Root                string `json:"root"`
	OS                  string `json:"os"`
	Architecture        string `json:"architecture"`
	PowerShell          string `json:"powershell"`
	PowerShellAvailable bool   `json:"powershell_available"`
	LanguageMode        string `json:"language_mode"`
	ProbeError          string `json:"probe_error,omitempty"`
	CoreUnaffected      bool   `json:"core_unaffected_by_clm"`
	Note                string `json:"note"`
}

type Doctor struct {
	Protocol       string            `json:"protocol"`
	HostVersion    string            `json:"host_version"`
	BuildID        string            `json:"build_id"`
	Root           string            `json:"root"`
	Security       SecurityStatus    `json:"security"`
	RequiredFiles  map[string]bool   `json:"required_files"`
	RequiredHashes map[string]string `json:"required_hashes,omitempty"`
}

type RouteManifest struct {
	Schema string           `json:"schema"`
	Routes map[string]Route `json:"routes"`
}

type Route struct {
	Kind       string   `json:"kind"`
	Executable string   `json:"executable"`
	Arguments  []string `json:"arguments"`
}

type ChildPlan struct {
	Kind string
	Name string
	Cmd  *exec.Cmd
}

func main() {
	root, err := executableRoot()
	if err != nil {
		fatalConsole("Cannot resolve PMM root", err)
	}

	args := os.Args[1:]
	if len(args) == 0 {
		args = []string{"start"}
	}

	if args[0] == "doctor" {
		jsonMode := hasArg(args[1:], "--json")
		d := doctor(root)
		printObject(d, jsonMode)
		if !d.RequiredFiles["Engine/PMMRuntime.exe"] || !d.RequiredFiles["Engine/Runner/routes.json"] {
			os.Exit(12)
		}
		return
	}
	if args[0] == "security" && len(args) > 1 && args[1] == "status" {
		s := securityStatus(root)
		printObject(s, hasArg(args[2:], "--json"))
		return
	}
	if args[0] == "handoff" && len(args) > 1 && args[1] == "create" {
		reason := "manual"
		for i := 2; i < len(args)-1; i++ {
			if args[i] == "--reason" {
				reason = args[i+1]
			}
		}
		h, err := newHost(root)
		if err != nil {
			fatalConsole("Could not create host session", err)
		}
		p, err := h.createHandoff(reason, 0, "Manual handoff requested.")
		if err != nil {
			fatalConsole("Could not create handoff", err)
		}
		fmt.Println(p)
		return
	}

	operation := args[0]
	forwarded := args[1:]
	h, err := newHost(root)
	if err != nil {
		fatalConsole("Could not initialize PMM Host", err)
	}
	exitCode := h.run(operation, forwarded)
	os.Exit(exitCode)
}

func executableRoot() (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", err
	}
	exe, err = filepath.Abs(exe)
	if err != nil {
		return "", err
	}
	return filepath.Dir(exe), nil
}

func newHost(root string) (*Host, error) {
	sid := time.Now().Format("20060102-150405") + "-" + fmt.Sprintf("%08x", time.Now().UnixNano()&0xffffffff)
	sdir := filepath.Join(root, "Workspace", "State", "HostSessions", sid)
	if err := os.MkdirAll(sdir, 0755); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(filepath.Join(root, "Workspace", "Logs"), 0755); err != nil {
		return nil, err
	}
	return &Host{Root: root, SessionID: sid, SessionDir: sdir, HostLog: filepath.Join(root, "Workspace", "Logs", "PMMHost.log"), OutLog: filepath.Join(sdir, "runner.stdout.log"), ErrLog: filepath.Join(sdir, "runner.stderr.log"), StateFile: filepath.Join(sdir, "state.txt")}, nil
}

func (h *Host) run(operation string, args []string) int {
	h.log("HOST", "SESSION START id="+h.SessionID+" operation="+operation)
	sec := securityStatus(h.Root)
	secBytes, _ := json.MarshalIndent(sec, "", "  ")
	os.WriteFile(filepath.Join(h.SessionDir, "security.json"), secBytes, 0644)
	if strings.EqualFold(sec.LanguageMode, "ConstrainedLanguage") {
		h.log("SECURITY", "PowerShell ConstrainedLanguage detected. Native routes remain available and do not request FullLanguage.")
	}

	plan, err := h.resolveChild(operation, args, sec)
	if err != nil {
		msg := err.Error()
		h.log("ERROR", msg)
		p, _ := h.createHandoff("DISPATCH_FAILURE", 20, msg)
		notify("Palworld Manager Merger", msg+"\n\nDiagnostic handoff:\n"+p)
		return 20
	}

	cmd := plan.Cmd
	configureChildProcess(cmd)
	cmd.Dir = h.Root
	cmd.Env = append(os.Environ(),
		"PMM_HOST_SESSION_ID="+h.SessionID,
		"PMM_HOST_SESSION_DIR="+h.SessionDir,
		"PMM_HOST_ROOT="+h.Root,
		"PMM_HOST_POWERSHELL="+sec.PowerShell,
	)
	stdout, _ := cmd.StdoutPipe()
	stderr, _ := cmd.StderrPipe()
	if err := cmd.Start(); err != nil {
		msg := "Could not start PMM child process: " + err.Error()
		h.log("ERROR", msg)
		p, _ := h.createHandoff("CHILD_START_FAILURE", 22, msg)
		notify("Palworld Manager Merger", msg+"\n\n"+p)
		return 22
	}
	h.log("HOST", fmt.Sprintf("CHILD START kind=%s name=%s pid=%d", plan.Kind, plan.Name, cmd.Process.Pid))
	done := make(chan struct{}, 2)
	go h.pipe(stdout, h.OutLog, os.Stdout, done)
	go h.pipe(stderr, h.ErrLog, os.Stderr, done)
	err = cmd.Wait()
	<-done
	<-done
	code := 0
	if err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			code = ee.ExitCode()
		} else {
			code = 23
		}
	}
	h.log("HOST", fmt.Sprintf("CHILD END kind=%s exit=%d", plan.Kind, code))
	h.writeSummary(operation, args, code)
	if code != 0 {
		state := readSmall(h.StateFile, 64*1024)
		reason := classifyFailure(state + "\n" + readTail(h.ErrLog, 256*1024) + "\n" + readTail(h.OutLog, 256*1024))
		p, e := h.createHandoff(reason, code, "PMM operation failed. Last state: "+strings.TrimSpace(state))
		if e != nil {
			h.log("ERROR", "Handoff creation failed: "+e.Error())
		}
		message := "PMM detected a failure while running '" + operation + "'.\n\nLast state:\n" + strings.TrimSpace(state)
		if p != "" {
			message += "\n\nAI handoff created:\n" + p
		}
		notify("Palworld Manager Merger - supervised failure", message)
	}
	h.log("HOST", fmt.Sprintf("SESSION END status=%s exit=%d", map[bool]string{true: "success", false: "failed"}[code == 0], code))
	return code
}

func (h *Host) resolveChild(operation string, args []string, sec SecurityStatus) (ChildPlan, error) {
	routesPath := filepath.Join(h.Root, "Engine", "Runner", "routes.json")
	if b, err := os.ReadFile(routesPath); err == nil {
		var manifest RouteManifest
		if json.Unmarshal(b, &manifest) == nil && manifest.Schema == "PMM_HOST_ROUTES_V1" {
			if route, ok := manifest.Routes[operation]; ok {
				kind := strings.ToLower(strings.TrimSpace(route.Kind))
				if kind == "native" {
					exe := route.Executable
					if !filepath.IsAbs(exe) {
						exe = filepath.Join(h.Root, filepath.FromSlash(exe))
					}
					if _, err := os.Stat(exe); err != nil {
						return ChildPlan{}, fmt.Errorf("native route executable is missing: %s", exe)
					}
					argv := append([]string{}, route.Arguments...)
					argv = append(argv, args...)
					return ChildPlan{Kind: "native", Name: filepath.Base(exe), Cmd: exec.Command(exe, argv...)}, nil
				}
			}
		}
	}

	if sec.PowerShell == "" {
		return ChildPlan{}, errors.New("No PowerShell executable was found for this script-routed operation.")
	}
	runner := filepath.Join(h.Root, "Engine", "Runner", "PMM-Runner.ps1")
	if _, err := os.Stat(runner); err != nil {
		return ChildPlan{}, fmt.Errorf("PMM Runner is missing: %s", runner)
	}
	argv := []string{"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", runner, operation}
	argv = append(argv, args...)
	return ChildPlan{Kind: "powershell", Name: "PMM-Runner.ps1", Cmd: exec.Command(sec.PowerShell, argv...)}, nil
}

func configureChildProcess(cmd *exec.Cmd) {
	if cmd == nil {
		return
	}
	// PMM.exe is a Windows GUI-subsystem application. Any console-subsystem
	// child (PMMRuntime.exe, PowerShell, helpers) must therefore be started
	// without allocating a transient console window. GUI children such as the
	// WPF workspace remain visible normally.
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000} // CREATE_NO_WINDOW
}

func (h *Host) pipe(r io.Reader, path string, screen io.Writer, done chan<- struct{}) {
	defer func() { done <- struct{}{} }()
	f, _ := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if f != nil {
		defer f.Close()
	}
	s := bufio.NewScanner(r)
	buf := make([]byte, 64*1024)
	s.Buffer(buf, 4*1024*1024)
	for s.Scan() {
		line := s.Text()
		if f != nil {
			fmt.Fprintln(f, line)
		}
		fmt.Fprintln(screen, line)
	}
}

func (h *Host) log(area, msg string) {
	line := time.Now().Format("2006-01-02 15:04:05.000") + " [" + area + "] " + msg
	fmt.Println(line)
	f, err := os.OpenFile(h.HostLog, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err == nil {
		fmt.Fprintln(f, line)
		f.Close()
	}
}

func (h *Host) writeSummary(op string, args []string, code int) {
	status := "success"
	if code != 0 {
		status = "failed"
	}
	v := map[string]any{"protocol": "PMM_HOST_SESSION_V1", "session_id": h.SessionID, "operation": op, "arguments": args, "exit_code": code, "status": status, "ended_utc": time.Now().UTC().Format(time.RFC3339Nano)}
	b, _ := json.MarshalIndent(v, "", "  ")
	os.WriteFile(filepath.Join(h.SessionDir, "session.json"), b, 0644)
}

func classifyFailure(text string) string {
	l := strings.ToLower(text)
	switch {
	case strings.Contains(l, "cannotcreatetypeconstrainedlanguage") || strings.Contains(l, "constrainedlanguage"):
		return "POWERSHELL_CONSTRAINED_LANGUAGE"
	case strings.Contains(l, "setup") || strings.Contains(l, "dependencies"):
		return "STARTUP_DEPENDENCY_FAILURE"
	case strings.Contains(l, "xaml") || strings.Contains(l, "presentationframework"):
		return "UI_STARTUP_FAILURE"
	default:
		return "PMM_RUNTIME_FAILURE"
	}
}

func (h *Host) createHandoff(reason string, code int, message string) (string, error) {
	outDir := filepath.Join(h.Root, "Workspace", "Handoffs")
	if err := os.MkdirAll(outDir, 0755); err != nil {
		return "", err
	}
	name := "AI_HANDOFF_" + reason + "_" + h.SessionID + ".zip"
	out := filepath.Join(outDir, name)
	f, err := os.Create(out)
	if err != nil {
		return "", err
	}
	defer f.Close()
	zw := zip.NewWriter(f)
	defer zw.Close()
	incident := map[string]any{"protocol": "PMM_AI_HANDOFF_EMERGENCY_V1", "reason": reason, "exit_code": code, "message": message, "session_id": h.SessionID, "build_id": strings.TrimSpace(readSmall(filepath.Join(h.Root, "Resources", "Metadata", "BUILD_ID.txt"), 4096)), "host_version": hostVersion, "created_utc": time.Now().UTC().Format(time.RFC3339Nano)}
	ib, _ := json.MarshalIndent(incident, "", "  ")
	addZipBytes(zw, "incident.json", ib)
	addZipBytes(zw, "AI_READ_FIRST.md", []byte("# PMM emergency AI handoff\n\nPMM.exe created this package after observing a startup/runtime failure. Start with incident.json, security.json and the session logs. Do not assume the failure is a mod conflict unless the evidence says so.\n"))
	candidates := []struct {
		src, name string
		tail      int
	}{
		{filepath.Join(h.SessionDir, "security.json"), "session/security.json", 0},
		{filepath.Join(h.SessionDir, "session.json"), "session/session.json", 0},
		{h.StateFile, "session/state.txt", 0},
		{h.OutLog, "session/runner.stdout.log", 512 * 1024},
		{h.ErrLog, "session/runner.stderr.log", 512 * 1024},
		{h.HostLog, "logs/PMMHost.log", 512 * 1024},
		{filepath.Join(h.Root, "Workspace", "Logs", "PalModMerger.log"), "logs/PalModMerger.log", 1024 * 1024},
		{filepath.Join(h.Root, "Resources", "Metadata", "BUILD_ID.txt"), "pmminfo/BUILD_ID.txt", 0},
		{filepath.Join(h.Root, "Resources", "Metadata", "VERSION.txt"), "pmminfo/VERSION.txt", 0},
		{filepath.Join(h.Root, "Resources", "Metadata", "RELEASE_MANIFEST.json"), "pmminfo/RELEASE_MANIFEST.json", 0},
	}
	for _, c := range candidates {
		if b, ok := readFileBounded(c.src, c.tail); ok {
			addZipBytes(zw, c.name, b)
		}
	}
	return out, nil
}

func readFileBounded(path string, tail int) ([]byte, bool) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, false
	}
	if tail > 0 && len(b) > tail {
		b = b[len(b)-tail:]
	}
	return b, true
}
func addZipBytes(zw *zip.Writer, name string, b []byte) {
	w, e := zw.Create(filepath.ToSlash(name))
	if e == nil {
		w.Write(b)
	}
}
func readSmall(path string, max int) string {
	b, e := os.ReadFile(path)
	if e != nil {
		return ""
	}
	if len(b) > max {
		b = b[:max]
	}
	return string(b)
}
func readTail(path string, max int) string {
	b, e := os.ReadFile(path)
	if e != nil {
		return ""
	}
	if len(b) > max {
		b = b[len(b)-max:]
	}
	return string(b)
}

func doctor(root string) Doctor {
	req := []string{"Engine/PMMRuntime.exe", "Engine/Runner/routes.json", "Engine/Runner/PMM-Runner.ps1", "Modules/Bootstrap/Setup-Dependencies.ps1", "Modules/Bootstrap/Start-PalModMerger.ps1", "CKL/Stable/package-rules.json", "CKL/Catalog/case-index.json", "Engine/repak.exe", "Engine/PMMCore/pmmcore.dll"}
	files := map[string]bool{}
	hashes := map[string]string{}
	for _, r := range req {
		p := filepath.Join(root, filepath.FromSlash(r))
		_, e := os.Stat(p)
		files[r] = e == nil
		if e == nil {
			hashes[r] = fileSHA(p)
		}
	}
	return Doctor{Protocol: "PMM_DOCTOR_V1", HostVersion: hostVersion, BuildID: strings.TrimSpace(readSmall(filepath.Join(root, "Resources", "Metadata", "BUILD_ID.txt"), 4096)), Root: root, Security: securityStatus(root), RequiredFiles: files, RequiredHashes: hashes}
}
func securityStatus(root string) SecurityStatus {
	exe, _ := os.Executable()
	shell := findPowerShell()
	mode := "Unavailable"
	perr := ""
	if shell != "" {
		cmd := exec.Command(shell, "-NoProfile", "-NonInteractive", "-Command", "$ExecutionContext.SessionState.LanguageMode")
		configureChildProcess(cmd)
		cmd.Dir = root
		out, e := cmd.CombinedOutput()
		if e != nil {
			perr = strings.TrimSpace(string(out))
			if perr == "" {
				perr = e.Error()
			}
		} else {
			mode = strings.TrimSpace(string(out))
		}
	}
	note := "PMM.exe does not change or bypass Windows application-control policy. v1.2.1 dispatches the normal start route directly to PMMRuntime.exe without starting PowerShell. Script routes remain external and optional."
	return SecurityStatus{Protocol: "PMM_SECURITY_STATUS_V1", HostVersion: hostVersion, Executable: exe, Root: root, OS: runtime.GOOS, Architecture: runtime.GOARCH, PowerShell: shell, PowerShellAvailable: shell != "", LanguageMode: mode, ProbeError: perr, CoreUnaffected: false, Note: note}
}
func findPowerShell() string {
	if p, e := exec.LookPath("pwsh.exe"); e == nil {
		return p
	}
	sys := os.Getenv("WINDIR")
	if sys != "" {
		p := filepath.Join(sys, "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
		if _, e := os.Stat(p); e == nil {
			return p
		}
	}
	if p, e := exec.LookPath("powershell.exe"); e == nil {
		return p
	}
	return ""
}
func fileSHA(path string) string {
	f, e := os.Open(path)
	if e != nil {
		return ""
	}
	defer f.Close()
	h := sha256.New()
	io.Copy(h, f)
	return hex.EncodeToString(h.Sum(nil))
}
func hasArg(args []string, want string) bool {
	for _, a := range args {
		if a == want {
			return true
		}
	}
	return false
}
func printObject(v any, jsonMode bool) {
	if jsonMode {
		b, _ := json.MarshalIndent(v, "", "  ")
		fmt.Println(string(b))
		return
	}
	b, _ := json.MarshalIndent(v, "", "  ")
	fmt.Println(string(b))
}
func fatalConsole(msg string, err error) {
	fmt.Fprintln(os.Stderr, msg+": "+err.Error())
	notify("Palworld Manager Merger", msg+"\n\n"+err.Error())
	os.Exit(250)
}
func notify(title, text string) {
	tp, _ := syscall.UTF16PtrFromString(title)
	xp, _ := syscall.UTF16PtrFromString(text)
	procMessageBoxW.Call(0, uintptr(unsafe.Pointer(xp)), uintptr(unsafe.Pointer(tp)), 0x00000000|0x00000010)
}

// Keep bytes imported for deterministic future host extensions without adding dependencies.
var _ = bytes.MinRead
var _ = sort.Strings
