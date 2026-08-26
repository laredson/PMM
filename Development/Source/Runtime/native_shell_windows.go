//go:build windows

package main

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"unsafe"
)

var (
	uiUser32           = syscall.NewLazyDLL("user32.dll")
	uiKernel32         = syscall.NewLazyDLL("kernel32.dll")
	uiCreateWindowExW  = uiUser32.NewProc("CreateWindowExW")
	uiDefWindowProcW   = uiUser32.NewProc("DefWindowProcW")
	uiDispatchMessageW = uiUser32.NewProc("DispatchMessageW")
	uiGetMessageW      = uiUser32.NewProc("GetMessageW")
	uiLoadCursorW      = uiUser32.NewProc("LoadCursorW")
	uiLoadIconW        = uiUser32.NewProc("LoadIconW")
	uiPostQuitMessage  = uiUser32.NewProc("PostQuitMessage")
	uiRegisterClassExW = uiUser32.NewProc("RegisterClassExW")
	uiSetWindowTextW   = uiUser32.NewProc("SetWindowTextW")
	uiShowWindow       = uiUser32.NewProc("ShowWindow")
	uiTranslateMessage = uiUser32.NewProc("TranslateMessage")
	uiUpdateWindow     = uiUser32.NewProc("UpdateWindow")
	uiEnableWindow     = uiUser32.NewProc("EnableWindow")
	uiSendMessageW     = uiUser32.NewProc("SendMessageW")
	uiGetModuleHandleW = uiKernel32.NewProc("GetModuleHandleW")
)

const (
	wsOverlappedWindow = 0x00CF0000
	wsVisible          = 0x10000000
	wsChild            = 0x40000000
	wsBorder           = 0x00800000
	wsVScroll          = 0x00200000
	esMultiline        = 0x0004
	esAutoVScroll      = 0x0040
	esReadOnly         = 0x0800
	bsPushButton       = 0x00000000
	swShow             = 5
	wmDestroy          = 0x0002
	wmCommand          = 0x0111
	wmClose            = 0x0010
	wmSetIcon          = 0x0080
	wmSetFont          = 0x0030
	iconSmall          = 0
	iconBig            = 1
	idcArrow           = 32512
	defaultGuiFont     = 17
)

const (
	btnRefresh = 1001 + iota
	btnDetectGame
	btnOpenPMM
	btnOpenLibrary
	btnOpenGame
	btnLegacyUI
	btnSelfTest
	btnClose
)

type point struct{ X, Y int32 }
type msg struct {
	Hwnd    uintptr
	Message uint32
	WParam  uintptr
	LParam  uintptr
	Time    uint32
	Pt      point
}
type wndClassEx struct {
	CbSize        uint32
	Style         uint32
	LpfnWndProc   uintptr
	CbClsExtra    int32
	CbWndExtra    int32
	HInstance     uintptr
	HIcon         uintptr
	HCursor       uintptr
	HbrBackground uintptr
	LpszMenuName  *uint16
	LpszClassName *uint16
	HIconSm       uintptr
}

var nativeShell *nativeShellState

type nativeShellState struct {
	root       string
	sec        SecurityStatus
	labels     NativeShellLabels
	main       uintptr
	statusEdit uintptr
	gameButton uintptr
	legacyBtn  uintptr
}

func launchNativeUIShell(root string, sec SecurityStatus) int {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	labels := loadNativeShellLabels(root)
	nativeShell = &nativeShellState{root: root, sec: sec, labels: labels}

	instance, _, _ := uiGetModuleHandleW.Call(0)
	className := utf16ptr("PMMRuntimeNativeShellV1")
	cursor, _, _ := uiLoadCursorW.Call(0, uintptr(idcArrow))
	appIcon, _, _ := uiLoadIconW.Call(instance, uintptr(1)) // RT_GROUP_ICON id 1
	wc := wndClassEx{
		CbSize:        uint32(unsafe.Sizeof(wndClassEx{})),
		LpfnWndProc:   syscall.NewCallback(nativeShellWndProc),
		HInstance:     instance,
		HIcon:         appIcon,
		HCursor:       cursor,
		HbrBackground: uintptr(6),
		LpszClassName: className,
		HIconSm:       appIcon,
	}
	atom, _, err := uiRegisterClassExW.Call(uintptr(unsafe.Pointer(&wc)))
	if atom == 0 && err != syscall.Errno(1410) { // class already exists is harmless
		fmt.Println("Native UI class registration failed:", err)
		return 31
	}

	hwnd, _, err := uiCreateWindowExW.Call(
		0,
		uintptr(unsafe.Pointer(className)),
		uintptr(unsafe.Pointer(utf16ptr(labels.Title))),
		uintptr(wsOverlappedWindow|wsVisible),
		180, 100, 980, 680,
		0, 0, instance, 0,
	)
	if hwnd == 0 {
		fmt.Println("Native UI window creation failed:", err)
		return 31
	}
	nativeShell.main = hwnd
	if appIcon != 0 {
		uiSendMessageW.Call(hwnd, wmSetIcon, iconBig, appIcon)
		uiSendMessageW.Call(hwnd, wmSetIcon, iconSmall, appIcon)
	}
	nativeShellCreateControls(hwnd, instance)
	nativeShellRefresh()
	uiShowWindow.Call(hwnd, swShow)
	uiUpdateWindow.Call(hwnd)

	var m msg
	for {
		r, _, _ := uiGetMessageW.Call(uintptr(unsafe.Pointer(&m)), 0, 0, 0)
		if int32(r) == -1 {
			return 31
		}
		if r == 0 {
			break
		}
		uiTranslateMessage.Call(uintptr(unsafe.Pointer(&m)))
		uiDispatchMessageW.Call(uintptr(unsafe.Pointer(&m)))
	}
	return 0
}

