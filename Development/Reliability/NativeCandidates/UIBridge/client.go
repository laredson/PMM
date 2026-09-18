package uibridge

import (
	"context"
	"errors"
	"math"
	"strconv"
	"sync"
	"time"
)

// Transport must be authenticated separately. Windows production uses Dial/Conn.
type Transport interface {
	Send(context.Context, Message) error
	Receive(context.Context) (Message, error)
	Close()
	Closed() <-chan struct{}
}

const ExchangeTimeout = 3 * time.Second
const HeartbeatInterval = time.Second

var ErrInactive = errors.New("UI generation is no longer active")

// Client serializes WHOLE send+ACK exchanges, not merely individual I/O calls.
// All methods with I/O belong on background/startup workers, never a GUI callback.
// Close revokes without waiting for a held transaction lock or OS cleanup.
type Client struct {
	transport               Transport
	session                 string
	token                   chan struct{}
	stop                    chan struct{}
	once                    sync.Once
	seq, generation, active uint64 // protected by token
	ready                   bool
}

func NewClient(ctx context.Context, transport Transport, session string, self Identity) (*Client, error) {
	if ctx == nil || transport == nil || !ValidSession(session) || !self.Valid() {
		return nil, errors.New("invalid client binding")
	}
	c := &Client{transport: transport, session: session, token: make(chan struct{}, 1), stop: make(chan struct{})}
	c.token <- struct{}{}
	e := c.withLock(ctx, func(ctx context.Context) error {
		m := Control(session, 1, "HELLO", 0)
		m.PID = strconv.FormatUint(uint64(self.PID), 10)
		m.Created = strconv.FormatUint(self.Created, 10)
		return c.exchange(ctx, m)
	})
	if e != nil {
		c.Close()
		return nil, e
	}
	go c.heartbeat()
	return c, nil
}
func (c *Client) Closed() <-chan struct{} { return c.stop }
func (c *Client) Close()                  { c.once.Do(func() { close(c.stop); c.transport.Close() }) }
func (c *Client) withLock(ctx context.Context, action func(context.Context) error) error {
	if ctx == nil {
		return errors.New("nil context")
	}
	ctx, cancel := context.WithTimeout(ctx, ExchangeTimeout)
	defer cancel()
	select {
	case <-c.stop:
		return errors.New("bridge client closed")
	case <-c.transport.Closed():
		c.Close()
		return errors.New("bridge transport closed")
	case <-ctx.Done():
		return ctx.Err()
	case <-c.token:
	}
	defer func() { c.token <- struct{}{} }()
	select {
	case <-c.stop:
		return errors.New("bridge client closed")
	default:
	}
	return action(ctx)
}
func (c *Client) exchange(ctx context.Context, m Message) error {
	if c.seq == math.MaxUint64 {
		c.Close()
		return errors.New("sequence exhausted")
	}
	m.Seq = strconv.FormatUint(c.seq+1, 10)
	if e := c.transport.Send(ctx, m); e != nil {
		c.Close()
		return e
	}
	ack, e := c.transport.Receive(ctx)
	if e == nil {
		e = ValidateAck(m, ack)
	}
	if e != nil {
		c.Close()
		return e
	}
	c.seq++
	return nil
}
func (c *Client) heartbeat() {
	tick := time.NewTicker(HeartbeatInterval)
	defer tick.Stop()
	for {
		select {
		case <-c.stop:
			return
		case <-c.transport.Closed():
			c.Close()
			return
		case <-tick.C:
			e := c.withLock(context.Background(), func(ctx context.Context) error { return c.exchange(ctx, Control(c.session, 1, "PING", 0)) })
			if e != nil {
				c.Close()
				return
			}
		}
	}
}

// Begin explicitly retires the old owner before assigning a fresh generation.
// eligible is local liveness/epoch observation, NOT a replacement for OS checks.
func (c *Client) Begin(ctx context.Context, id Identity, route string, eligible func() bool) (uint64, error) {
	var gen uint64
	e := c.withLock(ctx, func(ctx context.Context) error {
		if !id.Valid() || (route != "native" && route != "wpf") {
			return errors.New("invalid owner")
		}
		if eligible != nil && !eligible() {
			return ErrInactive
		}
		if c.active != 0 {
			if e := c.exchange(ctx, Control(c.session, 1, "EXIT", c.active)); e != nil {
				return e
			}
			c.active = 0
		}
		if c.generation == math.MaxUint64 {
			c.Close()
			return errors.New("generation exhausted")
		}
		c.generation++
		gen = c.generation
		m := Control(c.session, 1, "REGISTER", gen)
		m.PID = strconv.FormatUint(uint64(id.PID), 10)
		m.Created = strconv.FormatUint(id.Created, 10)
		m.Route = route
		if e := c.exchange(ctx, m); e != nil {
			return e
		}
		c.active = gen
		c.ready = false
		return nil
	})
	return gen, e
}
func (c *Client) Ready(ctx context.Context, gen, hwnd uint64, eligible func() bool) error {
	return c.withLock(ctx, func(ctx context.Context) error {
		if c.active != gen || gen == 0 {
			return ErrInactive
		}
		if c.ready {
			return nil
		}
		if eligible != nil && !eligible() {
			return ErrInactive
		}
		if hwnd == 0 {
			return errors.New("zero window handle")
		}
		m := Control(c.session, 1, "READY", gen)
		m.HWND = strconv.FormatUint(hwnd, 10)
		if e := c.exchange(ctx, m); e != nil {
			return e
		}
		c.ready = true
		return nil
	})
}
func (c *Client) Retire(ctx context.Context, gen uint64, failed bool) error {
	return c.withLock(ctx, func(ctx context.Context) error {
		if gen == 0 || c.active != gen {
			return nil
		}
		kind := "EXIT"
		if failed {
			kind = "FAILED"
		}
		if e := c.exchange(ctx, Control(c.session, 1, kind, gen)); e != nil {
			return e
		}
		c.active = 0
		c.ready = false
		return nil
	})
}
func (c *Client) Shutdown(ctx context.Context) {
	defer c.Close()
	_ = c.withLock(ctx, func(ctx context.Context) error { return c.exchange(ctx, Control(c.session, 1, "CLOSE", 0)) })
}

// ServeGate is a bounded single-connection loop. Only REGISTER's successfully
// written ACK commits registration. Notifications contain generation, never HWND.
func ServeGate(ctx context.Context, conn Transport, gate *Gate, notify func(string, uint64)) error {
	defer conn.Close()
	defer gate.Close()
	for {
		m, e := conn.Receive(ctx)
		if e != nil {
			return e
		}
		ack, e := gate.Apply(m)
		if e != nil {
			return e
		}
		if e = conn.Send(ctx, ack); e != nil {
			return e
		}
		gen, _ := Decimal(m.Generation, 64, true)
		if m.Kind == "REGISTER" {
			if e = gate.AckWritten(gen); e != nil {
				return e
			}
		}
		if notify != nil && (m.Kind == "READY" || m.Kind == "EXIT" || m.Kind == "FAILED" || m.Kind == "CLOSE") {
			notify(m.Kind, gen)
		}
		if m.Kind == "CLOSE" {
			return nil
		}
	}
}
