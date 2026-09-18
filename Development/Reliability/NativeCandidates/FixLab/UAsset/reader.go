package uasset

import (
	"context"
	"fmt"
	"sort"
)

// Read inspects separate .uasset bytes. A nil exportData means header-only:
// serial extents are checked for arithmetic/overlap, not for data availability.
// Non-nil exportData supplies the .uexp bytes (which remain opaque). Both inputs
// must remain immutable for the duration of the call. Nothing is loaded/executed.
func Read(ctx context.Context, header, exportData []byte, opt Options) (*Package, error) {
	if ctx == nil {
		return nil, fmt.Errorf("%w: nil context", ErrInvalid)
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	if opt.Profile != CookedUE51 {
		return nil, fmt.Errorf("%w: explicit profile required", ErrUnsupported)
	}
	lim, e := opt.Limits.checked()
	if e != nil {
		return nil, e
	}
	if len(header) > lim.HeaderBytes || len(exportData) > lim.ExportBytes {
		return nil, fmt.Errorf("%w: input bytes", ErrLimit)
	}
	p := &Package{Profile: CookedUE51, Fields: map[string]Span{}}
	r := &reader{ctx: ctx, b: header, end: len(header), limits: lim, fields: p.Fields}
	p.Summary = readSummary(r, opt)
	if r.err != nil {
		return nil, r.err
	}
	s := p.Summary
	summaryEnd := r.pos
	p.Sections = append(p.Sections, Section{"summary", Span{0, summaryEnd}})
	for _, x := range []struct {
		n    int32
		max  int
		name string
	}{{s.NameCount, lim.Names, "names"}, {s.ImportCount, lim.Objects, "imports"}, {s.ExportCount, lim.Objects, "exports"}} {
		if x.n < 0 {
			return nil, fmt.Errorf("%w: negative %s count", ErrInvalid, x.name)
		}
		if int64(x.n) > int64(x.max) {
			return nil, fmt.Errorf("%w: %s", ErrLimit, x.name)
		}
	}
	if int64(s.ImportCount)+int64(s.ExportCount) > int64(lim.Objects) {
		return nil, fmt.Errorf("%w: total objects", ErrLimit)
	}
	preload := s.PreloadCount
	if preload == -1 && s.PreloadOffset == 0 {
		preload = 0
	}
	if preload < 0 || int64(preload) > int64(lim.Dependencies) {
		return nil, fmt.Errorf("%w: preload count", ErrLimit)
	}
	// Any marker must lie outside the summary and within this header, even for a
	// zero-count optional list. Distinct nonempty sections cannot share a marker.
	markers := []int{len(header)}
	used := map[int]string{}
	slots := []struct {
		name   string
		off    int32
		active bool
	}{
		{"names", s.NameOffset, s.NameCount > 0}, {"imports", s.ImportOffset, s.ImportCount > 0}, {"exports", s.ExportOffset, s.ExportCount > 0},
		{"depends", s.DependsOffset, s.DependsOffset > 0 && s.ExportCount > 0}, {"preload", s.PreloadOffset, preload > 0},
		{"assetRegistry", s.AssetRegistryOffset, s.AssetRegistryOffset > 0},
		{"softObjects", s.SoftObjectOffset, false}, {"gatherableText", s.GatherOffset, false}, {"softPackages", s.SoftPackageOffset, false},
	}
	for _, slot := range slots {
		off := int64(slot.off)
		if off < 0 || (off != 0 && (off < int64(summaryEnd) || off > int64(len(header)))) || (slot.active && (off == 0 || off == int64(len(header)))) {
			return nil, fmt.Errorf("%w: %s offset", ErrInvalid, slot.name)
		}
		if slot.active {
			if old, ok := used[int(off)]; ok {
				return nil, fmt.Errorf("%w: %s overlaps %s", ErrInvalid, slot.name, old)
			}
			used[int(off)] = slot.name
			markers = append(markers, int(off))
		}
	}
	sort.Ints(markers)
	open := func(off int32) *reader {
		end := len(header)
		for _, m := range markers {
			if m > int(off) {
				end = m
				break
			}
		}
		return &reader{ctx: ctx, b: header, pos: int(off), end: end, limits: lim}
	}
	closeSection := func(name string, start int32, q *reader) error {
		if q.err != nil {
			return q.err
		}
		p.Sections = append(p.Sections, Section{name, Span{int(start), q.pos - int(start)}})
		return nil
	}
	if s.NameCount > 0 {
		q := open(s.NameOffset)
		if int64(s.NameCount)*8 > int64(q.end-q.pos) {
			return nil, fmt.Errorf("%w: name table cannot fit", ErrInvalid)
		}
		for i := int32(0); i < s.NameCount && q.err == nil; i++ {
			start := q.pos
			text, wide := q.str()
			lo, hi := q.u16(), q.u16()
			p.Names = append(p.Names, Name{text, wide, lo, hi, Span{start, q.pos - start}})
		}
		if e := closeSection("names", s.NameOffset, q); e != nil {
			return nil, e
		}
	}
	if s.ImportCount > 0 {
		q := open(s.ImportOffset)
		if int64(s.ImportCount)*32 > int64(q.end-q.pos) {
			return nil, fmt.Errorf("%w: import table cannot fit", ErrInvalid)
		}
		for i := int32(0); i < s.ImportCount && q.err == nil; i++ {
			start := q.pos
			v := Import{ClassPackage: q.fname(len(p.Names)), ClassName: q.fname(len(p.Names)), Outer: q.i32(), ObjectName: q.fname(len(p.Names)), Optional: q.boolean()}
			v.Span = Span{start, q.pos - start}
			p.Imports = append(p.Imports, v)
		}
		if e := closeSection("imports", s.ImportOffset, q); e != nil {
			return nil, e
		}
	}
	if s.ExportCount > 0 {
		q := open(s.ExportOffset)
		if int64(s.ExportCount)*96 > int64(q.end-q.pos) {
			return nil, fmt.Errorf("%w: export table cannot fit", ErrInvalid)
		}
		for i := int32(0); i < s.ExportCount && q.err == nil; i++ {
			start := q.pos
			v := Export{Class: q.i32(), Super: q.i32(), Template: q.i32(), Outer: q.i32(), ObjectName: q.fname(len(p.Names)), ObjectFlags: q.u32(), SerialSize: q.i64(), SerialOffset: q.i64()}
			v.Forced = q.boolean()
			v.NotForClient = q.boolean()
			v.NotForServer = q.boolean()
			v.Inherited = q.boolean()
			v.PackageFlags = q.u32()
			v.NotAlwaysLoaded = q.boolean()
			v.IsAsset = q.boolean()
			v.PublicHash = q.boolean()
			v.FirstDependency = q.i32()
			for j := range v.DependencyCounts {
				v.DependencyCounts[j] = q.i32()
			}
			v.Span = Span{start, q.pos - start}
			p.Exports = append(p.Exports, v)
		}
		if e := closeSection("exports", s.ExportOffset, q); e != nil {
			return nil, e
		}
	}
	validIndex := func(n int32) bool { return int64(n) >= -int64(s.ImportCount) && int64(n) <= int64(s.ExportCount) }
	if s.DependsOffset > 0 && s.ExportCount > 0 {
		q := open(s.DependsOffset)
		remaining := lim.Dependencies
		for i := int32(0); i < s.ExportCount && q.err == nil; i++ {
			n := q.count(remaining)
			remaining -= n
			if n > (q.end-q.pos)/4 {
				q.fail(ErrInvalid, "depends cannot fit")
				break
			}
			row := make([]int32, n)
			for j := range row {
				row[j] = q.i32()
				if !validIndex(row[j]) {
					q.fail(ErrInvalid, "depends index")
				}
			}
			p.Depends = append(p.Depends, row)
		}
		if e := closeSection("depends", s.DependsOffset, q); e != nil {
			return nil, e
		}
	}
	if preload > 0 {
		q := open(s.PreloadOffset)
		if int64(preload)*4 > int64(q.end-q.pos) {
			return nil, fmt.Errorf("%w: preload cannot fit", ErrInvalid)
		}
		for i := int32(0); i < preload && q.err == nil; i++ {
			v := q.i32()
			if !validIndex(v) {
				q.fail(ErrInvalid, "preload index")
			}
			p.Preload = append(p.Preload, v)
		}
		if e := closeSection("preload", s.PreloadOffset, q); e != nil {
			return nil, e
		}
	}
	// Validate all signed object references without negating INT32_MIN.
	for _, v := range p.Imports {
		if !validIndex(v.Outer) {
			return nil, fmt.Errorf("%w: import outer", ErrInvalid)
		}
	}
	for _, v := range p.Exports {
		for _, ref := range []int32{v.Class, v.Super, v.Template, v.Outer} {
			if !validIndex(ref) {
				return nil, fmt.Errorf("%w: export reference", ErrInvalid)
			}
		}
		total := int64(0)
		for _, n := range v.DependencyCounts {
			if n < 0 {
				return nil, fmt.Errorf("%w: dependency count", ErrInvalid)
			}
			total += int64(n)
		}
		if v.FirstDependency < -1 || (v.FirstDependency == -1 && total != 0) || (v.FirstDependency >= 0 && (int64(v.FirstDependency) > int64(preload) || total > int64(preload)-int64(v.FirstDependency))) {
			return nil, fmt.Errorf("%w: export dependency slice", ErrInvalid)
		}
	}
	if e := checkOuters(ctx, p); e != nil {
		return nil, e
	}
	// Logical export offsets include the header. Header-only mode never asserts
	// that the opaque .uexp bytes actually exist or contain valid properties.
	type extent struct{ start, end int64 }
	var extents []extent
	for _, v := range p.Exports {
		if e := ctx.Err(); e != nil {
			return nil, e
		}
		if v.SerialSize < 0 || v.SerialOffset < 0 {
			return nil, fmt.Errorf("%w: negative export range", ErrInvalid)
		}
		if v.SerialSize == 0 && v.SerialOffset == 0 {
			continue
		}
		off := v.SerialOffset - int64(s.HeaderSize)
		if off < 0 || off > int64(lim.ExportBytes) || v.SerialSize > int64(lim.ExportBytes)-off {
			return nil, fmt.Errorf("%w: export range outside profile", ErrInvalid)
		}
		if exportData != nil && (off > int64(len(exportData)) || v.SerialSize > int64(len(exportData))-off) {
			return nil, fmt.Errorf("%w: export data truncated", ErrInvalid)
		}
		if v.SerialSize > 0 {
			extents = append(extents, extent{off, off + v.SerialSize})
		}
	}
	sort.Slice(extents, func(i, j int) bool { return extents[i].start < extents[j].start })
	for i := 1; i < len(extents); i++ {
		if extents[i].start < extents[i-1].end {
			return nil, fmt.Errorf("%w: overlapping export data", ErrInvalid)
		}
	}
	// Preserve unknown spans explicitly instead of claiming every byte was parsed.
	if s.AssetRegistryOffset > 0 {
		q := open(s.AssetRegistryOffset)
		p.Opaque = append(p.Opaque, Section{"assetRegistry", Span{q.pos, q.end - q.pos}})
	}
	all := append([]Section{}, p.Sections...)
	all = append(all, p.Opaque...)
	sort.Slice(all, func(i, j int) bool { return all[i].Offset < all[j].Offset })
	cursor := 0
	for _, v := range all {
		if v.Offset < cursor {
			return nil, fmt.Errorf("%w: overlapping header sections", ErrInvalid)
		}
		if v.Offset > cursor {
			p.Opaque = append(p.Opaque, Section{"unparsedGap", Span{cursor, v.Offset - cursor}})
		}
		cursor = v.Offset + v.Size
	}
	if cursor < len(header) {
		p.Opaque = append(p.Opaque, Section{"unparsedTail", Span{cursor, len(header) - cursor}})
	}
	sort.Slice(p.Sections, func(i, j int) bool { return p.Sections[i].Offset < p.Sections[j].Offset })
	sort.Slice(p.Opaque, func(i, j int) bool { return p.Opaque[i].Offset < p.Opaque[j].Offset })
	p.HeaderSHA256, e = hashBytes(ctx, header)
	if e != nil {
		return nil, e
	}
	if exportData != nil {
		p.ExportDataSHA256, e = hashBytes(ctx, exportData)
		if e != nil {
			return nil, e
		}
		p.ExportRangesChecked = true
	}
	if e := ctx.Err(); e != nil {
		return nil, e
	}
	return p, nil
}

func checkOuters(ctx context.Context, p *Package) error {
	n := len(p.Imports) + len(p.Exports)
	color := make([]uint8, n)
	refNode := func(v int32) int {
		if v < 0 {
			return int(-int64(v) - 1)
		}
		if v > 0 {
			return len(p.Imports) + int(v) - 1
		}
		return -1
	}
	next := func(i int) int {
		if i < len(p.Imports) {
			return refNode(p.Imports[i].Outer)
		}
		return refNode(p.Exports[i-len(p.Imports)].Outer)
	}
	for start := 0; start < n; start++ {
		if e := ctx.Err(); e != nil {
			return e
		}
		if color[start] != 0 {
			continue
		}
		trail := []int{}
		i := start
		for i >= 0 && color[i] == 0 {
			if e := ctx.Err(); e != nil {
				return e
			}
			color[i] = 1
			trail = append(trail, i)
			i = next(i)
		}
		if i >= 0 && color[i] == 1 {
			return fmt.Errorf("%w: cyclic outer references", ErrInvalid)
		}
		for _, j := range trail {
			color[j] = 2
		}
	}
	return nil
}
