package runtime

import "strings"

// Pure launch decisions. System PowerShell version/mode is verified by supervision.Probe.
const (
	uiRouteNative         = "native"
	uiRouteWPF            = "powershell-wpf"
	createNoWindow uint32 = 0x08000000
)

func selectUIRoute(forceNative bool, shell, languageMode string) string {
	if forceNative || shell == "" || !strings.EqualFold(languageMode, "FullLanguage") {
		return uiRouteNative
	}
	return uiRouteWPF
}

func legacyUIArguments(script string) []string {
	// Preserved snapshot contract, NOT a claim of completed policy hardening.
	return []string{"-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script}
}

type childPresentation struct {
	HideWindow    bool
	CreationFlags uint32
}

func presentationForChild(editableUI bool) childPresentation {
	// Suppress the console, but do not give WPF an initial SW_HIDE.
	// Generic CLI helpers retain snapshot behavior.
	return childPresentation{HideWindow: !editableUI, CreationFlags: createNoWindow}
}
