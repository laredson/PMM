//go:build !windows

package main

import "os/exec"

func configureProcess(cmd *exec.Cmd) {}

func configureUIProcess(cmd *exec.Cmd) {}
