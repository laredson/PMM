package uasset

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"unicode/utf8"
)

const (
	FixedSchemaV1     = "PMM_FIXED_UNVERSIONED_SCHEMA_V1"
	FixedSchemaV2     = "PMM_FIXED_UNVERSIONED_SCHEMA_V2"
	MaxSchemaBytes    = 128 << 10
	MaxSchemaFields   = 1024
	MaxFragments      = 1024
	MaxArrayElements  = 1 << 20
	PostProcessField  = "PostProcessAnimBlueprint"
	SkeletalMeshClass = "/Script/Engine.SkeletalMesh"
)

type scalarField struct {
	Name      string `json:"name"`
	Type      string `json:"type"`
	InnerType string `json:"innerType,omitempty"`
}
type fixedSchema struct {
	Schema    string        `json:"schema"`
	Profile   string        `json:"profile"`
	ClassPath string        `json:"classPath"`
	Fields    []scalarField `json:"fields"`
}

type propertySpan struct {
	Name         string `json:"name"`
	Type         string `json:"type"`
	InnerType    string `json:"innerType,omitempty"`
	ElementCount int    `json:"elementCount,omitempty"`
	SchemaIndex  int    `json:"schemaIndex"`
	Zero         bool   `json:"zero"`
	Span
}
type propertyPrefix struct {
	Fields []propertySpan `json:"fields"`
	End    int            `json:"end"` // absolute position in the supplied .uexp
	Target propertySpan   `json:"target"`
}

func scalarWidth(t string) int {
	switch t {
	case "BoolProperty", "ByteProperty":
		return 1
	case "IntProperty", "UInt32Property", "FloatProperty", "ObjectProperty", "ClassProperty":
		return 4
	case "Int64Property", "DoubleProperty", "NameProperty":
		return 8
	}
	return 0
}
func schemaName(s string) bool {
	if len(s) == 0 || len(s) > 128 {
		return false
	}
	for i, c := range []byte(s) {
		if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || (i > 0 && c >= '0' && c <= '9')) {
			return false
		}
	}
	return true
}

// Reject duplicate keys even when differently escaped. No nulls, trailing JSON,
// unknown members, case-insensitive aliases, or recursive schema extension.
func strictSchemaJSON(b []byte) error {
	d := json.NewDecoder(bytes.NewReader(b))
	var walk func(int) error
	walk = func(depth int) error {
		if depth > 4 {
			return fmt.Errorf("%w: schema nesting", ErrLimit)
		}
		t, e := d.Token()
		if e != nil {
			return e
		}
		delim, compound := t.(json.Delim)
		if !compound {
			if t == nil {
				return fmt.Errorf("%w: null schema value", ErrInvalid)
			}
			return nil
		}
		if delim != '{' && delim != '[' {
			return fmt.Errorf("%w: schema delimiter", ErrInvalid)
		}
		keys := map[string]bool{}
		for d.More() {
			if delim == '{' {
				kt, e := d.Token()
				if e != nil {
					return e
				}
				k, ok := kt.(string)
				if !ok || keys[k] {
					return fmt.Errorf("%w: duplicate schema key", ErrInvalid)
				}
				if k != "schema" && k != "profile" && k != "classPath" && k != "fields" && k != "name" && k != "type" && k != "innerType" {
					return fmt.Errorf("%w: unknown schema key", ErrUnsupported)
				}
				keys[k] = true
			}
			if e := walk(depth + 1); e != nil {
				return e
			}
		}
		end, e := d.Token()
		if e != nil {
			return e
		}
		want := json.Delim('}')
		if delim == '[' {
			want = ']'
		}
		if end != want {
			return fmt.Errorf("%w: schema delimiter", ErrInvalid)
		}
		return nil
	}
	if e := walk(0); e != nil {
		return e
	}
	if _, e := d.Token(); e != io.EOF {
		return fmt.Errorf("%w: trailing schema JSON", ErrInvalid)
	}
	return nil
}

