package main

import (
	"crypto/sha256"
	"crypto/sha512"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

func executableRoot() (string, error) {
	if override := strings.TrimSpace(os.Getenv("PMM_ROOT")); override != "" {
		return filepath.Abs(override)
	}
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

func fileSHA256(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return ""
	}
	return hex.EncodeToString(h.Sum(nil))
}

func fileSHA512(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	h := sha512.New()
	if _, err := io.Copy(h, f); err != nil {
		return ""
	}
	return hex.EncodeToString(h.Sum(nil))
}

func existsFile(path string) bool { st, err := os.Stat(path); return err == nil && !st.IsDir() }
func existsDir(path string) bool  { st, err := os.Stat(path); return err == nil && st.IsDir() }

func readTrim(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func writeJSON(path string, v any) error {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}
	return os.WriteFile(path, append(b, '\n'), 0644)
}

func logLine(root, area, msg string) {
	line := time.Now().Format("2006-01-02 15:04:05.000") + " [Runtime:" + area + "] " + msg
	fmt.Println(line)
	logDir := filepath.Join(root, "Logs")
	_ = os.MkdirAll(logDir, 0755)
	f, err := os.OpenFile(filepath.Join(logDir, "PalModMerger.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err == nil {
		fmt.Fprintln(f, line)
		_ = f.Close()
	}
}

func commandOutput(timeout time.Duration, cwd, exe string, args ...string) (int, string, error) {
	result := runProcess(ProcessRequest{Executable: exe, Arguments: args, WorkingDirectory: cwd, Timeout: timeout})
	combined := strings.TrimSpace(result.Stdout)
	if strings.TrimSpace(result.Stderr) != "" {
		if combined != "" {
			combined += "\n"
		}
		combined += strings.TrimSpace(result.Stderr)
	}
	if result.StartError != "" {
		return result.ExitCode, combined, errors.New(result.StartError)
	}
	return result.ExitCode, combined, nil
}

func findExecutable(name string) string {
	if p, err := exec.LookPath(name); err == nil {
		return p
	}
	return ""
}

func cleanRelPath(rel string) (string, error) {
	rel = filepath.Clean(filepath.FromSlash(rel))
	if rel == "." || rel == "" || filepath.IsAbs(rel) || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return "", fmt.Errorf("unsafe relative path: %q", rel)
	}
	return rel, nil
}

func samePath(a, b string) bool {
	aa, _ := filepath.Abs(a)
	bb, _ := filepath.Abs(b)
	return strings.EqualFold(filepath.Clean(aa), filepath.Clean(bb))
}
