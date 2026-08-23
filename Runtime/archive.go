package main

import (
	"archive/zip"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

func extractZipSafe(zipPath, destination string) error {
	zr, err := zip.OpenReader(zipPath)
	if err != nil {
		return err
	}
	defer zr.Close()
	root, err := filepath.Abs(destination)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(root, 0755); err != nil {
		return err
	}
	prefix := root + string(filepath.Separator)
	for _, f := range zr.File {
		rel, err := cleanRelPath(f.Name)
		if err != nil {
			return err
		}
		target := filepath.Join(root, rel)
		full, err := filepath.Abs(target)
		if err != nil {
			return err
		}
		if !strings.EqualFold(full, root) && !strings.HasPrefix(strings.ToLower(full), strings.ToLower(prefix)) {
			return fmt.Errorf("zip path escapes destination: %s", f.Name)
		}
		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(full, 0755); err != nil {
				return err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(full), 0755); err != nil {
			return err
		}
		in, err := f.Open()
		if err != nil {
			return err
		}
		out, err := os.OpenFile(full, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, f.Mode())
		if err != nil {
			in.Close()
			return err
		}
		_, copyErr := io.Copy(out, in)
		closeErr := out.Close()
		in.Close()
		if copyErr != nil {
			return copyErr
		}
		if closeErr != nil {
			return closeErr
		}
	}
	return nil
}

func createZipFromDirectory(source, output string) error {
	sourceAbs, err := filepath.Abs(source)
	if err != nil {
		return err
	}
	if !existsDir(sourceAbs) {
		return fmt.Errorf("source directory not found: %s", sourceAbs)
	}
	if err := os.MkdirAll(filepath.Dir(output), 0755); err != nil {
		return err
	}
	f, err := os.Create(output)
	if err != nil {
		return err
	}
	zw := zip.NewWriter(f)
	walkErr := filepath.Walk(sourceAbs, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(sourceAbs, path)
		if err != nil {
			return err
		}
		hdr, err := zip.FileInfoHeader(info)
		if err != nil {
			return err
		}
		hdr.Name = filepath.ToSlash(rel)
		hdr.Method = zip.Deflate
		w, err := zw.CreateHeader(hdr)
		if err != nil {
			return err
		}
		in, err := os.Open(path)
		if err != nil {
			return err
		}
		defer in.Close()
		_, err = io.Copy(w, in)
		return err
	})
	closeErr := zw.Close()
	fileClose := f.Close()
	if walkErr != nil {
		return walkErr
	}
	if closeErr != nil {
		return closeErr
	}
	return fileClose
}
