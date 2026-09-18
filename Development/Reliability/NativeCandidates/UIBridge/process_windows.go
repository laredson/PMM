//go:build windows

package uibridge

import (
	"errors"
	"fmt"
	"sync"
	"syscall"
	"unsafe"
)

var kernel = syscall.NewLazyDLL("kernel32.dll")
var user = syscall.NewLazyDLL("user32.dll")
var procWindowPID = user.NewProc("GetWindowThreadProcessId")
var procAncestor = user.NewProc("GetAncestor")
var procIsWindow = user.NewProc("IsWindow")

// WinProcess owns a non-inheritable query+synchronize handle. Capture immediately
// after Cmd.Start and BEFORE Cmd.Wait releases the original OS process handle.
// This capture order is a requirement for the future Host/Runtime integration.
type WinProcess struct {
	mu sync.Mutex
	h  syscall.Handle
	id Identity
}

func CaptureProcess(pid uint32) (*WinProcess, error) {
	if pid == 0 {
		return nil, errors.New("zero PID")
	}
	h, e := syscall.OpenProcess(0x00100000|0x1000, false, pid)
	if e != nil {
		return nil, e
	}
	p, e := fromHandle(h, pid)
	if e != nil {
		_ = syscall.CloseHandle(h)
		return nil, e
	}
	return p, nil
}
func fromHandle(h syscall.Handle, pid uint32) (*WinProcess, error) {
	var c, x, k, u syscall.Filetime
	if e := syscall.GetProcessTimes(h, &c, &x, &k, &u); e != nil {
		return nil, e
	}
	p := &WinProcess{h: h, id: Identity{pid, uint64(c.HighDateTime)<<32 | uint64(c.LowDateTime)}}
	if !p.id.Valid() || !p.Alive() {
		return nil, errors.New("process already exited")
	}
	return p, nil
}
func OpenExpected(id Identity) (*WinProcess, error) {
	if !id.Valid() {
		return nil, errors.New("invalid identity")
	}
	p, e := CaptureProcess(id.PID)
	if e != nil {
		return nil, e
	}
	if p.id != id {
		_ = p.Close()
		return nil, errors.New("PID creation identity mismatch")
	}
	return p, nil
}
func (p *WinProcess) Identity() Identity { return p.id }
func (p *WinProcess) Alive() bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.h == 0 {
		return false
	}
	r, e := syscall.WaitForSingleObject(p.h, 0)
	return e == nil && r == syscall.WAIT_TIMEOUT
}
func (p *WinProcess) Close() error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.h == 0 {
		return nil
	}
	e := syscall.CloseHandle(p.h)
	p.h = 0
	return e
}
func (p *WinProcess) Duplicate() (*WinProcess, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.h == 0 {
		return nil, errors.New("closed process handle")
	}
	self, e := syscall.GetCurrentProcess()
	if e != nil {
		return nil, e
	}
	var h syscall.Handle
	if e = syscall.DuplicateHandle(self, p.h, self, &h, 0, false, syscall.DUPLICATE_SAME_ACCESS); e != nil {
		return nil, e
	}
	d, e := fromHandle(h, p.id.PID)
	if e != nil {
		_ = syscall.CloseHandle(h)
		return nil, e
	}
	return d, nil
}

// WindowsPlatform never consults state.txt or names as process identity evidence.
type WindowsPlatform struct{}

func (WindowsPlatform) AcquireOwner(runtime ProcessRef, id Identity, route string) (ProcessRef, error) {
	rp, ok := runtime.(*WinProcess)
	if !ok || !rp.Alive() {
		return nil, errors.New("verified Windows runtime handle required")
	}
	if route == "native" {
		if id != rp.Identity() {
			return nil, errors.New("wrong native owner")
		}
		return rp.Duplicate()
	}
	if route != "wpf" || id.PID == rp.id.PID || id.Created < rp.id.Created {
		return nil, errors.New("invalid child identity/route")
	}
	child, e := OpenExpected(id)
	if e != nil {
		return nil, e
	}
	parent, e := parentPID(id.PID)
	if e != nil || parent != rp.id.PID || !child.Alive() || !rp.Alive() {
		_ = child.Close()
		return nil, fmt.Errorf("owner not live direct Runtime child (parent=%d): %v", parent, e)
	}
	return child, nil
}
func parentPID(pid uint32) (uint32, error) {
	h, e := syscall.CreateToolhelp32Snapshot(0x00000002, 0)
	if e != nil {
		return 0, e
	}
	defer syscall.CloseHandle(h)
	var p syscall.ProcessEntry32
	p.Size = uint32(unsafe.Sizeof(p))
	e = syscall.Process32First(h, &p)
	for n := 0; e == nil && n < 65536; n++ {
		if p.ProcessID == pid {
			return p.ParentProcessID, nil
		}
		e = syscall.Process32Next(h, &p)
	}
	return 0, errors.New("process not in bounded Toolhelp snapshot")
}
func (WindowsPlatform) WindowOwnedBy(hwnd uint64, owner ProcessRef) bool {
	p, ok := owner.(*WinProcess)
	if !ok || !p.Alive() || hwnd == 0 || uint64(uintptr(hwnd)) != hwnd {
		return false
	}
	for _, proc := range []*syscall.LazyProc{procWindowPID, procAncestor, procIsWindow} {
		if proc.Find() != nil {
			return false
		}
	}
	h := uintptr(hwnd)
	root, _, _ := procAncestor.Call(h, 2)
	if root != h {
		return false
	}
	var pid uint32
	t, _, _ := procWindowPID.Call(h, uintptr(unsafe.Pointer(&pid)))
	if t == 0 || pid != p.id.PID {
		return false
	}
	valid, _, _ := procIsWindow.Call(h)
	return valid != 0 && p.Alive()
}
