package supervision

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

// Only this deliberately selected TEST function acts as a child. Never PMM/PS.
func TestFixtureProcess(t *testing.T) {
	mode := os.Getenv("PMM_SUPERVISION_FIXTURE")
	if mode == "" {
		return
	}
	switch mode {
	case "long":
		fmt.Fprint(os.Stdout, strings.Repeat("x", 5<<20))
		fmt.Fprint(os.Stderr, "stderr-no-newline")
	case "sleep":
		time.Sleep(2 * time.Second)
	case "exit7":
		fmt.Fprint(os.Stdout, "partial result")
		os.Exit(7)
	case "hold0", "hold7":
		c := fixture("descendant")
		c.Stdout = os.Stdout
		c.Stderr = os.Stderr
		if e := c.Start(); e != nil {
			os.Exit(99)
		}
		fmt.Fprintln(os.Stdout, c.Process.Pid)
		if mode == "hold7" {
			os.Exit(7)
		}
	case "descendant":
		time.Sleep(600 * time.Millisecond)
	case "raw":
		fmt.Fprint(os.Stdout, "one\r\ntwo\nlast\x00")
		fmt.Fprint(os.Stderr, "err")
	case "probe":
		fmt.Fprintln(os.Stdout, "PMM_PS_PROBE_V1|5.1|Desktop|FullLanguage")
	case "bad-probe":
		fmt.Fprintln(os.Stdout, "PMM_PS_PROBE_V1|7.4|Core|FullLanguage")
	case "binary":
		os.Stdout.Write([]byte{0xff, 0xfe})
	default:
		os.Exit(98)
	}
	os.Exit(0)
}
func fixture(mode string) *exec.Cmd {
	c := exec.Command(os.Args[0], "-test.run=^TestFixtureProcess$")
	// Replace rather than append the mode: the descendant must not spawn itself.
	for _, v := range os.Environ() {
		if !strings.HasPrefix(v, "PMM_SUPERVISION_FIXTURE=") && !strings.HasPrefix(v, "GORACE=") {
			c.Env = append(c.Env, v)
		}
	}
	c.Env = append(c.Env, "PMM_SUPERVISION_FIXTURE="+mode, "GORACE=atexit_sleep_ms=0")
	return c
}
func opts() Options {
	return Options{Stdout: Output{Limit: 8 << 20}, Stderr: Output{Limit: 8 << 20}, DrainTimeout: 150 * time.Millisecond}
}
func TestLongLineAndNoFinalNewline(t *testing.T) {
	r := Run(context.Background(), fixture("long"), opts())
	if r.ExitCode != 0 || !r.OutputComplete || r.Stdout.Text != strings.Repeat("x", 5<<20) || r.Stderr.Text != "stderr-no-newline" {
		t.Fatalf("exit=%d complete=%v out=%d err=%s", r.ExitCode, r.OutputComplete, len(r.Stdout.Text), r.Error)
	}
}
func TestExactDiskOutputAndExclusiveCreation(t *testing.T) {
	dir := t.TempDir()
	o := opts()
	o.Stdout.Path = filepath.Join(dir, "out")
	o.Stderr.Path = filepath.Join(dir, "err")
	r := Run(context.Background(), fixture("raw"), o)
	b, e := os.ReadFile(o.Stdout.Path)
	if e != nil || string(b) != "one\r\ntwo\nlast\x00" || !r.OutputComplete || r.Stdout.Text != "" {
		t.Fatalf("%+v %q %v", r, b, e)
	}
	r = Run(context.Background(), fixture("raw"), o)
	if r.Started || r.ExitCode != 127 || !strings.Contains(r.Error, "storage") {
		t.Fatal(r)
	}
}
func TestOutputLimitFailsExplicitly(t *testing.T) {
	o := opts()
	o.Stdout.Limit = 64
	r := Run(context.Background(), fixture("long"), o)
	if r.ExitCode != 125 || r.OutputComplete || len(r.Stdout.Text) != 64 || !strings.Contains(r.Error, "limit") {
		t.Fatal(r)
	}
}
func TestDeadlineKillsOnlyDirectChild(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Millisecond)
	defer cancel()
	start := time.Now()
	r := Run(ctx, fixture("sleep"), opts())
	if r.ExitCode != 124 || !r.TimedOut || !r.ChildReaped || time.Since(start) > time.Second {
		t.Fatal(r, time.Since(start))
	}
}
func TestCancellation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	o := opts()
	o.Started = func(int) { cancel() }
	r := Run(ctx, fixture("sleep"), o)
	if !r.Cancelled || r.TimedOut || r.ExitCode != 130 || !r.ChildReaped {
		t.Fatal(r)
	}
}
func TestCancelledBeforeStart(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	r := Run(ctx, fixture("sleep"), opts())
	if r.Started || r.ExitCode != 130 {
		t.Fatal(r)
	}
}
func TestInheritedPipesDeadlineIndependentOfChildExit(t *testing.T) {
	for _, mode := range []string{"hold0", "hold7"} {
		t.Run(mode, func(t *testing.T) {
			o := opts()
			o.DrainTimeout = 35 * time.Millisecond
			start := time.Now()
			exitObserved := false
			o.Exited = func() { exitObserved = true }
			r := Run(context.Background(), fixture(mode), o)
			// Cleanup only the intentionally created, finite-lived fixture descendant.
			if pid, e := strconv.Atoi(strings.TrimSpace(r.Stdout.Text)); e == nil {
				if p, e := os.FindProcess(pid); e == nil {
					p.Kill()
				}
			}
			want := 0
			if mode == "hold7" {
				want = 7
			}
			if !r.DrainTimedOut || r.ExitCode != 125 || r.ChildExitCode != want || !exitObserved || time.Since(start) > time.Second {
				t.Fatal(r, time.Since(start))
			}
		})
	}
}

