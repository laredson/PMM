// Package supervision supplies bounded child I/O for the isolated PMM candidates.
// It does not manage a process family or authenticate a UI window.
package supervision

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"time"
	"unicode/utf8"
)

const (
	HelperLimit  int64 = 16 << 20  // Per stream. Overflow is an error, never a success.
	HostLogLimit int64 = 256 << 20 // Per stream, per Host session, exclusive files.
	DefaultDrain       = 2 * time.Second
	DefaultReap        = 2 * time.Second
)

var ErrOutputLimit = errors.New("output limit exceeded; output incomplete")

type Output struct {
	Path  string
	Limit int64
}
type Options struct {
	Stdout, Stderr            Output
	DrainTimeout, ReapTimeout time.Duration
	// Hooks must return promptly. Exited is called BEFORE draining inherited pipes.
	// Capture is synchronous BEFORE Wait can release the original process handle.
	// It must only perform prompt identity capture (no logging or IPC waits).
	Capture func(pid int)
	Started func(pid int)
	Exited  func()
}
type Stream struct {
	Text        string `json:"text,omitempty"`
	Path        string `json:"path,omitempty"`
	BytesStored int64  `json:"bytes_stored"`
	Complete    bool   `json:"complete"`
	Error       string `json:"error,omitempty"`
}
type Result struct {
	Started        bool   `json:"started"`
	PID            int    `json:"pid"`
	ExitCode       int    `json:"exit_code"`
	ChildExitCode  int    `json:"child_exit_code"`
	ChildReaped    bool   `json:"child_reaped"`
	TimedOut       bool   `json:"timed_out"`
	Cancelled      bool   `json:"cancelled"`
	DrainTimedOut  bool   `json:"drain_timed_out"`
	OutputComplete bool   `json:"output_complete"`
	Stdout         Stream `json:"stdout"`
	Stderr         Stream `json:"stderr"`
	Error          string `json:"error,omitempty"`
}

type destination struct {
	writer io.Writer
	close  func() error
	buffer *bytes.Buffer
	spec   Output
}
type opener func(Output) (*destination, error)

