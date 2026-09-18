package supervision

import (
	"context"
	"testing"
	"time"
)

func TestCapturePrecedesWaitAndStartedHook(t *testing.T) {
	cmd := fixture("raw")
	captured, started, exited := false, false, false
	o := opts()
	o.Capture = func(pid int) {
		if pid <= 0 || cmd.Process == nil || cmd.Process.Pid != pid {
			t.Fatal("wrong controlled process")
		}
		// Deliberately let the finite child finish. No Wait may release its handle yet.
		time.Sleep(100 * time.Millisecond)
		if cmd.ProcessState != nil {
			t.Fatal("Wait ran before capture finished")
		}
		captured = true
	}
	o.Started = func(pid int) {
		if !captured {
			t.Fatal("Started before capture")
		}
		started = true
	}
	o.Exited = func() {
		if !captured || !started {
			t.Fatal("exit order")
		}
		exited = true
	}
	r := Run(context.Background(), cmd, o)
	if !captured || !started || !exited || !r.OutputComplete || r.Stdout.Text != "one\r\ntwo\nlast\x00" {
		t.Fatal(r)
	}
}
func TestFailedStartDoesNotCapture(t *testing.T) {
	cmd := fixture("raw")
	cmd.Path = "/this-fixture-does-not-exist"
	o := opts()
	o.Capture = func(int) { t.Fatal("captured a failed start") }
	if r := Run(context.Background(), cmd, o); r.Started {
		t.Fatal(r)
	}
}