type brokenWriter struct{ short bool }

func (w brokenWriter) Write(p []byte) (int, error) {
	if w.short {
		return len(p) / 2, nil
	}
	return 0, errors.New("fixture disk full")
}
func TestFailedStorageAndShortWrite(t *testing.T) {
	for _, short := range []bool{false, true} {
		t.Run(fmt.Sprint(short), func(t *testing.T) {
			open := func(o Output) (*destination, error) {
				return &destination{spec: o, writer: brokenWriter{short}, close: func() error { return nil }}, nil
			}
			r := run(context.Background(), fixture("long"), opts(), open)
			if r.ExitCode != 125 || r.OutputComplete || r.Error == "" {
				t.Fatal(r)
			}
		})
	}
}
func TestStorageCloseError(t *testing.T) {
	open := func(o Output) (*destination, error) {
		return &destination{spec: o, writer: io.Discard, close: func() error { return errors.New("fixture close failure") }}, nil
	}
	r := run(context.Background(), fixture("raw"), opts(), open)
	if r.ExitCode != 125 || r.OutputComplete || !strings.Contains(r.Error, "close failure") {
		t.Fatal(r)
	}
}
func TestNonzeroExitKeepsOutput(t *testing.T) {
	r := Run(context.Background(), fixture("exit7"), opts())
	if r.ExitCode != 7 || !r.OutputComplete || r.Stdout.Text != "partial result" {
		t.Fatal(r)
	}
}
func TestStartFailure(t *testing.T) {
	r := Run(context.Background(), exec.Command(filepath.Join(t.TempDir(), "missing")), opts())
	if r.Started || r.ExitCode != 127 || r.Error == "" {
		t.Fatal(r)
	}
}
func TestNonUTF8NotSilent(t *testing.T) {
	r := Run(context.Background(), fixture("binary"), opts())
	if r.ExitCode != 125 || r.OutputComplete || !strings.Contains(r.Error, "UTF8") {
		t.Fatal(r)
	}
}
func TestInvalidOptions(t *testing.T) {
	o := opts()
	o.Stdout.Limit = 0
	r := Run(context.Background(), fixture("raw"), o)
	if r.Started {
		t.Fatal(r)
	}
}
