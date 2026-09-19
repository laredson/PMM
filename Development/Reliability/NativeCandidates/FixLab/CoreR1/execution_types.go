package corer1

import uasset "pmm.local/fixlab/uasset"

const ExecutionProfile = "SAME_WIDTH_NAMES_SCALAR_POSTPROCESS_PAKV11_V1"

// This is a reviewed, hash-bound operation document, not automatic discovery of
// a mesh layout. Every family and output must be specified. The review is a
// bound declaration, NOT authenticated approval; the caller owns its trust.
type ExecutionPlan struct {
	Schema           string            `json:"schema"`
	Profile          string            `json:"profile"`
	RecipeSHA256     string            `json:"recipeSHA256"`
	PlanSHA256       string            `json:"planSHA256"`
	CaptureSHA256    string            `json:"captureSHA256"`
	MembershipSHA256 string            `json:"membershipSHA256"`
	UAssetProfile    string            `json:"uassetProfile"`
	AllowUnversioned bool              `json:"allowUnversioned"`
	Families         []ExecutionFamily `json:"families"`
	Outputs          []File            `json:"outputs"`
}
type ExecutionFamily struct {
	Group                  string                `json:"group"`
	TargetPath             string                `json:"targetPath"`
	DonorHeaderSHA256      string                `json:"donorHeaderSHA256"`
	DonorExportSHA256      string                `json:"donorExportSHA256"`
	TargetHeaderSHA256     string                `json:"targetHeaderSHA256"`
	TargetExportSHA256     string                `json:"targetExportSHA256"`
	NameEdits              []ExecutionNameEdit   `json:"nameEdits"`
	AfterNamesHeaderSHA256 string                `json:"afterNamesHeaderSHA256"`
	AfterNamesExportSHA256 string                `json:"afterNamesExportSHA256"`
	PostProcess            *ExecutionPostProcess `json:"postProcess,omitempty"`
}
type ExecutionNameEdit struct {
	Index       int    `json:"index"`
	SourcePath  string `json:"sourcePath"`
	SourceIndex int    `json:"sourceIndex"`
}

// Positions are assertions checked by the UAsset parser, never permission for
// blind byte writes. Layout bytes come ONLY from the captured linked dossier.
type ExecutionPostProcess struct {
	ClaimSHA256              string                `json:"claimSHA256"`
	ExportIndex              int                   `json:"exportIndex"`
	ExportObject             string                `json:"exportObject"`
	Stale                    uasset.ImportIdentity `json:"stale"`
	Safe                     uasset.ImportIdentity `json:"safe"`
	PreloadIndex             int                   `json:"preloadIndex"`
	DependencyGroup          int                   `json:"dependencyGroup"`
	ExpectedSerializedOffset int                   `json:"expectedSerializedOffset"`
}
type ExecutionReview struct {
	Schema              string   `json:"schema"`
	ExecutionPlanSHA256 string   `json:"executionPlanSHA256"`
	Reviewer            string   `json:"reviewer"`
	Origin              string   `json:"origin"`
	Revision            string   `json:"revision"`
	Method              string   `json:"method"`
	Findings            []string `json:"findings"`
}
type ExecutionLimits struct {
	DocumentBytes, Families, Outputs, EditsPerFamily int
	SnapshotBytes, OutputBytes                       int64
}

func (l ExecutionLimits) checked() (ExecutionLimits, error) {
	v := []*int{&l.DocumentBytes, &l.Families, &l.Outputs, &l.EditsPerFamily}
	max := []int{2 << 20, 256, 1024, 256}
	for i, p := range v {
		if *p == 0 {
			*p = max[i]
		}
		if *p < 1 || *p > max[i] {
			return l, fail("LIMIT", "execution", "ceilings may only be reduced")
		}
	}
	for _, x := range []struct {
		p   *int64
		max int64
	}{{&l.SnapshotBytes, 512 << 20}, {&l.OutputBytes, 128 << 20}} {
		if *x.p == 0 {
			*x.p = x.max
		}
		if *x.p < 1 || *x.p > x.max {
			return l, fail("LIMIT", "execution bytes", "ceilings may only be reduced")
		}
	}
	return l, nil
}

type ExecutionRequest struct {
	Plan, Review PinnedJSON
	Limits       ExecutionLimits
}
type ExecutedFamily struct {
	TargetPath  string                    `json:"targetPath"`
	Names       uasset.RewriteReport      `json:"names"`
	PostProcess *uasset.PostProcessReport `json:"postProcess,omitempty"`
}
type ExecutionReport struct {
	Schema                  string           `json:"schema"`
	Status                  string           `json:"status"`
	ExecutionPlanSHA256     string           `json:"executionPlanSHA256"`
	ReviewSHA256            string           `json:"reviewSHA256"`
	CaptureSHA256           string           `json:"captureSHA256"`
	MembershipSHA256        string           `json:"membershipSHA256"`
	RecipeSHA256            string           `json:"recipeSHA256"`
	Families                []ExecutedFamily `json:"families"`
	Outputs                 []File           `json:"outputs"`
	PAKSHA256               string           `json:"pakSHA256"`
	PAKBytes                int              `json:"pakBytes"`
	OutputPinsChecked       bool             `json:"outputPinsChecked"`
	PAKReadbackByteEqual    bool             `json:"pakReadbackByteEqual"`
	ReviewState             string           `json:"reviewState"`
	SchemaSemanticsVerified bool             `json:"schemaSemanticsVerified"`
	ReviewerAuthenticated   bool             `json:"reviewerAuthenticated"`
	CoreR1Complete          bool             `json:"coreR1Complete"`
	TransformReady          bool             `json:"transformReady"`
	BuildReady              bool             `json:"buildReady"`
	Validated               bool             `json:"validated"`
	Installed               bool             `json:"installed"`
	Blockers                []string         `json:"blockers"`
}

// MemoryResult cannot be deserialized into a verified result. Accessors copy.
// A valid in-memory PAK is NOT installed, signed or accepted by Unreal/Palworld.
type MemoryResult struct {
	files       map[string][]byte
	pak, report []byte
}

func (r *MemoryResult) Bytes(path string) ([]byte, bool) {
	if r == nil {
		return nil, false
	}
	b, ok := r.files[path]
	if !ok {
		return nil, false
	}
	return append([]byte{}, b...), true
}
func (r *MemoryResult) PAKBytes() []byte {
	if r == nil {
		return nil
	}
	return append([]byte{}, r.pak...)
}
func (r *MemoryResult) ReportJSON() []byte {
	if r == nil {
		return nil
	}
	return append([]byte{}, r.report...)
}
