package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

type KnowledgeValidation struct {
	Protocol         string            `json:"protocol"`
	OK               bool              `json:"ok"`
	Files            map[string]string `json:"files"`
	PackageRuleCount int               `json:"package_rule_count"`
	Errors           []string          `json:"errors,omitempty"`
}

type cklCaseIndexDoc struct {
	Schema      string `json:"schema"`
	SourceFiles []struct {
		Path   string `json:"path"`
		SHA256 string `json:"sha256"`
	} `json:"sourceFiles"`
	Entries []json.RawMessage `json:"entries"`
}

type packageRulesDoc struct {
	Schema string `json:"schema"`
	Rules  []struct {
		ID string `json:"id"`
	} `json:"rules"`
}

func validateKnowledge(root string) KnowledgeValidation {
	names := []string{"behavior-symbols.json", "known-behaviors.json", "known-fixtures.json", "package-rules.json", "production-recipes.json", "reference-relations.json"}
	v := KnowledgeValidation{Protocol: "PMM_KNOWLEDGE_VALIDATION_V1", OK: true, Files: map[string]string{}}
	for _, n := range names {
		p := filepath.Join(root, "CKL", "Stable", n)
		b, e := os.ReadFile(p)
		if e != nil {
			v.OK = false
			v.Errors = append(v.Errors, n+": "+e.Error())
			continue
		}
		var anyDoc any
		if e := json.Unmarshal(b, &anyDoc); e != nil {
			v.OK = false
			v.Errors = append(v.Errors, n+": invalid JSON: "+e.Error())
			continue
		}
		v.Files[n] = fileSHA256(p)
	}
	p := filepath.Join(root, "CKL", "Stable", "package-rules.json")
	if b, e := os.ReadFile(p); e == nil {
		var d packageRulesDoc
		if e := json.Unmarshal(b, &d); e != nil {
			v.OK = false
			v.Errors = append(v.Errors, "package-rules.json: "+e.Error())
		} else {
			if d.Schema != "PMM_PACKAGE_RULES_V1" {
				v.OK = false
				v.Errors = append(v.Errors, "package-rules.json: unexpected schema "+d.Schema)
			}
			seen := map[string]bool{}
			for _, r := range d.Rules {
				if r.ID == "" {
					v.OK = false
					v.Errors = append(v.Errors, "package-rules.json: empty rule id")
					continue
				}
				if seen[r.ID] {
					v.OK = false
					v.Errors = append(v.Errors, "package-rules.json: duplicate rule id "+r.ID)
				}
				seen[r.ID] = true
			}
			v.PackageRuleCount = len(d.Rules)
		}
	}
	for _, rel := range []string{"CKL/Catalog/case-index.json", "CKL/channels.json", "CKL/Experimental/library.json"} {
		p := filepath.Join(root, filepath.FromSlash(rel))
		b, e := os.ReadFile(p)
		if e != nil {
			v.OK = false
			v.Errors = append(v.Errors, rel+": "+e.Error())
			continue
		}
		var doc any
		if e := json.Unmarshal(b, &doc); e != nil {
			v.OK = false
			v.Errors = append(v.Errors, rel+": invalid JSON: "+e.Error())
			continue
		}
		v.Files[rel] = fileSHA256(p)
	}
	indexPath := filepath.Join(root, "CKL", "Catalog", "case-index.json")
	if b, e := os.ReadFile(indexPath); e == nil {
		var idx cklCaseIndexDoc
		if e := json.Unmarshal(b, &idx); e != nil {
			v.OK = false
			v.Errors = append(v.Errors, "CKL/Catalog/case-index.json: "+e.Error())
		} else {
			if idx.Schema != "PMM_CKL_CASE_INDEX_V1" {
				v.OK = false
				v.Errors = append(v.Errors, "CKL/Catalog/case-index.json: unexpected schema "+idx.Schema)
			}
			if len(idx.Entries) == 0 {
				v.OK = false
				v.Errors = append(v.Errors, "CKL/Catalog/case-index.json: no indexed entries")
			}
			for _, src := range idx.SourceFiles {
				if src.Path == "" || src.SHA256 == "" {
					v.OK = false
					v.Errors = append(v.Errors, "CKL/Catalog/case-index.json: invalid sourceFiles entry")
					continue
				}
				p := filepath.Join(root, "CKL", filepath.FromSlash(src.Path))
				if got := fileSHA256(p); got == "" || got != src.SHA256 {
					v.OK = false
					v.Errors = append(v.Errors, "CKL catalog source hash mismatch: "+src.Path)
				}
			}
		}
	}
	return v
}

func requireKnowledge(root string) error {
	v := validateKnowledge(root)
	if v.OK {
		return nil
	}
	return fmt.Errorf("knowledge validation failed: %v", v.Errors)
}
