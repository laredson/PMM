package corer1

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"reflect"
	"strings"
	"unicode/utf8"
)

func validHash(s string) bool {
	if len(s) != 64 {
		return false
	}
	for _, c := range s {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
			return false
		}
	}
	return true
}

func decode(ctx context.Context, in PinnedJSON, limit int, subject string, out any) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if !validHash(in.SHA256) {
		return fail("PIN", subject, "missing or noncanonical SHA-256")
	}
	if len(in.Data) == 0 || len(in.Data) > limit {
		return fail("LIMIT", subject, "JSON size")
	}
	h := sha256.New()
	for i := 0; i < len(in.Data); i += 32768 {
		if err := ctx.Err(); err != nil {
			return err
		}
		end := i + 32768
		if end > len(in.Data) {
			end = len(in.Data)
		}
		h.Write(in.Data[i:end])
	}
	if hex.EncodeToString(h.Sum(nil)) != in.SHA256 {
		return fail("PIN", subject, "JSON identity mismatch")
	}
	if !utf8.Valid(in.Data) {
		return fail("JSON", subject, "invalid UTF-8")
	}
	d := json.NewDecoder(bytes.NewReader(in.Data))
	d.UseNumber()
	budget := 400000
	v, err := jsonValue(ctx, d, 0, &budget)
	if err != nil {
		return err
	}
	if _, err = d.Token(); err != io.EOF {
		return fail("JSON", subject, "trailing input")
	}
	if err = shape(ctx, v, reflect.TypeOf(out).Elem()); err != nil {
		return err
	}
	if err = json.Unmarshal(in.Data, out); err != nil {
		return fail("JSON", subject, err.Error())
	}
	return ctx.Err()
}

// Token traversal rejects duplicates before encoding/json can silently merge them.
func jsonValue(ctx context.Context, d *json.Decoder, depth int, budget *int) (any, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	*budget--
	if depth > 16 || *budget < 0 {
		return nil, fail("LIMIT", "JSON", "depth/token count")
	}
	t, err := d.Token()
	if err != nil {
		return nil, fail("JSON", "token", err.Error())
	}
	switch t {
	case json.Delim('{'):
		m := map[string]any{}
		for d.More() {
			k, e := d.Token()
			if e != nil {
				return nil, e
			}
			s, ok := k.(string)
			if !ok {
				return nil, fail("JSON", "key", "not string")
			}
			if _, ok = m[s]; ok {
				return nil, fail("JSON", s, "duplicate key")
			}
			v, e := jsonValue(ctx, d, depth+1, budget)
			if e != nil {
				return nil, e
			}
			m[s] = v
		}
		end, e := d.Token()
		if e != nil || end != json.Delim('}') {
			return nil, fail("JSON", "object", "unclosed")
		}
		return m, nil
	case json.Delim('['):
		a := []any{}
		for d.More() {
			v, e := jsonValue(ctx, d, depth+1, budget)
			if e != nil {
				return nil, e
			}
			a = append(a, v)
		}
		end, e := d.Token()
		if e != nil || end != json.Delim(']') {
			return nil, fail("JSON", "array", "unclosed")
		}
		return a, nil
	case nil:
		return nil, fail("JSON", "value", "null not supported; omit optional fields")
	}
	if s, ok := t.(string); ok {
		for _, c := range s {
			if c == utf8.RuneError || c < 32 {
				return nil, fail("JSON", "string", "control or replacement character")
			}
		}
	}
	return t, nil
}

// Exact field spelling and required fields: DisallowUnknownFields alone still
// accepts case-insensitive aliases and missing zero-valued fields.
func shape(ctx context.Context, v any, t reflect.Type) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if t.Kind() == reflect.Pointer {
		t = t.Elem()
	}
	switch t.Kind() {
	case reflect.Struct:
		m, ok := v.(map[string]any)
		if !ok {
			return fail("JSON", t.Name(), "expected object")
		}
		allowed := map[string]reflect.Type{}
		for i := 0; i < t.NumField(); i++ {
			f := t.Field(i)
			parts := strings.Split(f.Tag.Get("json"), ",")
			key := parts[0]
			allowed[key] = f.Type
			_, present := m[key]
			optional := len(parts) > 1 && parts[1] == "omitempty"
			if !present && !optional {
				return fail("JSON", key, "required field missing")
			}
		}
		for key, val := range m {
			ft, ok := allowed[key]
			if !ok {
				return fail("JSON", key, "unknown or mis-cased field")
			}
			if err := shape(ctx, val, ft); err != nil {
				return err
			}
		}
	case reflect.Slice:
		a, ok := v.([]any)
		if !ok {
			return fail("JSON", t.String(), "expected array")
		}
		for _, x := range a {
			if err := shape(ctx, x, t.Elem()); err != nil {
				return err
			}
		}
	}
	return nil
}
