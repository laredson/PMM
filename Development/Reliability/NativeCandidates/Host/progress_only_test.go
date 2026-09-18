package main

import "testing"

func TestFileReadinessNeverGrantsHandoff(t *testing.T) {
	var view startupView
	for _, s := range []string{"startup:UI-shell-ready:42", "startup:UI-ready", "startup:UI-window-created"} {
		view = progressOnlyView(view, s)
		if view.Ready || view.Window != 0 {
			t.Fatal("state file granted focus", view)
		}
	}
}
