package corer1

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
)

func bytesDigest(b []byte) string { h := sha256.Sum256(b); return hex.EncodeToString(h[:]) }

type scalarLayoutField struct {
	Name string `json:"name"`
	Type string `json:"type"`
}
type scalarLayout struct {
	Schema    string              `json:"schema"`
	Profile   string              `json:"profile"`
	ClassPath string              `json:"classPath"`
	Fields    []scalarLayoutField `json:"fields"`
}

// No approval boolean. This is a REVIEW RECORD whose authorship, claims and
// evidence are not authenticated by a SHA-256 match. It cannot enable execution.
type SchemaReview struct {
	Schema                string   `json:"schema"`
	RecipeSHA256          string   `json:"recipeSHA256"`
	DonorHeaderSHA256     string   `json:"donorHeaderSHA256"`
	DonorExportSHA256     string   `json:"donorExportSHA256"`
	CurrentProviderSHA256 string   `json:"currentProviderSHA256"`
	LayoutSHA256          string   `json:"layoutSHA256"`
	Profile               string   `json:"profile"`
	ClassPath             string   `json:"classPath"`
	Origin                string   `json:"origin"`
	Revision              string   `json:"revision"`
	Reviewer              string   `json:"reviewer"`
	Method                string   `json:"method"`
	Findings              []string `json:"findings"`
}

func fieldIdentifier(s string) bool {
	if len(s) < 1 || len(s) > 128 {
		return false
	}
	for i, c := range []byte(s) {
		if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || (i > 0 && c >= '0' && c <= '9')) {
			return false
		}
	}
	return true
}
func verifyDossier(ctx context.Context, record ClaimRecord, files DossierFiles, layoutBytes, reviewBytes []byte) (DossierResult, error) {
	s := record.Claim
	var layout scalarLayout
	var review SchemaReview
	out := DossierResult{}
	if files.ClaimSHA256 != record.SHA256 || files.Layout.SHA256 != s.LayoutSHA256 || files.Review.SHA256 != s.ReviewRecordSHA256 {
		return out, fail("BINDING", "dossier", "document references")
	}
	if e := decode(ctx, PinnedJSON{layoutBytes, s.LayoutSHA256}, 128<<10, "schema layout", &layout); e != nil {
		return out, e
	}
	if e := decode(ctx, PinnedJSON{reviewBytes, s.ReviewRecordSHA256}, 128<<10, "schema review", &review); e != nil {
		return out, e
	}
	if layout.Schema != "PMM_FIXED_UNVERSIONED_SCHEMA_V1" || layout.Profile != s.Profile || layout.ClassPath != s.ClassPath || len(layout.Fields) < 1 || len(layout.Fields) > 1024 {
		return out, fail("LAYOUT", "schema", "unsupported profile/field count")
	}
	seen := map[string]bool{}
	target := false
	for _, f := range layout.Fields {
		if e := ctx.Err(); e != nil {
			return out, e
		}
		if !fieldIdentifier(f.Name) || seen[f.Name] {
			return out, fail("LAYOUT", f.Name, "invalid or duplicate field name")
		}
		seen[f.Name] = true
		switch f.Type {
		case "BoolProperty", "ByteProperty", "IntProperty", "UInt32Property", "FloatProperty", "ObjectProperty", "ClassProperty", "Int64Property", "DoubleProperty", "NameProperty":
		default:
			return out, fail("UNSUPPORTED", f.Name, "non-scalar serializer")
		}
		if f.Name == "PostProcessAnimBlueprint" {
			if f.Type != "ClassProperty" {
				return out, fail("LAYOUT", f.Name, "ClassProperty required")
			}
			target = true
		}
	}
	if !target {
		return out, fail("LAYOUT", "schema", "postprocess property absent")
	}
	if review.Schema != "PMM_R1_SCHEMA_REVIEW_V1" || review.RecipeSHA256 != s.RecipeSHA256 || review.DonorHeaderSHA256 != s.DonorHeaderSHA256 || review.DonorExportSHA256 != s.DonorExportSHA256 || review.CurrentProviderSHA256 != s.CurrentProviderSHA256 || review.LayoutSHA256 != s.LayoutSHA256 || review.Profile != s.Profile || review.ClassPath != s.ClassPath || review.Origin != s.Origin || review.Revision != s.Revision {
		return out, fail("BINDING", "review", "unrelated record")
	}
	if !label(review.Reviewer) || !label(review.Method) || len(review.Findings) < 1 || len(review.Findings) > 64 {
		return out, fail("REVIEW", "record", "missing or oversized declarations")
	}
	for _, f := range review.Findings {
		if !label(f) {
			return out, fail("REVIEW", "findings", "invalid declaration")
		}
	}
	return DossierResult{ClaimSHA256: record.SHA256, Layout: files.Layout, Review: files.Review, State: "BYTES_AND_BINDINGS_CHECKED_NOT_AUTHENTICATED", LayoutProfile: layout.Profile, FieldCount: len(layout.Fields), BytesVerified: true, BindingsChecked: true}, ctx.Err()
}
