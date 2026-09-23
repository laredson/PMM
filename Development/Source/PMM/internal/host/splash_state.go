package host

// Pure state parsing. No Win32, process launches or filesystem access.
// Stage numbers are presentation steps, not measured percentages or time left.
import (
	"strconv"
	"strings"
)

type startupView struct {
	Stage  int
	Label  string
	Ready  bool
	Window uintptr
	Failed bool
	Closed bool
}

var startupLabels = [...]string{
	"Preparing workspace", "Checking system compatibility", "Starting runtime",
	"Checking dependencies", "Loading interface", "Ready",
}

func parseStartupWindowHandle(state string) uintptr {
	const prefix = "startup:UI-shell-ready:"
	s := strings.TrimSpace(strings.TrimPrefix(state, "\ufeff"))
	if !strings.HasPrefix(s, prefix) {
		return 0
	}
	text := strings.TrimPrefix(s, prefix)
	if text == "" {
		return 0
	}
	for _, c := range text {
		if c < '0' || c > '9' {
			return 0
		}
	}
	// WPF writes IntPtr.ToInt64() as decimal. Reject signs and overflow rather
	// than accepting hexadecimal, expressions, suffixes or wrapping handles.
	n, err := strconv.ParseUint(text, 10, 63)
	if err != nil || n == 0 || uint64(uintptr(n)) != n {
		return 0
	}
	return uintptr(n)
}

func startupState(state string) (startupView, bool) {
	s := strings.TrimSpace(strings.TrimPrefix(state, "\ufeff"))
	v := startupView{}
	switch {
	case strings.HasPrefix(s, "startup:UI-shell-ready:"):
		v.Window = parseStartupWindowHandle(s)
		if v.Window == 0 {
			return v, false
		}
		v.Stage, v.Ready = 5, true
	case s == "startup:UI-ready":
		v.Stage, v.Ready = 5, true // WPF fallback, without a target handle.
	case s == "startup:UI-closed-normally":
		v.Closed = true
		return v, true
	case strings.HasPrefix(s, "startup:UI-runtime-exit:"):
		code, err := strconv.ParseInt(strings.TrimPrefix(s, "startup:UI-runtime-exit:"), 10, 32)
		if err != nil {
			return v, false
		}
		v.Closed = code == 0
		v.Failed = code != 0
		v.Label = "Startup ended - see diagnostic report"
		return v, true
	case s == "startup:runtime-dependency-failed":
		v.Stage, v.Failed, v.Label = 3, true, "Startup failed - see diagnostic report"
		return v, true
	case s == "startup:workspace":
		v.Stage = 0
	case s == "startup:security":
		v.Stage = 1
	case s == "startup:runtime":
		v.Stage = 2
	case s == "startup:runtime-dependency-verification":
		v.Stage = 3
	case s == "startup:runtime-ui-dispatch" || s == "startup:UI-script-loading" || s == "startup:UI-window-created":
		v.Stage = 4
	default:
		// A partial state-file write or an unknown future state cannot assert readiness.
		return v, false
	}
	v.Label = startupLabels[v.Stage]
	return v, true
}

func nextStartupView(previous startupView, state string) startupView {
	next, known := startupState(state)
	if !known || previous.Closed || previous.Failed {
		return previous
	}
	// Closing or failure must invalidate a previously seen readiness handle.
	if next.Closed || next.Failed {
		return next
	}
	if previous.Ready {
		return previous
	}
	if next.Stage >= previous.Stage {
		return next
	}
	return previous
}

// The current WPF and Runtime writers terminate records with LF/CRLF. Do not
// turn a prefix of an in-progress decimal HWND write into a different handle.
// This is framing validation, NOT authenticated/atomic IPC.
func completeStartupRecord(raw string) (string, bool) {
	if len(raw) == 0 || len(raw) > 65536 || !strings.HasSuffix(raw, "\n") {
		return "", false
	}
	line := strings.TrimSuffix(strings.TrimSuffix(raw, "\n"), "\r")
	line = strings.TrimPrefix(line, "\ufeff")
	if line == "" || strings.ContainsAny(line, "\r\n\x00") {
		return "", false
	}
	return line, true
}

type startupAction int

const (
	startupUpdate startupAction = iota
	startupClose
	startupHandoff
)

func nextStartupAction(view startupView, stopping bool) startupAction {
	if stopping || view.Closed || view.Failed {
		return startupClose
	}
	if view.Ready {
		return startupHandoff
	}
	return startupUpdate
}

// Progress from state.txt must never turn into a focus capability.
func progressOnlyView(current startupView, raw string) startupView {
	next := nextStartupView(current, raw)
	next.Ready = false
	next.Window = 0
	return next
}
