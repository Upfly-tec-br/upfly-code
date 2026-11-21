//go:build !windows

package main

import (
	"os"
	"os/exec"
)

// No macOS/Linux, arquivos com ponto aparecem (como no VS Code); só o
// que está em alwaysHidden some.
func isSystemHidden(path string, info os.FileInfo) bool { return false }

func hideWindow(cmd *exec.Cmd) {}