func loadFixedSchema(ctx context.Context, data []byte, pin string) (*fixedSchema, error) {
	b, e := pinnedSnapshot(ctx, data, pin, MaxSchemaBytes)
	if e != nil {
		return nil, e
	}
	if !utf8.Valid(b) {
		return nil, fmt.Errorf("%w: schema UTF-8", ErrInvalid)
	}
	if e = strictSchemaJSON(b); e != nil {
		return nil, e
	}
	var s fixedSchema
	d := json.NewDecoder(bytes.NewReader(b))
	d.DisallowUnknownFields()
	if e = d.Decode(&s); e != nil {
		return nil, e
	}
	if (s.Schema != FixedSchemaV1 && s.Schema != FixedSchemaV2) || s.Profile != CookedUE51 || s.ClassPath != SkeletalMeshClass {
		return nil, fmt.Errorf("%w: fixed schema profile/class", ErrUnsupported)
	}
	if len(s.Fields) == 0 || len(s.Fields) > MaxSchemaFields {
		return nil, fmt.Errorf("%w: schema field count", ErrLimit)
	}
	seen := map[string]bool{}
	target := false
	for _, f := range s.Fields {
		if e := ctx.Err(); e != nil {
			return nil, e
		}
		if !schemaName(f.Name) || seen[f.Name] {
			return nil, fmt.Errorf("%w: schema field name", ErrInvalid)
		}
		if f.Type == "ArrayProperty" {
			if s.Schema != FixedSchemaV2 || scalarWidth(f.InnerType) == 0 {
				return nil, fmt.Errorf("%w: array serializer %q", ErrUnsupported, f.InnerType)
			}
		} else if scalarWidth(f.Type) == 0 || f.InnerType != "" {
			return nil, fmt.Errorf("%w: unsupported schema type %q", ErrUnsupported, f.Type)
		}
		seen[f.Name] = true
		if f.Name == PostProcessField {
			if f.Type != "ClassProperty" {
				return nil, fmt.Errorf("%w: post-process requires ClassProperty", ErrUnsupported)
			}
			target = true
		}
	}
	if !target {
		return nil, fmt.Errorf("%w: missing post-process schema field", ErrInvalid)
	}
	return &s, nil
}

func validateScalar(p *Package, typ string, b []byte) error {
	switch typ {
	case "ByteProperty", "IntProperty", "UInt32Property", "FloatProperty", "Int64Property", "DoubleProperty":
		return nil
	case "BoolProperty":
		if len(b) != 1 || b[0] > 1 {
			return fmt.Errorf("%w: property boolean", ErrInvalid)
		}
	case "ObjectProperty", "ClassProperty":
		if len(b) != 4 {
			return fmt.Errorf("%w: property object width", ErrInvalid)
		}
		v := int32(binary.LittleEndian.Uint32(b))
		if int64(v) < -int64(len(p.Imports)) || int64(v) > int64(len(p.Exports)) {
			return fmt.Errorf("%w: property object index", ErrInvalid)
		}
	case "NameProperty":
		if len(b) != 8 {
			return fmt.Errorf("%w: property name width", ErrInvalid)
		}
		n := FName{int32(binary.LittleEndian.Uint32(b)), int32(binary.LittleEndian.Uint32(b[4:]))}
		if _, e := p.ResolveName(n); e != nil {
			return e
		}
	default:
		return fmt.Errorf("%w: scalar serializer %q", ErrUnsupported, typ)
	}
	return nil
}

