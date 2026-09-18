package uasset

import (
	"context"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"strings"
)

// Expected import identity comes from a reviewed reference, not a short-name
// search or the stale integer's magnitude. Pins establish identity, not trust.
type ImportIdentity struct {
	Path         string `json:"path"`
	ClassPackage string `json:"classPackage"`
	ClassName    string `json:"className"`
}
type PostProcessRequest struct {
	HeaderSHA256       string `json:"headerSha256"`
	ExportSHA256       string `json:"exportSha256"`
	ResultHeaderSHA256 string `json:"resultHeaderSha256"`
	ResultExportSHA256 string `json:"resultExportSha256"`
	// Flattened, reviewed external schema: not .usmap, no offset overrides.
	Schema          []byte         `json:"schema"`
	SchemaSHA256    string         `json:"schemaSha256"`
	ExportIndex     int            `json:"exportIndex"`
	ExportObject    string         `json:"exportObject"`
	Stale           ImportIdentity `json:"stale"`
	Safe            ImportIdentity `json:"safe"`
	PreloadIndex    int            `json:"preloadIndex"`
	DependencyGroup int            `json:"dependencyGroup"`
	// Absolute byte offset within .uexp, independently checked against parsing.
	ExpectedSerializedOffset int `json:"expectedSerializedOffset"`
}
type ReferenceEdit struct {
	File   string `json:"file"`
	Offset int    `json:"offset"`
	Before int32  `json:"before"`
	After  int32  `json:"after"`
}
type PostProcessReport struct {
	SchemaSHA256             string          `json:"schemaSha256"`
	HeaderBefore             string          `json:"headerBefore"`
	ExportBefore             string          `json:"exportBefore"`
	HeaderAfter              string          `json:"headerAfter"`
	ExportAfter              string          `json:"exportAfter"`
	ExportIndex              int             `json:"exportIndex"`
	Field                    string          `json:"field"`
	SchemaIndex              int             `json:"schemaIndex"`
	ExportRelativeOffset     int             `json:"exportRelativeOffset"`
	LogicalOffset            int64           `json:"logicalOffset"`
	ParsedPrefixEnd          int             `json:"parsedPrefixEnd"`
	OpaqueExportTailBytes    int             `json:"opaqueExportTailBytes"`
	Edits                    []ReferenceEdit `json:"edits"`
	ExternalSchemaRequired   bool            `json:"externalSchemaRequired"`
	FunctionalParityVerified bool            `json:"functionalParityVerified"`
}
type PostProcessResult struct {
	Header     []byte
	ExportData []byte
	Package    *Package
	Report     PostProcessReport
}

