package uibridge

import (
	"errors"
	"fmt"
	"math"
	"sync"
)

// Created is the raw Windows FILETIME, not Unix time or a JSON floating point.
type Identity struct {
	PID     uint32
	Created uint64
}

func (i Identity) Valid() bool { return i.PID != 0 && i.Created != 0 }

type ProcessRef interface {
	Identity() Identity
	Alive() bool
	Close() error
}

// AcquireOwner MUST independently open and retain a live process handle and
// verify creation identity. For WPF it also verifies direct Runtime parentage.
// A production adapter never accepts pid/name/title alone as evidence.
type Platform interface {
	AcquireOwner(runtime ProcessRef, owner Identity, route string) (ProcessRef, error)
	WindowOwnedBy(hwnd uint64, owner ProcessRef) bool
}
type ownerState struct {
	generation uint64
	identity   Identity
	route      string
	ref        ProcessRef
	ack        bool
	pending    uint64
	consumed   bool
}

// Gate is host-side. Call only after AuthenticateClient verified the named pipe
// peer against the retained Runtime handle. NewGate cannot authenticate a peer.
// Gate owns runtime on successful construction, and closes all refs on Close.
type Gate struct {
	mu       sync.Mutex
	session  string
	runtime  ProcessRef
	platform Platform
	hello    bool
	closed   bool
	lastSeq  uint64
	lastGen  uint64
	owner    *ownerState
	revoked  <-chan struct{}
	done     chan struct{}
}

func NewGate(session string, runtime ProcessRef, platform Platform) (*Gate, error) {
	if !ValidSession(session) || runtime == nil || platform == nil || !runtime.Identity().Valid() || !runtime.Alive() {
		return nil, errors.New("invalid gate binding")
	}
	return &Gate{session: session, runtime: runtime, platform: platform, done: make(chan struct{})}, nil
}
func (g *Gate) closeLocked() {
	if g.closed {
		return
	}
	g.closed = true
	close(g.done)
	if g.owner != nil {
		_ = g.owner.ref.Close()
		g.owner = nil
	}
	_ = g.runtime.Close()
}
func (g *Gate) Close()                        { g.mu.Lock(); defer g.mu.Unlock(); g.closeLocked() }
func (g *Gate) fail(e error) (Message, error) { g.closeLocked(); return Message{}, e }
func (g *Gate) liveLocked() bool {
	select {
	case <-g.revoked:
		g.closeLocked()
		return false
	default:
	}
	if g.closed {
		return false
	}
	if !g.runtime.Alive() {
		g.closeLocked()
		return false
	}
	return true
}

