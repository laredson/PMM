//go:build !windows

package uibridge

// No TCP/file-based fallback. Only protocol/model and synthetic tests compile on
// non-Windows platforms. Production Win32 transport APIs are deliberately absent.
