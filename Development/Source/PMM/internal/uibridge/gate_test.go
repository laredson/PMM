package uibridge

import (
	"bytes"
	"errors"
	"strconv"
	"sync"
	"sync/atomic"
	"testing"
)

// Fake OS process objects preserve independent handle closure and shared life.
type fakeLife struct {
	id   Identity
	live atomic.Bool
}
type fakeRef struct {
	life   *fakeLife
	closed atomic.Bool
}

func newFake(id Identity) *fakeRef {
	p := &fakeRef{life: &fakeLife{id: id}}
	p.life.live.Store(true)
	return p
}
func (p *fakeRef) Identity() Identity { return p.life.id }
func (p *fakeRef) Alive() bool        { return !p.closed.Load() && p.life.live.Load() }
func (p *fakeRef) Close() error       { p.closed.Store(true); return nil }
func (p *fakeRef) dup() *fakeRef      { return &fakeRef{life: p.life} }

type fakePlatform struct {
	owners         map[Identity]*fakeRef
	windows        map[uint64]Identity
	deny           bool
	windowCalls    int
	dieDuringCheck bool
	onWindowCheck  func()
}

func (p *fakePlatform) AcquireOwner(r ProcessRef, id Identity, route string) (ProcessRef, error) {
	if p.deny {
		return nil, errors.New("access denied")
	}
	o := p.owners[id]
	if o == nil {
		return nil, errors.New("not controlled direct child")
	}
	return o.dup(), nil
}
func (p *fakePlatform) WindowOwnedBy(h uint64, r ProcessRef) bool {
	p.windowCalls++
	if p.onWindowCheck != nil {
		p.onWindowCheck()
	}
	if p.dieDuringCheck {
		r.(*fakeRef).life.live.Store(false)
	}
	return r.Alive() && p.windows[h] == r.Identity()
}
func register(seq, gen uint64, id Identity, route string) Message {
	m := Control("test-session", seq, "REGISTER", gen)
	m.PID = strconv.FormatUint(uint64(id.PID), 10)
	m.Created = strconv.FormatUint(id.Created, 10)
	m.Route = route
	return m
}
func ready(seq, gen, h uint64) Message {
	m := Control("test-session", seq, "READY", gen)
	m.HWND = strconv.FormatUint(h, 10)
	return m
}
func fixture(t *testing.T) (*Gate, *fakePlatform, *fakeRef, *fakeRef) {
	t.Helper()
	r := newFake(Identity{101, 1000})
	u := newFake(Identity{202, 2000})
	p := &fakePlatform{owners: map[Identity]*fakeRef{r.Identity(): r, u.Identity(): u}, windows: map[uint64]Identity{42: u.Identity(), 43: r.Identity()}}
	g, e := NewGate("test-session", r.dup(), p)
	if e != nil {
		t.Fatal(e)
	}
	t.Cleanup(g.Close)
	if _, e = g.Apply(hello()); e != nil {
		t.Fatal(e)
	}
	return g, p, r, u
}
func apply(t *testing.T, g *Gate, m Message) {
	t.Helper()
	if _, e := g.Apply(m); e != nil {
		t.Fatal(e)
	}
}
func TestReadyWaitsForAckAndRevalidates(t *testing.T) {
	g, p, _, u := fixture(t)
	apply(t, g, register(2, 1, u.Identity(), "wpf"))
	apply(t, g, ready(3, 1, 42))
	n := 0
	if g.TryHandoff(1, func(uint64) { n++ }) {
		t.Fatal("focused before ACK")
	}
	if e := g.AckWritten(1); e != nil {
		t.Fatal(e)
	}
	before := p.windowCalls
	if !g.TryHandoff(1, func(h uint64) {
		if h != 42 {
			t.Fatal(h)
		}
		n++
	}) || n != 1 || p.windowCalls <= before {
		t.Fatal("no revalidation/action")
	}
	if g.TryHandoff(1, func(uint64) { n++ }) {
		t.Fatal("duplicate focus")
	}
}
func TestDuplicateRegistrationIsIdempotent(t *testing.T) {
	g, _, _, u := fixture(t)
	apply(t, g, register(2, 1, u.Identity(), "wpf"))
	_ = g.AckWritten(1)
	apply(t, g, ready(3, 1, 42))
	_ = g.TryHandoff(1, func(uint64) {})
	apply(t, g, register(4, 1, u.Identity(), "wpf"))
	_ = g.AckWritten(1)
	apply(t, g, ready(5, 1, 42))
	if g.TryHandoff(1, func(uint64) {}) {
		t.Fatal("duplicate reset consumed bit")
	}
}
func TestExitBeatsPendingReady(t *testing.T) {
	for _, kind := range []string{"EXIT", "FAILED", "CLOSE"} {
		t.Run(kind, func(t *testing.T) {
			g, _, _, u := fixture(t)
			apply(t, g, register(2, 1, u.Identity(), "wpf"))
			_ = g.AckWritten(1)
			apply(t, g, ready(3, 1, 42))
			gen := uint64(1)
			if kind == "CLOSE" {
				gen = 0
			}
			apply(t, g, Control("test-session", 4, kind, gen))
			if g.TryHandoff(1, func(uint64) { t.Fatal("terminal focus") }) {
				t.Fatal("terminal")
			}
		})
	}
}
func TestLivenessCheckedAtAction(t *testing.T) {
	for _, which := range []string{"owner", "runtime", "window-reused", "during-check"} {
		t.Run(which, func(t *testing.T) {
			g, p, r, u := fixture(t)
			apply(t, g, register(2, 1, u.Identity(), "wpf"))
			_ = g.AckWritten(1)
			apply(t, g, ready(3, 1, 42))
			switch which {
			case "owner":
				u.life.live.Store(false)
			case "runtime":
				r.life.live.Store(false)
			case "window-reused":
				p.windows[42] = Identity{999, 777}
			case "during-check":
				p.dieDuringCheck = true
			}
			if g.TryHandoff(1, func(uint64) { t.Fatal("invalid action") }) {
				t.Fatal("accepted")
			}
		})
	}
}
func TestRejectsForeignWindowAndReusedPID(t *testing.T) {
	t.Run("foreign-HWND", func(t *testing.T) {
		g, _, _, u := fixture(t)
		apply(t, g, register(2, 1, u.Identity(), "wpf"))
		if _, e := g.Apply(ready(3, 1, 999)); e == nil {
			t.Fatal("foreign window")
		}
	})
	t.Run("PID-reused", func(t *testing.T) {
		g, _, _, u := fixture(t)
		id := u.Identity()
		id.Created++
		if _, e := g.Apply(register(2, 1, id, "wpf")); e == nil {
			t.Fatal("new creation accepted")
		}
	})
	t.Run("access-denied", func(t *testing.T) {
		g, p, _, u := fixture(t)
		p.deny = true
		if _, e := g.Apply(register(2, 1, u.Identity(), "wpf")); e == nil {
			t.Fatal("denied ignored")
		}
	})
}
func TestGenerationRequiresRetirement(t *testing.T) {
	g, _, _, u := fixture(t)
	apply(t, g, register(2, 1, u.Identity(), "wpf"))
	if _, e := g.Apply(register(3, 2, u.Identity(), "wpf")); e == nil {
		t.Fatal("overlapping generation")
	}
}
func TestNativeToWPFGeneration(t *testing.T) {
	g, _, r, u := fixture(t)
	apply(t, g, register(2, 1, r.Identity(), "native"))
	_ = g.AckWritten(1)
	apply(t, g, Control("test-session", 3, "EXIT", 1))
	apply(t, g, register(4, 2, u.Identity(), "wpf"))
	_ = g.AckWritten(2)
	if g.ObserveExit(1) {
		t.Fatal("stale exit retired new owner")
	}
	apply(t, g, ready(5, 2, 42))
	if !g.TryHandoff(2, func(uint64) {}) {
		t.Fatal("new owner not permitted")
	}
}
func TestOldGenerationRejected(t *testing.T) {
	g, _, _, u := fixture(t)
	apply(t, g, register(2, 1, u.Identity(), "wpf"))
	apply(t, g, Control("test-session", 3, "EXIT", 1))
	if _, e := g.Apply(register(4, 1, u.Identity(), "wpf")); e == nil {
		t.Fatal("reused generation")
	}
}
func TestWrongSequenceSessionAndHello(t *testing.T) {
	for _, kind := range []string{"sequence", "session", "hello", "ack", "ready-before-register"} {
		t.Run(kind, func(t *testing.T) {
			g, _, _, _ := fixture(t)
			m := Control("test-session", 2, "PING", 0)
			switch kind {
			case "sequence":
				m.Seq = "1"
			case "session":
				m.Session = "other"
			case "hello":
				m = hello()
				m.Seq = "2"
			case "ack":
				m.Kind = "ACK"
			case "ready-before-register":
				m = ready(2, 1, 42)
			}
			if _, e := g.Apply(m); e == nil {
				t.Fatal("accepted")
			}
			if _, e := g.Apply(Control("test-session", 3, "PING", 0)); e == nil {
				t.Fatal("gate reopened")
			}
		})
	}
}
func TestHelloMustMatchVerifiedOSPeer(t *testing.T) {
	r := newFake(Identity{999, 1000})
	g, e := NewGate("test-session", r, &fakePlatform{})
	if e != nil {
		t.Fatal(e)
	}
	defer g.Close()
	if _, e = g.Apply(hello()); e == nil {
		t.Fatal("HELLO spoof")
	}
}
func TestObserveExitAndTransportCloseRevoke(t *testing.T) {
	g, _, _, u := fixture(t)
	apply(t, g, register(2, 1, u.Identity(), "wpf"))
	_ = g.AckWritten(1)
	apply(t, g, ready(3, 1, 42))
	u.life.live.Store(false)
	if !g.ObserveExit(1) {
		t.Fatal("missed exit")
	}
	if g.TryHandoff(1, func(uint64) {}) {
		t.Fatal("focus after exit")
	}
	g.Close()
	if _, e := g.Apply(Control("test-session", 4, "PING", 0)); e == nil {
		t.Fatal("channel closed gate reusable")
	}
}
func TestWrongNativeOwner(t *testing.T) {
	g, _, _, u := fixture(t)
	if _, e := g.Apply(register(2, 1, u.Identity(), "native")); e == nil {
		t.Fatal("native not Runtime")
	}
}
func TestConcurrentCloseNeverAllowsSubsequentAction(t *testing.T) {
	g, _, _, u := fixture(t)
	apply(t, g, register(2, 1, u.Identity(), "wpf"))
	_ = g.AckWritten(1)
	apply(t, g, ready(3, 1, 42))
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); g.Close() }()
	}
	wg.Wait()
	if g.TryHandoff(1, func(uint64) { t.Fatal("action after closed") }) {
		t.Fatal("closed")
	}
}

