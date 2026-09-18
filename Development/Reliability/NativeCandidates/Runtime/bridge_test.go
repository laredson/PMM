package main

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"pmm/uibridge"
)

// Model-only transport: the real Windows peer checks are deliberately NOT mocked
// into a claim of Windows acceptance. Library conversation is tested separately.
type bridgeTestTransport struct {
	stop        chan struct{}
	once        sync.Once
	ack         chan uibridge.Message
	sent        chan uibridge.Message
	hold        chan struct{}
	registering chan struct{}
}

func (t *bridgeTestTransport) Closed() <-chan struct{} { return t.stop }
func (t *bridgeTestTransport) Close()                  { t.once.Do(func() { close(t.stop) }) }
func (t *bridgeTestTransport) Send(ctx context.Context, m uibridge.Message) error {
	if e := m.Validate(); e != nil {
		return e
	}
	t.sent <- m
	if m.Kind == "REGISTER" && t.hold != nil {
		close(t.registering)
		select {
		case <-t.hold:
		case <-ctx.Done():
			return ctx.Err()
		case <-t.stop:
			return errors.New("closed")
		}
	}
	seq, _ := uibridge.Decimal(m.Seq, 64, false)
	gen, _ := uibridge.Decimal(m.Generation, 64, true)
	select {
	case t.ack <- uibridge.Control(m.Session, seq, "ACK", gen):
		return nil
	case <-ctx.Done():
		return ctx.Err()
	case <-t.stop:
		return errors.New("closed")
	}
}
func (t *bridgeTestTransport) Receive(ctx context.Context) (uibridge.Message, error) {
	select {
	case m := <-t.ack:
		return m, nil
	case <-ctx.Done():
		return uibridge.Message{}, ctx.Err()
	case <-t.stop:
		return uibridge.Message{}, errors.New("closed")
	}
}

type bridgeTestRef struct {
	live atomic.Bool
	id   uibridge.Identity
}

func (r *bridgeTestRef) Identity() uibridge.Identity { return r.id }
func (r *bridgeTestRef) Alive() bool                 { return r.live.Load() }
func (r *bridgeTestRef) Close() error                { r.live.Store(false); return nil }

type bridgeTestPlatform struct{ calls atomic.Int32 }

func (p *bridgeTestPlatform) AcquireOwner(uibridge.ProcessRef, uibridge.Identity, string) (uibridge.ProcessRef, error) {
	return nil, errors.New("not used by Runtime fixture")
}
func (p *bridgeTestPlatform) WindowOwnedBy(h uint64, r uibridge.ProcessRef) bool {
	p.calls.Add(1)
	return h == 42 && r.Alive()
}
func bridgeFixture(t *testing.T, hold bool) (*runtimeUIBridge, *bridgeTestRef, *bridgeTestTransport) {
	t.Helper()
	tr := &bridgeTestTransport{stop: make(chan struct{}), ack: make(chan uibridge.Message, 1), sent: make(chan uibridge.Message, 40)}
	if hold {
		tr.hold = make(chan struct{})
		tr.registering = make(chan struct{})
	}
	ctx, cancel := context.WithCancel(context.Background())
	c, e := uibridge.NewClient(ctx, tr, "fixture-session", uibridge.Identity{PID: 101, Created: 1000})
	if e != nil {
		t.Fatal(e)
	}
	r := &runtimeUIBridge{root: t.TempDir(), client: c, platform: &bridgeTestPlatform{}, ctx: ctx, cancel: cancel}
	r.epoch.Store(1)
	ref := &bridgeTestRef{id: uibridge.Identity{PID: 202, Created: 2000}}
	ref.live.Store(true)
	t.Cleanup(func() { cancel(); c.Close() })
	return r, ref, tr
}
func waitBridgeMessage(t *testing.T, tr *bridgeTestTransport, kind string) uibridge.Message {
	t.Helper()
	timer := time.NewTimer(time.Second)
	defer timer.Stop()
	for {
		select {
		case m := <-tr.sent:
			if m.Kind == kind {
				return m
			}
		case <-timer.C:
			t.Fatal("message missing", kind)
			return uibridge.Message{}
		}
	}
}
func TestWPFReadyBeforeRegistrationWaitsForAck(t *testing.T) {
	r, ref, tr := bridgeFixture(t, true)
	dir, e := uibridge.FreshUIState(r.root)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(dir, "state.txt"), []byte("startup:UI-shell-ready:42\r\n"), 0600); e != nil {
		t.Fatal(e)
	}
	exited, done := make(chan struct{}), make(chan struct{})
	go func() { defer close(done); r.watchWPF(r.ctx, exited, ref, dir, 1) }()
	<-tr.registering
	// File readiness existed before registration but no READY may be sent yet.
	waitBridgeMessage(t, tr, "REGISTER")
	select {
	case m := <-tr.sent:
		t.Fatal("message before ACK", m)
	default:
	}
	close(tr.hold)
	m := waitBridgeMessage(t, tr, "READY")
	if m.HWND != "42" || m.Generation != "1" {
		t.Fatal(m)
	}
	close(exited)
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("watcher did not retire")
	}
	waitBridgeMessage(t, tr, "EXIT")
}
func TestForeignWPFHintRevokesWithoutReady(t *testing.T) {
	r, ref, tr := bridgeFixture(t, false)
	dir, _ := uibridge.FreshUIState(r.root)
	os.WriteFile(filepath.Join(dir, "state.txt"), []byte("startup:UI-shell-ready:999\n"), 0600)
	done := make(chan struct{})
	go func() { defer close(done); r.watchWPF(r.ctx, make(chan struct{}), ref, dir, 1) }()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("foreign hint not rejected")
	}
	select {
	case <-r.client.Closed():
	default:
		t.Fatal("coordination not revoked")
	}
	for len(tr.sent) > 0 {
		if m := <-tr.sent; m.Kind == "READY" {
			t.Fatal("foreign HWND transmitted")
		}
	}
}
func TestExitedWPFNeverRegisters(t *testing.T) {
	r, ref, tr := bridgeFixture(t, false)
	ref.live.Store(false)
	r.watchWPF(r.ctx, make(chan struct{}), ref, t.TempDir(), 1)
	for len(tr.sent) > 0 {
		if m := <-tr.sent; m.Kind != "HELLO" {
			t.Fatal("exited instance transmitted", m)
		}
	}
}
func TestDuplicateWPFButtonDoesNotLaunchAnotherChild(t *testing.T) {
	r, _, _ := bridgeFixture(t, false)
	r.wpf.Store(true)
	old := activeUIBridge
	activeUIBridge = r
	defer func() { activeUIBridge = old }()
	if rc := coordinatedLegacyUI(r.root, SecurityStatus{PowerShell: "a-fixture-that-must-not-be-started"}); rc != 30 {
		t.Fatal(rc)
	}
	if r.epoch.Load() != 1 {
		t.Fatal("duplicate changed generation")
	}
}
func TestNativeCloseRevokesWithoutIOWait(t *testing.T) {
	r, _, _ := bridgeFixture(t, false)
	r.retireImmediately()
	if r.ctx.Err() == nil {
		t.Fatal("context not retired")
	}
	select {
	case <-r.client.Closed():
	default:
		t.Fatal("client not revoked")
	}
}
