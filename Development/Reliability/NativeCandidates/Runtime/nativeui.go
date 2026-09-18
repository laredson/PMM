package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func launchUserInterface(root string, forceNative bool) int {
	sec := runtimeSecurity(root)
	if selectUIRoute(forceNative, sec.PowerShell, sec.PowerShellLanguageMode) == uiRouteNative {
		return launchNativeUIShell(root, sec)
	}
	return launchLegacyPowerShellUI(root, sec)
}

func launchLegacyPowerShellUI(root string, sec SecurityStatus) int {
	if sec.PowerShell == "" {
		fmt.Fprintln(os.Stderr, "PowerShell is unavailable; legacy UI cannot start.")
		return 30
	}
	cmd := legacyUICommand(root, sec)
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		fmt.Fprintln(os.Stderr, err)
		return 30
	}
	return 0
}

// Construction only: no process is started until the caller invokes Run.
func legacyUICommand(root string, sec SecurityStatus) *exec.Cmd {
	script := filepath.Join(root, "Modules", "Bootstrap", "Start-PalModMerger.ps1")
	cmd := exec.Command(sec.PowerShell, legacyUIArguments(script)...)
	configureUIProcess(cmd)
	cmd.Dir = root
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	// Env remains nil: the Host session environment is inherited unchanged.
	return cmd
}
