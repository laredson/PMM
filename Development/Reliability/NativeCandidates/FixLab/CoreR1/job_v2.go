package corer1

import (
	"context"
	"errors"
	"path/filepath"
	"strings"
)

const CandidateJobSchemaV2 = "PMM_R1_CANDIDATE_JOB_V2"
const CandidateJobOperationV2 = "EXECUTE_AND_PUBLISH_CANDIDATE_ONLY"

type CandidateJobDocumentsV2 struct {
	Recipe             File   `json:"recipe"`
	DonorInventory     File   `json:"donorInventory"`
	CurrentInventory   File   `json:"currentInventory"`
	SchemaClaims       []File `json:"schemaClaims"`
	CurrentProviderSet File   `json:"currentProviderSet"`
	ExecutionPlan      File   `json:"executionPlan"`
	ExecutionReview    File   `json:"executionReview"`
}

type CandidateJobRootsV2 struct {
	Donor    string `json:"donor"`
	Current  string `json:"current"`
	Archives string `json:"archives"`
	Schemas  string `json:"schemas"`
}

type CandidateJobDossierV2 struct {
	ClaimSHA256 string `json:"claimSHA256"`
	Layout      File   `json:"layout"`
	Review      File   `json:"review"`
}

type CandidateJobPlanLimitsV2 struct {
	RecipeBytes    int `json:"recipeBytes"`
	InventoryBytes int `json:"inventoryBytes"`
	ClaimBytes     int `json:"claimBytes"`
	Files          int `json:"files"`
	Outputs        int `json:"outputs"`
	Claims         int `json:"claims"`
}

type CandidateJobCaptureLimitsV2 struct {
	FileBytes         int64 `json:"fileBytes"`
	SnapshotBytes     int64 `json:"snapshotBytes"`
	ArchiveBytes      int64 `json:"archiveBytes"`
	TotalArchiveBytes int64 `json:"totalArchiveBytes"`
	Providers         int   `json:"providers"`
}

type CandidateJobMembershipLimitsV2 struct {
	ArchiveBytes      int64 `json:"archiveBytes"`
	TotalArchiveBytes int64 `json:"totalArchiveBytes"`
	Providers         int   `json:"providers"`
}

type CandidateJobExecutionLimitsV2 struct {
	DocumentBytes  int   `json:"documentBytes"`
	Families       int   `json:"families"`
	Outputs        int   `json:"outputs"`
	EditsPerFamily int   `json:"editsPerFamily"`
	SnapshotBytes  int64 `json:"snapshotBytes"`
	OutputBytes    int64 `json:"outputBytes"`
}

type CandidateJobPublicationV2 struct {
	Parent         string `json:"parent"`
	RepositoryRoot string `json:"repositoryRoot"`
	GameRoot       string `json:"gameRoot"`
	WorkspaceRoot  string `json:"workspaceRoot"`
	MaxBundleBytes int64  `json:"maxBundleBytes"`
}

// CandidateJobV2 contains only explicit paths, pins and ceilings. It cannot
// request installation or deployment. CandidateOnly must be true and both
// negative capability flags must be false.
type CandidateJobV2 struct {
	Schema            string                         `json:"schema"`
	Operation         string                         `json:"operation"`
	CandidateOnly     bool                           `json:"candidateOnly"`
	InstallRequested  bool                           `json:"installRequested"`
	DeployRequested   bool                           `json:"deployRequested"`
	DocumentRoot      string                         `json:"documentRoot"`
	Documents         CandidateJobDocumentsV2        `json:"documents"`
	Roots             CandidateJobRootsV2            `json:"roots"`
	DonorArchive      File                           `json:"donorArchive"`
	Dossiers          []CandidateJobDossierV2        `json:"dossiers"`
	PlanLimits        CandidateJobPlanLimitsV2       `json:"planLimits"`
	CaptureLimits     CandidateJobCaptureLimitsV2    `json:"captureLimits"`
	MembershipProfile string                         `json:"membershipProfile"`
	CurrentOwnership  string                         `json:"currentOwnership"`
	MembershipLimits  CandidateJobMembershipLimitsV2 `json:"membershipLimits"`
	ExecutionLimits   CandidateJobExecutionLimitsV2  `json:"executionLimits"`
	Publication       CandidateJobPublicationV2      `json:"publication"`
}

type CandidateJobErrorV2 struct {
	Code   string `json:"code"`
	Detail string `json:"detail"`
}

