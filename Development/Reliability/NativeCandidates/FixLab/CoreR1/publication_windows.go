//go:build windows

package corer1

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"syscall"
	"unsafe"
)

var candidateSetInfo = syscall.NewLazyDLL("kernel32.dll").NewProc("SetFileInformationByHandle")
var candidateRename = captureDLL.NewProc("NtSetInformationFile")
var candidateSDDL = syscall.NewLazyDLL("advapi32.dll").NewProc("ConvertStringSecurityDescriptorToSecurityDescriptorW")
var candidateFree = syscall.NewLazyDLL("kernel32.dll").NewProc("LocalFree")

// Standard documented Windows file operations via DLL entry points, not direct
// syscalls. No policy changes, executable mappings, process access or privilege
// adjustments. Directory creation sets a protected, inheritable user/SYSTEM DACL.
func candidateSecurity() (uintptr, error) {
	tok, e := syscall.OpenCurrentProcessToken()
	if e != nil {
		return 0, e
	}
	u, ue := tok.GetTokenUser()
	ce := tok.Close()
	if ue != nil || ce != nil {
		return 0, errors.Join(ue, ce)
	}
	sid, e := u.User.Sid.String()
	if e != nil {
		return 0, e
	}
	str, e := syscall.UTF16PtrFromString("D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;" + sid + ")")
	if e != nil {
		return 0, e
	}
	var sd uintptr
	ok, _, err := candidateSDDL.Call(uintptr(unsafe.Pointer(str)), 1, uintptr(unsafe.Pointer(&sd)), 0)
	runtime.KeepAlive(str)
	if ok == 0 {
		return 0, err
	}
	return sd, nil
}
func candidateNt(parent *os.File, name string, dir, create, writable bool, sd uintptr) (*os.File, error) {
	b, e := syscall.UTF16FromString(name)
	if e != nil || len(b) > 32767 {
		return nil, fail("PATH", "candidate", "invalid name")
	}
	u := captureUnicode{uint16(2 * (len(b) - 1)), uint16(2 * len(b)), &b[0]}
	a := captureObjectAttributes{RootDirectory: syscall.Handle(parent.Fd()), ObjectName: &u, Attributes: 0x40, SecurityDescriptor: sd}
	a.Length = uint32(unsafe.Sizeof(a))
	var h syscall.Handle
	var ios captureIOStatus
	opts := uint32(0x00200020)
	if dir {
		opts |= 1
	} else {
		opts |= 0x40
	}
	access := uint32(0x00100081)
	share := uint32(7)
	if writable {
		access = 0xc0110000
		share = 5
		if dir {
			share = 3
			if !create {
				// The existing parent is never deleted. Requesting DELETE while
				// denying delete sharing made independent publications conflict.
				access &^= 0x00010000
			}
		}
	} // GENERIC_READ/WRITE, DELETE, SYNCHRONIZE
	disposition := uintptr(1)
	if create {
		disposition = 2
	} // FILE_CREATE refuses any existing entry
	s, _, _ := captureNT.Call(uintptr(unsafe.Pointer(&h)), uintptr(access), uintptr(unsafe.Pointer(&a)), uintptr(unsafe.Pointer(&ios)), 0, 0, uintptr(share), disposition, uintptr(opts), 0, 0)
	runtime.KeepAlive(parent)
	runtime.KeepAlive(b)
	runtime.KeepAlive(u)
	runtime.KeepAlive(a)
	if int32(s) < 0 {
		return nil, fmt.Errorf("candidate file operation NTSTATUS 0x%08x", uint32(s))
	}
	return os.NewFile(uintptr(h), "candidate-object"), nil
}
func candidateParent(root *anchoredRoot, path string) (*os.File, error) {
	// NtCreateFile does not resolve the Win32 "." pseudo-component. Reopen
	// the real basename relative to its HELD ancestor, then compare identity.
	// A volume root cannot be a private publication namespace.
	if len(root.chain) < 2 {
		return nil, fail("BOUNDARY", "parent", "volume root is not a publication directory")
	}
	parent := root.file
	f, e := candidateNt(root.chain[len(root.chain)-2], filepath.Base(path), true, false, true, 0)
	if e != nil {
		return nil, e
	}
	a, ae := stamp(parent, true)
	b, be := stamp(f, true)
	if ae != nil || be != nil || a.volume != b.volume || a.id != b.id {
		f.Close()
		return nil, errors.Join(ae, be, fail("CHANGED", "parent", "writable handle mismatch"))
	}
	return f, nil
}
func candidateLookup(parent *os.File, name string, dir bool) (*os.File, error) {
	return candidateNt(parent, name, dir, false, false, 0)
}
func candidateMkdir(parent *os.File, name string) (*os.File, bool, error) {
	sd, e := candidateSecurity()
	if e != nil {
		return nil, false, e
	}
	defer candidateFree.Call(sd)
	f, e := candidateNt(parent, name, true, true, true, sd)
	if e != nil {
		return nil, false, e
	}
	_, e = stamp(f, true)
	return f, true, e
}
func candidateCreate(parent *os.File, name string) (*os.File, error) {
	return candidateNt(parent, name, false, true, true, 0)
}
func candidateRemove(parent *os.File, name string, f *os.File, dir bool) error {
	if e := candidateSame(parent, name, f, dir); e != nil {
		return e
	}
	var deleteFile byte = 1
	ok, _, e := candidateSetInfo.Call(f.Fd(), 4, uintptr(unsafe.Pointer(&deleteFile)), 1)
	runtime.KeepAlive(f)
	if ok == 0 {
		return e
	}
	return nil
}

