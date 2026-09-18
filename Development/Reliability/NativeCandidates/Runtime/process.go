package main

import (
	"context"
	"os/exec"
	"pmm.local/supervision"
	"time"
)

type ProcessRequest struct {
	Executable       string
	Arguments        []string
	WorkingDirectory string
	Timeout          time.Duration
	Context          context.Context
	OutputLimit      int64
}
type ProcessResult struct {
	Protocol       string   `json:"protocol"`
	Executable     string   `json:"executable"`
	Arguments      []string `json:"arguments"`
	ExitCode       int      `json:"exit_code"`
	ChildExitCode  int      `json:"child_exit_code"`
	TimedOut       bool     `json:"timed_out"`
	Cancelled      bool     `json:"cancelled"`
	Stdout         string   `json:"stdout"`
	Stderr         string   `json:"stderr"`
	StartError     string   `json:"start_error,omitempty"`
	RunError       string   `json:"run_error,omitempty"`
	OutputComplete bool     `json:"output_complete"`
	DrainTimedOut  bool     `json:"drain_timed_out"`
	ChildReaped    bool     `json:"child_reaped"`
}

func runProcess(req ProcessRequest) ProcessResult {
	res := ProcessResult{Protocol: "PMM_RUNTIME_PROCESS_V1", Executable: req.Executable, Arguments: req.Arguments, ExitCode: 127, ChildExitCode: -1}
	if req.Timeout == 0 {
		req.Timeout = 5 * time.Minute
	}
	if req.OutputLimit == 0 {
		req.OutputLimit = supervision.HelperLimit
	}
	if req.Timeout < 0 || req.Timeout > MaxProcessTimeout || req.OutputLimit < 0 || req.OutputLimit > supervision.HelperLimit {
		res.ExitCode = 64
		res.RunError = "invalid helper timeout or output limit"
		return res
	}
	parent := req.Context
	if parent == nil {
		parent = context.Background()
	}
	ctx, cancel := context.WithTimeout(parent, req.Timeout)
	defer cancel()
	cmd := exec.Command(req.Executable, req.Arguments...)
	cmd.Dir = req.WorkingDirectory
	configureProcess(cmd)
	r := supervision.Run(ctx, cmd, supervision.Options{
		Stdout: supervision.Output{Limit: req.OutputLimit}, Stderr: supervision.Output{Limit: req.OutputLimit}})
	res.ExitCode = r.ExitCode
	res.ChildExitCode = r.ChildExitCode
	res.Stdout = r.Stdout.Text
	res.Stderr = r.Stderr.Text
	res.TimedOut = r.TimedOut
	res.Cancelled = r.Cancelled
	res.OutputComplete = r.OutputComplete
	res.DrainTimedOut = r.DrainTimedOut
	res.ChildReaped = r.ChildReaped
	res.RunError = r.Error
	if !r.Started {
		res.StartError = r.Error
	}
	return res
}
