//go:build !windows

package runtime

import (
	"errors"
	"pmm.local/pmm/internal/uibridge"
)

func connectRuntimeUIBridge() (*uibridge.Client, uibridge.ProcessRef, uibridge.Platform, error) {
	return nil, nil, nil, nil
}
func captureUIProcess(pid uint32) (uibridge.ProcessRef, error) {
	return nil, errors.New("Windows identity unavailable")
}