type CandidateJobResultV2 struct {
	Schema        string               `json:"schema"`
	State         CandidateRunState    `json:"state"`
	CandidateOnly bool                 `json:"candidateOnly"`
	Receipt       *PublicationReceipt  `json:"receipt,omitempty"`
	ResidueName   string               `json:"residueName,omitempty"`
	Error         *CandidateJobErrorV2 `json:"error,omitempty"`
}

type candidateJobDocuments struct {
	recipe, donor, current, providers, execution, review PinnedJSON
	claims                                               []PinnedJSON
}

func candidateJobError(err error) *CandidateJobErrorV2 {
	if err == nil {
		return nil
	}
	var core *Error
	if errors.As(err, &core) {
		return &CandidateJobErrorV2{Code: core.Code, Detail: core.Subject + ": " + core.Detail}
	}
	if errors.Is(err, context.Canceled) {
		return &CandidateJobErrorV2{Code: "CANCELLED", Detail: "candidate job cancelled"}
	}
	var publication *PublicationError
	if errors.As(err, &publication) {
		return &CandidateJobErrorV2{Code: "PUBLICATION", Detail: publication.Error()}
	}
	return &CandidateJobErrorV2{Code: "IO", Detail: err.Error()}
}

func rejectedCandidateJob(err error) (*CandidateJobResultV2, error) {
	return &CandidateJobResultV2{Schema: "PMM_R1_CANDIDATE_JOB_RESULT_V2", State: CandidateJobRejected, CandidateOnly: true, Error: candidateJobError(err)}, err
}

func loadCandidateJobDocuments(ctx context.Context, job CandidateJobV2) (_ candidateJobDocuments, err error) {
	var out candidateJobDocuments
	root, err := openRoot(job.DocumentRoot)
	if err != nil {
		return out, err
	}
	defer func() { err = errors.Join(err, root.Close()) }()
	type wanted struct {
		subject string
		file    File
		limit   int64
		target  *PinnedJSON
	}
	claims := make([]PinnedJSON, len(job.Documents.SchemaClaims))
	all := []wanted{
		{"recipe", job.Documents.Recipe, 256 << 10, &out.recipe},
		{"donor inventory", job.Documents.DonorInventory, 8 << 20, &out.donor},
		{"current inventory", job.Documents.CurrentInventory, 8 << 20, &out.current},
		{"provider set", job.Documents.CurrentProviderSet, 128 << 10, &out.providers},
		{"execution plan", job.Documents.ExecutionPlan, 2 << 20, &out.execution},
		{"execution review", job.Documents.ExecutionReview, 2 << 20, &out.review},
	}
	for i := range job.Documents.SchemaClaims {
		all = append(all, wanted{"schema claim", job.Documents.SchemaClaims[i], 16 << 10, &claims[i]})
	}
	used, paths := map[string]string{}, map[string]bool{}
	var total int64
	for _, item := range all {
		if !strings.HasSuffix(item.file.Path, ".json") || item.file.SizeBytes <= 0 || item.file.SizeBytes > item.limit || item.file.SizeBytes > (24<<20)-total {
			return out, fail("LIMIT", item.subject, "bounded JSON descriptor required")
		}
		if err = addPath(used, paths, item.file.Path); err != nil {
			return out, err
		}
		data, readErr := captureFile(ctx, root, item.file, true, item.limit, nil)
		if readErr != nil {
			return out, readErr
		}
		total += item.file.SizeBytes
		*item.target = PinnedJSON{Data: data, SHA256: item.file.SHA256}
	}
	out.claims = claims
	return out, nil
}

