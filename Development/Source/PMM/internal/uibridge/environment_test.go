package uibridge

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestLocatorRoundTripAndNoChildLeak(t *testing.T) {
	d := Descriptor{pipePrefix + strings.Repeat("a", 32), "test-session", Identity{123, 456}}
	env, e := d.Environment([]string{"Path=a", "PATH=b", "PMM_UIBRIDGE_OLD=bad", "=C:=C:\\p", "PMM_HOST_SESSION_DIR=old"})
	if e != nil {
		t.Fatal(e)
	}
	got, present, e := DescriptorFromEnvironment(env)
	if !present || e != nil || got != d {
		t.Fatal(got, e)
	}
	child := MergeEnvironment(env, map[string]string{"PMM_HOST_SESSION_DIR": "new"})
	_, present, e = DescriptorFromEnvironment(child)
	if present || e != nil {
		t.Fatal("leaked descriptors")
	}
	if !reflect.DeepEqual(child, []string{"=C:=C:\\p", "PATH=b", "PMM_HOST_SESSION_DIR=new"}) {
		t.Fatal(child)
	}
}
func TestAmbiguousLocatorsRejected(t *testing.T) {
	d := Descriptor{pipePrefix + strings.Repeat("a", 32), "test-session", Identity{123, 456}}
	env, _ := d.Environment(nil)
	for _, bad := range [][]string{env[:3], append(append([]string{}, env...), "pmm_uibridge_host_pid=123"), append(append([]string{}, env...), "PMM_UIBRIDGE_UNKNOWN=x"), {EnvPrefix + "PIPE=remote"}} {
		if _, present, e := DescriptorFromEnvironment(bad); !present || e == nil {
			t.Fatal(bad)
		}
	}
}
func TestHintsRequireWholeRecordsAndCanonicalHandles(t *testing.T) {
	for _, raw := range []string{"startup:UI-shell-ready:4", "startup:UI-shell-ready:042\n", "startup:UI-shell-ready:0\n", "startup:UI-shell-ready:-1\n", "startup:UI-shell-ready:42\nother\n", "startup:UI-ready\x00\n", strings.Repeat("x", 65536) + "\n"} {
		if _, e := ParseHint(raw); e == nil {
			t.Fatal("accepted", len(raw))
		}
	}
	h, e := ParseHint("startup:UI-shell-ready:42\r\n")
	if e != nil || !h.Ready || h.HWND != 42 {
		t.Fatal(h, e)
	}
	h, e = ParseHint("startup:UI-ready\n")
	if e != nil || !h.Ready || h.HWND != 0 {
		t.Fatal(h, e)
	}
}
func TestFreshStateNeverReusesOldReady(t *testing.T) {
	root := t.TempDir()
	a, e := FreshUIState(root)
	if e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(a, "state.txt"), []byte("startup:UI-shell-ready:42\n"), 0600); e != nil {
		t.Fatal(e)
	}
	b, e := FreshUIState(root)
	if e != nil || a == b {
		t.Fatal(b, e)
	}
	if _, e = ReadHint(b); e == nil {
		t.Fatal("reused old ready")
	}
	if _, e = FreshUIState("relative"); e == nil {
		t.Fatal("relative root accepted")
	}
}
