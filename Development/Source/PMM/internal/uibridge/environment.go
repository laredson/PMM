package uibridge

import (
	"errors"
	"sort"
	"strconv"
	"strings"
)

const pipePrefix = `\\.\pipe\PMM.UIBridge.`
const EnvPrefix = "PMM_UIBRIDGE_"

// Descriptor is only a locator. Endpoint/parent authentication remains mandatory.
type Descriptor struct {
	Name    string
	Session string
	Host    Identity
}

func (d Descriptor) valid() bool {
	if !ValidSession(d.Session) || !d.Host.Valid() || !strings.HasPrefix(d.Name, pipePrefix) {
		return false
	}
	tail := strings.TrimPrefix(d.Name, pipePrefix)
	if len(tail) != 32 {
		return false
	}
	for _, c := range tail {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
			return false
		}
	}
	return true
}

// MergeEnvironment removes all transport locators by default and deduplicates
// Windows keys case-insensitively. Drive-current-directory entries (=C:=...) survive.
func MergeEnvironment(base []string, overrides map[string]string) []string {
	values := map[string]string{}
	keyOf := func(s string) string {
		i := strings.IndexByte(s, '=')
		if i == 0 {
			if j := strings.IndexByte(s[1:], '='); j >= 0 {
				i = j + 1
			}
		}
		if i <= 0 {
			return ""
		}
		return strings.ToUpper(s[:i])
	}
	for _, item := range base {
		key := keyOf(item)
		if key != "" && !strings.HasPrefix(key, EnvPrefix) {
			values[key] = item
		}
	}
	for key, value := range overrides {
		// Callers are trusted launch code, not arbitrary message fields.
		if key == "" || strings.ContainsAny(key, "=\x00") || strings.ContainsRune(value, 0) {
			continue
		}
		values[strings.ToUpper(key)] = key + "=" + value
	}
	keys := make([]string, 0, len(values))
	for k := range values {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	out := make([]string, 0, len(keys))
	for _, k := range keys {
		out = append(out, values[k])
	}
	return out
}

func (d Descriptor) Environment(base []string) ([]string, error) {
	if !d.valid() {
		return nil, errors.New("invalid bridge locator")
	}
	return MergeEnvironment(base, map[string]string{
		EnvPrefix + "PIPE": d.Name, EnvPrefix + "SESSION": d.Session,
		EnvPrefix + "HOST_PID":     strconv.FormatUint(uint64(d.Host.PID), 10),
		EnvPrefix + "HOST_CREATED": strconv.FormatUint(d.Host.Created, 10),
	}), nil
}

func DescriptorFromEnvironment(env []string) (Descriptor, bool, error) {
	var d Descriptor
	values := map[string]string{}
	allowed := map[string]bool{EnvPrefix + "PIPE": true, EnvPrefix + "SESSION": true, EnvPrefix + "HOST_PID": true, EnvPrefix + "HOST_CREATED": true}
	for _, item := range env {
		k, v, ok := strings.Cut(item, "=")
		k = strings.ToUpper(k)
		if !strings.HasPrefix(k, EnvPrefix) {
			continue
		}
		if !ok || !allowed[k] {
			return d, true, errors.New("unknown bridge environment field")
		}
		if _, found := values[k]; found {
			return d, true, errors.New("duplicate bridge environment field")
		}
		values[k] = v
	}
	if len(values) == 0 {
		return d, false, nil
	}
	if len(values) != 4 {
		return d, true, errors.New("incomplete bridge environment")
	}
	pid, e := Decimal(values[EnvPrefix+"HOST_PID"], 32, false)
	if e != nil {
		return d, true, e
	}
	created, e := Decimal(values[EnvPrefix+"HOST_CREATED"], 64, false)
	if e != nil {
		return d, true, e
	}
	d = Descriptor{values[EnvPrefix+"PIPE"], values[EnvPrefix+"SESSION"], Identity{uint32(pid), created}}
	if !d.valid() {
		return d, true, errors.New("invalid bridge environment")
	}
	return d, true, nil
}
