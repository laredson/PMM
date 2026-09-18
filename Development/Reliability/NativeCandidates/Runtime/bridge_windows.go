//go:build windows

package main

import (
	"context"
	"errors"
	"os"
	"strings"

	"pmm/uibridge"
)

func connectRuntimeUIBridge() (*uibridge.Client, uibridge.ProcessRef, uibridge.Platform, error) {
	env := os.Environ()
	d, present, e := uibridge.DescriptorFromEnvironment(env)
	// Happens BEFORE probes/dependencies/other children. Locators never propagate.
	for _, item := range env {
		key, _, ok := strings.Cut(item, "=")
		if ok && strings.HasPrefix(strings.ToUpper(key), uibridge.EnvPrefix) {
			_ = os.Unsetenv(key)
		}
	}
	if e != nil {
		return nil, nil, nil, e
	}
	if !present {
		return nil, nil, nil, nil
	}
	host, e := uibridge.CaptureLaunchingParent()
	if e != nil {
		return nil, nil, nil, e
	}
	defer host.Close()
	if host.Identity() != d.Host {
		return nil, nil, nil, errors.New("locator does not match OS parent instance")
	}
	self, e := uibridge.CaptureProcess(uint32(os.Getpid()))
	if e != nil {
		return nil, nil, nil, e
	}
	conn, e := uibridge.Dial(context.Background(), d, host)
	if e != nil {
		_ = self.Close()
		return nil, nil, nil, e
	}
	c, e := uibridge.NewClient(context.Background(), conn, d.Session, self.Identity())
	if e != nil {
		conn.Close()
		_ = self.Close()
		return nil, nil, nil, e
	}
	return c, self, uibridge.WindowsPlatform{}, nil
}
func captureUIProcess(pid uint32) (uibridge.ProcessRef, error) { return uibridge.CaptureProcess(pid) }