// Parse only a complete unversioned property prefix using a hash-pinned external
// externally reviewed schema. V1 accepts only scalar fields. V2 additionally
// accepts ArrayProperty with a fixed-width scalar inner type; all other
// variable-size/custom serializers remain unsupported. The schema is NOT
// discovered from values or the recipe offset.
// After the prefix: native export data, GUID/bulkdata etc. remain opaque and unmoved.
func readFixedProperties(ctx context.Context, p *Package, x []byte, ex Export, s *fixedSchema) (*propertyPrefix, error) {
	if p.Summary.Flags&0x2000 == 0 || ex.ObjectFlags&0x10 != 0 {
		return nil, fmt.Errorf("%w: requires non-CDO unversioned properties", ErrUnsupported)
	}
	start := ex.SerialOffset - int64(p.Summary.HeaderSize)
	if start < 0 || start > int64(len(x)) || ex.SerialSize > int64(len(x))-start || ex.SerialSize <= 0 {
		return nil, fmt.Errorf("%w: property export extent", ErrInvalid)
	}
	pos, end := int(start), int(start+ex.SerialSize)
	take := func(n int) ([]byte, error) {
		if e := ctx.Err(); e != nil {
			return nil, e
		}
		if n < 0 || n > end-pos {
			return nil, fmt.Errorf("%w: truncated property prefix", ErrInvalid)
		}
		b := x[pos : pos+n]
		pos += n
		return b, nil
	}
	type slot struct{ index, bit int }
	slots := []slot{}
	index, bits := 0, 0
	for nf := 0; ; nf++ {
		if nf >= MaxFragments {
			return nil, fmt.Errorf("%w: unversioned fragments", ErrLimit)
		}
		b, e := take(2)
		if e != nil {
			return nil, e
		}
		v := binary.LittleEndian.Uint16(b)
		skip, count := int(v&127), int(v>>9)
		masked, last := v&128 != 0, v&256 != 0
		if skip > len(s.Fields)-index {
			return nil, fmt.Errorf("%w: schema skip range", ErrInvalid)
		}
		index += skip
		if count > len(s.Fields)-index {
			return nil, fmt.Errorf("%w: schema value range", ErrInvalid)
		}
		if count == 0 && masked || count == 0 && skip == 0 && !last {
			return nil, fmt.Errorf("%w: empty fragment", ErrInvalid)
		}
		for i := 0; i < count; i++ {
			bit := -1
			if masked {
				bit = bits
				bits++
			}
			slots = append(slots, slot{index + i, bit})
		}
		index += count
		if last {
			break
		}
	}
	maskBytes := 0
	if bits > 0 {
		if bits <= 8 {
			maskBytes = 1
		} else if bits <= 16 {
			maskBytes = 2
		} else {
			maskBytes = ((bits + 31) / 32) * 4
		}
	}
	mask, e := take(maskBytes)
	if e != nil {
		return nil, e
	}
	// This narrow profile accepts only zero padding bits. We never rewrite the mask.
	for bit := bits; bit < maskBytes*8; bit++ {
		if mask[bit/8]&(1<<uint(bit%8)) != 0 {
			return nil, fmt.Errorf("%w: nonzero zero-mask padding", ErrUnsupported)
		}
	}
	r := &propertyPrefix{}
	found := false
	for _, q := range slots {
		f := s.Fields[q.index]
		v := propertySpan{Name: f.Name, Type: f.Type, InnerType: f.InnerType, SchemaIndex: q.index, Span: Span{pos, 0}}
		v.Zero = q.bit >= 0 && mask[q.bit/8]&(1<<uint(q.bit%8)) != 0
		if !v.Zero {
			if f.Type == "ArrayProperty" {
				header, e := take(4)
				if e != nil {
					return nil, e
				}
				count := int64(int32(binary.LittleEndian.Uint32(header)))
				if count < 0 || count > MaxArrayElements {
					return nil, fmt.Errorf("%w: array element count", ErrLimit)
				}
				width := scalarWidth(f.InnerType)
				if width == 0 {
					return nil, fmt.Errorf("%w: array serializer %q", ErrUnsupported, f.InnerType)
				}
				payload, e := take(int(count) * width)
				if e != nil {
					return nil, e
				}
				for i := 0; i < int(count); i++ {
					if i&1023 == 0 {
						if e := ctx.Err(); e != nil {
							return nil, e
						}
					}
					if e := validateScalar(p, f.InnerType, payload[i*width:(i+1)*width]); e != nil {
						return nil, e
					}
				}
				v.ElementCount = int(count)
				v.Size = 4 + len(payload)
			} else {
				v.Size = scalarWidth(f.Type)
				if v.Size == 0 {
					return nil, fmt.Errorf("%w: scalar serializer %q", ErrUnsupported, f.Type)
				}
				b, e := take(v.Size)
				if e != nil {
					return nil, e
				}
				if e := validateScalar(p, f.Type, b); e != nil {
					return nil, e
				}
			}
		}
		r.Fields = append(r.Fields, v)
		if f.Name == PostProcessField {
			r.Target = v
			found = true
		}
	}
	if !found || r.Target.Zero || r.Target.Size != 4 {
		return nil, fmt.Errorf("%w: post-process not explicitly serialized", ErrInvalid)
	}
	r.End = pos
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	return r, nil
}

// Imported paths are rooted in a Package import; exported outers and ambiguous
// dotted object names are outside this profile. Same short name is not identity.
func importPath(ctx context.Context, p *Package, index int) (string, error) {
	var leaf []string
	for depth := 0; depth < 64; depth++ {
		if e := ctx.Err(); e != nil {
			return "", e
		}
		if index < 0 || index >= len(p.Imports) {
			return "", fmt.Errorf("%w: import path index", ErrInvalid)
		}
		v := p.Imports[index]
		name, e := p.ResolveName(v.ObjectName)
		if e != nil {
			return "", e
		}
		if v.Optional {
			return "", fmt.Errorf("%w: optional import chain", ErrUnsupported)
		}
		if v.Outer == 0 {
			cp, _ := p.ResolveName(v.ClassPackage)
			cn, _ := p.ResolveName(v.ClassName)
			if cp != "/Script/CoreUObject" || cn != "Package" || !strings.HasPrefix(name, "/") || strings.ContainsAny(name, ".\\:\x00") || len(name) > 1024 {
				return "", fmt.Errorf("%w: import package root", ErrUnsupported)
			}
			for i := len(leaf) - 1; i >= 0; i-- {
				name += "." + leaf[i]
			}
			if len(name) > 4096 {
				return "", fmt.Errorf("%w: import path bytes", ErrLimit)
			}
			return name, nil
		}
		if name == "" || len(name) > 128 || strings.ContainsAny(name, "./\\:\x00") || v.Outer > 0 {
			return "", fmt.Errorf("%w: import object path", ErrUnsupported)
		}
		leaf = append(leaf, name)
		index = int(-int64(v.Outer) - 1)
	}
	return "", fmt.Errorf("%w: import path depth", ErrLimit)
}
