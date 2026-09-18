package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// These fixtures call the inventory reader only: no .NET, repair, downloads or UI.
func inventoryFixture(t *testing.T) (string, string, ReleaseManifest, string) {
	t.Helper()
	root := t.TempDir()
	dir := filepath.Join(root, "Engine", "dotnet", "fixture")
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatal(err)
	}
	var rows strings.Builder
	for i := 0; i < 20; i++ {
		name := fmt.Sprintf("file-%02d.dat", i)
		p := filepath.Join(dir, name)
		if err := os.WriteFile(p, []byte(name), 0644); err != nil {
			t.Fatal(err)
		}
		fmt.Fprintf(&rows, "%s  %s\n", fileSHA256(p), name)
	}
	m := ReleaseManifest{StandardPackageDotnetBundled: true, DotnetRuntimeInventory: "inventory.sha256"}
	return root, dir, m, rows.String()
}

func writeInventoryFixture(t *testing.T, root string, m ReleaseManifest, rows string) ReleaseManifest {
	t.Helper()
	p := filepath.Join(root, m.DotnetRuntimeInventory)
	if err := os.WriteFile(p, []byte(rows), 0644); err != nil {
		t.Fatal(err)
	}
	m.DotnetRuntimeInventorySha256 = fileSHA256(p)
	return m
}

func TestInventoryRejectsIncompleteScan(t *testing.T) {
	root, dir, m, rows := inventoryFixture(t)
	// Hash pin matches these bytes. Parse completion must still be checked.
	m = writeInventoryFixture(t, root, m, rows+strings.Repeat("x", 70*1024)+"\n")
	if testRuntimeInventory(root, m, dir) {
		t.Fatal("accepted valid prefix after Scanner stopped with an oversized record")
	}
}

func TestInventoryRejectsDuplicateRecords(t *testing.T) {
	root, dir, m, rows := inventoryFixture(t)
	m = writeInventoryFixture(t, root, m, rows+strings.Split(rows, "\n")[0]+"\n")
	if testRuntimeInventory(root, m, dir) {
		t.Fatal("accepted duplicate inventory path")
	}
}

func TestInventoryAcceptsCompleteAndRejectsMissingOrExtraFiles(t *testing.T) {
	root, dir, m, rows := inventoryFixture(t)
	m = writeInventoryFixture(t, root, m, rows)
	if !testRuntimeInventory(root, m, dir) {
		t.Fatal("complete fixture rejected")
	}
	extra := filepath.Join(dir, "extra.dat")
	if err := os.WriteFile(extra, []byte("extra"), 0644); err != nil {
		t.Fatal(err)
	}
	if testRuntimeInventory(root, m, dir) {
		t.Fatal("extra file accepted")
	}
	if err := os.Remove(extra); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(filepath.Join(dir, "file-00.dat")); err != nil {
		t.Fatal(err)
	}
	if testRuntimeInventory(root, m, dir) {
		t.Fatal("missing file accepted")
	}
}

func TestInventoryRejectsInvalidRecordAndPin(t *testing.T) {
	root, dir, m, rows := inventoryFixture(t)
	m = writeInventoryFixture(t, root, m, rows+"not-a-checksum\n")
	if testRuntimeInventory(root, m, dir) {
		t.Fatal("invalid record accepted")
	}
	m = writeInventoryFixture(t, root, m, rows)
	m.DotnetRuntimeInventorySha256 = strings.Repeat("0", 64)
	if testRuntimeInventory(root, m, dir) {
		t.Fatal("wrong pin accepted")
	}
}

func TestPackagedRuntimeInventoryReadOnly(t *testing.T) {
	root := os.Getenv("PMM_TEST_PACKAGE_ROOT")
	if root == "" {
		t.Skip("set PMM_TEST_PACKAGE_ROOT to check the real inventory without executing binaries")
	}
	m, err := loadReleaseManifest(root)
	if err != nil {
		t.Fatal(err)
	}
	if !testRuntimeInventory(root, m, filepath.Join(root, "Engine", "dotnet", m.DotnetRuntimeContract)) {
		t.Fatal("pinned bundled runtime inventory rejected")
	}
	t.Log("read-only packaged runtime inventory: accepted; no dependency command executed")
}
