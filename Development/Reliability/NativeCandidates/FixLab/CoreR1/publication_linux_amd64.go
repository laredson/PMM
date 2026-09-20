//go:build linux && amd64

package corer1

import (
	"os"
	"runtime"
	"syscall"
	"unsafe"
)

func candidateParent(f *os.File) (*os.File, error) { return openChild(f, ".", true) }
func candidateLookup(parent *os.File, name string, dir bool) (*os.File, error) {
	return openChild(parent, name, dir)
}
func candidateMkdir(parent *os.File, name string) (*os.File, bool, error) {
	if e := syscall.Mkdirat(int(parent.Fd()), name, 0700); e != nil {
		return nil, false, e
	}
	f, e := openChild(parent, name, true)
	return f, true, e
}
func candidateCreate(parent *os.File, name string) (*os.File, error) {
	fd, e := syscall.Openat(int(parent.Fd()), name, syscall.O_RDWR|syscall.O_CREAT|syscall.O_EXCL|syscall.O_CLOEXEC|syscall.O_NOFOLLOW, 0600)
	if e != nil {
		return nil, e
	}
	return os.NewFile(uintptr(fd), "candidate-file"), nil
}
func candidateRemove(parent *os.File, name string, f *os.File, dir bool) error {
	if e := candidateSame(parent, name, f, dir); e != nil {
		return e
	}
	p, e := syscall.BytePtrFromString(name)
	if e != nil {
		return e
	}
	var flags uintptr
	if dir {
		flags = 0x200
	} // AT_REMOVEDIR: never recursively delete
	_, _, errno := syscall.Syscall(syscall.SYS_UNLINKAT, parent.Fd(), uintptr(unsafe.Pointer(p)), flags)
	runtime.KeepAlive(parent)
	runtime.KeepAlive(f)
	runtime.KeepAlive(p)
	if errno != 0 {
		return errno
	}
	return nil
}
func candidateCommit(parent, stage *os.File, old, new string) (bool, error) {
	if e := candidateSame(parent, old, stage, true); e != nil {
		return false, e
	}
	a, e := syscall.BytePtrFromString(old)
	if e != nil {
		return false, e
	}
	b, e := syscall.BytePtrFromString(new)
	if e != nil {
		return false, e
	}
	// Linux amd64 renameat2, RENAME_NOREPLACE=1. No overwrite fallback on kernels
	// or filesystems without this operation. This is ordinary filesystem I/O.
	_, _, errno := syscall.Syscall6(316, parent.Fd(), uintptr(unsafe.Pointer(a)), parent.Fd(), uintptr(unsafe.Pointer(b)), 1, 0)
	runtime.KeepAlive(parent)
	runtime.KeepAlive(stage)
	runtime.KeepAlive(a)
	runtime.KeepAlive(b)
	if errno != 0 {
		return false, errno
	}
	return true, candidateSame(parent, new, stage, true)
}
func candidateSyncDir(f *os.File) (bool, error) { e := f.Sync(); return e == nil, e }