func nativeShellCreateControls(parent, instance uintptr) {
	s := nativeShell
	font := getStockObject(defaultGuiFont)
	createLabel(parent, instance, s.labels.Heading, 24, 22, 540, 34, font)
	createLabel(parent, instance, s.labels.Subtitle, 24, 55, 720, 25, font)
	createLabel(parent, instance, s.labels.MigrationNote, 24, 91, 915, 45, font)

	s.statusEdit = createControl("EDIT", "", uintptr(wsChild|wsVisible|wsBorder|wsVScroll|esMultiline|esAutoVScroll|esReadOnly), 24, 148, 915, 330, parent, 0, instance)
	setFont(s.statusEdit, font)

	x, y, w, h := int32(24), int32(500), int32(145), int32(34)
	createButton(parent, instance, s.labels.Refresh, x, y, w, h, btnRefresh, font)
	x += 153
	createButton(parent, instance, s.labels.DetectGame, x, y, w, h, btnDetectGame, font)
	x += 153
	createButton(parent, instance, s.labels.OpenPMMFolder, x, y, w, h, btnOpenPMM, font)
	x += 153
	createButton(parent, instance, s.labels.OpenLibrary, x, y, w, h, btnOpenLibrary, font)
	x += 153
	s.gameButton = createButton(parent, instance, s.labels.OpenGameFolder, x, y, w, h, btnOpenGame, font)
	x += 153
	s.legacyBtn = createButton(parent, instance, s.labels.OpenLegacyUI, x, y, w+25, h, btnLegacyUI, font)

	createButton(parent, instance, s.labels.RuntimeSelfTest, 24, 548, 165, 34, btnSelfTest, font)
	createButton(parent, instance, s.labels.Close, 804, 590, 135, 34, btnClose, font)

	legacyAllowed := strings.EqualFold(s.sec.PowerShellLanguageMode, "FullLanguage") && s.sec.PowerShell != ""
	uiEnableWindow.Call(s.legacyBtn, boolUintptr(legacyAllowed))
}

func nativeShellWndProc(hwnd uintptr, message uint32, wParam, lParam uintptr) uintptr {
	switch message {
	case wmCommand:
		id := int(wParam & 0xffff)
		switch id {
		case btnRefresh:
			nativeShellRefresh()
		case btnDetectGame:
			nativeShellRefresh()
		case btnOpenPMM:
			openFolder(nativeShell.root)
		case btnOpenLibrary:
			openFolder(filepath.Join(nativeShell.root, "Mods"))
		case btnOpenGame:
			d := detectPalworld(nativeShell.root)
			if d.Found && d.Selected != "" {
				openFolder(d.Selected)
			}
		case btnLegacyUI:
			if strings.EqualFold(nativeShell.sec.PowerShellLanguageMode, "FullLanguage") && nativeShell.sec.PowerShell != "" {
				go launchLegacyPowerShellUI(nativeShell.root, nativeShell.sec)
			}
		case btnSelfTest:
			rc := selfTest(nativeShell.root)
			if rc == 0 {
				nativeShellAppend("\r\nRuntime self-test: PASS")
			} else {
				nativeShellAppend(fmt.Sprintf("\r\nRuntime self-test: FAIL (%d)", rc))
			}
		case btnClose:
			uiPostQuitMessage.Call(0)
		}
		return 0
	case wmClose:
		uiPostQuitMessage.Call(0)
		return 0
	case wmDestroy:
		uiPostQuitMessage.Call(0)
		return 0
	}
	r, _, _ := uiDefWindowProcW.Call(hwnd, uintptr(message), wParam, lParam)
	return r
}

