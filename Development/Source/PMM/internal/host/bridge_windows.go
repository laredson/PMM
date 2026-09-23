//go:build windows

package host

import (
	"context"
	"fmt"
	"os"
	"sync"

	"pmm.local/pmm/internal/uibridge"
)

// Captured from the actual supervised Start; never populated from state.txt.
type hostUIBridge struct {
	mu         sync.Mutex
	server     *uibridge.Server
	runtime    *uibridge.WinProcess
	gate       *uibridge.Gate
	splash     *startupSplash
	ctx        context.Context
	cancel     context.CancelFunc
	stopped    bool
	diagnostic string
}

func newHostUIBridge(session string, splash *startupSplash) (*hostUIBridge, error) {
	server, e := uibridge.NewServer(session)
	if e != nil {
		return nil, e
	}
	ctx, cancel := context.WithCancel(context.Background())
	return &hostUIBridge{server: server, splash: splash, ctx: ctx, cancel: cancel}, nil
}
func (b *hostUIBridge) capture(pid int) {
	// Called synchronously by Supervision BEFORE Cmd.Wait. No logging or I/O wait.
	ref, e := uibridge.CaptureProcess(uint32(pid))
	b.mu.Lock()
	defer b.mu.Unlock()
	if e != nil {
		b.diagnostic = "Runtime identity capture failed: " + e.Error()
		return
	}
	if b.stopped {
		_ = ref.Close()
		return
	}
	b.runtime = ref
}
func (b *hostUIBridge) start() { go b.serve() }
func (b *hostUIBridge) serve() {
	defer b.close()
	b.mu.Lock()
	ref := b.runtime
	stopped := b.stopped
	b.mu.Unlock()
	if stopped || ref == nil {
		return
	}
	conn, e := b.server.Accept(b.ctx, ref)
	if e != nil {
		b.record(e)
		return
	}
	gate, e := uibridge.NewAuthenticatedGate(conn)
	if e != nil {
		conn.Close()
		b.record(e)
		return
	}
	b.mu.Lock()
	if b.stopped {
		b.mu.Unlock()
		gate.Close()
		conn.Close()
		return
	}
	b.gate = gate
	b.mu.Unlock()
	e = uibridge.ServeGate(b.ctx, conn, gate, func(kind string, generation uint64) {
		if b.splash == nil {
			return
		}
		if kind == "READY" {
			b.splash.queueVerifiedHandoff(gate, generation)
		} else {
			b.splash.requestClose()
		}
	})
	if e != nil {
		b.record(e)
	}
}
func (b *hostUIBridge) record(e error) {
	if e == nil {
		return
	}
	b.mu.Lock()
	if b.diagnostic == "" {
		b.diagnostic = e.Error()
	}
	b.mu.Unlock()
}
func (b *hostUIBridge) close() {
	if b == nil {
		return
	}
	// Stop is published BEFORE taking locks or releasing OS resources.
	if b.splash != nil {
		b.splash.requestClose()
	}
	b.cancel()
	b.server.Close()
	b.mu.Lock()
	b.stopped = true
	gate := b.gate
	ref := b.runtime
	b.mu.Unlock()
	if gate != nil {
		gate.Close()
	}
	if ref != nil {
		_ = ref.Close()
	}
}
func (b *hostUIBridge) report() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.diagnostic
}

func bridgeLaunchEnvironment(h *Host, shell string, b *hostUIBridge) []string {
	env := uibridge.MergeEnvironment(os.Environ(), map[string]string{
		"PMM_HOST_SESSION_ID": h.SessionID, "PMM_HOST_SESSION_DIR": h.SessionDir,
		"PMM_HOST_ROOT": h.Root, "PMM_HOST_POWERSHELL": shell,
	})
	if b == nil {
		return env
	}
	out, e := b.server.Descriptor().Environment(env)
	if e != nil {
		b.record(fmt.Errorf("bridge environment: %w", e))
		b.close()
		return env
	}
	return out
}
