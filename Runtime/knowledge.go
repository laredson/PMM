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
		p := filepath.Join(root, "Knowledge", n)
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
	p := filepath.Join(root, "Knowledge", "package-rules.json")
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
	return v
}

func requireKnowledge(root string) error {
	v := validateKnowledge(root)
	if v.OK {
		return nil
	}
	return fmt.Errorf("knowledge validation failed: %v", v.Errors)
}
