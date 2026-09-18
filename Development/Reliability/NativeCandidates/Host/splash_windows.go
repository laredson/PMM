//go:build windows

package main

// RECONSTRUCTION from startup states and documented RC21/WPF contracts.
// This is NOT the original splash source and does not claim pixel or byte parity.
import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"syscall"
	"time"
	"unsafe"
)

var (
	splashKernel    = syscall.NewLazyDLL("kernel32.dll")
	splashGDI       = syscall.NewLazyDLL("gdi32.dll")
	splashShell     = syscall.NewLazyDLL("shell32.dll")
	splashControls  = syscall.NewLazyDLL("comctl32.dll")
	spModule        = splashKernel.NewProc("GetModuleHandleW")
	spRegister      = user32.NewProc("RegisterClassExW")
	spUnregister    = user32.NewProc("UnregisterClassW")
	spCreate        = user32.NewProc("CreateWindowExW")
	spDef           = user32.NewProc("DefWindowProcW")
	spGetMessage    = user32.NewProc("GetMessageW")
	spTranslate     = user32.NewProc("TranslateMessage")
	spDispatch      = user32.NewProc("DispatchMessageW")
	spShow          = user32.NewProc("ShowWindow")
	spShowAsync     = user32.NewProc("ShowWindowAsync")
	spDestroy       = user32.NewProc("DestroyWindow")
	spQuit          = user32.NewProc("PostQuitMessage")
	spTimer         = user32.NewProc("SetTimer")
	spKillTimer     = user32.NewProc("KillTimer")
	spSetText       = user32.NewProc("SetWindowTextW")
	spSend          = user32.NewProc("SendMessageW")
	spIcon          = user32.NewProc("LoadIconW")
	spCursor        = user32.NewProc("LoadCursorW")
	spMetrics       = user32.NewProc("GetSystemMetrics")
	spIsWindow      = user32.NewProc("IsWindow")
	spForeground    = user32.NewProc("GetForegroundWindow")
	spSetForeground = user32.NewProc("SetForegroundWindow")
	spFont          = splashGDI.NewProc("GetStockObject")
	spInitControls  = splashControls.NewProc("InitCommonControlsEx")
	spAppID         = splashShell.NewProc("SetCurrentProcessExplicitAppUserModelID")
)

const (
	splashWMClose   = 0x0010
	splashWMDestroy = 0x0002
	splashWMTimer   = 0x0113
	splashTimerID   = 1
)

type splashPoint struct{ X, Y int32 }
type splashMsg struct {
	Window         uintptr
	Message        uint32
	WParam, LParam uintptr
	Time           uint32
	Point          splashPoint
	Private        uint32
}
type splashClass struct {
	Size, Style                        uint32
	WndProc                            uintptr
	ClassExtra, WindowExtra            int32
	Instance, Icon, Cursor, Background uintptr
	Menu, Name                         *uint16
	SmallIcon                          uintptr
}

type startupSplash struct {
	mu        sync.Mutex
	view      startupView
	stop      chan struct{}
	done      chan struct{}
	ready     chan struct{}
	closeOnce sync.Once
	readyOnce sync.Once
	root      string
	log       func(string)
	// Native handles below are owned/read exclusively by the locked UI thread.
	window, label, progress uintptr
}

func setPMMAppUserModelID() {
	if spAppID.Find() != nil {
		return
	}
	text := splashUTF16("laredson.PalworldManagerMerger")
	code, _, _ := spAppID.Call(uintptr(unsafe.Pointer(text)))
	runtime.KeepAlive(text)
	if int32(code) < 0 {
		fmt.Fprintln(os.Stderr, "PMM AppUserModelID could not be set")
	}
}

func startStartupSplash(root string, log func(string)) *startupSplash {
	s := &startupSplash{
		root: root, log: log, view: startupView{Label: startupLabels[0]},
		stop: make(chan struct{}), done: make(chan struct{}), ready: make(chan struct{}),
	}
	go s.run()
	select {
	case <-s.ready:
	case <-time.After(2 * time.Second):
		s.log("Splash initialization timed out; supervision continues.")
		s.Close()
	}
	return s
}

