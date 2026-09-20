package corer1

import (
	"context"
	"errors"
)

// CandidateRunState is a UI/reporting distinction, never permission to install,
// retry, delete residue or import serialized evidence as executable input.
type CandidateRunState string

const (
	CandidateExecutionRejected   CandidateRunState = "EXECUTION_REJECTED"
	CandidatePublicationRejected CandidateRunState = "PUBLICATION_REJECTED"
	CandidatePublicationResidue  CandidateRunState = "PUBLICATION_REJECTED_WITH_POSSIBLE_RESIDUE"
	CandidatePublished           CandidateRunState = "CANDIDATE_PUBLISHED_NOT_GAME_ACCEPTED"
	CandidatePublishedWithError  CandidateRunState = "CANDIDATE_PUBLISHED_REQUIRES_ATTENTION"
)

type CandidateRunResult struct {
	State       CandidateRunState   `json:"state"`
	Receipt     *PublicationReceipt `json:"receipt,omitempty"`
	ResidueName string              `json:"residueName,omitempty"`
}

// ExecuteAndPublishCandidate executes the existing bounded profile and publishes
// ONCE in a caller-controlled isolated directory. It does not discover schemas,
// capture inputs, authenticate reviews, install anything or retry failures.
// The result is always non-nil. Callers MUST inspect it even when err != nil:
// a PublishedWithError result preserves the committed receipt.
func ExecuteAndPublishCandidate(ctx context.Context, capture *CapturedInputs, membership *MembershipEvidence, execution ExecutionRequest, publication PublicationRequest) (*CandidateRunResult, error) {
	return executeAndPublishCandidate(ctx, capture, membership, execution, publication, publicationHooks{})
}

func executeAndPublishCandidate(ctx context.Context, capture *CapturedInputs, membership *MembershipEvidence, execution ExecutionRequest, publication PublicationRequest, hooks publicationHooks) (*CandidateRunResult, error) {
	memory, err := ExecuteBounded(ctx, capture, membership, execution)
	if err != nil {
		return &CandidateRunResult{State: CandidateExecutionRejected}, err
	}
	receipt, err := publishCandidate(ctx, memory, publication, hooks)
	result := &CandidateRunResult{State: CandidatePublicationRejected, Receipt: receipt}
	if receipt != nil {
		result.State = CandidatePublished
		if err != nil {
			result.State = CandidatePublishedWithError
		}
		return result, err
	}
	var pe *PublicationError
	if errors.As(err, &pe) && pe.ResidueName != "" {
		result.State = CandidatePublicationResidue
		result.ResidueName = pe.ResidueName
	}
	return result, err
}
