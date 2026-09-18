package main

import (
	"encoding/json"
	"os"
	"path/filepath"
)

type NativeShellLabels struct {
	Title           string `json:"title"`
	Heading         string `json:"heading"`
	Subtitle        string `json:"subtitle"`
	Refresh         string `json:"refresh"`
	DetectGame      string `json:"detect_game"`
	OpenPMMFolder   string `json:"open_pmm_folder"`
	OpenLibrary     string `json:"open_library"`
	OpenGameFolder  string `json:"open_game_folder"`
	OpenLegacyUI    string `json:"open_legacy_ui"`
	RuntimeSelfTest string `json:"runtime_self_test"`
	Close           string `json:"close"`
	MigrationNote   string `json:"migration_note"`
}

func loadNativeShellLabels(root string) NativeShellLabels {
	labels := NativeShellLabels{
		Title:           "Palworld Manager Merger 1.2.1",
		Heading:         "PALWORLD MANAGER MERGER",
		Subtitle:        "Native runtime shell - no PowerShell FullLanguage required",
		Refresh:         "Refresh",
		DetectGame:      "Detect Palworld",
		OpenPMMFolder:   "Open PMM folder",
		OpenLibrary:     "Open mod library",
		OpenGameFolder:  "Open game folder",
		OpenLegacyUI:    "Open current PMM interface",
		RuntimeSelfTest: "Runtime self-test",
		Close:           "Close",
		MigrationNote:   "Native startup/UI bootstrap is active. Analyze, Build, Deploy and the full management workspace are still being migrated into PMMRuntime in later 1.2 alphas.",
	}
	p := filepath.Join(root, "Resources", "UI", "native-shell.json")
	if b, err := os.ReadFile(p); err == nil {
		_ = json.Unmarshal(b, &labels)
	}
	return labels
}
