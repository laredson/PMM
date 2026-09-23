//go:build windows

package main

import (
	"os"

	"pmm.local/pmm/internal/dispatch"
	"pmm.local/pmm/internal/host"
	pmmruntime "pmm.local/pmm/internal/runtime"
)

func main() {
	role, args := dispatch.Route(os.Args[1:])
	if role == dispatch.Runtime {
		os.Args = append([]string{os.Args[0]}, args...)
		pmmruntime.Main()
		return
	}
	host.Main()
}
