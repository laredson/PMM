package main

import (
	"fmt"
	"strconv"
	"time"
)

const MaxProcessTimeout = 24 * time.Hour

// Seconds are positive decimal integers, at most 86400. Validate BEFORE duration
// multiplication. Duplicate/unknown flags and missing values are errors (64).
func parseProcessRequest(args []string) (ProcessRequest, error) {
	req := ProcessRequest{Timeout: 5 * time.Minute}
	seen := map[string]bool{}
	for i := 0; i < len(args); {
		a := args[i]
		if a == "--" {
			if i+1 == len(args) || args[i+1] == "" {
				return req, fmt.Errorf("process run requires -- <executable> [args]")
			}
			req.Executable = args[i+1]
			req.Arguments = append([]string(nil), args[i+2:]...)
			return req, nil
		}
		if (a != "--timeout-sec" && a != "--cwd") || seen[a] || i+1 >= len(args) {
			return req, fmt.Errorf("invalid, repeated or incomplete process option %q", a)
		}
		seen[a] = true
		value := args[i+1]
		if a == "--cwd" {
			if value == "" || value == "--" {
				return req, fmt.Errorf("--cwd requires a directory")
			}
			req.WorkingDirectory = value
		} else {
			if value == "" {
				return req, fmt.Errorf("--timeout-sec requires seconds")
			}
			for _, r := range value {
				if r < '0' || r > '9' {
					return req, fmt.Errorf("--timeout-sec requires positive decimal seconds")
				}
			}
			n, e := strconv.ParseUint(value, 10, 64)
			if e != nil || n == 0 || n > uint64(MaxProcessTimeout/time.Second) {
				return req, fmt.Errorf("--timeout-sec must be in 1..86400")
			}
			req.Timeout = time.Duration(n) * time.Second
		}
		i += 2
	}
	return req, fmt.Errorf("process run requires -- <executable> [args]")
}