func openOutput(spec Output) (*destination, error) {
	if spec.Limit <= 0 {
		return nil, errors.New("output requires a positive byte limit")
	}
	d := &destination{spec: spec, close: func() error { return nil }}
	if spec.Path == "" {
		d.buffer = &bytes.Buffer{}
		d.writer = d.buffer
		return d, nil
	}
	// Never append to or overwrite another session's log, including a symlink.
	f, e := os.OpenFile(spec.Path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if e != nil {
		return nil, e
	}
	d.writer = f
	d.close = f.Close
	return d, nil
}

type limitedWriter struct {
	w                 io.Writer
	remaining, stored int64
}

func (w *limitedWriter) Write(p []byte) (int, error) {
	original := len(p)
	if int64(len(p)) > w.remaining {
		p = p[:int(w.remaining)]
	}
	n, e := w.w.Write(p)
	w.stored += int64(n)
	w.remaining -= int64(n)
	if e != nil {
		return n, e
	}
	if n != len(p) {
		return n, io.ErrShortWrite
	}
	if n != original {
		return n, ErrOutputLimit
	}
	return n, nil
}

type streamResult struct {
	index  int
	stream Stream
}

func pump(index int, r *os.File, d *destination, finished chan<- streamResult, failure chan<- struct{}) {
	defer r.Close()
	w := &limitedWriter{w: d.writer, remaining: d.spec.Limit}
	// Hide ReaderFrom/WriterTo optimizations: fixed-size reads, no Scanner token cap.
	_, e := io.CopyBuffer(w, struct{ io.Reader }{r}, make([]byte, 32<<10))
	if e != nil {
		select {
		case failure <- struct{}{}:
		default:
		}
	}
	ce := d.close()
	e = errors.Join(e, ce)
	s := Stream{Path: d.spec.Path, BytesStored: w.stored, Complete: e == nil}
	if d.buffer != nil {
		s.Text = d.buffer.String()
		if !utf8.ValidString(s.Text) {
			e = errors.Join(e, errors.New("non-UTF8 helper output; text representation is not lossless"))
			s.Complete = false
		}
	}
	if e != nil {
		s.Error = e.Error()
		select {
		case failure <- struct{}{}:
		default:
		}
	}
	finished <- streamResult{index, s}
}

// Run owns both pipes and drains them concurrently. exec.Cmd.Wait cannot close
// these readers: Cmd receives our *os.File write ends, not StdoutPipe readers.
// Context/failed storage kills ONLY the direct child. EOF has its own deadline.
// Bounds assume responsive local OS operations; a stuck kernel/file write cannot
// be forcibly interrupted by Go. Incomplete pumps are not reported as success.
func Run(ctx context.Context, cmd *exec.Cmd, opt Options) Result {
	return run(ctx, cmd, opt, openOutput)
}
func run(ctx context.Context, cmd *exec.Cmd, opt Options, open opener) (res Result) {
	res.ExitCode = 127
	res.ChildExitCode = -1
	res.Stdout.Path = opt.Stdout.Path
	res.Stderr.Path = opt.Stderr.Path
	fail := func(e error) Result { res.Error = e.Error(); return res }
	if ctx == nil || cmd == nil {
		return fail(errors.New("nil context or command"))
	}
	if cmd.Process != nil || cmd.Stdout != nil || cmd.Stderr != nil {
		return fail(errors.New("command must be unstarted with unassigned output"))
	}
	if cmd.Stdin != nil {
		if _, ok := cmd.Stdin.(*os.File); !ok {
			return fail(errors.New("only a file or nil stdin is supported"))
		}
	}
	if e := ctx.Err(); e != nil {
		res.Cancelled = e != context.DeadlineExceeded
		res.TimedOut = !res.Cancelled
		res.ExitCode = 130
		if res.TimedOut {
			res.ExitCode = 124
		}
		return fail(e)
	}
	if opt.DrainTimeout <= 0 {
		opt.DrainTimeout = DefaultDrain
	}
	if opt.ReapTimeout <= 0 {
		opt.ReapTimeout = DefaultReap
	}
	out, e := open(opt.Stdout)
	if e != nil {
		return fail(fmt.Errorf("stdout storage: %w", e))
	}
	errout, e := open(opt.Stderr)
	if e != nil {
		out.close()
		return fail(fmt.Errorf("stderr storage: %w", e))
	}
	ro, wo, e := os.Pipe()
	if e != nil {
		out.close()
		errout.close()
		return fail(e)
	}
	re, we, e := os.Pipe()
	if e != nil {
		ro.Close()
		wo.Close()
		out.close()
		errout.close()
		return fail(e)
	}
	cmd.Stdout = wo
	cmd.Stderr = we
	if e = cmd.Start(); e != nil {
		ro.Close()
		wo.Close()
		re.Close()
		we.Close()
		out.close()
		errout.close()
		return fail(e)
	}
	// Parent must release the write ends immediately, or it would prevent EOF.
	wo.Close()
	we.Close()
	res.Started = true
	res.PID = cmd.Process.Pid
	done := make(chan streamResult, 2)
	failed := make(chan struct{}, 2)
	go pump(0, ro, out, done, failed)
	go pump(1, re, errout, done, failed)
	if opt.Capture != nil {
		opt.Capture(res.PID)
	}
	waited := make(chan error, 1)
	go func() { waited <- cmd.Wait() }()
	if opt.Started != nil {
		opt.Started(res.PID)
	}
	contextDone := ctx.Done()
	failureChannel := failed
	var killTimer *time.Timer
	var killDeadline <-chan time.Time
	var waitError error
	var problems []error
	stopChild := func() {
		if killTimer != nil {
			return
		}
		if e := cmd.Process.Kill(); e != nil && !errors.Is(e, os.ErrProcessDone) {
			problems = append(problems, fmt.Errorf("kill direct child: %w", e))
		}
		killTimer = time.NewTimer(opt.ReapTimeout)
		killDeadline = killTimer.C
	}
childLoop:
	for {
		select {
		case waitError = <-waited:
			res.ChildReaped = cmd.ProcessState != nil
			res.ChildExitCode = cmd.ProcessState.ExitCode()
			if res.ChildReaped && opt.Exited != nil {
				opt.Exited()
			}
			break childLoop
		case <-contextDone:
			res.TimedOut = ctx.Err() == context.DeadlineExceeded
			res.Cancelled = !res.TimedOut
			problems = append(problems, ctx.Err())
			contextDone = nil
			stopChild()
		case <-failureChannel:
			problems = append(problems, errors.New("child output/storage failed"))
			failureChannel = nil
			stopChild()
		case <-killDeadline:
			problems = append(problems, errors.New("direct child reap deadline exceeded; lifetime unresolved"))
			break childLoop
		}
	}
	if killTimer != nil {
		killTimer.Stop()
	}
	// Child completion and stream completion are separate, even on a nonzero exit.
	pending := 2
	drain := time.NewTimer(opt.DrainTimeout)
	closed := false
	for pending > 0 {
		select {
		case item := <-done:
			pending--
			if item.index == 0 {
				res.Stdout = item.stream
			} else {
				res.Stderr = item.stream
			}
		case <-drain.C:
			if closed {
				problems = append(problems, errors.New("stream worker still pending after pipe closure"))
				pending = 0 // No waiting forever for an uninterruptible OS write.
			} else {
				res.DrainTimedOut = true
				closed = true
				ro.Close()
				re.Close()
				problems = append(problems, errors.New("output EOF deadline exceeded; output incomplete"))
				drain.Reset(100 * time.Millisecond)
			}
		}
	}
	drain.Stop()
	ro.Close()
	re.Close()
	res.OutputComplete = res.ChildReaped && !res.DrainTimedOut && res.Stdout.Complete && res.Stderr.Complete
	if res.Stdout.Error != "" {
		problems = append(problems, fmt.Errorf("stdout: %s", res.Stdout.Error))
	}
	if res.Stderr.Error != "" {
		problems = append(problems, fmt.Errorf("stderr: %s", res.Stderr.Error))
	}
	if waitError != nil {
		problems = append(problems, waitError)
	}
	res.ExitCode = res.ChildExitCode
	// Never report success when output was lost, even if the child exited with 0.
	if !res.OutputComplete {
		res.ExitCode = 125
	}
	if res.Cancelled {
		res.ExitCode = 130
	}
	if res.TimedOut {
		res.ExitCode = 124
	}
	if len(problems) > 0 {
		res.Error = errors.Join(problems...).Error()
	}
	return res
}
