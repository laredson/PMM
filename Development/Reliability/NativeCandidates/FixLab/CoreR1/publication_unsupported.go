//go:build (!linux && !windows) || (linux && !amd64)

package corer1

import "os"

func publicationPlatformError() error {
	return fail("UNSUPPORTED", "publication", "platform adapter unavailable")
}
func candidateParent(*os.File) (*os.File, error) { return nil, publicationPlatformError() }
func candidateLookup(*os.File, string, bool) (*os.File, error) {
	return nil, publicationPlatformError()
}
func candidateMkdir(*os.File, string) (*os.File, bool, error) {
	return nil, false, publicationPlatformError()
}
func candidateCreate(*os.File, string) (*os.File, error)     { return nil, publicationPlatformError() }
func candidateRemove(*os.File, string, *os.File, bool) error { return publicationPlatformError() }
func candidateCommit(*os.File, *os.File, string, string) (bool, error) {
	return false, publicationPlatformError()
}
func candidateSyncDir(*os.File) (bool, error) { return false, publicationPlatformError() }
