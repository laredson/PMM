//go:build !windows

package runtime

import "fmt"

func notify(title, text string) { fmt.Println(title + ": " + text) }
