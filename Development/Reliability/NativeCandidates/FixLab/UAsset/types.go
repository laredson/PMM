// Package uasset reads an explicit cooked UE5.1 layout. RECONSTRUCTION, not
// recovered FixLab source. It never loads objects, parses properties or writes files.
package uasset

import (
	"errors"
	"fmt"
)

const CookedUE51 = "cooked-ue4-522-ue5-1008"

var (
	ErrInvalid     = errors.New("invalid UAsset")
	ErrUnsupported = errors.New("unsupported UAsset profile or section")
	ErrLimit       = errors.New("UAsset resource limit")
)

type Limits struct{ HeaderBytes, ExportBytes, StringBytes, Names, Objects, Dependencies, Generations int }

func DefaultLimits() Limits { return Limits{64 << 20, 256 << 20, 8192, 65536, 16384, 262144, 128} }
func (l Limits) checked() (Limits, error) {
	cap := DefaultLimits()
	dst := []*int{&l.HeaderBytes, &l.ExportBytes, &l.StringBytes, &l.Names, &l.Objects, &l.Dependencies, &l.Generations}
	max := []int{cap.HeaderBytes, cap.ExportBytes, cap.StringBytes, cap.Names, cap.Objects, cap.Dependencies, cap.Generations}
	for i, p := range dst {
		if *p == 0 {
			*p = max[i]
		}
		if *p < 1 || *p > max[i] {
			return l, fmt.Errorf("%w: option %d", ErrLimit, i)
		}
	}
	return l, nil
}

// Profile is mandatory. AllowUnversioned is an explicit, externally established
// layout assertion, not version detection. Supplying it does not prove that assertion.
type Options struct {
	Profile          string
	AllowUnversioned bool
	Limits           Limits
}
type Span struct {
	Offset int `json:"offset"`
	Size   int `json:"size"`
}
type Section struct {
	Name string `json:"name"`
	Span
}
type Name struct {
	Text      string `json:"text"`
	UTF16     bool   `json:"utf16"`
	HashLower uint16 `json:"hashLower"`
	HashCase  uint16 `json:"hashCase"`
	Span
}
type FName struct {
	Index  int32 `json:"index"`
	Number int32 `json:"number"`
}
type Import struct {
	ClassPackage FName `json:"classPackage"`
	ClassName    FName `json:"className"`
	Outer        int32 `json:"outer"`
	ObjectName   FName `json:"objectName"`
	Optional     bool  `json:"optional"`
	Span
}
type Export struct {
	Class                                         int32  `json:"class"`
	Super                                         int32  `json:"super"`
	Template                                      int32  `json:"template"`
	Outer                                         int32  `json:"outer"`
	ObjectName                                    FName  `json:"objectName"`
	ObjectFlags                                   uint32 `json:"objectFlags"`
	SerialSize                                    int64  `json:"serialSize"`
	SerialOffset                                  int64  `json:"serialOffset"`
	Forced, NotForClient, NotForServer, Inherited bool
	PackageFlags                                  uint32 `json:"packageFlags"`
	NotAlwaysLoaded, IsAsset, PublicHash          bool
	FirstDependency                               int32    `json:"firstDependency"`
	DependencyCounts                              [4]int32 `json:"dependencyCounts"`
	Span
}
type EngineVersion struct {
	Major, Minor, Patch uint16
	Changelist          uint32
	Branch              string
}
type Generation struct{ Exports, Names int32 }
type Summary struct {
	Legacy, UE3, UE4, UE5, Licensee                                                       int32
	Unversioned                                                                           bool
	HeaderSize                                                                            int32
	Folder                                                                                string
	Flags                                                                                 uint32
	NameCount, NameOffset, SoftObjectCount, SoftObjectOffset                              int32
	GatherCount, GatherOffset, ExportCount, ExportOffset, ImportCount, ImportOffset       int32
	DependsOffset, SoftPackageCount, SoftPackageOffset, SearchableOffset, ThumbnailOffset int32
	GUID                                                                                  string
	Generations                                                                           []Generation
	SavedEngine, CompatibleEngine                                                         EngineVersion
	CompressionFlags                                                                      uint32
	PackageSource                                                                         uint32
	AssetRegistryOffset                                                                   int32
	BulkDataStart                                                                         int64
	WorldTileOffset                                                                       int32
	ChunkIDs                                                                              []int32
	PreloadCount, PreloadOffset, NamesReferenced                                          int32
	PayloadToc                                                                            int64
}
type Package struct {
	Profile             string          `json:"profile"`
	Summary             Summary         `json:"summary"`
	Names               []Name          `json:"names"`
	Imports             []Import        `json:"imports"`
	Exports             []Export        `json:"exports"`
	Depends             [][]int32       `json:"depends"`
	Preload             []int32         `json:"preload"`
	Sections            []Section       `json:"sections"`
	Opaque              []Section       `json:"opaque"`
	Fields              map[string]Span `json:"fields"`
	HeaderSHA256        string          `json:"headerSha256"`
	ExportRangesChecked bool            `json:"exportRangesChecked"`
	ExportDataSHA256    string          `json:"exportDataSha256,omitempty"`
	// Properties, bulk data and opaque-section internals are not interpreted.
}

func (p *Package) ResolveName(n FName) (string, error) {
	if p == nil || n.Index < 0 || int64(n.Index) >= int64(len(p.Names)) || n.Number < 0 {
		return "", fmt.Errorf("%w: FName", ErrInvalid)
	}
	s := p.Names[n.Index].Text
	if n.Number > 0 {
		s += fmt.Sprintf("_%d", n.Number-1)
	}
	return s, nil
}