func (s *startupSplash) Update(state string) {
	if s == nil {
		return
	}
	s.mu.Lock()
	s.view = nextStartupView(s.view, state)
	s.mu.Unlock()
}

func (s *startupSplash) Close() {
	if s == nil {
		return
	}
	s.closeOnce.Do(func() { close(s.stop) })
	// Destruction is performed only by the native window's owner thread.
	// No timer, another process or a stuck GUI may block supervisor shutdown forever.
	select {
	case <-s.done:
	case <-time.After(2 * time.Second):
		s.log("Splash did not acknowledge close; supervisor will continue.")
	}
}

func (s *startupSplash) HandoffTo(target uintptr) {
	if target == 0 {
		s.log("WPF readiness received without a window handle.")
		return
	}
	valid, _, _ := spIsWindow.Call(target)
	if valid == 0 {
		s.log("WPF readiness handle is no longer a window.")
		return
	}
	// Do not attach input queues, synthesize keystrokes, force TOPMOST, or
	// change foreground-lock settings. Windows retains the final decision.
	spShowAsync.Call(target, 5) // SW_SHOW, asynchronous across process boundaries.
	foreground, _, _ := spForeground.Call()
	if foreground != s.window {
		s.log("UI ready; focus left unchanged because splash is not foreground.")
		return
	}
	ok, _, _ := spSetForeground.Call(target)
	if ok == 0 {
		s.log("Windows declined the foreground handoff; UI remains available.")
	}
}

func (s *startupSplash) run() {
	runtime.LockOSThread()
	// Keep this dedicated thread locked on return: Go terminates it, so an
	// early-exit WM_QUIT/message queue cannot leak into a reused worker thread.
	defer close(s.done)
	signalReady := func() { s.readyOnce.Do(func() { close(s.ready) }) }
	defer signalReady()
	// Resolve entry points explicitly so an optional splash cannot turn a missing
	// Win32 export into an unhandled LazyProc panic.
	procedures := []*syscall.LazyProc{spModule, spRegister, spUnregister, spCreate, spDef,
		spGetMessage, spTranslate, spDispatch, spShow, spShowAsync, spDestroy, spQuit,
		spTimer, spKillTimer, spSetText, spSend, spIcon, spCursor, spMetrics,
		spIsWindow, spForeground, spSetForeground, spFont, spInitControls}
	for _, p := range procedures {
		if err := p.Find(); err != nil {
			s.log("Splash unavailable: " + err.Error())
			return
		}
	}
	select {
	case <-s.stop:
		return
	default:
	}
	init := struct{ Size, Classes uint32 }{8, 0x20} // ICC_PROGRESS_CLASS
	ok, _, _ := spInitControls.Call(uintptr(unsafe.Pointer(&init)))
	if ok == 0 {
		s.log("Could not initialize splash progress control.")
		return
	}
	instance, _, _ := spModule.Call(0)
	icon, _, _ := spIcon.Call(instance, 1)  // Same RT_GROUP_ICON as the historical build helper.
	cursor, _, _ := spCursor.Call(0, 32512) // IDC_ARROW, shared resource.
	name := splashUTF16("PMMStartupSplashCandidate02A")
	callback := syscall.NewCallback(s.windowProc)
	class := splashClass{
		Size: uint32(unsafe.Sizeof(splashClass{})), WndProc: callback,
		Instance: instance, Icon: icon, Cursor: cursor, Background: 6,
		Name: name, SmallIcon: icon,
	}
	atom, _, err := spRegister.Call(uintptr(unsafe.Pointer(&class)))
	if atom == 0 {
		s.log("Splash registration failed: " + err.Error())
		return
	}
	defer func() { spUnregister.Call(uintptr(unsafe.Pointer(name)), instance); runtime.KeepAlive(name) }()
	width, height := int32(540), int32(188)
	screenW, _, _ := spMetrics.Call(0)
	screenH, _, _ := spMetrics.Call(1)
	x, y := (int32(screenW)-width)/2, (int32(screenH)-height)/2
	if x < 0 {
		x = 0
	}
	if y < 0 {
		y = 0
	}
	title := splashUTF16("PMM - Starting")
	window, _, err := spCreate.Call(0x00040000, uintptr(unsafe.Pointer(name)),
		uintptr(unsafe.Pointer(title)), 0x00C00000, // WS_EX_APPWINDOW; WS_CAPTION
		uintptr(x), uintptr(y), uintptr(width), uintptr(height), 0, 0, instance, 0)
	runtime.KeepAlive(title)
	if window == 0 {
		s.log("Splash window failed: " + err.Error())
		return
	}
	s.window = window
	defer func() {
		valid, _, _ := spIsWindow.Call(window)
		if valid != 0 {
			spDestroy.Call(window)
		}
	}()
	font, _, _ := spFont.Call(17) // DEFAULT_GUI_FONT is shared; never delete it.
	version := strings.TrimSpace(readSmall(filepath.Join(s.root, "Resources", "Metadata", "VERSION.txt"), 128))
	if version == "" {
		version = hostVersion
	}
	heading := s.control(instance, "STATIC", "Palworld Manager Merger - "+version, 24, 20, 480, 24)
	s.label = s.control(instance, "STATIC", startupLabels[0], 24, 55, 480, 22)
	s.progress = s.control(instance, "msctls_progress32", "", 24, 94, 480, 20)
	if heading == 0 || s.label == 0 || s.progress == 0 {
		s.log("Splash controls unavailable.")
		return
	}
	spSend.Call(heading, 0x0030, font, 1) // WM_SETFONT
	spSend.Call(s.label, 0x0030, font, 1)
	spSend.Call(s.progress, 0x0406, 0, 6) // PBM_SETRANGE32: six presentation steps.
	timer, _, _ := spTimer.Call(window, splashTimerID, 100, 0)
	if timer == 0 {
		s.log("Splash timer unavailable.")
		return
	}
	defer spKillTimer.Call(window, splashTimerID)
	spShow.Call(window, 5)
	signalReady()
	var msg splashMsg
	for {
		code, _, _ := spGetMessage.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0)
		if int32(code) == -1 {
			s.log("Splash message loop failed.")
			return
		}
		if code == 0 {
			return
		}
		spTranslate.Call(uintptr(unsafe.Pointer(&msg)))
		spDispatch.Call(uintptr(unsafe.Pointer(&msg)))
	}
}

