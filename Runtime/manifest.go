package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type ReleaseManifest struct {
	Schema                         string            `json:"schema"`
	Version                        string            `json:"version"`
	BuildID                        string            `json:"buildId"`
	PMMCoreVersion                 string            `json:"pmmCoreVersion"`
	RepakVersion                   string            `json:"repakVersion"`
	RepakSha256                    string            `json:"repakSha256"`
	MappingsSha256                 string            `json:"mappingsSha256"`
	OodleExpectedSha256            string            `json:"oodleExpectedSha256"`
	StandardPackageDotnetBundled   bool              `json:"standardPackageDotnetBundled"`
	DotnetRuntimeContract          string            `json:"dotnetRuntimeContract"`
	DotnetRuntimeArchiveURL        string            `json:"dotnetRuntimeArchiveUrl"`
	DotnetRuntimeArchiveSha512     string            `json:"dotnetRuntimeArchiveSha512"`
	DotnetRuntimeInventory         string            `json:"dotnetRuntimeInventory"`
	DotnetRuntimeInventorySha256   string            `json:"dotnetRuntimeInventorySha256"`
	ManagedRuntimeSha256           map[string]string `json:"managedRuntimeSha256"`
	SourceTreeRequiresReleaseBuild bool              `json:"sourceTreeRequiresReleaseBuild"`
}

func loadReleaseManifest(root string) (ReleaseManifest, error) {
	var m ReleaseManifest
	p := filepath.Join(root, "RELEASE_MANIFEST.json")
	b, err := os.ReadFile(p)
	if err != nil {
		return m, err
	}
	if err := json.Unmarshal(b, &m); err != nil {
		return m, err
	}
	if m.Schema != "PMM_RELEASE_MANIFEST_V1" {
		return m, fmt.Errorf("unsupported release manifest schema: %s", m.Schema)
	}
	return m, nil
}
