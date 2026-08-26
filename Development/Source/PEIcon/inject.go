// Command peicon injects a Windows ICO as RT_ICON/RT_GROUP_ICON resources into
// a freshly linked PE32+ executable. It is intentionally dependency-free so
// PMM's Windows build scripts can embed the application icon without requiring
// windres, Resource Hacker, Python, or another third-party build tool.
//
// PMM's Go executables are linked without a .rsrc section. This tool validates
// that assumption and appends one resource section, updating the PE headers.
package main

import (
	"encoding/binary"
	"errors"
	"flag"
	"fmt"
	"os"
)

const (
	pe32PlusMagic           = 0x20b
	resourceDirectoryIndex  = 2
	imageScnCntInitialized  = 0x00000040
	imageScnMemRead         = 0x40000000
	resourceDirSubdirectory = 0x80000000
	rtIcon                  = 3
	rtGroupIcon             = 14
	defaultLanguageID       = 1033
)

type iconEntry struct {
	width, height, colorCount, reserved byte
	planes, bitCount                    uint16
	bytesInRes, imageOffset             uint32
	data                                []byte
}

type section struct {
	virtualSize, virtualAddress uint32
	rawSize, rawOffset          uint32
}

func main() {
	exe := flag.String("exe", "", "PE32+ executable to update")
	ico := flag.String("ico", "", "ICO file to embed")
	flag.Parse()
	if *exe == "" || *ico == "" {
		flag.Usage()
		os.Exit(2)
	}
	if err := inject(*exe, *ico); err != nil {
		fmt.Fprintln(os.Stderr, "peicon:", err)
		os.Exit(1)
	}
}

