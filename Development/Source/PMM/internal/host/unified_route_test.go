//go:build windows

package host

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestUnifiedRuntimeRouteUsesSameExecutableChild(t *testing.T) {
	root := t.TempDir()
	runner := filepath.Join(root, "Engine", "Runner")
	if err := os.MkdirAll(runner, 0o755); err != nil {
		t.Fatal(err)
	}
	routes := []byte(`{
  "schema": "PMM_HOST_ROUTES_V1",
  "routes": {
    "runtime-self-test": {
      "kind": "native",
      "executable": "Engine/PMMRuntime.exe",
      "arguments": ["self-test"]
    }
  }
}`)
	if err := os.WriteFile(filepath.Join(runner, "routes.json"), routes, 0o644); err != nil {
		t.Fatal(err)
	}

	h := &Host{Root: root}
	plan, err := h.resolveChild("runtime-self-test", []string{"--probe"}, SecurityStatus{})
	if err != nil {
		t.Fatal(err)
	}
	if plan.Kind != "native" || plan.Name != "PMM.exe runtime" {
		t.Fatalf("unexpected plan: %#v", plan)
	}
	if len(plan.Cmd.Args) < 4 {
		t.Fatalf("short command args: %#v", plan.Cmd.Args)
	}
	wantTail := []string{"runtime", "self-test", "--probe"}
	if got := plan.Cmd.Args[len(plan.Cmd.Args)-3:]; !reflect.DeepEqual(got, wantTail) {
		t.Fatalf("unexpected runtime child args: got %#v want %#v", got, wantTail)
	}
	self, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	gotPath, _ := filepath.Abs(plan.Cmd.Path)
	wantPath, _ := filepath.Abs(self)
	if !reflect.DeepEqual(filepath.Clean(gotPath), filepath.Clean(wantPath)) {
		t.Fatalf("runtime child does not use same executable: got %q want %q", gotPath, wantPath)
	}
}