func (s *startupSplash) control(instance uintptr, class, text string, x, y, w, h int32) uintptr {
	c, t := splashUTF16(class), splashUTF16(text)
	hwnd, _, _ := spCreate.Call(0, uintptr(unsafe.Pointer(c)), uintptr(unsafe.Pointer(t)),
		0x50000000, uintptr(x), uintptr(y), uintptr(w), uintptr(h), s.window, 0, instance, 0)
	runtime.KeepAlive(c)
	runtime.KeepAlive(t)
	return hwnd
}

func (s *startupSplash) windowProc(hwnd uintptr, message uint32, wParam, lParam uintptr) uintptr {
	switch message {
	case splashWMTimer:
		if wParam != splashTimerID {
			break
		}
		s.mu.Lock()
		view := s.view
		s.mu.Unlock()
		if view.Ready {
			// Handoff must precede splash destruction, as required by the WPF contract.
			s.HandoffTo(view.Window)
			spDestroy.Call(hwnd)
			return 0
		}
		select {
		case <-s.stop:
			spDestroy.Call(hwnd)
			return 0
		default:
		}
		if s.label != 0 {
			label := splashUTF16(view.Label)
			spSetText.Call(s.label, uintptr(unsafe.Pointer(label)))
			runtime.KeepAlive(label)
			spSend.Call(s.progress, 0x0402, uintptr(view.Stage+1), 0) // PBM_SETPOS
		}
		return 0
	case splashWMClose:
		// Closing this auxiliary window never kills the child or the supervisor.
		spDestroy.Call(hwnd)
		return 0
	case splashWMDestroy:
		spQuit.Call(0)
		return 0
	}
	r, _, _ := spDef.Call(hwnd, uintptr(message), wParam, lParam)
	return r
}

func splashUTF16(s string) *uint16 {
	p, _ := syscall.UTF16PtrFromString(strings.ReplaceAll(s, "\x00", ""))
	return p
}
