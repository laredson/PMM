//go:build windows

package supervision

import (
	"fmt"
	"os/exec"
	"syscall"
	"unsafe"
)

func systemDirectory() (string, error) {
	// The candidates target windows/amd64; do not trust PATH/WINDIR for this tool.
	buf := make([]uint16, 32768)
	p := syscall.NewLazyDLL("kernel32.dll").NewProc("GetSystemDirectoryW")
	n, _, e := p.Call(uintptr(unsafe.Pointer(&buf[0])), uintptr(len(buf)))
	if n == 0 || n >= uintptr(len(buf)) {
		return "", fmt.Errorf("GetSystemDirectoryW failed: %v", e)
	}
	return syscall.UTF16ToString(buf[:n]), nil
}
func configureProbe(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}
}
