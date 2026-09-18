//go:build windows

package uibridge

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"io"
	"os"
	"runtime"
	"sync"
	"syscall"
	"time"
	"unsafe"
)

const OperationTimeout = 5 * time.Second
const pipeRights = 0x00120083 // data read/write, read attributes/control, synchronize; NOT create instance.
var createPipe = kernel.NewProc("CreateNamedPipeW")
var connectPipe = kernel.NewProc("ConnectNamedPipe")
var clientPID = kernel.NewProc("GetNamedPipeClientProcessId")
var serverPID = kernel.NewProc("GetNamedPipeServerProcessId")
var createEvent = kernel.NewProc("CreateEventW")
var overlappedResult = kernel.NewProc("GetOverlappedResult")
var localFree = kernel.NewProc("LocalFree")
var advapi = syscall.NewLazyDLL("advapi32.dll")
var convertSD = advapi.NewProc("ConvertStringSecurityDescriptorToSecurityDescriptorW")

func pipeAPIs() error {
	for _, p := range []*syscall.LazyProc{createPipe, connectPipe, clientPID, serverPID, createEvent, overlappedResult, localFree, convertSD} {
		if e := p.Find(); e != nil {
			return e
		}
	}
	return nil
}
func winError(e error) error {
	if e == nil || e == syscall.Errno(0) {
		return errors.New("Win32 operation failed")
	}
	return e
}

// Restrict to the interactive logon SID, not all logons of the user's account.
// No service/Everyone fallback when there is no appropriate logon SID.
func logonSID() (string, error) {
	token, e := syscall.OpenCurrentProcessToken()
	if e != nil {
		return "", e
	}
	defer token.Close()
	var size uint32
	e = syscall.GetTokenInformation(token, syscall.TokenGroups, nil, 0, &size)
	if e != syscall.ERROR_INSUFFICIENT_BUFFER || size == 0 || size > 1<<20 {
		return "", errors.New("invalid token group size")
	}
	b := make([]byte, size)
	if e = syscall.GetTokenInformation(token, syscall.TokenGroups, &b[0], size, &size); e != nil {
		return "", e
	}
	type group struct {
		SID        *syscall.SID
		Attributes uint32
	}
	type groups struct {
		Count uint32
		First group
	}
	if len(b) < int(unsafe.Sizeof(groups{})) {
		return "", errors.New("truncated token groups")
	}
	head := (*groups)(unsafe.Pointer(&b[0]))
	offset := unsafe.Offsetof(head.First)
	stride := unsafe.Sizeof(head.First)
	if uint64(offset)+uint64(head.Count)*uint64(stride) > uint64(len(b)) {
		return "", errors.New("invalid token groups")
	}
	var found string
	for i := uint32(0); i < head.Count; i++ {
		g := (*group)(unsafe.Add(unsafe.Pointer(&b[0]), offset+uintptr(i)*stride))
		if g.Attributes&0xc0000000 == 0xc0000000 {
			if g.SID == nil {
				return "", errors.New("nil logon SID")
			}
			found, e = g.SID.String()
			if e != nil {
				return "", e
			}
			break
		}
	}
	runtime.KeepAlive(b)
	if found == "" {
		return "", errors.New("interactive logon SID unavailable")
	}
	return found, nil
}

type Server struct {
	mu       sync.Mutex
	desc     Descriptor
	h        syscall.Handle
	accepted bool
	conn     *Conn
}

