//go:build !windows

package main

import "fmt"

func notify(title, text string) { fmt.Println(title + ": " + text) }