type candidateRenameInfo struct {
	Replace uint32
	Root    syscall.Handle
	Length  uint32
	Name    [1]uint16
}

func candidateCommit(parent, stage *os.File, old, new string) (bool, error) {
	if e := candidateSame(parent, old, stage, true); e != nil {
		return false, e
	}
	if e := candidateRenameRelative(parent, stage, new); e != nil {
		return false, e
	}
	return true, candidateSame(parent, new, stage, true)
}

func candidateRenameRelative(parent, object *os.File, new string) error {
	b, e := syscall.UTF16FromString(new)
	if e != nil {
		return e
	}
	off := unsafe.Offsetof(candidateRenameInfo{}.Name)
	raw := make([]byte, int(unsafe.Sizeof(candidateRenameInfo{}))+2*len(b))
	info := (*candidateRenameInfo)(unsafe.Pointer(&raw[0]))
	info.Root = syscall.Handle(parent.Fd())
	info.Length = uint32(2 * (len(b) - 1)) // Replace remains FALSE
	copy(unsafe.Slice((*uint16)(unsafe.Pointer(&raw[off])), len(b)), b)
	// Win10's Win32 FileRenameInfo wrapper rejects this root-relative request
	// with ERROR_INVALID_PARAMETER. Use the documented native file-information
	// API through ntdll, preserving the anchored destination and no-replace bit.
	var ios captureIOStatus
	status, _, _ := candidateRename.Call(object.Fd(), uintptr(unsafe.Pointer(&ios)), uintptr(unsafe.Pointer(&raw[0])), uintptr(len(raw)), 10)
	runtime.KeepAlive(parent)
	runtime.KeepAlive(object)
	runtime.KeepAlive(raw)
	if int32(status) < 0 {
		return fmt.Errorf("candidate rename NTSTATUS 0x%08x", uint32(status))
	}
	return nil
}

// File buffers are flushed by File.Sync. No unverified directory/volume flush
// guarantee is invented on Windows; the receipt records this weaker durability.
func candidateSyncDir(*os.File) (bool, error) { return false, nil }

func candidateSeal(stage *os.File, names []string, files []*os.File) (func() error, error) {
	stamps := make([]diskStamp, len(files))
	for i, f := range files {
		st, e := stamp(f, false)
		if e != nil {
			return nil, e
		}
		stamps[i] = st
	}
	restore := func() error {
		var failures []error
		for i := range files {
			if files[i] != nil {
				continue
			}
			f, e := candidateNt(stage, names[i], false, false, true, 0)
			if e != nil {
				failures = append(failures, e)
				continue
			}
			st, e := stamp(f, false)
			if e != nil || st.volume != stamps[i].volume || st.id != stamps[i].id {
				failures = append(failures, errors.Join(e, f.Close(), fail("CHANGED", names[i], "rollback identity differs")))
				continue
			}
			files[i] = f
		}
		return errors.Join(failures...)
	}
	var failures []error
	for i, f := range files {
		failures = append(failures, f.Close())
		files[i] = nil
	}
	return restore, errors.Join(failures...)
}