// Apply validates monotone wire sequence and state. It returns a reply but does
// NOT grant focus. After successfully writing REGISTER_ACK, call AckWritten.
// Any malformed/wrong-session/stale message retires the entire capability.
func (g *Gate) Apply(m Message) (Message, error) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if !g.liveLocked() {
		return Message{}, errors.New("gate closed/runtime exited")
	}
	if e := m.Validate(); e != nil {
		return g.fail(e)
	}
	seq, _ := Decimal(m.Seq, 64, false)
	gen, _ := Decimal(m.Generation, 64, true)
	if m.Session != g.session || g.lastSeq == math.MaxUint64 || seq != g.lastSeq+1 {
		return g.fail(errors.New("wrong session/sequence"))
	}
	g.lastSeq = seq
	ack := Control(g.session, seq, "ACK", gen)
	if !g.hello {
		if m.Kind != "HELLO" {
			return g.fail(errors.New("HELLO required"))
		}
		pid, _ := Decimal(m.PID, 32, false)
		created, _ := Decimal(m.Created, 64, false)
		if (Identity{uint32(pid), created}) != g.runtime.Identity() {
			return g.fail(errors.New("HELLO does not match OS peer"))
		}
		g.hello = true
		return ack, nil
	}
	switch m.Kind {
	case "REGISTER":
		pid, _ := Decimal(m.PID, 32, false)
		created, _ := Decimal(m.Created, 64, false)
		id := Identity{uint32(pid), created}
		if g.owner != nil {
			o := g.owner
			if o.generation == gen && o.identity == id && o.route == m.Route && o.ref.Alive() {
				return ack, nil
			}
			return g.fail(errors.New("owner already registered; explicit retirement required"))
		}
		if gen <= g.lastGen {
			return g.fail(errors.New("generation reused"))
		}
		if m.Route == "native" && id != g.runtime.Identity() {
			return g.fail(errors.New("native owner must be Runtime"))
		}
		ref, e := g.platform.AcquireOwner(g.runtime, id, m.Route)
		if e != nil {
			return g.fail(fmt.Errorf("owner: %w", e))
		}
		if ref == nil || ref.Identity() != id || !ref.Alive() {
			if ref != nil {
				_ = ref.Close()
			}
			return g.fail(errors.New("owner instance invalid/exited"))
		}
		g.lastGen = gen
		g.owner = &ownerState{generation: gen, identity: id, route: m.Route, ref: ref}
		return ack, nil
	case "READY":
		if g.owner == nil || g.owner.generation != gen || !g.owner.ref.Alive() {
			return g.fail(errors.New("READY without live matching owner"))
		}
		hwnd, _ := Decimal(m.HWND, 64, false)
		if !g.platform.WindowOwnedBy(hwnd, g.owner.ref) {
			return g.fail(errors.New("foreign/stale HWND"))
		}
		if !g.owner.consumed {
			g.owner.pending = hwnd
		} // At most ONE pending hint.
		return ack, nil
	case "EXIT", "FAILED":
		if g.owner == nil || g.owner.generation != gen {
			return g.fail(errors.New("invalid retirement"))
		}
		_ = g.owner.ref.Close()
		g.owner = nil
		return ack, nil
	case "PING":
		return ack, nil
	case "CLOSE":
		g.closeLocked()
		return ack, nil
	default:
		return g.fail(errors.New("unexpected message in established session"))
	}
}

// AckWritten only commits an ACK for the exact currently pending REGISTER. It
// must NOT be called when the write failed or timed out (Close instead).
func (g *Gate) AckWritten(generation uint64) error {
	g.mu.Lock()
	defer g.mu.Unlock()
	if !g.liveLocked() || g.owner == nil || g.owner.generation != generation || !g.owner.ref.Alive() {
		return errors.New("no live registration to acknowledge")
	}
	g.owner.ack = true
	return nil
}

// ObserveExit revokes an exact owner even if no EXIT frame arrived. A stale
// observation cannot retire a newer generation. Returns true when retired.
func (g *Gate) ObserveExit(generation uint64) bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	if !g.liveLocked() || g.owner == nil || g.owner.generation != generation {
		return false
	}
	if g.owner.ref.Alive() {
		return false
	}
	_ = g.owner.ref.Close()
	g.owner = nil
	return true
}

// TryHandoff revalidates process life + HWND ownership immediately before the
// caller's foreground-respecting action. The callback is short, non-reentrant
// and must itself check foreground; it MUST NOT block or cache HWND for later.
// A successfully consumed hint is never retried (even if Windows denies focus).
// Win32 has no atomic process/window validation+focus transaction: residual OS
// races and same-process HWND reuse remain Windows acceptance requirements.
func (g *Gate) TryHandoff(generation uint64, action func(uint64)) bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	if action == nil || !g.liveLocked() || g.owner == nil {
		return false
	}
	o := g.owner
	if o.generation != generation || !o.ack || o.consumed || o.pending == 0 {
		return false
	}
	if !o.ref.Alive() || !g.platform.WindowOwnedBy(o.pending, o.ref) || !g.liveLocked() {
		g.closeLocked()
		return false
	}
	hwnd := o.pending
	o.pending = 0
	o.consumed = true
	action(hwnd)
	return true
}
