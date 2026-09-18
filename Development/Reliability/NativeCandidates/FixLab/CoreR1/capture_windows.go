//go:build windows

package corer1

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"unsafe"
)

// NtCreateFile is used solely as the documented root-directory-relative OPEN
// operation missing from Go 1.23's os API. No direct syscalls, privilege changes,
// process memory access, executable mappings, or instrumentation bypass.
var captureDLL = syscall.NewLazyDLL("ntdll.dll")
var captureNT = captureDLL.NewProc("NtCreateFile")
var captureVolume = captureDLL.NewProc("NtQueryVolumeInformationFile")

type captureUnicode struct {
	Length, MaximumLength uint16
	Buffer                *uint16
}
type captureObjectAttributes struct {
	Length                                       uint32
	RootDirectory                                syscall.Handle
	ObjectName                                   *captureUnicode
	Attributes                                   uint32
	SecurityDescriptor, SecurityQualityOfService uintptr
}
type captureIOStatus struct{ Status, Information uintptr }

func absoluteRootParts(path string) (string, []string, error) {
	if e := cleanAbsolute(path); e != nil {
		return "", nil, e
	}
	vol := filepath.VolumeName(path)
	if len(vol) != 2 || vol[1] != ':' || !((vol[0] >= 'A' && vol[0] <= 'Z') || (vol[0] >= 'a' && vol[0] <= 'z')) || len(path) < 3 || path[2] != '\\' || strings.Contains(path, "/") {
		return "", nil, fail("PATH", "root", "only canonical local drive paths; no UNC/device paths")
	}
	tail := strings.TrimPrefix(path[2:], "\\")
	if tail == "" {
		return vol + "\\", nil, nil
	}
	return vol + "\\", strings.Split(tail, "\\"), nil
}
func openAnchor(path string) (*os.File, error) {
	p, e := syscall.UTF16PtrFromString(path)
	if e != nil {
		return nil, e
	}
	h, e := syscall.CreateFile(p, 0x00100080, syscall.FILE_SHARE_READ|syscall.FILE_SHARE_WRITE|syscall.FILE_SHARE_DELETE, nil, syscall.OPEN_EXISTING, syscall.FILE_FLAG_BACKUP_SEMANTICS|syscall.FILE_FLAG_OPEN_REPARSE_POINT, 0)
	if e != nil {
		return nil, e
	}
	f := os.NewFile(uintptr(h), "capture-anchor")
	if e := localFilesystem(f); e != nil {
		f.Close()
		return nil, e
	}
	if _, e = stamp(f, true); e != nil {
		f.Close()
		return nil, e
	}
	return f, nil
}
func openChild(parent *os.File, name string, dir bool) (*os.File, error) {
	b, e := syscall.UTF16FromString(name)
	if e != nil || len(b) > 32767 {
		return nil, fail("PATH", "component", "invalid UTF16")
	}
	u := captureUnicode{uint16(2 * (len(b) - 1)), uint16(2 * len(b)), &b[0]}
	a := captureObjectAttributes{RootDirectory: syscall.Handle(parent.Fd()), ObjectName: &u, Attributes: 0x40}
	a.Length = uint32(unsafe.Sizeof(a))
	var h syscall.Handle
	var status captureIOStatus
	// FILE_OPEN (1), OPEN_REPARSE_POINT (0x200000), SYNCHRONOUS_IO_NONALERT.
	// Parents are held handles; each name is exactly one path component.
	opts := uint32(0x00200020)
	access := uint32(0x00100081)
	share := uint32(syscall.FILE_SHARE_READ)
	if dir {
		opts |= 1
		access = 0x00100080
		share |= syscall.FILE_SHARE_WRITE | syscall.FILE_SHARE_DELETE
	} else {
		opts |= 0x40
	}
	s, _, _ := captureNT.Call(uintptr(unsafe.Pointer(&h)), uintptr(access), uintptr(unsafe.Pointer(&a)), uintptr(unsafe.Pointer(&status)), 0, 0, uintptr(share), 1, uintptr(opts), 0, 0)
	runtime.KeepAlive(parent)
	runtime.KeepAlive(b)
	runtime.KeepAlive(u)
	runtime.KeepAlive(a)
	if int32(s) < 0 {
		return nil, fmt.Errorf("capture relative open NTSTATUS 0x%08x", uint32(s))
	}
	f := os.NewFile(uintptr(h), "capture-component")
	if _, e = stamp(f, dir); e != nil {
		f.Close()
		return nil, e
	}
	return f, nil
}
func stamp(f *os.File, dir bool) (diskStamp, error) {
	h := syscall.Handle(f.Fd())
	typ, e := syscall.GetFileType(h)
	if e != nil {
		return diskStamp{}, e
	}
	var s syscall.ByHandleFileInformation
	if e = syscall.GetFileInformationByHandle(h, &s); e != nil {
		return diskStamp{}, e
	}
	isDir := s.FileAttributes&syscall.FILE_ATTRIBUTE_DIRECTORY != 0
	if typ != syscall.FILE_TYPE_DISK || s.FileAttributes&syscall.FILE_ATTRIBUTE_REPARSE_POINT != 0 || isDir != dir || (!dir && s.NumberOfLinks != 1) {
		return diskStamp{}, fail("FILESYSTEM", "input", "disk objects only; no reparse points or multiple links")
	}
	size := uint64(s.FileSizeHigh)<<32 | uint64(s.FileSizeLow)
	if size > uint64(^uint64(0)>>1) {
		return diskStamp{}, fail("LIMIT", "input", "size overflow")
	}
	return diskStamp{uint64(s.VolumeSerialNumber), uint64(s.FileIndexHigh)<<32 | uint64(s.FileIndexLow), uint64(s.NumberOfLinks), int64(size), int64(s.LastWriteTime.HighDateTime), int64(s.LastWriteTime.LowDateTime), int64(s.CreationTime.HighDateTime), int64(s.CreationTime.LowDateTime), s.FileAttributes}, nil
}

func localFilesystem(f *os.File) error {
	var ios captureIOStatus
	var device struct{ Type, Characteristics uint32 }
	status, _, _ := captureVolume.Call(f.Fd(), uintptr(unsafe.Pointer(&ios)), uintptr(unsafe.Pointer(&device)), unsafe.Sizeof(device), 4)
	runtime.KeepAlive(f)
	if uint32(status) != 0 || ios.Information < 8 || device.Type == 0 || device.Characteristics&0x10 != 0 {
		return fail("FILESYSTEM", "root", "local filesystem required; remote or unknown device rejected")
	}
	return nil
}