func TestProtocolConversationThroughFrames(t *testing.T) {
	g, _, _, u := fixture(t)
	for _, m := range []Message{register(2, 1, u.Identity(), "wpf"), ready(3, 1, 42), Control("test-session", 4, "EXIT", 1), Control("test-session", 5, "CLOSE", 0)} {
		var wire bytes.Buffer
		if e := WriteFrame(&wire, m); e != nil {
			t.Fatal(e)
		}
		decoded, e := ReadFrame(&wire)
		if e != nil {
			t.Fatal(e)
		}
		ack, e := g.Apply(decoded)
		if e != nil {
			t.Fatal(e)
		}
		if e = WriteFrame(&wire, ack); e != nil {
			t.Fatal(e)
		}
		reply, e := ReadFrame(&wire)
		if e != nil {
			t.Fatal(e)
		}
		if e = ValidateAck(m, reply); e != nil {
			t.Fatal(e)
		}
		if m.Kind == "REGISTER" {
			if e = g.AckWritten(1); e != nil {
				t.Fatal(e)
			}
		}
	}
	if g.TryHandoff(1, func(uint64) { t.Fatal("retired action") }) {
		t.Fatal("closed")
	}
}
func TestSequenceOverflowFailsClosed(t *testing.T) {
	g, _, _, _ := fixture(t)
	g.lastSeq = ^uint64(0)
	if _, e := g.Apply(Control("test-session", 1, "PING", 0)); e == nil {
		t.Fatal("wraparound accepted")
	}
}
func TestAckFailureLeavesNoCapability(t *testing.T) {
	g, _, _, u := fixture(t)
	apply(t, g, register(2, 1, u.Identity(), "wpf"))
	apply(t, g, ready(3, 1, 42))
	// A failed ACK write revokes the channel; adapter owner must close Gate too.
	g.Close()
	if e := g.AckWritten(1); e == nil {
		t.Fatal("ACK after close")
	}
	if g.TryHandoff(1, func(uint64) {}) {
		t.Fatal("action after failed ACK")
	}
}

func TestTransportRevocationCheckedWithoutWatcherScheduling(t *testing.T) {
	g, _, _, u := fixture(t)
	revoke := make(chan struct{})
	g.revoked = revoke
	apply(t, g, register(2, 1, u.Identity(), "wpf"))
	_ = g.AckWritten(1)
	apply(t, g, ready(3, 1, 42))
	close(revoke)
	if g.TryHandoff(1, func(uint64) { t.Fatal("focused on revoked transport") }) {
		t.Fatal("revoked")
	}
}

func TestRevocationDuringWindowCheck(t *testing.T) {
	g, p, _, u := fixture(t)
	revoke := make(chan struct{})
	g.revoked = revoke
	apply(t, g, register(2, 1, u.Identity(), "wpf"))
	_ = g.AckWritten(1)
	apply(t, g, ready(3, 1, 42))
	p.onWindowCheck = func() { close(revoke) }
	if g.TryHandoff(1, func(uint64) { t.Fatal("focused after channel close during validation") }) {
		t.Fatal("revoked")
	}
}
