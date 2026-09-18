//go:build !windows

package main

import "fmt"

func launchNativeUIShell(root string, sec SecurityStatus) int {
	fmt.Println("PMM native UI shell is available only on Windows.")
	return 31
}