// RunCandidateJobV2 rebuilds all private evidence in one process and performs
// exactly one candidate publication attempt. Serialized reports are outputs,
// never imported as CapturedInputs, MembershipEvidence or MemoryResult.
func RunCandidateJobV2(ctx context.Context, input PinnedJSON) (*CandidateJobResultV2, error) {
	if ctx == nil {
		return rejectedCandidateJob(fail("CONTEXT", "candidate job", "nil"))
	}
	var job CandidateJobV2
	if err := decode(ctx, input, 512<<10, "candidate job", &job); err != nil {
		return rejectedCandidateJob(err)
	}
	if job.Schema != CandidateJobSchemaV2 || job.Operation != CandidateJobOperationV2 || !job.CandidateOnly || job.InstallRequested || job.DeployRequested {
		return rejectedCandidateJob(fail("POLICY", "candidate job", "candidate-only operation and negative install/deploy flags required"))
	}
	documents, err := loadCandidateJobDocuments(ctx, job)
	if err != nil {
		return rejectedCandidateJob(err)
	}
	planLimits := Limits{job.PlanLimits.RecipeBytes, job.PlanLimits.InventoryBytes, job.PlanLimits.ClaimBytes, job.PlanLimits.Files, job.PlanLimits.Outputs, job.PlanLimits.Claims}
	roots := CaptureRoots{job.Roots.Donor, job.Roots.Current, job.Roots.Archives, job.Roots.Schemas}
	dossiers := make([]DossierFiles, len(job.Dossiers))
	for i, dossier := range job.Dossiers {
		dossiers[i] = DossierFiles{dossier.ClaimSHA256, dossier.Layout, dossier.Review}
	}
	capture, err := CaptureCore(ctx, CaptureRequest{
		Plan:  Request{Recipe: documents.recipe, DonorInventory: documents.donor, CurrentInventory: documents.current, SchemaClaims: documents.claims, Limits: planLimits},
		Roots: roots, DonorArchive: job.DonorArchive, CurrentProviderSet: documents.providers, Dossiers: dossiers,
		Limits: CaptureLimits{job.CaptureLimits.FileBytes, job.CaptureLimits.SnapshotBytes, job.CaptureLimits.ArchiveBytes, job.CaptureLimits.TotalArchiveBytes, job.CaptureLimits.Providers},
	})
	if err != nil {
		return rejectedCandidateJob(err)
	}
	membership, err := VerifyMembership(ctx, capture, MembershipRequest{
		ArchivesRoot: roots.Archives, DonorArchive: job.DonorArchive, CurrentProviderSet: documents.providers,
		Profile: job.MembershipProfile, CurrentOwnership: job.CurrentOwnership,
		Limits: MembershipLimits{job.MembershipLimits.ArchiveBytes, job.MembershipLimits.TotalArchiveBytes, job.MembershipLimits.Providers},
	})
	if err != nil {
		return rejectedCandidateJob(err)
	}
	execution := ExecutionRequest{Plan: documents.execution, Review: documents.review, Limits: ExecutionLimits{
		job.ExecutionLimits.DocumentBytes, job.ExecutionLimits.Families, job.ExecutionLimits.Outputs, job.ExecutionLimits.EditsPerFamily,
		job.ExecutionLimits.SnapshotBytes, job.ExecutionLimits.OutputBytes,
	}}
	publication := PublicationRequest{job.Publication.Parent, job.Publication.RepositoryRoot, job.Publication.GameRoot, job.Publication.WorkspaceRoot, job.Publication.MaxBundleBytes}
	run, err := ExecuteAndPublishCandidate(ctx, capture, membership, execution, publication)
	result := &CandidateJobResultV2{Schema: "PMM_R1_CANDIDATE_JOB_RESULT_V2", State: run.State, CandidateOnly: true, Receipt: run.Receipt, ResidueName: run.ResidueName, Error: candidateJobError(err)}
	return result, err
}

// RunCandidateJobFileV2 reads one exact, pinned job through the anchored local
// filesystem adapter. The size is caller supplied to prevent unbounded reads.
func RunCandidateJobFileV2(ctx context.Context, path, sha256 string, size int64) (*CandidateJobResultV2, error) {
	if ctx == nil {
		return rejectedCandidateJob(fail("CONTEXT", "candidate job file", "nil"))
	}
	if err := cleanAbsolute(path); err != nil {
		return rejectedCandidateJob(err)
	}
	parent, leaf := filepath.Split(path)
	leaf = strings.TrimSuffix(leaf, string(filepath.Separator))
	if leaf == "" || size <= 0 || size > 512<<10 {
		return rejectedCandidateJob(fail("LIMIT", "candidate job file", "name/size"))
	}
	root, err := openRoot(filepath.Clean(parent))
	if err != nil {
		return rejectedCandidateJob(err)
	}
	data, readErr := captureFile(ctx, root, File{Path: filepath.ToSlash(leaf), SHA256: sha256, SizeBytes: size}, true, 512<<10, nil)
	closeErr := root.Close()
	if err = errors.Join(readErr, closeErr); err != nil {
		return rejectedCandidateJob(err)
	}
	return RunCandidateJobV2(ctx, PinnedJSON{Data: data, SHA256: sha256})
}
