package main

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestUIRouteContract(t *testing.T) {
	cases := []struct {
		name              string
		force             bool
		shell, mode, want string
	}{
		{"full", false, "powershell.exe", "FullLanguage", uiRouteWPF},
		{"case", false, "powershell.exe", "fulllanguage", uiRouteWPF},
		{"forced", true, "powershell.exe", "FullLanguage", uiRouteNative},
		{"constrained", false, "powershell.exe", "ConstrainedLanguage", uiRouteNative},
		{"restricted", false, "powershell.exe", "RestrictedLanguage", uiRouteNative},
		{"none", false, "powershell.exe", "NoLanguage", uiRouteNative},
		{"probe-empty", false, "powershell.exe", "", uiRouteNative},
		{"no-exe", false, "", "FullLanguage", uiRouteNative},
		{"ambiguous-output", false, "powershell.exe", "FullLanguage\nnoise", uiRouteNative},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := selectUIRoute(c.force, c.shell, c.mode); got != c.want {
				t.Fatalf("got %s want %s", got, c.want)
			}
		})
	}
}

func TestUIArgumentsAreSeparateAndFresh(t *testing.T) {
	// Unicode, spaces and shell metacharacters remain one argv item.
	script := `C:\PMM space\` + string(rune(0x6d4b)) + ` & name\Start-PalModMerger.ps1`
	want := []string{"-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script}
	a := legacyUIArguments(script)
	if !reflect.DeepEqual(a, want) {
		t.Fatal(a)
	}
	a[0] = "changed"
	if !reflect.DeepEqual(legacyUIArguments(script), want) {
		t.Fatal("arguments shared between launches")
	}
}

func TestWPFPresentationDiffersOnlyInHideWindow(t *testing.T) {
	ui, cli := presentationForChild(true), presentationForChild(false)
	if ui.HideWindow || !cli.HideWindow || ui.CreationFlags != 0x08000000 || cli.CreationFlags != ui.CreationFlags {
		t.Fatalf("ui=%+v cli=%+v", ui, cli)
	}
}

func TestUICommandPreservesSessionDirectoryStreamsAndArgv(t *testing.T) {
	root := filepath.Join(t.TempDir(), "PMM space "+string(rune(0xf1)))
	shell := filepath.Join(root, "WindowsPowerShell", "powershell.exe")
	values := map[string]string{
		"PMM_HOST_SESSION_ID": "fixture-session", "PMM_HOST_SESSION_DIR": filepath.Join(root, "Workspace", "State", "HostSessions", "fixture"),
		"PMM_HOST_ROOT": root, "PMM_HOST_POWERSHELL": shell,
	}
	for k, v := range values {
		t.Setenv(k, v)
	}
	cmd := legacyUICommand(root, SecurityStatus{PowerShell: shell})
	if cmd.Process != nil {
		t.Fatal("constructor must not start a process")
	}
	if cmd.Path != shell || cmd.Dir != root || cmd.Env != nil {
		t.Fatal("command contract changed")
	}
	if cmd.Stdin != os.Stdin || cmd.Stdout != os.Stdout || cmd.Stderr != os.Stderr {
		t.Fatal("streams must be inherited directly")
	}
	want := append([]string{shell}, legacyUIArguments(filepath.Join(root, "Modules", "Bootstrap", "Start-PalModMerger.ps1"))...)
	if !reflect.DeepEqual(cmd.Args, want) {
		t.Fatal(cmd.Args)
	}
	for k, v := range values {
		found := false
		for _, item := range cmd.Environ() {
			if item == k+"="+v {
				found = true
			}
		}
		if !found {
			t.Fatal("missing inherited field", k)
		}
	}
}

func TestMissingPowerShellDoesNotLaunch(t *testing.T) {
	if rc := launchLegacyPowerShellUI(t.TempDir(), SecurityStatus{}); rc != 30 {
		t.Fatal(rc)
	}
}

func TestRuntimeStateSessionScopedAndCRLF(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("PMM_HOST_SESSION_DIR", dir)
	runtimeState("startup:runtime-ui-dispatch")
	b, err := os.ReadFile(filepath.Join(dir, "state.txt"))
	if err != nil || string(b) != "startup:runtime-ui-dispatch\r\n" {
		t.Fatalf("%q %v", b, err)
	}
	t.Setenv("PMM_HOST_SESSION_DIR", "")
	runtimeState("must-not-be-written")
	b, _ = os.ReadFile(filepath.Join(dir, "state.txt"))
	if string(b) != "startup:runtime-ui-dispatch\r\n" {
		t.Fatal("state leaked across session")
	}
}
