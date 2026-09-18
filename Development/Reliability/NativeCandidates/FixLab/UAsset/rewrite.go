package uasset

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/hex"
	"fmt"
)

// NameSource is an externally approved header containing the EXACT serialized
// name/hash entries to import. A matching digest proves identity, not approval.
// The caller must obtain expected hashes independently of these untrusted bytes.
type NameSource struct {
	Header []byte
	SHA256 string
}

// NameEdit replaces one existing slot. It never appends, deduplicates, reorders
// or changes FName indices. No arbitrary replacement text or computed CRC API.
type NameEdit struct{ Index, Source, SourceIndex int }
type RewriteRequest struct {
	HeaderSHA256, ExportSHA256 string
	Sources                    []NameSource
	Edits                      []NameEdit
}
type OffsetChange struct {
	Field       string `json:"field"`
	OldPosition int    `json:"oldPosition"`
	NewPosition int    `json:"newPosition"`
	Width       int    `json:"width"`
	Old         int64  `json:"old"`
	New         int64  `json:"new"`
}
type RewriteReport struct {
	HeaderBefore      string         `json:"headerBefore"`
	HeaderAfter       string         `json:"headerAfter"`
	ExportSHA256      string         `json:"exportSha256"`
	Sources           []string       `json:"sources"`
	Edits             []NameEdit     `json:"edits"`
	HeaderDelta       int            `json:"headerDelta"`
	NameLayoutChanged bool           `json:"nameLayoutChanged"`
	Offsets           []OffsetChange `json:"offsets"`
	Changed           bool           `json:"changed"`
	// This result does not certify property semantics or engine compatibility.
}
type RewriteResult struct {
	Header     []byte
	ExportData []byte
	Package    *Package
	Report     RewriteReport
}

const MaxNameSources = 8

func copyChecked(ctx context.Context, dst, src []byte) error {
	if len(dst) != len(src) {
		return fmt.Errorf("%w: copy extent", ErrInvalid)
	}
	for pos := 0; pos < len(src); {
		if e := ctx.Err(); e != nil {
			return e
		}
		end := pos + 65536
		if end > len(src) {
			end = len(src)
		}
		copy(dst[pos:end], src[pos:end])
		pos = end
	}
	return ctx.Err()
}
func pinnedSnapshot(ctx context.Context, b []byte, expected string, max int) ([]byte, error) {
	if len(b) > max {
		return nil, fmt.Errorf("%w: snapshot", ErrLimit)
	}
	if len(expected) != 64 {
		return nil, fmt.Errorf("%w: mandatory 64-character SHA-256", ErrInvalid)
	}
	d, e := hex.DecodeString(expected)
	if e != nil || len(d) != 32 || hex.EncodeToString(d) != expected {
		return nil, fmt.Errorf("%w: mandatory canonical SHA-256", ErrInvalid)
	}
	out := make([]byte, len(b))
	if e = copyChecked(ctx, out, b); e != nil {
		return nil, e
	}
	actual, e := hashBytes(ctx, out)
	if e != nil {
		return nil, e
	}
	if actual != expected {
		return nil, fmt.Errorf("%w: input SHA-256 mismatch", ErrInvalid)
	}
	return out, nil
}

