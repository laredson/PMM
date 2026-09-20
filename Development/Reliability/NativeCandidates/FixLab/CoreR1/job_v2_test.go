package corer1

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func makeCandidateJob(t *testing.T, captureRequest CaptureRequest, executionRequest ExecutionRequest, publication PublicationRequest, docRoot string) PinnedJSON {
	t.Helper()
	store := func(name string, value PinnedJSON) File {
		return put(t, docRoot, name, value.Data)
	}
	claimFiles := make([]File, len(captureRequest.Plan.SchemaClaims))
	for i, claim := range captureRequest.Plan.SchemaClaims {
		claimFiles[i] = store("claims/claim-"+string(rune('a'+i))+".json", claim)
	}
	dossiers := make([]CandidateJobDossierV2, len(captureRequest.Dossiers))
	for i, dossier := range captureRequest.Dossiers {
		dossiers[i] = CandidateJobDossierV2{dossier.ClaimSHA256, dossier.Layout, dossier.Review}
	}
	membership := memberRequest(captureRequest)
	job := CandidateJobV2{
		Schema: CandidateJobSchemaV2, Operation: CandidateJobOperationV2, CandidateOnly: true,
		InstallRequested: false, DeployRequested: false, DocumentRoot: docRoot,
		Documents: CandidateJobDocumentsV2{
			Recipe: store("recipe.json", captureRequest.Plan.Recipe), DonorInventory: store("donor.json", captureRequest.Plan.DonorInventory),
			CurrentInventory: store("current.json", captureRequest.Plan.CurrentInventory), SchemaClaims: claimFiles,
			CurrentProviderSet: store("providers.json", captureRequest.CurrentProviderSet),
			ExecutionPlan:      store("execution-plan.json", executionRequest.Plan), ExecutionReview: store("execution-review.json", executionRequest.Review),
		},
		Roots:        CandidateJobRootsV2{captureRequest.Roots.Donor, captureRequest.Roots.Current, captureRequest.Roots.Archives, captureRequest.Roots.Schemas},
		DonorArchive: captureRequest.DonorArchive, Dossiers: dossiers,
		MembershipProfile: membership.Profile, CurrentOwnership: membership.CurrentOwnership,
		Publication: CandidateJobPublicationV2{publication.Parent, publication.RepositoryRoot, publication.GameRoot, publication.WorkspaceRoot, publication.MaxBundleBytes},
	}
	return pinned(job)
}

func candidateJobFixture(t *testing.T, id int) (PinnedJSON, PublicationRequest) {
	t.Helper()
	captureRequest, _, _, executionRequest, _ := executorFixture(t, id)
	_, publication := publicationFixture(t)
	return makeCandidateJob(t, captureRequest, executionRequest, publication, t.TempDir()), publication
}

