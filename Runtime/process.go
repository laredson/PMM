package main

import (
	"bytes"
	"context"
	"os/exec"
	"time"
)

type ProcessRequest struct {
	Executable       string
	Arguments        []string
	WorkingDirectory string
	Timeout          time.Duration
}

type ProcessResult struct {
	Protocol   string   `json:"protocol"`
	Executable string   `json:"executable"`
	Arguments  []string `json:"arguments"`
	ExitCode   int      `json:"exit_code"`
	TimedOut   bool     `json:"timed_out"`
	Stdout     string   `json:"stdout"`
	Stderr     string   `json:"stderr"`
	StartError string   `json:"start_error,omitempty"`
}

func runProcess(req ProcessRequest) ProcessResult {
	if req.Timeout <= 0 {
		req.Timeout = 5 * time.Minute
	}
	ctx, cancel := context.WithTimeout(context.Background(), req.Timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, req.Executable, req.Arguments...)
	if req.WorkingDirectory != "" {
		cmd.Dir = req.WorkingDirectory
	}
	configureProcess(cmd)
	var out, errOut bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &errOut
	res := ProcessResult{Protocol: "PMM_RUNTIME_PROCESS_V1", Executable: req.Executable, Arguments: req.Arguments, ExitCode: -1}
	err := cmd.Run()
	res.Stdout = out.String()
	res.Stderr = errOut.String()
	if ctx.Err() == context.DeadlineExceeded {
		res.TimedOut = true
		res.ExitCode = 124
		return res
	}
	if err == nil {
		res.ExitCode = 0
		return res
	}
	if ee, ok := err.(*exec.ExitError); ok {
		res.ExitCode = ee.ExitCode()
		return res
	}
	res.StartError = err.Error()
	res.ExitCode = 127
	return res
}