func inject(exePath, icoPath string) error {
	pe, err := os.ReadFile(exePath)
	if err != nil {
		return err
	}
	icons, err := readICO(icoPath)
	if err != nil {
		return err
	}
	if len(icons) == 0 {
		return errors.New("ICO contains no images")
	}
	if len(pe) < 0x100 {
		return errors.New("file is too small to be a PE executable")
	}

	peOff := int(binary.LittleEndian.Uint32(pe[0x3c:0x40]))
	if peOff < 0 || peOff+24 > len(pe) || string(pe[peOff:peOff+4]) != "PE\x00\x00" {
		return errors.New("invalid PE signature")
	}
	coff := peOff + 4
	numSections := int(binary.LittleEndian.Uint16(pe[coff+2 : coff+4]))
	optSize := int(binary.LittleEndian.Uint16(pe[coff+16 : coff+18]))
	opt := coff + 20
	if opt+optSize > len(pe) || optSize < 112+16*3 {
		return errors.New("invalid optional header")
	}
	if binary.LittleEndian.Uint16(pe[opt:opt+2]) != pe32PlusMagic {
		return errors.New("only PE32+ executables are supported")
	}

	sectionAlignment := binary.LittleEndian.Uint32(pe[opt+32 : opt+36])
	fileAlignment := binary.LittleEndian.Uint32(pe[opt+36 : opt+40])
	sizeOfImage := binary.LittleEndian.Uint32(pe[opt+56 : opt+60])
	sizeOfHeaders := binary.LittleEndian.Uint32(pe[opt+60 : opt+64])
	if sectionAlignment == 0 || fileAlignment == 0 {
		return errors.New("invalid PE alignment")
	}

	dataDir := opt + 112
	resourceEntry := dataDir + resourceDirectoryIndex*8
	if binary.LittleEndian.Uint32(pe[resourceEntry:resourceEntry+4]) != 0 || binary.LittleEndian.Uint32(pe[resourceEntry+4:resourceEntry+8]) != 0 {
		return errors.New("executable already contains a resource directory; rebuild a fresh binary before injection")
	}

	sectionTable := opt + optSize
	if sectionTable+numSections*40 > len(pe) {
		return errors.New("invalid section table")
	}
	if sectionTable+(numSections+1)*40 > int(sizeOfHeaders) {
		return errors.New("PE header has no room for an additional section")
	}

	var sections []section
	var maxVAEnd uint32
	for i := 0; i < numSections; i++ {
		h := sectionTable + i*40
		sec := section{
			virtualSize:    binary.LittleEndian.Uint32(pe[h+8 : h+12]),
			virtualAddress: binary.LittleEndian.Uint32(pe[h+12 : h+16]),
			rawSize:        binary.LittleEndian.Uint32(pe[h+16 : h+20]),
			rawOffset:      binary.LittleEndian.Uint32(pe[h+20 : h+24]),
		}
		sections = append(sections, sec)
		span := sec.virtualSize
		if sec.rawSize > span {
			span = sec.rawSize
		}
		end := sec.virtualAddress + span
		if end > maxVAEnd {
			maxVAEnd = end
		}
	}

	newVA := align(maxU32(maxVAEnd, sizeOfImage), sectionAlignment)
	rsrc := buildResourceSection(icons, newVA)
	rawOff := align(uint32(len(pe)), fileAlignment)
	rawSize := align(uint32(len(rsrc)), fileAlignment)

	if uint64(rawOff)+uint64(rawSize) > uint64(^uint32(0)) {
		return errors.New("resulting PE would exceed 4 GiB")
	}
	if int(rawOff) > len(pe) {
		pe = append(pe, make([]byte, int(rawOff)-len(pe))...)
	}
	pe = append(pe, rsrc...)
	if pad := int(rawSize) - len(rsrc); pad > 0 {
		pe = append(pe, make([]byte, pad)...)
	}

	// Add .rsrc section header.
	h := sectionTable + numSections*40
	copy(pe[h:h+8], []byte{'.', 'r', 's', 'r', 'c', 0, 0, 0})
	binary.LittleEndian.PutUint32(pe[h+8:h+12], uint32(len(rsrc)))
	binary.LittleEndian.PutUint32(pe[h+12:h+16], newVA)
	binary.LittleEndian.PutUint32(pe[h+16:h+20], rawSize)
	binary.LittleEndian.PutUint32(pe[h+20:h+24], rawOff)
	binary.LittleEndian.PutUint32(pe[h+36:h+40], imageScnCntInitialized|imageScnMemRead)

	binary.LittleEndian.PutUint16(pe[coff+2:coff+4], uint16(numSections+1))
	initialized := binary.LittleEndian.Uint32(pe[opt+8 : opt+12])
	binary.LittleEndian.PutUint32(pe[opt+8:opt+12], initialized+rawSize)
	binary.LittleEndian.PutUint32(pe[opt+56:opt+60], align(newVA+uint32(len(rsrc)), sectionAlignment))
	binary.LittleEndian.PutUint32(pe[resourceEntry:resourceEntry+4], newVA)
	binary.LittleEndian.PutUint32(pe[resourceEntry+4:resourceEntry+8], uint32(len(rsrc)))

	tmp := exePath + ".icon.tmp"
	if err := os.WriteFile(tmp, pe, 0755); err != nil {
		return err
	}
	if err := os.Rename(tmp, exePath); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	return nil
}

func readICO(path string) ([]iconEntry, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if len(b) < 6 {
		return nil, errors.New("ICO header is truncated")
	}
	if binary.LittleEndian.Uint16(b[0:2]) != 0 || binary.LittleEndian.Uint16(b[2:4]) != 1 {
		return nil, errors.New("input is not a Windows icon file")
	}
	count := int(binary.LittleEndian.Uint16(b[4:6]))
	if count <= 0 || count > 256 || len(b) < 6+count*16 {
		return nil, errors.New("invalid ICO directory")
	}
	out := make([]iconEntry, 0, count)
	for i := 0; i < count; i++ {
		o := 6 + i*16
		e := iconEntry{
			width: b[o], height: b[o+1], colorCount: b[o+2], reserved: b[o+3],
			planes:      binary.LittleEndian.Uint16(b[o+4 : o+6]),
			bitCount:    binary.LittleEndian.Uint16(b[o+6 : o+8]),
			bytesInRes:  binary.LittleEndian.Uint32(b[o+8 : o+12]),
			imageOffset: binary.LittleEndian.Uint32(b[o+12 : o+16]),
		}
		end := uint64(e.imageOffset) + uint64(e.bytesInRes)
		if e.bytesInRes == 0 || end > uint64(len(b)) {
			return nil, fmt.Errorf("ICO image %d is out of bounds", i)
		}
		e.data = append([]byte(nil), b[e.imageOffset:uint32(end)]...)
		out = append(out, e)
	}
	return out, nil
}

