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
	access := uint32(0x00100081)
	share := uint32(7)
	if writable {
		access = 0xc0110000
		share = 5
		if dir {
			share = 7
			if !create {
				// The existing parent is never deleted. It neither requests DELETE
				// nor denies delete sharing: Windows may require FILE_SHARE_DELETE
				// on every retained parent handle while independent children are
				// renamed. The anchored root handle uses the same sharing.
				access &^= 0x00010000
				share = 7
			}
		}
	} // GENERIC_READ/WRITE, DELETE, SYNCHRONIZE
	return candidateNtRaw(parent, name, dir, create, access, share, sd)
}

func candidateNtRaw(parent *os.File, name string, dir, create bool, access, share uint32, sd uintptr) (*os.File, error) {
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
func candidateLayout(_ string, final string) (string, string) {
	// Windows cannot reliably rename a directory immediately after closing its
	// scanned children. Create the uncommitted final namespace directly and use
	// an atomically renamed completion marker as the commit point instead.
	return final, ".pmm-complete-pending"
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
	want, e := stamp(f, true)
	if e != nil {
		return f, true, e
	}
	// Retain only traverse/read-attributes/synchronize. Microsoft documents
	// this access set for a rename RootDirectory without sharing conflicts.
	anchor, ae := candidateNtRaw(parent, name, true, false, 0x001000a0, 7, 0)
	if ae != nil {
		return f, true, ae
	}
	got, se := stamp(anchor, true)
	ce := f.Close()
	if se != nil || ce != nil || want.volume != got.volume || want.id != got.id {
		return anchor, true, errors.Join(se, ce, fail("CHANGED", name, "created directory anchor differs"))
	}
	return anchor, true, nil
}
func candidateCreate(parent *os.File, name string) (*os.File, error) {
	return candidateNt(parent, name, false, true, true, 0)
}
func candidateRemove(parent *os.File, name string, f *os.File, dir bool) error {
	if e := candidateSame(parent, name, f, dir); e != nil {
		return e
	}
	deleteHandle := f
	if dir {
		var e error
		deleteHandle, e = candidateNtRaw(parent, name, true, false, 0x00110080, 7, 0)
		if e != nil {
			return e
		}
		a, ae := stamp(f, true)
		b, be := stamp(deleteHandle, true)
		if ae != nil || be != nil || a.volume != b.volume || a.id != b.id {
			return errors.Join(ae, be, deleteHandle.Close(), fail("CHANGED", name, "delete handle identity differs"))
		}
	}
	var deleteFile byte = 1
	ok, _, e := candidateSetInfo.Call(deleteHandle.Fd(), 4, uintptr(unsafe.Pointer(&deleteFile)), 1)
	runtime.KeepAlive(deleteHandle)
	if ok == 0 {
		if dir {
			return errors.Join(e, deleteHandle.Close())
		}
		return e
	}
	if dir {
		return deleteHandle.Close()
	}
	return nil
}

type candidateRenameInfo struct {
	Flags  uint32
	Root   syscall.Handle
	Length uint32
	Name   [1]uint16
}

func candidateCommit(parent, stage *os.File, old, new, completionName string, completion *os.File) (bool, error) {
	if old != new || completionName == "COMPLETE.json" || completion == nil {
		return false, fail("COMMIT", "candidate", "invalid Windows marker layout")
	}
	runtime.KeepAlive(parent)
	runtime.KeepAlive(stage)
	// The generic commit path has just re-resolved both directory and marker,
	// while their original handles remain held. Do not introduce another
	// transient lookup handle between that verification and this rename.
	// candidateMkdir retained stage with the documented minimal access set.
	if e := candidateRenameRelative(stage, completion, "COMPLETE.json"); e != nil {
		return false, e
	}
	return true, candidateSame(stage, "COMPLETE.json", completion, false)
}

func candidateRenameRelative(parent, object *os.File, new string) error {
	b, e := syscall.UTF16FromString(new)
	if e != nil {
		return e
	}
	off := unsafe.Offsetof(candidateRenameInfo{}.Name)
	nameBytes := 2 * (len(b) - 1)
	raw := make([]byte, int(unsafe.Sizeof(candidateRenameInfo{}))+nameBytes)
	info := (*candidateRenameInfo)(unsafe.Pointer(&raw[0]))
	info.Flags = 0 // FileRenameInformation ReplaceIfExists remains FALSE
	info.Root = syscall.Handle(parent.Fd())
	info.Length = uint32(nameBytes)
	copy(unsafe.Slice((*uint16)(unsafe.Pointer(&raw[off])), len(b)-1), b[:len(b)-1])
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
	for _, f := range files {
		if _, e := stamp(f, false); e != nil {
			return nil, e
		}
	}
	return func() error { return nil }, nil
}
