// Package corer1 separates declarative planning from explicit read-only capture.
// PlanCore never reads assets; CaptureCore verifies snapshots. Neither runs repairs.
package corer1

import "fmt"

// PinnedJSON requires an externally supplied hash. Matching it proves identity,
// NOT authenticity of the document or truth of the file metadata it contains.
type PinnedJSON struct {
	Data   []byte
	SHA256 string
}

type Request struct {
	Recipe, DonorInventory, CurrentInventory PinnedJSON
	SchemaClaims                             []PinnedJSON
	Limits                                   Limits
}

// Zero values select ceilings; nonzero values may only reduce them.
type Limits struct {
	RecipeBytes, InventoryBytes, ClaimBytes int
	Files, Outputs, Claims                  int
}

var ceilings = Limits{256 << 10, 8 << 20, 16 << 10, 16384, 16384, 64}

func (l Limits) checked() (Limits, error) {
	x, max := []*int{&l.RecipeBytes, &l.InventoryBytes, &l.ClaimBytes, &l.Files, &l.Outputs, &l.Claims}, []int{ceilings.RecipeBytes, ceilings.InventoryBytes, ceilings.ClaimBytes, ceilings.Files, ceilings.Outputs, ceilings.Claims}
	for i, p := range x {
		if *p == 0 {
			*p = max[i]
		}
		if *p < 1 || *p > max[i] {
			return l, fail("LIMIT", "request", "limits can only be reduced")
		}
	}
	return l, nil
}

type Error struct{ Code, Subject, Detail string }

func (e *Error) Error() string                { return fmt.Sprintf("%s: %s: %s", e.Code, e.Subject, e.Detail) }
func fail(code, subject, detail string) error { return &Error{code, subject, detail} }

type File struct {
	Path      string `json:"path"`
	SHA256    string `json:"sha256"`
	SizeBytes int64  `json:"sizeBytes"`
}

type Inventory struct {
	Schema         string `json:"schema"`
	Role           string `json:"role"`
	ProviderSHA256 string `json:"providerSHA256"`
	Build          string `json:"build"`
	Files          []File `json:"files"`
}

type Signature struct {
	Name   string `json:"name"`
	SHA256 string `json:"sha256"`
	Role   string `json:"role"`
}
type Support struct {
	Roots    []string `json:"includeRoots"`
	Files    []string `json:"includeFiles"`
	Excludes []string `json:"excludeRegex"`
}
type PostProcess struct {
	StaleClass                string  `json:"staleClass"`
	SafeClass                 string  `json:"safeClass"`
	ExpectedSerializedOffsets []int64 `json:"expectedSerializedOffsets"`
}
type Relocate struct {
	Name               string       `json:"name"`
	DonorUasset        string       `json:"donorUasset"`
	TargetRegex        string       `json:"targetRegex"`
	PostProcess        *PostProcess `json:"postProcess,omitempty"`
	MinimumCount       int          `json:"minimumCount"`
	KnownBaselineCount int          `json:"knownBaselineCount"`
}
type Recipe struct {
	Schema       string      `json:"schema"`
	ID           string      `json:"id"`
	Name         string      `json:"name"`
	Version      int         `json:"version"`
	Status       string      `json:"status"`
	TargetBuild  string      `json:"targetBuild"`
	Signatures   []Signature `json:"sourceSignatures"`
	NameSources  []string    `json:"currentNameHashSources"`
	Support      Support     `json:"support"`
	Relocate     []Relocate  `json:"relocate"`
	Forbidden    []string    `json:"forbiddenOutputRegex"`
	MountPoint   string      `json:"mountPoint"`
	PathHashSeed uint64      `json:"pathHashSeed"`
}

// SchemaClaim is a bounded provenance declaration, not a schema or approval.
// Referenced layout/review bytes are NOT loaded, verified or executed here.
type SchemaClaim struct {
	Schema                string `json:"schema"`
	RecipeSHA256          string `json:"recipeSHA256"`
	DonorUasset           string `json:"donorUasset"`
	DonorHeaderSHA256     string `json:"donorHeaderSHA256"`
	DonorExportSHA256     string `json:"donorExportSHA256"`
	CurrentProviderSHA256 string `json:"currentProviderSHA256"`
	Profile               string `json:"profile"`
	ClassPath             string `json:"classPath"`
	LayoutSHA256          string `json:"layoutSHA256"`
	Origin                string `json:"origin"`
	Revision              string `json:"revision"`
	ReviewRecordSHA256    string `json:"reviewRecordSHA256"`
}

type Family struct {
	Header   File   `json:"header"`
	Export   File   `json:"export"`
	Sidecars []File `json:"sidecars"`
}
type Task struct {
	Group       string       `json:"group"`
	Donor       Family       `json:"donor"`
	Target      Family       `json:"target"`
	PostProcess *PostProcess `json:"postProcess,omitempty"`
}
type Group struct {
	Name     string `json:"name"`
	Count    int    `json:"count"`
	Minimum  int    `json:"minimum"`
	Baseline int    `json:"baselineAdvisory"`
}
type Output struct {
	Path       string `json:"path"`
	Operation  string `json:"operation"`
	SourcePath string `json:"sourcePath"`
}
type Requirement struct {
	Code    string `json:"code"`
	Subject string `json:"subject"`
	State   string `json:"state"`
	Detail  string `json:"detail"`
}
type ClaimRecord struct {
	SHA256 string      `json:"documentSHA256"`
	Claim  SchemaClaim `json:"claim"`
	State  string      `json:"state"`
}
type Plan struct {
	Schema                  string        `json:"schema"`
	Status                  string        `json:"status"`
	RecipeID                string        `json:"recipeID"`
	RecipeSHA256            string        `json:"recipeSHA256"`
	DonorInventorySHA256    string        `json:"donorInventorySHA256"`
	CurrentInventorySHA256  string        `json:"currentInventorySHA256"`
	DeclaredDonor           Signature     `json:"declaredDonor"`
	DeclaredCurrentProvider string        `json:"declaredCurrentProvider"`
	TargetBuild             string        `json:"targetBuild"`
	NameReferences          []File        `json:"nameReferences"`
	Tasks                   []Task        `json:"tasks"`
	Groups                  []Group       `json:"groups"`
	SupportFiles            []File        `json:"supportFiles"`
	ExcludedSupport         []string      `json:"excludedSupport"`
	Outputs                 []Output      `json:"outputs"`
	SchemaClaims            []ClaimRecord `json:"schemaClaims"`
	Requirements            []Requirement `json:"requirements"`
	InputBytesVerified      bool          `json:"inputBytesVerified"`
	TransformReady          bool          `json:"transformReady"`
	BuildReady              bool          `json:"buildReady"`
	Validated               bool          `json:"validated"`
	Installed               bool          `json:"installed"`
}
