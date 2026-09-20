package corer1

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestCandidateRunSuccessAndReinspection(t *testing.T) {
	for i, v := range executorVectors(t) {
		t.Run(v.ID, func(t *testing.T) {
			_, c, m, x, _ := executorFixture(t, i)
			_, q := publicationFixture(t)
			result, e := ExecuteAndPublishCandidate(context.Background(), c, m, x, q)
			if e != nil || result == nil || result.State != CandidatePublished || result.Receipt == nil || result.ResidueName != "" {
				t.Fatal(result, e)
			}
			if !result.Receipt.Published || result.Receipt.GameAccepted || result.Receipt.Installed || result.Receipt.CrashDurabilityGuaranteed {
				t.Fatal(result.Receipt)
			}
			if _, e := InspectCandidate(context.Background(), filepath.Join(q.Parent, result.Receipt.CandidateName), result.Receipt.ManifestSHA256); e != nil {
				t.Fatal(e)
			}
		})
	}
}

func TestCandidateRunExecutionRejectionNeverPublishes(t *testing.T) {
	_, c, m, x, _ := executorFixture(t, 0)
	_, q := publicationFixture(t)
	for _, mode := range []string{"nil-context", "cancelled", "missing-evidence", "bad-pin"} {
		t.Run(mode, func(t *testing.T) {
			ctx := context.Background()
			capture := c
			request := x
			switch mode {
			case "nil-context":
				ctx = nil
			case "cancelled":
				var cancel context.CancelFunc
				ctx, cancel = context.WithCancel(ctx)
				cancel()
			case "missing-evidence":
				capture = nil
			case "bad-pin":
				request.Plan.SHA256 = ""
			}
			result, e := ExecuteAndPublishCandidate(ctx, capture, m, request, q)
			if e == nil || result == nil || result.State != CandidateExecutionRejected || result.Receipt != nil || result.ResidueName != "" {
				t.Fatal(result, e)
			}
			emptyCandidateParent(t, q.Parent)
		})
	}
}

func TestCandidateRunPublicationRejection(t *testing.T) {
	_, c, m, x, _ := executorFixture(t, 0)
	_, q := publicationFixture(t)
	q.Parent = q.GameRoot
	result, e := ExecuteAndPublishCandidate(context.Background(), c, m, x, q)
	if e == nil || result == nil || result.State != CandidatePublicationRejected || result.Receipt != nil || result.ResidueName != "" {
		t.Fatal(result, e)
	}
	emptyCandidateParent(t, q.Parent)
}

func TestCandidateRunKeepsCommittedReceiptOnError(t *testing.T) {
	for _, phase := range []string{"after-commit", "parent-sync"} {
		t.Run(phase, func(t *testing.T) {
			_, c, m, x, _ := executorFixture(t, 0)
			_, q := publicationFixture(t)
			boom := errors.New("postcommit error")
			result, e := executeAndPublishCandidate(context.Background(), c, m, x, q, publicationHooks{event: func(s string) error {
				if s == phase {
					return boom
				}
				return nil
			}})
			var pe *PublicationError
			if result == nil || result.State != CandidatePublishedWithError || result.Receipt == nil || !errors.Is(e, boom) || !errors.As(e, &pe) || !pe.Committed {
				t.Fatal(result, e)
			}
			if _, e := InspectCandidate(context.Background(), filepath.Join(q.Parent, result.Receipt.CandidateName), result.Receipt.ManifestSHA256); e != nil {
				t.Fatal(e)
			}
			entries, e := os.ReadDir(q.Parent)
			if e != nil || len(entries) != 1 {
				t.Fatal("unexpected retry", entries, e)
			}
		})
	}
}

func TestCandidateRunReportsResidueWithoutRetry(t *testing.T) {
	_, c, m, x, _ := executorFixture(t, 0)
	_, q := publicationFixture(t)
	boom := errors.New("rollback failure")
	result, e := executeAndPublishCandidate(context.Background(), c, m, x, q, publicationHooks{event: func(s string) error {
		if s == "before-commit" || s == "cleanup:candidate.pak" {
			return boom
		}
		return nil
	}})
	var pe *PublicationError
	if result == nil || result.State != CandidatePublicationResidue || result.Receipt != nil || !errors.Is(e, boom) || !errors.As(e, &pe) || result.ResidueName == "" || result.ResidueName != pe.ResidueName || pe.Committed {
		t.Fatal(result, e)
	}
	entries, e := os.ReadDir(q.Parent)
	if e != nil || len(entries) != 1 {
		t.Fatal("unexpected retry", entries, e)
	}
}

func TestCandidateRunCancellationAtCommitBoundary(t *testing.T) {
	for _, phase := range []string{"sealed-before-commit", "after-commit"} {
		t.Run(phase, func(t *testing.T) {
			_, c, m, x, _ := executorFixture(t, 0)
			_, q := publicationFixture(t)
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			result, e := executeAndPublishCandidate(ctx, c, m, x, q, publicationHooks{event: func(s string) error {
				if s == phase {
					cancel()
				}
				return nil
			}})
			if phase == "after-commit" {
				if e != nil || result.State != CandidatePublished || result.Receipt == nil {
					t.Fatal(result, e)
				}
			} else {
				if !errors.Is(e, context.Canceled) || result.State != CandidatePublicationRejected || result.Receipt != nil || result.ResidueName != "" {
					t.Fatal(result, e)
				}
				emptyCandidateParent(t, q.Parent)
			}
		})
	}
}