func buildResourceSection(icons []iconEntry, sectionRVA uint32) []byte {
	// Directories: root; RT_ICON id list; RT_GROUP_ICON id list; one language
	// directory for every icon plus one for the group.
	n := len(icons)
	rootOff := uint32(0)
	iconTypeOff := uint32(16 + 2*8)
	groupTypeOff := iconTypeOff + uint32(16+n*8)
	langBase := groupTypeOff + uint32(16+1*8)
	groupLangOff := langBase + uint32(n*24)
	dataEntryBase := groupLangOff + 24
	dataCount := n + 1
	blobBase := align(dataEntryBase+uint32(dataCount*16), 4)

	// Group icon data is placed first, followed by each image payload.
	groupData := make([]byte, 6+n*14)
	binary.LittleEndian.PutUint16(groupData[0:2], 0)
	binary.LittleEndian.PutUint16(groupData[2:4], 1)
	binary.LittleEndian.PutUint16(groupData[4:6], uint16(n))
	for i, e := range icons {
		o := 6 + i*14
		groupData[o] = e.width
		groupData[o+1] = e.height
		groupData[o+2] = e.colorCount
		groupData[o+3] = e.reserved
		binary.LittleEndian.PutUint16(groupData[o+4:o+6], e.planes)
		binary.LittleEndian.PutUint16(groupData[o+6:o+8], e.bitCount)
		binary.LittleEndian.PutUint32(groupData[o+8:o+12], e.bytesInRes)
		binary.LittleEndian.PutUint16(groupData[o+12:o+14], uint16(i+1))
	}

	total := blobBase + uint32(len(groupData))
	total = align(total, 4)
	imageOffsets := make([]uint32, n)
	for i, e := range icons {
		imageOffsets[i] = total
		total += uint32(len(e.data))
		total = align(total, 4)
	}
	b := make([]byte, total)

	writeDir := func(off uint32, idCount uint16) {
		binary.LittleEndian.PutUint16(b[off+14:off+16], idCount)
	}
	writeEntry := func(off uint32, id uint32, target uint32, subdir bool) {
		binary.LittleEndian.PutUint32(b[off:off+4], id)
		if subdir {
			target |= resourceDirSubdirectory
		}
		binary.LittleEndian.PutUint32(b[off+4:off+8], target)
	}

	writeDir(rootOff, 2)
	writeEntry(rootOff+16, rtIcon, iconTypeOff, true)
	writeEntry(rootOff+24, rtGroupIcon, groupTypeOff, true)

	writeDir(iconTypeOff, uint16(n))
	for i := 0; i < n; i++ {
		writeEntry(iconTypeOff+16+uint32(i*8), uint32(i+1), langBase+uint32(i*24), true)
	}
	writeDir(groupTypeOff, 1)
	writeEntry(groupTypeOff+16, 1, groupLangOff, true)

	// Language directories point directly to IMAGE_RESOURCE_DATA_ENTRY records.
	for i := 0; i < n; i++ {
		off := langBase + uint32(i*24)
		writeDir(off, 1)
		writeEntry(off+16, defaultLanguageID, dataEntryBase+uint32((i+1)*16), false)
	}
	writeDir(groupLangOff, 1)
	writeEntry(groupLangOff+16, defaultLanguageID, dataEntryBase, false)

	writeDataEntry := func(off, dataOff, size uint32) {
		binary.LittleEndian.PutUint32(b[off:off+4], sectionRVA+dataOff)
		binary.LittleEndian.PutUint32(b[off+4:off+8], size)
	}
	writeDataEntry(dataEntryBase, blobBase, uint32(len(groupData)))
	for i, e := range icons {
		writeDataEntry(dataEntryBase+uint32((i+1)*16), imageOffsets[i], uint32(len(e.data)))
	}

	copy(b[blobBase:], groupData)
	for i, e := range icons {
		copy(b[imageOffsets[i]:], e.data)
	}
	return b
}

func align(v, a uint32) uint32 {
	if a == 0 {
		return v
	}
	return (v + a - 1) &^ (a - 1)
}
func maxU32(a, b uint32) uint32 {
	if a > b {
		return a
	}
	return b
}
