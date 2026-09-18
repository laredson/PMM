//go:build linux

package corer1

import (
	"os"
	"strings"
	"syscall"
)

func absoluteRootParts(path string) (string, []string, error) {
	if e := cleanAbsolute(path); e != nil {
		return "", nil, e
	}
	if path == "/" {
		return "/", nil, nil
	}
	return "/", strings.Split(strings.TrimPrefix(path, "/"), "/"), nil
}
func openAnchor(path string) (*os.File, error) {
	fd, e := syscall.Open(path, syscall.O_RDONLY|syscall.O_DIRECTORY|syscall.O_NOFOLLOW|syscall.O_CLOEXEC, 0)
	if e != nil {
		return nil, e
	}
	f := os.NewFile(uintptr(fd), "capture-anchor")
	if e := localFilesystem(f); e != nil {
		f.Close()
		return nil, e
	}
	return f, nil
}
func openChild(parent *os.File, name string, dir bool) (*os.File, error) {
	flags := syscall.O_RDONLY | syscall.O_NOFOLLOW | syscall.O_CLOEXEC | syscall.O_NONBLOCK
	if dir {
		flags |= syscall.O_DIRECTORY
	}
	fd, e := syscall.Openat(int(parent.Fd()), name, flags, 0)
	if e != nil {
		return nil, e
	}
	f := os.NewFile(uintptr(fd), "capture-component")
	if _, e = stamp(f, dir); e != nil {
		f.Close()
		return nil, e
	}
	return f, nil
}
func stamp(f *os.File, dir bool) (diskStamp, error) {
	var s syscall.Stat_t
	if e := syscall.Fstat(int(f.Fd()), &s); e != nil {
		return diskStamp{}, e
	}
	typ := s.Mode & syscall.S_IFMT
	if (dir && typ != syscall.S_IFDIR) || (!dir && (typ != syscall.S_IFREG || s.Nlink != 1)) {
		return diskStamp{}, fail("FILESYSTEM", "input", "only regular single-link files and directories")
	}
	return diskStamp{uint64(s.Dev), s.Ino, s.Nlink, s.Size, s.Mtim.Sec, s.Mtim.Nsec, s.Ctim.Sec, s.Ctim.Nsec, s.Mode}, nil
}

func localFilesystem(f *os.File) error {
	var fs syscall.Statfs_t
	if e := syscall.Fstatfs(int(f.Fd()), &fs); e != nil {
		return e
	}
	switch uint64(fs.Type) {
	case 0xef53, 0x58465342, 0x9123683e, 0x01021994, 0x794c7630, 0x858458f6:
		return nil
	}
	return fail("FILESYSTEM", "root", "local filesystem type not in capture profile")
}