func NewServer(session string) (*Server, error) {
	if !ValidSession(session) {
		return nil, errors.New("invalid session")
	}
	if e := pipeAPIs(); e != nil {
		return nil, e
	}
	host, e := CaptureProcess(uint32(os.Getpid()))
	if e != nil {
		return nil, e
	}
	defer host.Close()
	sid, e := logonSID()
	if e != nil {
		return nil, e
	}
	random := make([]byte, 16)
	if _, e = rand.Read(random); e != nil {
		return nil, e
	}
	d := Descriptor{pipePrefix + hex.EncodeToString(random), session, host.id}
	sddl, e := syscall.UTF16PtrFromString("D:P(A;;0x00120083;;;" + sid + ")")
	if e != nil {
		return nil, e
	}
	var sd uintptr
	ok, _, e := convertSD.Call(uintptr(unsafe.Pointer(sddl)), 1, uintptr(unsafe.Pointer(&sd)), 0)
	runtime.KeepAlive(sddl)
	if ok == 0 {
		return nil, winError(e)
	}
	defer localFree.Call(sd)
	sa := syscall.SecurityAttributes{Length: uint32(unsafe.Sizeof(syscall.SecurityAttributes{})), SecurityDescriptor: sd, InheritHandle: 0}
	name, _ := syscall.UTF16PtrFromString(d.Name)
	// Duplex + overlapped + FIRST_PIPE_INSTANCE; byte mode + REJECT_REMOTE_CLIENTS.
	// Exactly one server instance. A collision fails, never attaches to another pipe.
	h, _, e := createPipe.Call(uintptr(unsafe.Pointer(name)), 3|0x40000000|0x00080000, 8, 1, MaxFrame+4, MaxFrame+4, 0, uintptr(unsafe.Pointer(&sa)))
	runtime.KeepAlive(name)
	runtime.KeepAlive(sa)
	if syscall.Handle(h) == syscall.InvalidHandle {
		return nil, winError(e)
	}
	return &Server{desc: d, h: syscall.Handle(h)}, nil
}
func (s *Server) Descriptor() Descriptor { return s.desc }
func (s *Server) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.conn != nil {
		s.conn.Close()
	}
	if s.h != 0 {
		_ = syscall.CloseHandle(s.h)
		s.h = 0
	}
}

// Accept is single-use. expectedRuntime must come from the real controlled Start,
// not a message/name. A wrong peer consumes/revokes the endpoint (fail closed).
func (s *Server) Accept(ctx context.Context, expectedRuntime *WinProcess) (*Conn, error) {
	s.mu.Lock()
	if s.accepted || s.h == 0 || expectedRuntime == nil {
		s.mu.Unlock()
		return nil, errors.New("invalid/reused accept")
	}
	peer, e := expectedRuntime.Duplicate()
	if e != nil {
		s.mu.Unlock()
		return nil, e
	}
	s.accepted = true
	c := newConn(s.h, s.desc.Session, peer, true)
	s.h = 0
	s.conn = c
	s.mu.Unlock()
	if _, e = c.call(ctx, operation{kind: "connect"}); e != nil {
		c.Close()
		return nil, e
	}
	return c, nil
}
func Dial(ctx context.Context, d Descriptor, expectedHost *WinProcess) (*Conn, error) {
	if ctx == nil || !d.valid() || expectedHost == nil || expectedHost.Identity() != d.Host {
		return nil, errors.New("invalid independent Host binding")
	}
	if e := pipeAPIs(); e != nil {
		return nil, e
	}
	peer, e := expectedHost.Duplicate()
	if e != nil {
		return nil, e
	}
	// Runtime must itself be the live direct child of the expected Host.
	// This independently checks launch provenance even when a Descriptor was
	// obtained from environment strings. Leaking those strings to WPF is not
	// sufficient for WPF to impersonate Runtime on a separate connection.
	self, e := CaptureProcess(uint32(os.Getpid()))
	if e != nil {
		_ = peer.Close()
		return nil, e
	}
	parent, parentErr := parentPID(self.id.PID)
	validParent := parentErr == nil && parent == peer.id.PID && self.id.Created >= peer.id.Created && self.Alive() && peer.Alive()
	_ = self.Close()
	if !validParent {
		_ = peer.Close()
		return nil, errors.New("pipe server is not the live launching parent")
	}
	success := false
	defer func() {
		if !success {
			_ = peer.Close()
		}
	}()
	ctx, cancel := context.WithTimeout(ctx, OperationTimeout)
	defer cancel()
	name, _ := syscall.UTF16PtrFromString(d.Name)
	for {
		if e = ctx.Err(); e != nil {
			return nil, e
		}
		if !peer.Alive() {
			return nil, errors.New("Host exited")
		}
		// Local explicit name. Identification SQOS denies impersonation/delegation.
		h, e := syscall.CreateFile(name, pipeRights, 0, nil, syscall.OPEN_EXISTING, 0x40000000|0x00100000|0x00010000, 0)
		runtime.KeepAlive(name)
		if e == nil {
			if e = checkPeer(h, false, peer); e != nil {
				_ = syscall.CloseHandle(h)
				return nil, e
			}
			success = true
			return newConn(h, d.Session, peer, false), nil
		}
		if e != syscall.Errno(231) && e != syscall.ERROR_FILE_NOT_FOUND {
			return nil, e
		}
		timer := time.NewTimer(20 * time.Millisecond)
		select {
		case <-ctx.Done():
			timer.Stop()
			return nil, ctx.Err()
		case <-timer.C:
		}
	}
}
func checkPeer(h syscall.Handle, isServer bool, peer *WinProcess) error {
	if !peer.Alive() {
		return errors.New("peer process no longer alive")
	}
	p := serverPID
	if isServer {
		p = clientPID
	}
	var pid uint32
	ok, _, e := p.Call(uintptr(h), uintptr(unsafe.Pointer(&pid)))
	if ok == 0 {
		return winError(e)
	}
	if pid != peer.id.PID || !peer.Alive() {
		return errors.New("OS pipe peer does not match retained process")
	}
	return nil
}

