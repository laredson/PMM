package uibridge

import (
	"bytes"
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// Framed in-memory endpoints, NOT Windows pipe authentication.
type testLink struct {
	stop chan struct{}
	once sync.Once
}
type testEnd struct {
	in, out    chan []byte
	link       *testLink
	beforeSend func(context.Context, Message) error
	received   atomic.Int64
}

func pair() (*testEnd, *testEnd) {
	a, b := make(chan []byte), make(chan []byte)
	l := &testLink{stop: make(chan struct{})}
	return &testEnd{in: a, out: b, link: l}, &testEnd{in: b, out: a, link: l}
}
func (e *testEnd) Closed() <-chan struct{} { return e.link.stop }
func (e *testEnd) Close()                  { e.link.once.Do(func() { close(e.link.stop) }) }
func (e *testEnd) Send(ctx context.Context, m Message) error {
	if e.beforeSend != nil {
		if x := e.beforeSend(ctx, m); x != nil {
			return x
		}
	}
	var b bytes.Buffer
	if x := WriteFrame(&b, m); x != nil {
		return x
	}
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-e.link.stop:
		return errors.New("closed")
	case e.out <- b.Bytes():
		return nil
	}
}
func (e *testEnd) Receive(ctx context.Context) (Message, error) {
	select {
	case <-ctx.Done():
		return Message{}, ctx.Err()
	case <-e.link.stop:
		return Message{}, errors.New("closed")
	case b := <-e.in:
		e.received.Add(1)
		return ReadFrame(bytes.NewReader(b))
	}
}
func clientFixture(t *testing.T, hold func(context.Context, Message) error) (*Client, *Gate, *fakeRef, *fakeRef, <-chan string, *testEnd) {
	t.Helper()
	r, u := newFake(Identity{101, 1000}), newFake(Identity{202, 2000})
	p := &fakePlatform{owners: map[Identity]*fakeRef{r.Identity(): r, u.Identity(): u}, windows: map[uint64]Identity{42: u.Identity(), 43: r.Identity()}}
	g, e := NewGate("test-session", r.dup(), p)
	if e != nil {
		t.Fatal(e)
	}
	client, server := pair()
	server.beforeSend = hold
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	events := make(chan string, 20)
	go func() { defer close(done); _ = ServeGate(ctx, server, g, func(k string, _ uint64) { events <- k }) }()
	c, e := NewClient(ctx, client, "test-session", r.Identity())
	if e != nil {
		t.Fatal(e)
	}
	t.Cleanup(func() {
		c.Close()
		cancel()
		g.Close()
		select {
		case <-done:
		case <-time.After(time.Second):
			t.Error("server failed to stop")
		}
	})
	return c, g, r, u, events, server
}
func nextEvent(t *testing.T, events <-chan string, want string) {
	t.Helper()
	select {
	case got := <-events:
		if got != want {
			t.Fatalf("event %s want %s", got, want)
		}
	case <-time.After(time.Second):
		t.Fatal("missing event", want)
	}
}
func TestIntegratedConversationHandoffOnceAndExit(t *testing.T) {
	c, g, _, u, events, _ := clientFixture(t, nil)
	gen, e := c.Begin(context.Background(), u.Identity(), "wpf", u.Alive)
	if e != nil {
		t.Fatal(e)
	}
	if e = c.Ready(context.Background(), gen, 42, u.Alive); e != nil {
		t.Fatal(e)
	}
	nextEvent(t, events, "READY")
	count := 0
	if !g.TryHandoff(gen, func(h uint64) {
		if h != 42 {
			t.Error(h)
		}
		count++
	}) {
		t.Fatal("handoff denied")
	}
	if e = c.Ready(context.Background(), gen, 42, u.Alive); e != nil {
		t.Fatal(e)
	}
	if g.TryHandoff(gen, func(uint64) { count++ }) || count != 1 {
		t.Fatal("repeated handoff")
	}
	if e = c.Retire(context.Background(), gen, false); e != nil {
		t.Fatal(e)
	}
	nextEvent(t, events, "EXIT")
	if g.TryHandoff(gen, func(uint64) { t.Error("after exit") }) {
		t.Fatal("after exit")
	}
}
func TestRegistrationAckMustFinishBeforeReady(t *testing.T) {
	blocked, release := make(chan struct{}), make(chan struct{})
	c, g, _, u, events, _ := clientFixture(t, func(ctx context.Context, m Message) error {
		if m.Generation == "1" && m.Seq == "2" {
			close(blocked)
			select {
			case <-release:
			case <-ctx.Done():
				return ctx.Err()
			}
		}
		return nil
	})
	done := make(chan error, 1)
	go func() {
		gen, e := c.Begin(context.Background(), u.Identity(), "wpf", u.Alive)
		if e == nil {
			e = c.Ready(context.Background(), gen, 42, u.Alive)
		}
		done <- e
	}()
	<-blocked
	if g.TryHandoff(1, func(uint64) { t.Error("before ACK") }) {
		t.Fatal("uncommitted ACK")
	}
	select {
	case e := <-done:
		t.Fatal("early return", e)
	default:
	}
	close(release)
	if e := <-done; e != nil {
		t.Fatal(e)
	}
	nextEvent(t, events, "READY")
	if !g.TryHandoff(1, func(uint64) {}) {
		t.Fatal("missing ACK commit")
	}
}
func TestAckFailureRevokesConversation(t *testing.T) {
	c, g, _, u, _, _ := clientFixture(t, func(_ context.Context, m Message) error {
		if m.Generation == "1" {
			return errors.New("fixture failed ACK")
		}
		return nil
	})
	if _, e := c.Begin(context.Background(), u.Identity(), "wpf", u.Alive); e == nil {
		t.Fatal("accepted failed ACK")
	}
	if g.TryHandoff(1, func(uint64) { t.Error("focus") }) {
		t.Fatal("focus after ACK error")
	}
	select {
	case <-c.Closed():
	default:
		t.Fatal("client still alive")
	}
}
func TestConcurrentTransactionsRemainSerialized(t *testing.T) {
	c, _, _, u, _, _ := clientFixture(t, nil)
	gen, e := c.Begin(context.Background(), u.Identity(), "wpf", u.Alive)
	if e != nil {
		t.Fatal(e)
	}
	var wg sync.WaitGroup
	errs := make(chan error, 20)
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); errs <- c.Ready(context.Background(), gen, 42, u.Alive) }()
	}
	wg.Wait()
	close(errs)
	for e := range errs {
		if e != nil {
			t.Fatal(e)
		}
	}
}
func TestHeartbeatDuringIdleInitialization(t *testing.T) {
	c, _, _, _, _, server := clientFixture(t, nil)
	before := server.received.Load()
	deadline := time.After(2 * time.Second)
	for server.received.Load() == before {
		select {
		case <-deadline:
			t.Fatal("missing heartbeat")
		case <-time.After(10 * time.Millisecond):
		}
	}
	select {
	case <-c.Closed():
		t.Fatal("heartbeat closed client")
	default:
	}
}
func TestNativeToWPFReplacesGenerationAndRejectsOldReady(t *testing.T) {
	c, g, r, u, events, _ := clientFixture(t, nil)
	a, e := c.Begin(context.Background(), r.Identity(), "native", r.Alive)
	if e != nil {
		t.Fatal(e)
	}
	b, e := c.Begin(context.Background(), u.Identity(), "wpf", u.Alive)
	if e != nil || b <= a {
		t.Fatal(b, e)
	}
	nextEvent(t, events, "EXIT")
	if !errors.Is(c.Ready(context.Background(), a, 43, r.Alive), ErrInactive) {
		t.Fatal("stale ready accepted")
	}
	if g.TryHandoff(a, func(uint64) { t.Error("stale") }) {
		t.Fatal("stale")
	}
	if e = c.Ready(context.Background(), b, 42, u.Alive); e != nil {
		t.Fatal(e)
	}
}
func TestClientCloseCancelsPendingAckWithoutLockWait(t *testing.T) {
	blocked := make(chan struct{})
	c, _, _, u, _, _ := clientFixture(t, func(ctx context.Context, m Message) error {
		if m.Generation == "1" {
			close(blocked)
			<-ctx.Done()
			return ctx.Err()
		}
		return nil
	})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan error, 1)
	go func() { _, e := c.Begin(ctx, u.Identity(), "wpf", u.Alive); done <- e }()
	<-blocked
	c.Close()
	cancel()
	select {
	case e := <-done:
		if e == nil {
			t.Fatal("no cancellation")
		}
	case <-time.After(time.Second):
		t.Fatal("Close waited on transaction")
	}
}
