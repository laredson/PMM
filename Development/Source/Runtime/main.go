package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const runtimeVersion = "1.2.1"

func main() {
	root, err := executableRoot()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(250)
	}
	args := os.Args[1:]
	if len(args) == 0 {
		args = []string{"doctor", "--json"}
	}
	switch args[0] {
	case "version", "--version", "-v":
		fmt.Println(runtimeVersion)
		return
	case "doctor":
		printJSON(runtimeDoctor(root))
		return
	case "security":
		printJSON(runtimeSecurity(root))
		return
	case "knowledge":
		if len(args) > 1 && args[1] == "validate" {
			v := validateKnowledge(root)
			printJSON(v)
			if !v.OK {
				os.Exit(2)
			}
			return
		}
	case "game":
		if len(args) > 1 && args[1] == "detect" {
			d := detectPalworld(root)
			printJSON(d)
			if !d.Found {
				os.Exit(3)
			}
			return
		}
	case "dependencies":
		if len(args) > 1 && args[1] == "status" {
			m, e := loadReleaseManifest(root)
			if e != nil {
				fail(e)
			}
			s := inspectDependencies(root, m)
			printJSON(s)
			if !s.Ready {
				os.Exit(4)
			}
			return
		}
		if len(args) > 1 && args[1] == "ensure" {
			ifNeeded := has(args, "--if-needed")
			refresh := has(args, "--refresh-mappings")
			s, e := ensureDependencies(root, ifNeeded, refresh)
			printJSON(s)
			if e != nil {
				fmt.Fprintln(os.Stderr, e)
				os.Exit(5)
			}
			return
		}
	case "hash":
		if len(args) == 3 && args[1] == "sha256" {
			h := fileSHA256(args[2])
			if h == "" {
				os.Exit(6)
			}
			fmt.Println(h)
			return
		}
	case "archive":
		if len(args) == 4 && args[1] == "extract" {
			if e := extractZipSafe(args[2], args[3]); e != nil {
				fail(e)
			}
			return
		}
		if len(args) == 4 && args[1] == "create" {
			if e := createZipFromDirectory(args[3], args[2]); e != nil {
				fail(e)
			}
			return
		}
	case "process":
		if len(args) > 1 && args[1] == "run" {
			os.Exit(processCommand(args[2:]))
		}
	case "start":
		os.Exit(startApplication(root))
	case "ui":
		os.Exit(launchUserInterface(root, has(args[1:], "--native")))
	case "ui-native":
		os.Exit(launchUserInterface(root, true))
	case "self-test":
		os.Exit(selfTest(root))
	}
	usage()
	os.Exit(64)
}

func processCommand(args []string) int {
	timeout := 300 * time.Second
	cwd := ""
	sep := -1
	for i, a := range args {
		if a == "--" {
			sep = i
			break
		}
		if a == "--timeout-sec" && i+1 < len(args) {
			if n, e := strconv.Atoi(args[i+1]); e == nil && n > 0 {
				timeout = time.Duration(n) * time.Second
			}
		}
		if a == "--cwd" && i+1 < len(args) {
			cwd = args[i+1]
		}
	}
	if sep < 0 || sep+1 >= len(args) {
		fmt.Fprintln(os.Stderr, "process run requires -- <executable> [args]")
		return 64
	}
	req := ProcessRequest{Executable: args[sep+1], Arguments: args[sep+2:], WorkingDirectory: cwd, Timeout: timeout}
	r := runProcess(req)
	printJSON(r)
	return r.ExitCode
}
func selfTest(root string) int {
	m, e := loadReleaseManifest(root)
	if e != nil {
		fmt.Fprintln(os.Stderr, e)
		return 2
	}
	k := validateKnowledge(root)
	if !k.OK {
		fmt.Fprintln(os.Stderr, "knowledge validation failed")
		return 3
	}
	if readTrim(filepath.Join(root, "Resources", "Metadata", "BUILD_ID.txt")) == "" {
		return 4
	}
	fmt.Println("PMMRUNTIME_SELFTEST_OK " + runtimeVersion)
	fmt.Println("MANIFEST=" + m.Schema)
	fmt.Printf("PACKAGE_RULES=%d\n", k.PackageRuleCount)
	return 0
}
func runtimeState(value string) {
	if dir := os.Getenv("PMM_HOST_SESSION_DIR"); dir != "" {
		_ = os.WriteFile(filepath.Join(dir, "state.txt"), []byte(value+"\r\n"), 0644)
	}
}

func startApplication(root string) int {
	runtimeState("startup:runtime-dependency-verification")
	if _, err := ensureDependencies(root, true, false); err != nil {
		fmt.Fprintln(os.Stderr, err)
		runtimeState("startup:runtime-dependency-failed")
		return 5
	}
	runtimeState("startup:runtime-ui-dispatch")
	rc := launchUserInterface(root, false)
	if rc == 0 {
		runtimeState("startup:UI-closed-normally")
	} else {
		runtimeState("startup:UI-runtime-exit:" + strconv.Itoa(rc))
	}
	return rc
}

func has(args []string, w string) bool {
	for _, a := range args {
		if a == w {
			return true
		}
	}
	return false
}
func fail(e error) { fmt.Fprintln(os.Stderr, e); os.Exit(1) }
func usage() {
	fmt.Println("PMMRuntime.exe <start|doctor|security|dependencies|knowledge|game|hash|archive|process|ui|ui-native|self-test>")
}

var _ = json.Valid
var _ = flag.ErrHelp
var _ = strings.Compare
