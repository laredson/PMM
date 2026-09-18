// Static Go/PE inspection helper. It NEVER executes or loads the inspected EXE.
// Input scope: bounded AMD64 PE32+ built with the Go 1.20+ pclntab format.
package main

import (
	"bytes"
	"crypto/sha256"
	"debug/buildinfo"
	"debug/gosym"
	"debug/pe"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"
)

type function struct {
	Name   string `json:"name"`
	Entry  uint64 `json:"entryVA"`
	End    uint64 `json:"endVA"`
	Size   uint64 `json:"sizeBytes"`
	SHA256 string `json:"rawCodeSha256"`
}

func digest(data []byte) string { h := sha256.Sum256(data); return hex.EncodeToString(h[:]) }

func inspect(path string) (_ map[string]any, err error) {
	defer func() {
		if v := recover(); v != nil {
			err = fmt.Errorf("invalid Go metadata: %v", v)
		}
	}()
	st, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if !st.Mode().IsRegular() || st.Size() > 128*1024*1024 {
		return nil, fmt.Errorf("input must be a regular file <=128 MiB")
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	f, err := pe.NewFile(bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	defer f.Close()
	oh, ok := f.OptionalHeader.(*pe.OptionalHeader64)
	if !ok || f.Machine != pe.IMAGE_FILE_MACHINE_AMD64 {
		return nil, fmt.Errorf("expected AMD64 PE32+")
	}
	ts, rs := f.Section(".text"), f.Section(".rdata")
	if ts == nil || rs == nil {
		return nil, fmt.Errorf("missing .text/.rdata")
	}
	text, err := ts.Data()
	if err != nil {
		return nil, err
	}
	data, err := rs.Data()
	if err != nil {
		return nil, err
	}
	magic := []byte{0xf1, 0xff, 0xff, 0xff, 0, 0, 1, 8}
	at := bytes.Index(data, magic)
	if at < 0 || at+72 > len(data) {
		return nil, fmt.Errorf("supported Go pclntab not found")
	}
	pc := data[at:]
	n := binary.LittleEndian.Uint64(pc[8:16])
	if n == 0 || n > 100000 {
		return nil, fmt.Errorf("invalid function count")
	}
	// Validate all Go 1.20+ table offsets before handing input to debug/gosym.
	for off := 32; off <= 64; off += 8 {
		if binary.LittleEndian.Uint64(pc[off:off+8]) >= uint64(len(pc)) {
			return nil, fmt.Errorf("invalid pclntab offset")
		}
	}
	base := oh.ImageBase + uint64(ts.VirtualAddress)
	if binary.LittleEndian.Uint64(pc[24:32]) != base {
		return nil, fmt.Errorf("unexpected text start")
	}
	table, err := gosym.NewTable(nil, gosym.NewLineTable(pc, base))
	if err != nil {
		return nil, err
	}
	var funcs []function
	for _, fn := range table.Funcs {
		if !strings.HasPrefix(fn.Name, "main.") {
			continue
		}
		if fn.End < fn.Entry || fn.Entry < base || fn.End-base > uint64(len(text)) {
			return nil, fmt.Errorf("function outside .text")
		}
		funcs = append(funcs, function{fn.Name, fn.Entry, fn.End, fn.End - fn.Entry, digest(text[fn.Entry-base : fn.End-base])})
	}
	if len(funcs) == 0 {
		return nil, fmt.Errorf("no application functions found")
	}
	sort.Slice(funcs, func(i, j int) bool { return funcs[i].Name < funcs[j].Name })
	bi, err := buildinfo.Read(bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	settings := map[string]string{}
	for _, s := range bi.Settings {
		settings[s.Key] = s.Value
	}
	var deps []string
	for _, d := range bi.Deps {
		deps = append(deps, d.Path+" "+d.Version)
	}
	return map[string]any{
		"schema": "PMM_HOST_GO_STATIC_V1", "sha256": digest(b), "goVersion": bi.GoVersion,
		"modulePath": bi.Path, "settings": settings, "dependencies": deps,
		"pclntabRVA": uint64(rs.VirtualAddress) + uint64(at), "applicationFunctions": funcs,
		"executed": false, "sourceRecovered": false, "functionalParityVerified": false,
		"warning": "Function spans come from Go pclntab, not a strings search. Raw-code equality is not whole-program semantic equivalence; unequal relocation bytes need not imply changed behavior.",
	}, nil
}
func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: hostmeta <Go-Windows-EXE>")
		os.Exit(2)
	}
	r, err := inspect(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	e := json.NewEncoder(os.Stdout)
	e.SetIndent("", "  ")
	if err = e.Encode(r); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
}