func TestCandidateJobV2PublishesAndReinspects(t *testing.T) {
	for i := range executorVectors(t) {
		t.Run(executorVectors(t)[i].ID, func(t *testing.T) {
			job, publication := candidateJobFixture(t, i)
			result, err := RunCandidateJobV2(context.Background(), job)
			if err != nil || result.State != CandidatePublished || result.Error != nil || result.Receipt == nil || !result.CandidateOnly {
				t.Fatal(result, err)
			}
			if result.Receipt.Installed || result.Receipt.GameAccepted {
				t.Fatal("candidate job escalated acceptance", result.Receipt)
			}
			if _, err = InspectCandidate(context.Background(), filepath.Join(publication.Parent, result.Receipt.CandidateName), result.Receipt.ManifestSHA256); err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestCandidateJobV2RejectsCapabilityEscalation(t *testing.T) {
	for _, change := range []func(*CandidateJobV2){
		func(j *CandidateJobV2) { j.CandidateOnly = false },
		func(j *CandidateJobV2) { j.InstallRequested = true },
		func(j *CandidateJobV2) { j.DeployRequested = true },
		func(j *CandidateJobV2) { j.Operation = "INSTALL" },
	} {
		job, publication := candidateJobFixture(t, 0)
		var value CandidateJobV2
		if err := json.Unmarshal(job.Data, &value); err != nil {
			t.Fatal(err)
		}
		change(&value)
		result, err := RunCandidateJobV2(context.Background(), pinned(value))
		if err == nil || result.State != CandidateJobRejected || result.Error == nil || result.Error.Code != "POLICY" {
			t.Fatal(result, err)
		}
		emptyCandidateParent(t, publication.Parent)
	}
}

func TestCandidateJobV2RejectsChangedDocumentsBeforeCapture(t *testing.T) {
	job, publication := candidateJobFixture(t, 0)
	var value CandidateJobV2
	if err := json.Unmarshal(job.Data, &value); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(value.DocumentRoot, value.Documents.Recipe.Path), []byte("{}"), 0600); err != nil {
		t.Fatal(err)
	}
	result, err := RunCandidateJobV2(context.Background(), pinned(value))
	if err == nil || result.State != CandidateJobRejected || result.Error == nil {
		t.Fatal(result, err)
	}
	emptyCandidateParent(t, publication.Parent)
}

func TestCandidateJobV2RejectsUnknownImportedEvidence(t *testing.T) {
	job, publication := candidateJobFixture(t, 0)
	var value map[string]any
	if err := json.Unmarshal(job.Data, &value); err != nil {
		t.Fatal(err)
	}
	value["capturedInputs"] = map[string]any{"report": "caller-controlled"}
	result, err := RunCandidateJobV2(context.Background(), pinned(value))
	if err == nil || result.State != CandidateJobRejected || result.Error == nil || result.Error.Code != "JSON" {
		t.Fatal(result, err)
	}
	emptyCandidateParent(t, publication.Parent)
}

func TestCandidateJobV2PublicationPolicyStillApplies(t *testing.T) {
	job, publication := candidateJobFixture(t, 0)
	var value CandidateJobV2
	if err := json.Unmarshal(job.Data, &value); err != nil {
		t.Fatal(err)
	}
	value.Publication.Parent = value.Publication.GameRoot
	result, err := RunCandidateJobV2(context.Background(), pinned(value))
	if err == nil || result.State != CandidatePublicationRejected || result.Receipt != nil || result.Error == nil {
		t.Fatal(result, err)
	}
	emptyCandidateParent(t, publication.Parent)
}

func TestCandidateJobV2CancellationFailsClosed(t *testing.T) {
	job, publication := candidateJobFixture(t, 0)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	result, err := RunCandidateJobV2(ctx, job)
	if err == nil || result.State != CandidateJobRejected || result.Error == nil || result.Error.Code != "CANCELLED" {
		t.Fatal(result, err)
	}
	emptyCandidateParent(t, publication.Parent)
}

func TestCandidateJobFileV2RequiresExactExternalPin(t *testing.T) {
	job, publication := candidateJobFixture(t, 0)
	root := t.TempDir()
	path := filepath.Join(root, "job.json")
	if err := os.WriteFile(path, job.Data, 0600); err != nil {
		t.Fatal(err)
	}
	result, err := RunCandidateJobFileV2(context.Background(), path, job.SHA256, int64(len(job.Data)))
	if err != nil || result.State != CandidatePublished || result.Receipt == nil {
		t.Fatal(result, err)
	}
	wrong := "0" + job.SHA256[1:]
	if job.SHA256[0] == '0' {
		wrong = "1" + job.SHA256[1:]
	}
	if _, err = RunCandidateJobFileV2(context.Background(), path, wrong, int64(len(job.Data))); err == nil {
		t.Fatal("changed external pin accepted")
	}
	entries, err := os.ReadDir(publication.Parent)
	if err != nil || len(entries) != 1 {
		t.Fatal(entries, err)
	}
}

func TestCandidateJobV2FixtureExport(t *testing.T) {
	output := os.Getenv("PMM_R1_JOB_V2_OUTPUT")
	if output == "" {
		t.Skip("opt-in candidate job fixture")
	}
	if _, err := os.Stat(output); !os.IsNotExist(err) {
		t.Fatal("output must not exist")
	}
	captureRequest, _, _, executionRequest, _ := executorFixture(t, 0)
	if err := os.Mkdir(output, 0700); err != nil {
		t.Fatal(err)
	}
	inputs := filepath.Join(output, "inputs")
	for name, source := range map[string]string{
		"donor": captureRequest.Roots.Donor, "current": captureRequest.Roots.Current,
		"archives": captureRequest.Roots.Archives, "schemas": captureRequest.Roots.Schemas,
	} {
		destination := filepath.Join(inputs, name)
		if err := os.CopyFS(destination, os.DirFS(source)); err != nil {
			t.Fatal(err)
		}
		switch name {
		case "donor":
			captureRequest.Roots.Donor = destination
		case "current":
			captureRequest.Roots.Current = destination
		case "archives":
			captureRequest.Roots.Archives = destination
		case "schemas":
			captureRequest.Roots.Schemas = destination
		}
	}
	protected := filepath.Join(output, "protected")
	for _, name := range []string{"repository", "game", "workspace"} {
		if err := os.MkdirAll(filepath.Join(protected, name), 0700); err != nil {
			t.Fatal(err)
		}
	}
	candidates := filepath.Join(output, "candidates")
	if err := os.Mkdir(candidates, 0700); err != nil {
		t.Fatal(err)
	}
	publication := PublicationRequest{
		Parent: candidates, RepositoryRoot: filepath.Join(protected, "repository"),
		GameRoot: filepath.Join(protected, "game"), WorkspaceRoot: filepath.Join(protected, "workspace"),
	}
	documents := filepath.Join(output, "documents")
	if err := os.Mkdir(documents, 0700); err != nil {
		t.Fatal(err)
	}
	job := makeCandidateJob(t, captureRequest, executionRequest, publication, documents)
	jobPath := filepath.Join(output, "job.json")
	if err := os.WriteFile(jobPath, job.Data, 0600); err != nil {
		t.Fatal(err)
	}
	result, err := RunCandidateJobFileV2(context.Background(), jobPath, job.SHA256, int64(len(job.Data)))
	if err != nil || result.State != CandidatePublished || result.Receipt == nil {
		t.Fatal(result, err)
	}
	resultJSON, err := candidateJSON(result)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(output, "result.json"), resultJSON, 0600); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(filepath.Join(output, "job.sha256"), []byte(job.SHA256+"\n"), 0600); err != nil {
		t.Fatal(err)
	}
}