func validPin(pin string) bool {
	if len(pin) != 64 {
		return false
	}
	b, e := hex.DecodeString(pin)
	return e == nil && hex.EncodeToString(b) == pin
}
func findImportIdentity(ctx context.Context, p *Package, want ImportIdentity) (int32, error) {
	if len(want.Path) > 4096 || len(want.ClassName) > 128 || len(want.ClassPackage) > 1024 {
		return 0, fmt.Errorf("%w: import identity length", ErrLimit)
	}
	dot := strings.LastIndexByte(want.Path, '.')
	if dot <= 0 || dot == len(want.Path)-1 || want.ClassName == "" || want.ClassPackage == "" {
		return 0, fmt.Errorf("%w: mandatory import identity", ErrInvalid)
	}
	short := want.Path[dot+1:]
	match := int32(0)
	for i, v := range p.Imports {
		if e := ctx.Err(); e != nil {
			return 0, e
		}
		n, _ := p.ResolveName(v.ObjectName)
		if n != short {
			continue
		}
		cp, _ := p.ResolveName(v.ClassPackage)
		cn, _ := p.ResolveName(v.ClassName)
		path, e := importPath(ctx, p, i)
		if e != nil {
			return 0, e
		}
		if path != want.Path {
			continue
		}
		if cp != want.ClassPackage || cn != want.ClassName {
			return 0, fmt.Errorf("%w: import class mismatch", ErrInvalid)
		}
		if match != 0 {
			return 0, fmt.Errorf("%w: ambiguous import identity", ErrInvalid)
		}
		match = -int32(i) - 1
	}
	if match == 0 {
		return 0, fmt.Errorf("%w: import not found", ErrInvalid)
	}
	return match, nil
}
func checkedPreload(ctx context.Context, p *Package, req PostProcessRequest, stale int32) (int, error) {
	if req.PreloadIndex < 0 || req.PreloadIndex >= len(p.Preload) || req.DependencyGroup < 0 || req.DependencyGroup > 3 {
		return 0, fmt.Errorf("%w: preload plan", ErrInvalid)
	}
	// The historical operation requires a single stale preload record. In
	// addition, require that record to belong only to the selected export/group.
	occurrences := 0
	for _, v := range p.Preload {
		if e := ctx.Err(); e != nil {
			return 0, e
		}
		if v == stale {
			occurrences++
		}
	}
	if occurrences != 1 || p.Preload[req.PreloadIndex] != stale {
		return 0, fmt.Errorf("%w: stale preload occurrence", ErrInvalid)
	}
	owners := 0
	for i, v := range p.Exports {
		if e := ctx.Err(); e != nil {
			return 0, e
		}
		start := int64(v.FirstDependency)
		if start < 0 {
			continue
		}
		for group, count := range v.DependencyCounts {
			if int64(req.PreloadIndex) >= start && int64(req.PreloadIndex) < start+int64(count) {
				if i != req.ExportIndex || group != req.DependencyGroup {
					return 0, fmt.Errorf("%w: preload owned by another export/group", ErrUnsupported)
				}
				owners++
			}
			start += int64(count)
		}
	}
	if owners != 1 {
		return 0, fmt.Errorf("%w: unowned preload record", ErrInvalid)
	}
	return int(p.Summary.PreloadOffset) + 4*req.PreloadIndex, nil
}