type operation struct {
	kind    string
	message Message
	ctx     context.Context
	reply   chan opResult
}
type opResult struct {
	message Message
	err     error
}

// One I/O worker, zero-length request queue. Close revokes immediately; Done
// signals final OS cleanup. A defective driver can delay cancellation completion:
// retain pinned OVERLAPPED/buffers until completion, never free kernel-owned data.
// No unbounded retry queue; never automatically reopen a revoked connection.
type Conn struct {
	h          syscall.Handle
	session    string
	peer       *WinProcess
	server     bool
	requests   chan operation
	stop, done chan struct{}
	once       sync.Once
}

func newConn(h syscall.Handle, session string, peer *WinProcess, server bool) *Conn {
	c := &Conn{h: h, session: session, peer: peer, server: server, requests: make(chan operation), stop: make(chan struct{}), done: make(chan struct{})}
	go c.worker()
	return c
}
func (c *Conn) Close()                  { c.once.Do(func() { close(c.stop) }) }
func (c *Conn) Closed() <-chan struct{} { return c.stop }
func (c *Conn) Done() <-chan struct{}   { return c.done }
func (c *Conn) Peer() Identity          { return c.peer.id }
func (c *Conn) Send(ctx context.Context, m Message) error {
	_, e := c.call(ctx, operation{kind: "send", message: m})
	return e
}
func (c *Conn) Receive(ctx context.Context) (Message, error) {
	return c.call(ctx, operation{kind: "receive"})
}
func (c *Conn) call(ctx context.Context, o operation) (Message, error) {
	if ctx == nil {
		return Message{}, errors.New("nil context")
	}
	ctx, cancel := context.WithTimeout(ctx, OperationTimeout)
	defer cancel()
	o.ctx = ctx
	o.reply = make(chan opResult, 1)
	select {
	case <-c.stop:
		return Message{}, errors.New("connection revoked")
	case <-ctx.Done():
		c.Close()
		return Message{}, ctx.Err()
	case c.requests <- o:
	}
	select {
	case r := <-o.reply:
		return r.message, r.err
	case <-c.stop:
		return Message{}, errors.New("connection revoked")
	case <-ctx.Done():
		c.Close()
		return Message{}, ctx.Err()
	}
}
func (c *Conn) worker() {
	defer close(c.done)
	defer c.Close()
	defer c.peer.Close()
	defer syscall.CloseHandle(c.h)
	tick := time.NewTicker(50 * time.Millisecond)
	defer tick.Stop()
	connected := !c.server
	for {
		select {
		case <-c.stop:
			return
		case <-tick.C:
			if !c.peer.Alive() {
				return
			}
		case o := <-c.requests:
			r := opResult{}
			rw := &pipeIO{c: c, ctx: o.ctx}
			if e := rw.canceled(); e != nil {
				r.err = e
			} else {
				switch o.kind {
				case "connect":
					if connected {
						r.err = errors.New("already connected")
					} else {
						r.err = rw.connect()
						if r.err == nil {
							r.err = checkPeer(c.h, true, c.peer)
							connected = r.err == nil
						}
					}
				case "send":
					if !connected || o.message.Session != c.session {
						r.err = errors.New("wrong binding")
					} else {
						r.err = WriteFrame(rw, o.message)
					}
				case "receive":
					if !connected {
						r.err = errors.New("not connected")
					} else {
						r.message, r.err = ReadFrame(rw)
						if r.err == nil && r.message.Session != c.session {
							r.err = errors.New("wrong session")
						}
					}
				default:
					r.err = errors.New("unknown I/O operation")
				}
				if r.err == nil {
					r.err = rw.canceled()
				}
			}
			o.reply <- r
			if r.err != nil {
				return
			}
		}
	}
}

type pipeIO struct {
	c   *Conn
	ctx context.Context
}

