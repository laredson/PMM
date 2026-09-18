package main

import (
	"context"
	"os"
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestProcessArgumentsRejectInvalidTimeouts(t *testing.T) {
	for _, s := range []string{"0", "-1", "+1", "0.5", "nan", "", "86401", "9223372036854775807", "18446744073709551616"} {
		if _, e := parseProcessRequest([]string{"--timeout-sec", s, "--", "tool"}); e == nil {
			t.Fatal(s)
		}
	}
	for _, args := range [][]string{{"--timeout-sec"}, {"--unknown", "x", "--", "tool"}, {"--"}, {"--", ""}, {"tool"}, {"--cwd"}, {"--cwd", "a", "--cwd", "b", "--", "tool"}, {"--timeout-sec", "1", "--timeout-sec", "2", "--", "tool"}} {
		if _, e := parseProcessRequest(args); e == nil {
			t.Fatal(args)
		}
	}
}
func TestProcessArgumentsKeepArgvAndBoundary(t *testing.T) {
	args := []string{"--cwd", "space & dir", "--timeout-sec", "86400", "--", "tool path", "--timeout-sec", "other & data"}
	r, e := parseProcessRequest(args)
	if e != nil || r.Timeout != 24*time.Hour || r.WorkingDirectory != "space & dir" || r.Executable != "tool path" || !reflect.DeepEqual(r.Arguments, args[6:]) {
		t.Fatal(r, e)
	}
	r, e = parseProcessRequest([]string{"--", "tool"})
	if e != nil || r.Timeout != 5*time.Minute {
		t.Fatal(r, e)
	}
}
func TestRuntimeProcessFixture(t *testing.T) {
	mode := os.Getenv("PMM_RUNTIME_FIXTURE")
	if mode == "" {
		return
	}
	if mode == "output" {
		os.Stdout.Write([]byte(strings.Repeat("x", 1024)))
	} else {
		time.Sleep(time.Second)
	}
	os.Exit(0)
}
func TestRuntimeIncompleteOutputReturnsError(t *testing.T) {
	t.Setenv("PMM_RUNTIME_FIXTURE", "output")
	r := runProcess(ProcessRequest{Executable: os.Args[0], Arguments: []string{"-test.run=^TestRuntimeProcessFixture$"}, OutputLimit: 64})
	if r.ExitCode != 125 || r.OutputComplete || r.RunError == "" || len(r.Stdout) != 64 {
		t.Fatal(r)
	}
}
func TestRuntimeCancellationIsNotStartFailure(t *testing.T) {
	t.Setenv("PMM_RUNTIME_FIXTURE", "sleep")
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	r := runProcess(ProcessRequest{Executable: os.Args[0], Arguments: []string{"-test.run=^TestRuntimeProcessFixture$"}, Context: ctx})
	if !r.TimedOut || r.StartError != "" || r.ExitCode != 124 {
		t.Fatal(r)
	}
}
func TestRuntimeNoNativeToolSelectionOnLinux(t *testing.T) {
	// No invocation of PowerShell; exercised only in the Linux fixture suite.
	if os.PathSeparator == '\\' {
		t.Skip("Windows acceptance separate")
	}
	s := runtimeSecurity(t.TempDir())
	if s.PowerShell != "" || s.PowerShellProbeStatus != "UNAVAILABLE" {
		t.Fatal(s)
	}
}
