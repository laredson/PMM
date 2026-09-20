package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/signal"

	corer1 "pmm/reliability/corer1"
)

func main() {
	flags := flag.NewFlagSet("CoreR1-candidate", flag.ContinueOnError)
	flags.SetOutput(os.Stderr)
	job := flags.String("job", "", "absolute path to a pinned PMM_R1_CANDIDATE_JOB_V2 document")
	hash := flags.String("job-sha256", "", "lowercase SHA-256 of the exact job bytes")
	size := flags.Int64("job-bytes", 0, "exact job byte count")
	if len(os.Args) < 2 || os.Args[1] != "run" {
		fmt.Fprintln(os.Stderr, "usage: CoreR1-candidate.exe run --job <absolute> --job-sha256 <hex> --job-bytes <n>")
		os.Exit(2)
	}
	if err := flags.Parse(os.Args[2:]); err != nil || flags.NArg() != 0 || *job == "" || *hash == "" || *size <= 0 {
		if err == nil {
			fmt.Fprintln(os.Stderr, "invalid or incomplete candidate-only arguments")
		}
		os.Exit(2)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	result, runErr := corer1.RunCandidateJobFileV2(ctx, *job, *hash, *size)
	encoded, jsonErr := json.MarshalIndent(result, "", "  ")
	if jsonErr != nil {
		fmt.Fprintln(os.Stderr, "cannot encode candidate result:", jsonErr)
		os.Exit(4)
	}
	fmt.Println(string(encoded))
	if runErr != nil {
		os.Exit(3)
	}
}
