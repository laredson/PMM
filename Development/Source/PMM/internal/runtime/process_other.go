//go:build !windows

package runtime

import "os/exec"

func configureProcess(cmd *exec.Cmd) {}

func configureUIProcess(cmd *exec.Cmd) {}
