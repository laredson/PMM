package supervision

import (
	"context"
	"strings"
	"testing"
	"time"
)

func TestProbeResponseContracts(t *testing.T) {
	for _, c := range []struct {
		out, err, status string
		compatible       bool
	}{
		{"PMM_PS_PROBE_V1|5.1|Desktop|FullLanguage\r\n", "", "OK", true},
		{"PMM_PS_PROBE_V1|5.1|Desktop|ConstrainedLanguage\n", "", "OK", true},
		{"PMM_PS_PROBE_V1|5.1|Desktop|RestrictedLanguage\n", "", "OK", true},
		{"PMM_PS_PROBE_V1|5.1|Desktop|NoLanguage\n", "", "OK", true},
		{"PMM_PS_PROBE_V1|7.4|Core|FullLanguage\n", "", "UNSUPPORTED_VERSION", false},
		{"PMM_PS_PROBE_V1|5.0|Desktop|FullLanguage\n", "", "UNSUPPORTED_VERSION", false},
		{"FullLanguage\n", "", "INVALID_RESPONSE", false},
		{"PMM_PS_PROBE_V1|5.1|Desktop|FullLanguage\nnoise", "", "INVALID_RESPONSE", false},
		{"PMM_PS_PROBE_V1|5.1|Desktop|FullLanguage\n", "error", "INVALID_RESPONSE", false},
		{"PMM_PS_PROBE_V1|5.1|Desktop|Unknown\n", "", "INVALID_RESPONSE", false},
	} {
		p := parseProbe(c.out, c.err)
		if p.Status != c.status || p.Compatible != c.compatible {
			t.Fatal(c, p)
		}
	}
}
func TestProbeUsesBoundedRunner(t *testing.T) {
	for _, mode := range []string{"probe", "bad-probe", "long", "sleep"} {
		t.Run(mode, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
			defer cancel()
			p := probeCommand(ctx, fixture(mode))
			want := map[string]string{"probe": "OK", "bad-probe": "UNSUPPORTED_VERSION", "long": "OUTPUT_INCOMPLETE", "sleep": "TIMEOUT"}[mode]
			if p.Status != want {
				t.Fatal(p)
			}
		})
	}
}
func TestProbeDoesNotRequestPolicyOverride(t *testing.T) {
	if strings.Contains(strings.ToLower(ProbeCommand), "bypass") {
		t.Fatal(ProbeCommand)
	}
}