// PatchPostProcess performs exactly two fixed-size edits after all preconditions:
// one parsed PostProcessAnimBlueprint ClassProperty becomes null, and its single
// preload reference changes from the stale import to the explicitly pinned safe
// import. It does NOT put safeClass into the serialized property.
//
// Frozen input/output SHA-256 pins and a pinned, externally reviewed flattened
// scalar schema are MANDATORY. Unversioned header fragments derive the property's
// offset; ExpectedSerializedOffset is a CHECK, never an instruction to seek/write.
// Real SkeletalMesh schemas with arrays/structs/custom serialization are currently
// UNSUPPORTED. There is no assumed Gura layout or .usmap reader in this component.
//
// All inputs/plans must be immutable for this call. Outputs are private copies.
// Unknown tail bytes and offsets are left at identical positions, not interpreted
// as safe to relocate. No disk, process, network, recipe discovery or installation.
// Errors always return nil; output pins are required even for a synthetically valid
// schema. Success is byte/precondition evidence, not Unreal or gameplay acceptance.
func PatchPostProcess(ctx context.Context, header, exportData []byte, opt Options, req PostProcessRequest) (*PostProcessResult, error) {
	if ctx == nil {
		return nil, fmt.Errorf("%w: nil context", ErrInvalid)
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	if exportData == nil {
		return nil, fmt.Errorf("%w: explicit .uexp required", ErrUnsupported)
	}
	if !validPin(req.ResultHeaderSHA256) || !validPin(req.ResultExportSHA256) {
		return nil, fmt.Errorf("%w: mandatory result SHA-256 pins", ErrInvalid)
	}
	if req.ExpectedSerializedOffset < 0 || !schemaName(req.ExportObject) {
		return nil, fmt.Errorf("%w: export plan identity/offset", ErrInvalid)
	}
	lim, e := opt.Limits.checked()
	if e != nil {
		return nil, e
	}
	h, e := pinnedSnapshot(ctx, header, req.HeaderSHA256, lim.HeaderBytes)
	if e != nil {
		return nil, e
	}
	x, e := pinnedSnapshot(ctx, exportData, req.ExportSHA256, lim.ExportBytes)
	if e != nil {
		return nil, e
	}
	p, e := Read(ctx, h, x, opt)
	if e != nil {
		return nil, e
	}
	s, e := loadFixedSchema(ctx, req.Schema, req.SchemaSHA256)
	if e != nil {
		return nil, e
	}
	if req.ExportIndex < 0 || req.ExportIndex >= len(p.Exports) {
		return nil, fmt.Errorf("%w: export index", ErrInvalid)
	}
	ex := p.Exports[req.ExportIndex]
	name, _ := p.ResolveName(ex.ObjectName)
	if name != req.ExportObject || ex.Outer != 0 || ex.Class >= 0 {
		return nil, fmt.Errorf("%w: expected top-level export", ErrUnsupported)
	}
	class, e := findImportIdentity(ctx, p, ImportIdentity{s.ClassPath, "/Script/CoreUObject", "Class"})
	if e != nil {
		return nil, e
	}
	if ex.Class != class {
		return nil, fmt.Errorf("%w: schema/export class mismatch", ErrUnsupported)
	}
	stale, e := findImportIdentity(ctx, p, req.Stale)
	if e != nil {
		return nil, e
	}
	safe, e := findImportIdentity(ctx, p, req.Safe)
	if e != nil {
		return nil, e
	}
	if stale == safe || stale == class || safe == class {
		return nil, fmt.Errorf("%w: distinct class references required", ErrInvalid)
	}
	fields, e := readFixedProperties(ctx, p, x, ex, s)
	if e != nil {
		return nil, e
	}
	f := fields.Target
	if f.Offset != req.ExpectedSerializedOffset {
		return nil, fmt.Errorf("%w: derived serialized offset mismatch", ErrInvalid)
	}
	if int32(binary.LittleEndian.Uint32(x[f.Offset:f.Offset+4])) != stale {
		return nil, fmt.Errorf("%w: property prior reference mismatch", ErrInvalid)
	}
	dep, e := checkedPreload(ctx, p, req, stale)
	if e != nil {
		return nil, e
	}
	if dep < 0 || dep > len(h)-4 || int32(binary.LittleEndian.Uint32(h[dep:dep+4])) != stale {
		return nil, fmt.Errorf("%w: preload byte invariant", ErrInvalid)
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	// These are the only two writes to the snapshotted data. No memmem replacement.
	binary.LittleEndian.PutUint32(h[dep:dep+4], uint32(safe))
	binary.LittleEndian.PutUint32(x[f.Offset:f.Offset+4], 0)
	result, e := Read(ctx, h, x, opt)
	if e != nil {
		return nil, e
	}
	reread, e := readFixedProperties(ctx, result, x, result.Exports[req.ExportIndex], s)
	if e != nil {
		return nil, e
	}
	if reread.Target != f || binary.LittleEndian.Uint32(x[f.Offset:f.Offset+4]) != 0 || result.Preload[req.PreloadIndex] != safe {
		return nil, fmt.Errorf("%w: post-process verification invariant", ErrInvalid)
	}
	if result.HeaderSHA256 != req.ResultHeaderSHA256 || result.ExportDataSHA256 != req.ResultExportSHA256 {
		return nil, fmt.Errorf("%w: result SHA-256 mismatch", ErrInvalid)
	}
	r := PostProcessReport{
		SchemaSHA256: req.SchemaSHA256, HeaderBefore: req.HeaderSHA256, ExportBefore: req.ExportSHA256,
		HeaderAfter: result.HeaderSHA256, ExportAfter: result.ExportDataSHA256, ExportIndex: req.ExportIndex,
		Field: PostProcessField, SchemaIndex: f.SchemaIndex, ExportRelativeOffset: f.Offset - int(ex.SerialOffset-int64(p.Summary.HeaderSize)),
		LogicalOffset: int64(p.Summary.HeaderSize) + int64(f.Offset), ParsedPrefixEnd: fields.End,
		OpaqueExportTailBytes: int(ex.SerialOffset-int64(p.Summary.HeaderSize)+ex.SerialSize) - fields.End,
		Edits:                 []ReferenceEdit{{"uasset", dep, stale, safe}, {"uexp", f.Offset, stale, 0}}, ExternalSchemaRequired: true,
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	return &PostProcessResult{Header: h, ExportData: x, Package: result, Report: r}, nil
}
