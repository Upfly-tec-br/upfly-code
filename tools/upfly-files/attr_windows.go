//go:build windows

package main

import (
	"os"
	"os/exec"
	"syscall"
)

// isSystemHidden esconde arquivos ocultos/de sistema do Windows e junções
// (ex.: "Ambiente de Impressão", "NTUSER.DAT").
func isSystemHidden(path string, info os.FileInfo) bool {
	if info.Mode()&os.ModeIrregular != 0 {
		return true
	}
	if d, ok := info.Sys().(*syscall.Win32FileAttributeData); ok {
		const hidden, system, reparse = 0x2, 0x4, 0x400
		if d.FileAttributes&(hidden|system) != 0 {
			return true
		}
		if d.FileAttributes&reparse != 0 && info.IsDir() {
			return true
		}
	}
	return false
}

func hideWindow(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000} // CREATE_NO_WINDOW
}