// RewriteNames reconstructs the name table by importing complete validated raw
// entries, preserving their FString encoding, terminator representation and hashes.
// All inputs must be immutable during this call (including edits and sources).
// Snapshot copies are pinned BEFORE parsing. A non-nil .uexp is mandatory, even
// when empty; header-only inspection is NOT permission to rewrite unseen data.
//
// Without layout changes: all positions and opaque bytes are preserved exactly.
// With ANY name-slot width change, including net-zero changes: reject opaque
// header regions, nonempty .uexp and nonzero BulkDataStart. Unknown payloads may
// contain absolute offsets; copying them unchanged while shifting is not safe.
// This deliberate limitation remains until an audited payload serializer exists.
//
// This is NOT a whole-package rename/core-R1 operation. It does not patch property
// values, GUIDs, object names outside the chosen slots, or external name caches.
// Errors return nil. No filesystem, subprocess, network or installation side effects.
func RewriteNames(ctx context.Context, header, exportData []byte, opt Options, req RewriteRequest) (*RewriteResult, error) {
	if ctx == nil {
		return nil, fmt.Errorf("%w: nil context", ErrInvalid)
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	if exportData == nil {
		return nil, fmt.Errorf("%w: supply explicit export data, even when empty", ErrUnsupported)
	}
	lim, e := opt.Limits.checked()
	if e != nil {
		return nil, e
	}
	if len(req.Sources) > MaxNameSources || len(req.Edits) > lim.Names {
		return nil, fmt.Errorf("%w: name sources/edits", ErrLimit)
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
	// Bound aggregate reference input before copying/parsing any source.
	aggregate := 0
	for _, s := range req.Sources {
		if len(s.Header) > lim.HeaderBytes-aggregate {
			return nil, fmt.Errorf("%w: aggregate source headers", ErrLimit)
		}
		aggregate += len(s.Header)
	}
	sourceBytes := make([][]byte, len(req.Sources))
	sourceMaps := make([]*Package, len(req.Sources))
	sourceHashes := make([]string, len(req.Sources))
	for i, s := range req.Sources {
		sourceBytes[i], e = pinnedSnapshot(ctx, s.Header, s.SHA256, lim.HeaderBytes)
		if e != nil {
			return nil, e
		}
		sourceMaps[i], e = Read(ctx, sourceBytes[i], nil, opt)
		if e != nil {
			return nil, e
		}
		sourceHashes[i] = s.SHA256
	}
	edits := append([]NameEdit(nil), req.Edits...)
	replacement := make(map[int][]byte, len(edits))
	layoutChanged := false
	total := 0
	for _, edit := range edits {
		if e := ctx.Err(); e != nil {
			return nil, e
		}
		if edit.Index < 0 || edit.Index >= len(p.Names) || edit.Source < 0 || edit.Source >= len(sourceMaps) || edit.SourceIndex < 0 || edit.SourceIndex >= len(sourceMaps[edit.Source].Names) {
			return nil, fmt.Errorf("%w: name edit index", ErrInvalid)
		}
		if _, seen := replacement[edit.Index]; seen {
			return nil, fmt.Errorf("%w: duplicate name edit", ErrInvalid)
		}
		n := sourceMaps[edit.Source].Names[edit.SourceIndex]
		raw := sourceBytes[edit.Source][n.Offset : n.Offset+n.Size]
		replacement[edit.Index] = raw
		if len(raw) != p.Names[edit.Index].Size {
			layoutChanged = true
		}
	}
	start, end := int(p.Summary.NameOffset), int(p.Summary.NameOffset)
	if len(p.Names) > 0 {
		start = p.Names[0].Offset
		last := p.Names[len(p.Names)-1]
		end = last.Offset + last.Size
	}
	for i, n := range p.Names {
		if e := ctx.Err(); e != nil {
			return nil, e
		}
		size := n.Size
		if raw, ok := replacement[i]; ok {
			size = len(raw)
		}
		if size > lim.HeaderBytes-total {
			return nil, fmt.Errorf("%w: name table size", ErrLimit)
		}
		total += size
	}
	delta := total - (end - start)
	if total > lim.HeaderBytes-(len(h)-(end-start)) {
		return nil, fmt.Errorf("%w: rebuilt header", ErrLimit)
	}
	if layoutChanged && (len(p.Opaque) != 0 || len(x) != 0 || p.Summary.BulkDataStart != 0) {
		return nil, fmt.Errorf("%w: moving names requires no opaque header/data and no bulk offset", ErrUnsupported)
	}
	out := make([]byte, len(h)+delta)
	if e = copyChecked(ctx, out[:start], h[:start]); e != nil {
		return nil, e
	}
	pos := start
	for i, n := range p.Names {
		raw, ok := replacement[i]
		if !ok {
			raw = h[n.Offset : n.Offset+n.Size]
		}
		if e = copyChecked(ctx, out[pos:pos+len(raw)], raw); e != nil {
			return nil, e
		}
		pos += len(raw)
	}
	if e = copyChecked(ctx, out[pos:], h[end:]); e != nil {
		return nil, e
	}
	report := RewriteReport{HeaderBefore: req.HeaderSHA256, ExportSHA256: req.ExportSHA256, Sources: sourceHashes, Edits: edits, HeaderDelta: delta, NameLayoutChanged: layoutChanged}
	// The splice does not move summary fields. Markers within the replaced table
	// have unknown meaning; even empty-list markers are rejected, never guessed.
	relocate := func(old int64) (int64, error) {
		if old == 0 || old <= int64(start) {
			return old, nil
		}
		if old < int64(end) {
			return 0, fmt.Errorf("%w: marker inside replaced names", ErrUnsupported)
		}
		return old + int64(delta), nil
	}
	writeField := func(label string, oldPos, newPos, width int, old, new int64) {
		if old == new {
			return
		}
		if width == 4 {
			binary.LittleEndian.PutUint32(out[newPos:newPos+4], uint32(new))
		} else {
			binary.LittleEndian.PutUint64(out[newPos:newPos+8], uint64(new))
		}
		report.Offsets = append(report.Offsets, OffsetChange{label, oldPos, newPos, width, old, new})
	}
	if layoutChanged {
		f := p.Fields["headerSize"]
		writeField("headerSize", f.Offset, f.Offset, 4, int64(len(h)), int64(len(out)))
		for _, label := range []string{"nameOffset", "softObjectOffset", "gatherOffset", "exportOffset", "importOffset", "dependsOffset", "softPackageOffset", "searchableOffset", "thumbnailOffset", "assetRegistryOffset", "worldTileOffset", "preloadOffset"} {
			f := p.Fields[label]
			old := int64(int32(binary.LittleEndian.Uint32(h[f.Offset : f.Offset+4])))
			moved, err := relocate(old)
			if err != nil {
				return nil, err
			}
			if moved < 0 || moved > int64(len(out)) {
				return nil, fmt.Errorf("%w: moved header marker", ErrInvalid)
			}
			writeField(label, f.Offset, f.Offset, 4, old, moved)
		}
		for i, v := range p.Exports {
			if v.SerialOffset == 0 && v.SerialSize == 0 {
				continue
			}
			// Offsets are logical .uasset+.uexp coordinates, not a .uexp file position.
			relative := v.SerialOffset - int64(p.Summary.HeaderSize)
			moved := int64(len(out)) + relative
			newPos, err := relocate(int64(v.Offset + 36))
			if err != nil {
				return nil, err
			}
			writeField(fmt.Sprintf("exports[%d].serialOffset", i), v.Offset+36, int(newPos), 8, v.SerialOffset, moved)
		}
	}
	verified, e := Read(ctx, out, x, opt)
	if e != nil {
		return nil, e
	}
	if verified.Summary.NameCount != p.Summary.NameCount || len(verified.Exports) != len(p.Exports) || len(verified.Imports) != len(p.Imports) {
		return nil, fmt.Errorf("%w: rewrite count invariant", ErrInvalid)
	}
	for i, n := range verified.Names {
		if e := ctx.Err(); e != nil {
			return nil, e
		}
		want, ok := replacement[i]
		if !ok {
			old := p.Names[i]
			want = h[old.Offset : old.Offset+old.Size]
		}
		if !bytes.Equal(out[n.Offset:n.Offset+n.Size], want) {
			return nil, fmt.Errorf("%w: name bytes invariant", ErrInvalid)
		}
	}
	for i, v := range verified.Exports {
		old := p.Exports[i]
		if old.SerialSize != v.SerialSize || (old.SerialOffset == 0 && v.SerialOffset != 0) || (old.SerialOffset != 0 && v.SerialOffset-int64(verified.Summary.HeaderSize) != old.SerialOffset-int64(p.Summary.HeaderSize)) {
			return nil, fmt.Errorf("%w: logical export coordinate invariant", ErrInvalid)
		}
	}
	report.HeaderAfter = verified.HeaderSHA256
	report.Changed = report.HeaderBefore != report.HeaderAfter
	if e = ctx.Err(); e != nil {
		return nil, e
	}
	return &RewriteResult{Header: out, ExportData: x, Package: verified, Report: report}, nil
}
