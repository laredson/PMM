package main

import "testing"

func TestStartupWindowHandle(t *testing.T) {
	cases := []struct {
		name, input string
		want        uintptr
	}{
		{"decimal", "startup:UI-shell-ready:123456", 123456},
		{"crlf", "startup:UI-shell-ready:42\r\n", 42},
		{"bom", "\ufeffstartup:UI-shell-ready:42\n", 42},
		{"leading-zero", "startup:UI-shell-ready:00042", 42},
		{"missing", "startup:UI-shell-ready:", 0},
		{"zero", "startup:UI-shell-ready:0", 0},
		{"negative", "startup:UI-shell-ready:-1", 0},
		{"plus", "startup:UI-shell-ready:+42", 0},
		{"hex", "startup:UI-shell-ready:0x2a", 0},
		{"expression", "startup:UI-shell-ready:42;whoami", 0},
		{"overflow", "startup:UI-shell-ready:18446744073709551616", 0},
		{"signed-overflow", "startup:UI-shell-ready:9223372036854775808", 0},
		{"wrong-prefix", "UI-shell-ready:42", 0},
		{"partial", "startup:UI-shell-read", 0},
		{"embedded-newline", "startup:UI-shell-ready:4\n2", 0},
		{"fallback", "startup:UI-ready", 0},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := parseStartupWindowHandle(c.input); got != c.want {
				t.Fatalf("got %d, want %d", got, c.want)
			}
		})
	}
}

func TestStageSequenceDoesNotTreatFirstPaintAsReady(t *testing.T) {
	states := []string{"startup:workspace", "startup:security", "startup:runtime",
		"startup:runtime-dependency-verification", "startup:runtime-ui-dispatch",
		"startup:UI-script-loading", "startup:UI-window-created"}
	expected := []int{0, 1, 2, 3, 4, 4, 4}
	view := startupView{}
	for i, s := range states {
		view = nextStartupView(view, s)
		if view.Stage != expected[i] || view.Ready {
			t.Fatalf("premature readiness or wrong stage for %q: %+v", s, view)
		}
	}
	view = nextStartupView(view, "startup:UI-shell-ready:42")
	if !view.Ready || view.Window != 42 || view.Stage != 5 {
		t.Fatalf("missing ready transition: %+v", view)
	}
}

func TestIncompleteOrUnknownStatesCannotRetireSplash(t *testing.T) {
	view := nextStartupView(startupView{}, "startup:UI-window-created")
	for _, state := range []string{"", "random-ready", "startup:UI-shell-ready:", "startup:UI-shell-ready:0",
		"startup:UI-shell-ready:abc", "startup:security"} {
		if got := nextStartupView(view, state); got != view {
			t.Fatalf("state %q changed view to %+v", state, got)
		}
	}
}

func TestFailureIsNotReadyAndDoesNotGetOverwritten(t *testing.T) {
	for _, state := range []string{"startup:runtime-dependency-failed", "startup:UI-runtime-exit:5"} {
		view := nextStartupView(startupView{}, state)
		if !view.Failed || view.Ready {
			t.Fatalf("unexpected failure view %+v", view)
		}
		if got := nextStartupView(view, "startup:UI-shell-ready:42"); got != view {
			t.Fatal("failure was hidden")
		}
	}
}

func TestFallbackAndReadyAreTerminal(t *testing.T) {
	view := nextStartupView(startupView{}, "startup:UI-ready")
	if !view.Ready || view.Window != 0 {
		t.Fatalf("bad fallback %+v", view)
	}
	if got := nextStartupView(view, "startup:workspace"); got != view {
		t.Fatal("ready state regressed")
	}
}

func TestCompleteRecordsRejectPartialHandleAndMultipleRecords(t *testing.T) {
	cases := []struct {
		input string
		want  bool
	}{
		{"startup:UI-shell-ready:42\r\n", true},
		{"\ufeffstartup:UI-ready\n", true},
		{"startup:UI-shell-ready:4", false},
		{"startup:UI-shell-ready:42\r", false},
		{"startup:UI-ready\nstartup:UI-closed-normally\n", false},
		{"startup:UI-ready\x00\n", false}, {"\n", false}, {"", false},
	}
	for _, c := range cases {
		if _, ok := completeStartupRecord(c.input); ok != c.want {
			t.Fatalf("record %q accepted=%v want %v", c.input, ok, c.want)
		}
	}
	raw := make([]byte, 65537)
	raw[len(raw)-1] = '\n'
	if _, ok := completeStartupRecord(string(raw)); ok {
		t.Fatal("oversize record accepted")
	}
}

func TestTerminalStateInvalidatesReadyAndCannotReopen(t *testing.T) {
	ready := nextStartupView(startupView{}, "startup:UI-shell-ready:42")
	for _, state := range []string{"startup:UI-closed-normally", "startup:UI-runtime-exit:5", "startup:UI-runtime-exit:0", "startup:runtime-dependency-failed"} {
		ended := nextStartupView(ready, state)
		if ended.Ready || ended.Window != 0 || (!ended.Failed && !ended.Closed) {
			t.Fatalf("stale readiness survives %q: %+v", state, ended)
		}
		if nextStartupView(ended, "startup:UI-shell-ready:42") != ended {
			t.Fatal("ended startup reopened")
		}
		if nextStartupAction(ended, false) != startupClose {
			t.Fatal("ended startup may hand off")
		}
	}
}

func TestStopWinsOverReadinessAtDecision(t *testing.T) {
	for _, ready := range []bool{false, true} {
		if nextStartupAction(startupView{Ready: ready, Window: 42}, true) != startupClose {
			t.Fatal("stop lost")
		}
	}
	if nextStartupAction(startupView{Ready: true, Window: 42}, false) != startupHandoff {
		t.Fatal("live readiness lost")
	}
	if nextStartupAction(startupView{}, false) != startupUpdate {
		t.Fatal("startup closed early")
	}
}

func TestPartialExitIsNotTerminal(t *testing.T) {
	v := nextStartupView(startupView{}, "startup:UI-window-created")
	for _, bad := range []string{"startup:UI-runtime-exit:", "startup:UI-runtime-exit:abc", "startup:UI-runtime-exit:2147483648"} {
		if nextStartupView(v, bad) != v {
			t.Fatal("partial exit changed state")
		}
	}
}