func nativeShellRefresh() {
	s := nativeShell
	if s == nil || s.statusEdit == 0 {
		return
	}
	s.sec = runtimeSecurity(s.root)
	game := detectPalworld(s.root)
	knowledge := validateKnowledge(s.root)
	manifest, _ := loadReleaseManifest(s.root)
	deps := inspectDependencies(s.root, manifest)

	mode := s.sec.PowerShellLanguageMode
	if mode == "" {
		mode = "Unavailable / not detected"
	}
	gameText := "not detected"
	if game.Found {
		gameText = game.Selected
	}
	text := strings.Join([]string{
		"PMM Runtime: " + runtimeVersion,
		"Build: " + readTrim(filepath.Join(s.root, "Resources", "Metadata", "BUILD_ID.txt")),
		"PowerShell LanguageMode: " + mode,
		"Normal startup requires PowerShell: NO",
		"PMMRuntime requires FullLanguage: NO",
		"Dependencies ready: " + yesNo(deps.Ready),
		fmt.Sprintf("Knowledge valid: %s (package rules: %d)", yesNo(knowledge.OK), knowledge.PackageRuleCount),
		"Palworld: " + gameText,
		"",
		"This native shell is launched by PMMRuntime.exe and does not use WPF/Add-Type/PowerShell objects.",
		"The current full Mods & Merge workspace remains available only through the temporary legacy UI on FullLanguage systems while its operations are migrated into PMMRuntime.",
	}, "\r\n")
	setWindowText(s.statusEdit, text)
	uiEnableWindow.Call(s.gameButton, boolUintptr(game.Found))
	legacyAllowed := strings.EqualFold(s.sec.PowerShellLanguageMode, "FullLanguage") && s.sec.PowerShell != ""
	uiEnableWindow.Call(s.legacyBtn, boolUintptr(legacyAllowed))
}

func nativeShellAppend(extra string) {
	nativeShellRefresh()
	// Keep append simple and deterministic by adding the new line to the refreshed status.
	if extra != "" {
		current := ""
		_ = current
		// A message box is used for one-shot self-test feedback so we do not need text retrieval APIs.
		notify("Palworld Manager Merger", strings.TrimSpace(extra))
	}
}

func openFolder(path string) {
	if path == "" {
		return
	}
	_ = exec.Command("explorer.exe", path).Start()
}

func yesNo(v bool) string {
	if v {
		return "YES"
	}
	return "NO"
}
func boolUintptr(v bool) uintptr {
	if v {
		return 1
	}
	return 0
}

func utf16ptr(s string) *uint16 {
	p, _ := syscall.UTF16PtrFromString(s)
	return p
}

func createLabel(parent, instance uintptr, text string, x, y, w, h int32, font uintptr) uintptr {
	c := createControl("STATIC", text, uintptr(wsChild|wsVisible), x, y, w, h, parent, 0, instance)
	setFont(c, font)
	return c
}

func createButton(parent, instance uintptr, text string, x, y, w, h int32, id int, font uintptr) uintptr {
	c := createControl("BUTTON", text, uintptr(wsChild|wsVisible|bsPushButton), x, y, w, h, parent, uintptr(id), instance)
	setFont(c, font)
	return c
}

func createControl(class, text string, style uintptr, x, y, w, h int32, parent, id, instance uintptr) uintptr {
	hwnd, _, _ := uiCreateWindowExW.Call(
		0,
		uintptr(unsafe.Pointer(utf16ptr(class))),
		uintptr(unsafe.Pointer(utf16ptr(text))),
		style,
		uintptr(x), uintptr(y), uintptr(w), uintptr(h),
		parent, id, instance, 0,
	)
	return hwnd
}

func setWindowText(hwnd uintptr, text string) {
	uiSetWindowTextW.Call(hwnd, uintptr(unsafe.Pointer(utf16ptr(text))))
}
func setFont(hwnd, font uintptr) {
	if hwnd != 0 && font != 0 {
		uiSendMessageW.Call(hwnd, wmSetFont, font, 1)
	}
}

func getStockObject(id int) uintptr {
	gdi32 := syscall.NewLazyDLL("gdi32.dll")
	proc := gdi32.NewProc("GetStockObject")
	r, _, _ := proc.Call(uintptr(id))
	return r
}
