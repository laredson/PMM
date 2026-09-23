package runtime

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"sync"
	"sync/atomic"
	"time"

	"pmm.local/pmm/internal/uibridge"
)

// One coordinator for the UI entrypoint; no global environment mutation after
// startup. Native GUI callbacks only enqueue work / take an atomic reservation.
type runtimeUIBridge struct {
	root      string
	client    *uibridge.Client
	self      uibridge.ProcessRef
	platform  uibridge.Platform
	ctx       context.Context
	cancel    context.CancelFunc
	lifecycle sync.Mutex
	epoch     atomic.Uint64
	wpf       atomic.Bool
}

const uiReadyTimeout = 30 * time.Second

var activeUIBridge *runtimeUIBridge

func withRuntimeUIBridge(root string, action func() int) int {
	client, self, platform, e := connectRuntimeUIBridge()
	if e != nil {
		fmt.Fprintln(os.Stderr, "UI coordination unavailable (application may continue):", e)
	}
	ctx, cancel := context.WithCancel(context.Background())
	r := &runtimeUIBridge{root: root, client: client, self: self, platform: platform, ctx: ctx, cancel: cancel}
	activeUIBridge = r
	defer func() {
		cancel()
		if client != nil {
			client.Shutdown(context.Background())
		}
		if self != nil {
			_ = self.Close()
		}
		// Do not clear the pointer while a native-shell WPF waiter may still finish.
		// Runtime exits next; family termination is a separate, still-pending gate.
	}()
	return action()
}
func (r *runtimeUIBridge) alive(ref uibridge.ProcessRef, epoch uint64) bool {
	return r.ctx.Err() == nil && r.epoch.Load() == epoch && ref != nil && ref.Alive()
}
func (r *runtimeUIBridge) retireImmediately() {
	if r != nil {
		r.cancel()
		if r.client != nil {
			r.client.Close()
		}
	}
}
func (r *runtimeUIBridge) disable(e error) {
	if r.client != nil {
		r.client.Close()
	}
	if e != nil {
		fmt.Fprintln(os.Stderr, "UI coordination retired:", e)
	}
}
func (r *runtimeUIBridge) register(ctx context.Context, ref uibridge.ProcessRef, route string, epoch uint64) (uint64, error) {
	r.lifecycle.Lock()
	defer r.lifecycle.Unlock()
	if r.client == nil {
		return 0, nil
	}
	return r.client.Begin(ctx, ref.Identity(), route, func() bool { return r.alive(ref, epoch) })
}
func (r *runtimeUIBridge) nativeReady(hwnd uint64) {
	if r == nil || r.client == nil {
		return
	}
	epoch := r.epoch.Add(1)
	go func() {
		if _, e := uibridge.FreshUIState(r.root); e != nil {
			r.disable(e)
			return
		}
		gen, e := r.register(r.ctx, r.self, "native", epoch)
		if e != nil {
			if !errors.Is(e, uibridge.ErrInactive) {
				r.disable(e)
			}
			return
		}
		e = r.client.Ready(r.ctx, gen, hwnd, func() bool { return r.alive(r.self, epoch) })
		if e != nil && !errors.Is(e, uibridge.ErrInactive) {
			r.disable(e)
		}
	}()
}

func coordinatedLegacyUI(root string, sec SecurityStatus) int {
	r := activeUIBridge
	if r == nil {
		// Non-UI entrypoint/unit construction; no transport authentication is invented.
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		r = &runtimeUIBridge{root: root, ctx: ctx, cancel: cancel}
	}
	if !r.wpf.CompareAndSwap(false, true) {
		fmt.Fprintln(os.Stderr, "PMM interface already starting or running.")
		return 30
	}
	defer r.wpf.Store(false)
	epoch := r.epoch.Add(1)
	dir, e := uibridge.FreshUIState(root)
	if e != nil {
		r.disable(e)
		dir = "" // Disable state hints, not the visible application. No old-directory fallback.
	}
	cmd := legacyUICommand(root, sec)
	cmd.Env = uibridge.MergeEnvironment(os.Environ(), map[string]string{"PMM_HOST_SESSION_DIR": dir})
	if e = cmd.Start(); e != nil {
		r.disable(e)
		fmt.Fprintln(os.Stderr, e)
		return 30
	}
	// This capture precedes any Wait: Windows cannot reuse the controlled PID
	// while the original Cmd process handle remains retained.
	var ref uibridge.ProcessRef
	if r.client != nil && dir != "" {
		ref, e = captureUIProcess(uint32(cmd.Process.Pid))
		if e != nil {
			r.disable(e)
		}
	}
	ctx, cancel := context.WithCancel(r.ctx)
	defer cancel()
	exited := make(chan struct{})
	result := make(chan error, 1)
	go func() { e := cmd.Wait(); close(exited); cancel(); result <- e }()
	monitorDone := make(chan struct{})
	if ref != nil {
		go func() { defer close(monitorDone); r.watchWPF(ctx, exited, ref, dir, epoch) }()
	} else {
		close(monitorDone)
	}
	e = <-result
	select {
	case <-monitorDone:
	case <-time.After(uibridge.ExchangeTimeout + time.Second):
		r.disable(errors.New("UI coordination cleanup pending"))
	}
	if ref != nil {
		_ = ref.Close()
	}
	if e != nil {
		if ee, ok := e.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		fmt.Fprintln(os.Stderr, e)
		return 30
	}
	return 0
}
func (r *runtimeUIBridge) watchWPF(ctx context.Context, exited <-chan struct{}, ref uibridge.ProcessRef, dir string, epoch uint64) {
	gen, e := r.register(ctx, ref, "wpf", epoch)
	if e != nil {
		if !errors.Is(e, uibridge.ErrInactive) && ctx.Err() == nil {
			r.disable(e)
		}
		return
	}
	defer func() {
		// Exit is observed independently by Host's retained process handle too.
		if e := r.client.Retire(context.Background(), gen, false); e != nil && r.ctx.Err() == nil {
			r.disable(e)
		}
	}()
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()
	deadline := time.NewTimer(uiReadyTimeout)
	defer deadline.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-exited:
			return
		case <-r.client.Closed():
			return
		case <-deadline.C:
			r.disable(errors.New("UI readiness deadline; application continues without focus coordination"))
			return
		case <-ticker.C:
			if !r.alive(ref, epoch) {
				return
			}
			h, e := uibridge.ReadHint(dir)
			if e != nil {
				continue
			}
			if h.Terminal {
				_ = r.client.Retire(ctx, gen, h.Failed)
				return
			}
			if h.Ready {
				if h.HWND == 0 {
					// Readiness with no usable owner handle retires splash WITHOUT focus.
					_ = r.client.Retire(ctx, gen, true)
					return
				}
				if !r.platform.WindowOwnedBy(h.HWND, ref) {
					r.disable(errors.New("UI hint does not belong to the captured UI process"))
					return
				}
				e = r.client.Ready(ctx, gen, h.HWND, func() bool {
					select {
					case <-exited:
						return false
					default:
					}
					return r.alive(ref, epoch) && r.platform.WindowOwnedBy(h.HWND, ref)
				})
				if e != nil {
					if !errors.Is(e, uibridge.ErrInactive) {
						r.disable(e)
					}
					return
				}
				// Do not replay READY. Keep the registered process alive until actual exit.
				select {
				case <-ctx.Done():
				case <-exited:
				case <-r.client.Closed():
				}
				return
			}
		}
	}
}
