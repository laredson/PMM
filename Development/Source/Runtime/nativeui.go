package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func launchUserInterface(root string, forceNative bool) int {
	sec := runtimeSecurity(root)
	if forceNative || !strings.EqualFold(sec.PowerShellLanguageMode, "FullLanguage") || sec.PowerShell == "" {
		return launchNativeUIShell(root, sec)
	}
	return launchLegacyPowerShellUI(root, sec)
}

func launchLegacyPowerShellUI(root string, sec SecurityStatus) int {
	if sec.PowerShell == "" {
		fmt.Fprintln(os.Stderr, "PowerShell is unavailable; legacy UI cannot start.")
		return 30
	}
	script := filepath.Join(root, "Modules", "Bootstrap", "Start-PalModMerger.ps1")
	cmd := exec.Command(sec.PowerShell, "-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script)
	configureProcess(cmd)
	cmd.Dir = root
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		fmt.Fprintln(os.Stderr, err)
		return 30
	}
	return 0
}
