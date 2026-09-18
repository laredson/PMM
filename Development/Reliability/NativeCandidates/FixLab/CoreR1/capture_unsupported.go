//go:build !linux && !windows

package corer1

import "os"

func absoluteRootParts(string) (string, []string, error) {
	return "", nil, fail("UNSUPPORTED", "capture", "platform adapter unavailable")
}
func openAnchor(string) (*os.File, error) {
	return nil, fail("UNSUPPORTED", "capture", "platform adapter unavailable")
}
func openChild(*os.File, string, bool) (*os.File, error) {
	return nil, fail("UNSUPPORTED", "capture", "platform adapter unavailable")
}
func stamp(*os.File, bool) (diskStamp, error) {
	return diskStamp{}, fail("UNSUPPORTED", "capture", "platform adapter unavailable")
}

func localFilesystem(*os.File) error {
	return fail("UNSUPPORTED", "capture", "platform adapter unavailable")
}
