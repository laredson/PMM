//go:build windows

package runtime

import (
	"os/exec"
	"syscall"
)

func configureProcess(cmd *exec.Cmd) {
	if cmd == nil {
		return
	}
	applyPresentation(cmd, presentationForChild(false))
}

func configureUIProcess(cmd *exec.Cmd) {
	applyPresentation(cmd, presentationForChild(true))
}

func applyPresentation(cmd *exec.Cmd, p childPresentation) {
	if cmd == nil {
		return
	}
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: p.HideWindow, CreationFlags: p.CreationFlags}
}
