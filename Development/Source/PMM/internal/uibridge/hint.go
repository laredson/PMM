package uibridge

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// Hint is untrusted presentation data. It NEVER binds a PID or grants focus.
type Hint struct {
	Ready, Terminal, Failed bool
	HWND                    uint64
}

func ParseHint(raw string) (Hint, error) {
	var h Hint
	if len(raw) == 0 || len(raw) > 65536 || !strings.HasSuffix(raw, "\n") {
		return h, errors.New("incomplete state record")
	}
	line := strings.TrimSuffix(strings.TrimSuffix(raw, "\n"), "\r")
	if strings.ContainsAny(line, "\r\n\x00") {
		return h, errors.New("multiple/invalid state records")
	}
	switch {
	case strings.HasPrefix(line, "startup:UI-shell-ready:"):
		n, e := Decimal(strings.TrimPrefix(line, "startup:UI-shell-ready:"), 64, false)
		if e != nil {
			return h, e
		}
		h.Ready = true
		h.HWND = n
	case line == "startup:UI-ready":
		h.Ready = true
	case line == "startup:UI-closed-normally":
		h.Terminal = true
	case strings.HasPrefix(line, "startup:UI-runtime-exit:") || strings.Contains(line, "failed"):
		h.Terminal = true
		h.Failed = true
	}
	return h, nil
}
func ReadHint(dir string) (Hint, error) {
	f, e := os.Open(filepath.Join(dir, "state.txt"))
	if e != nil {
		return Hint{}, e
	}
	defer f.Close()
	b, e := io.ReadAll(io.LimitReader(f, 65537))
	if e != nil {
		return Hint{}, e
	}
	return ParseHint(string(b))
}

// FreshUIState is separate from Runtime's Host-session diagnostics. Never reuse
// an older generation's directory, even when no authenticated channel is present.
func FreshUIState(root string) (string, error) {
	if !filepath.IsAbs(root) {
		return "", errors.New("UI state root must be absolute")
	}
	base := filepath.Join(root, "Workspace", "State", "UIInstances")
	if e := os.MkdirAll(base, 0700); e != nil {
		return "", e
	}
	return os.MkdirTemp(base, "ui-")
}
