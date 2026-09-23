//go:build windows

package uibridge

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"testing"
	"time"
)

func windowsOptIn(t *testing.T) {
	t.Helper()
	if os.Getenv("PMM_UIBRIDGE_WINDOWS_TESTS") != "1" {
		t.Skip("Windows adapter execution requires explicit opt-in; compilation is not execution")
	}
}
func TestWindowsDescriptorAndIdentity(t *testing.T) {
	windowsOptIn(t)
	p, e := CaptureProcess(uint32(os.Getpid()))
	if e != nil {
		t.Fatal(e)
	}
	defer p.Close()
	bad := p.Identity()
	bad.Created++
	if q, e := OpenExpected(bad); e == nil {
		q.Close()
		t.Fatal("reused identity accepted")
	}
	if (Descriptor{Name: `\\remote\pipe\x`, Session: "test", Host: p.id}).valid() {
		t.Fatal("remote path")
	}
}

// This helper runs ONLY as a child of the opt-in fixture, never PMM/PowerShell.
func TestWindowsPipeChild(t *testing.T) {
	if os.Getenv("PMM_UIBRIDGE_CHILD") != "1" {
		t.Skip("fixture child only")
	}
	var d Descriptor
	if e := json.Unmarshal([]byte(os.Getenv("PMM_UIBRIDGE_DESCRIPTOR")), &d); e != nil {
		t.Fatal(e)
	}
	// Descriptor is trusted launch data in this fixture, not untrusted state.txt.
	host, e := OpenExpected(d.Host)
	if e != nil {
		t.Fatal(e)
	}
	defer host.Close()
	c, e := Dial(context.Background(), d, host)
	if e != nil {
		t.Fatal(e)
	}
	defer c.Close()
	m := Control(d.Session, 1, "PING", 0)
	if e = c.Send(context.Background(), m); e != nil {
		t.Fatal(e)
	}
	ack, e := c.Receive(context.Background())
	if e != nil || ack.Kind != "ACK" || ack.Seq != "1" {
		t.Fatalf("ACK %v %v", ack, e)
	}
}
func TestWindowsRealPipeControlledChild(t *testing.T) {
	windowsOptIn(t)
	s, e := NewServer("test-session")
	if e != nil {
		t.Fatal(e)
	}
	defer s.Close()
	descriptor, _ := json.Marshal(s.Descriptor())
	exe, e := os.Executable()
	if e != nil {
		t.Fatal(e)
	}
	cmd := exec.Command(exe, "-test.run=^TestWindowsPipeChild$", "-test.v")
	cmd.Env = append(os.Environ(), "PMM_UIBRIDGE_CHILD=1", "PMM_UIBRIDGE_DESCRIPTOR="+string(descriptor))
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if e = cmd.Start(); e != nil {
		t.Fatal(e)
	}
	defer func() {
		if cmd.ProcessState == nil {
			_ = cmd.Process.Kill()
			_ = cmd.Wait()
		}
	}()
	child, e := CaptureProcess(uint32(cmd.Process.Pid))
	if e != nil {
		t.Fatal(e)
	}
	defer child.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	c, e := s.Accept(ctx, child)
	if e != nil {
		t.Fatal(e)
	}
	defer c.Close()
	m, e := c.Receive(ctx)
	if e != nil || m.Kind != "PING" {
		t.Fatalf("%+v %v", m, e)
	}
	if e = c.Send(ctx, Control("test-session", 1, "ACK", 0)); e != nil {
		t.Fatal(e)
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case e := <-done:
		if e != nil {
			t.Fatal(e)
		}
	case <-ctx.Done():
		_ = cmd.Process.Kill()
		<-done
		t.Fatal("fixture child timed out")
	}
}
func TestWindowsAcceptCancellation(t *testing.T) {
	windowsOptIn(t)
	p, e := CaptureProcess(uint32(os.Getpid()))
	if e != nil {
		t.Fatal(e)
	}
	defer p.Close()
	s, e := NewServer("test-session")
	if e != nil {
		t.Fatal(e)
	}
	defer s.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()
	start := time.Now()
	if c, e := s.Accept(ctx, p); e == nil {
		c.Close()
		t.Fatal("accepted without peer")
	}
	if time.Since(start) > 2*time.Second {
		t.Fatal("deadline caller blocked")
	}
}