func (p *pipeIO) canceled() error {
	select {
	case <-p.c.stop:
		return errors.New("connection revoked")
	default:
	}
	if e := p.ctx.Err(); e != nil {
		return e
	}
	if !p.c.peer.Alive() {
		return errors.New("peer exited")
	}
	return nil
}
func (p *pipeIO) Read(b []byte) (int, error) { return p.io(b, false, false) }
func (p *pipeIO) Write(b []byte) (int, error) {
	total := 0
	for total < len(b) {
		n, e := p.io(b[total:], true, false)
		total += n
		if e != nil {
			return total, e
		}
		if n == 0 {
			return total, io.ErrShortWrite
		}
	}
	return total, nil
}
func (p *pipeIO) connect() error { _, e := p.io(nil, false, true); return e }
func (p *pipeIO) io(b []byte, write, connect bool) (int, error) {
	if e := p.canceled(); e != nil {
		return 0, e
	}
	if !connect && len(b) == 0 {
		return 0, nil
	}
	event, _, e := createEvent.Call(0, 1, 0, 0)
	if event == 0 {
		return 0, winError(e)
	}
	defer syscall.CloseHandle(syscall.Handle(event))
	ov := &syscall.Overlapped{HEvent: syscall.Handle(event)}
	var pin runtime.Pinner
	pin.Pin(ov)
	if len(b) > 0 {
		pin.Pin(&b[0])
	}
	defer pin.Unpin()
	var n uint32
	pin.Pin(&n)
	if connect {
		ok, _, ce := connectPipe.Call(uintptr(p.c.h), uintptr(unsafe.Pointer(ov)))
		e = ce
		if ok != 0 || ce == syscall.Errno(535) {
			return 0, nil
		}
	} else if write {
		e = syscall.WriteFile(p.c.h, b, &n, ov)
	} else {
		e = syscall.ReadFile(p.c.h, b, &n, ov)
	}
	if e == nil {
		return int(n), nil
	}
	if e != syscall.ERROR_IO_PENDING {
		return 0, e
	}
	// API caller returns on deadline while this one worker waits for cancellation
	// completion. OS completion has no hard real-time bound; keep memory pinned.
	var canceled error
	for {
		if canceled == nil {
			if ce := p.canceled(); ce != nil {
				canceled = ce
				p.c.Close()
				_ = syscall.CancelIoEx(p.c.h, ov)
			}
		}
		wait, we := syscall.WaitForSingleObject(syscall.Handle(event), 25)
		if we != nil {
			p.c.Close()
			_ = syscall.CancelIoEx(p.c.h, ov)
			canceled = we
			time.Sleep(25 * time.Millisecond)
			continue
		}
		if wait == syscall.WAIT_TIMEOUT {
			continue
		}
		if wait != syscall.WAIT_OBJECT_0 {
			p.c.Close()
			_ = syscall.CancelIoEx(p.c.h, ov)
			canceled = errors.New("unexpected I/O event wait")
			time.Sleep(25 * time.Millisecond)
			continue
		}
		ok, _, ge := overlappedResult.Call(uintptr(p.c.h), uintptr(unsafe.Pointer(ov)), uintptr(unsafe.Pointer(&n)), 0)
		runtime.KeepAlive(b)
		runtime.KeepAlive(ov)
		if canceled != nil {
			return int(n), canceled
		}
		if ok == 0 {
			return int(n), winError(ge)
		}
		return int(n), nil
	}
}

var _ io.ReadWriter = (*pipeIO)(nil)

// RetainPeer returns a duplicate of the ALREADY verified pipe peer handle. Never
// reopen an identity supplied in an incoming payload to construct a host Gate.
func (c *Conn) RetainPeer() (*WinProcess, error) {
	select {
	case <-c.stop:
		return nil, errors.New("connection revoked")
	default:
	}
	peer, e := c.peer.Duplicate()
	if e != nil {
		return nil, e
	}
	select {
	case <-c.stop:
		_ = peer.Close()
		return nil, errors.New("connection revoked")
	default:
	}
	return peer, nil
}

// NewAuthenticatedGate is the Windows production binding. NewGate alone is only
// the model API. Pipe revocation is checked synchronously at every gate operation
// and also releases retained process references when no further messages arrive.
func NewAuthenticatedGate(c *Conn) (*Gate, error) {
	if c == nil || !c.server {
		return nil, errors.New("authenticated server connection required")
	}
	peer, e := c.RetainPeer()
	if e != nil {
		return nil, e
	}
	g, e := NewGate(c.session, peer, WindowsPlatform{})
	if e != nil {
		_ = peer.Close()
		return nil, e
	}
	g.revoked = c.Closed()
	go func() {
		select {
		case <-c.Closed():
			g.Close()
		case <-g.done:
		}
	}()
	return g, nil
}
