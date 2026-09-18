//go:build !windows

package supervision

import (
	"errors"
	"os/exec"
)

func systemDirectory() (string, error) {
	return "", errors.New("Windows system tools are unavailable on this platform")
}
func configureProbe(cmd *exec.Cmd) {}
