package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
)

// ----------------------------------------------------------------- abrir

// editorCommand: UPFLY_EDITOR, ou o primeiro editor encontrado (Trae, VS Code, Cursor).
func editorCommand() string {
	if e := strings.TrimSpace(os.Getenv("UPFLY_EDITOR")); e != "" && e != "auto" {
		return e
	}
	for _, c := range []string{"trae", "code", "cursor", "codium"} {
		if p, err := exec.LookPath(c); err == nil {
			return p
		}
	}
	return ""
}

func startDetached(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	hideWindow(cmd)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = nil, nil, nil
	if err := cmd.Start(); err != nil {
		return err
	}
	go cmd.Wait()
	return nil
}

func openInEditor(path string) (string, error) {
	if ed := editorCommand(); ed != "" {
		return filepath.Base(ed), startDetached(ed, path)
	}
	return "programa padrão", openDefault(path)
}

func openDefault(path string) error {
	switch runtime.GOOS {
	case "windows":
		return startDetached("rundll32.exe", "url.dll,FileProtocolHandler", path)
	case "darwin":
		return startDetached("open", path)
	default:
		return startDetached("xdg-open", path)
	}
}

func reveal(path string) error {
	switch runtime.GOOS {
	case "windows":
		return startDetached("explorer.exe", "/select,"+path)
	case "darwin":
		return startDetached("open", "-R", path)
	default:
		return startDetached("xdg-open", filepath.Dir(path))
	}
}

// moveToTrash envia para a Lixeira (nunca apaga direto).
func moveToTrash(path string, isDir bool) error {
	switch runtime.GOOS {
	case "windows":
		fn := "DeleteFile"
		if isDir {
			fn = "DeleteDirectory"
		}
		ps := fmt.Sprintf("Add-Type -AssemblyName Microsoft.VisualBasic;"+
			"[Microsoft.VisualBasic.FileIO.FileSystem]::%s('%s','OnlyErrorDialogs','SendToRecycleBin')",
			fn, strings.ReplaceAll(path, "'", "''"))
		cmd := exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", ps)
		hideWindow(cmd)
		return cmd.Run()
	case "darwin":
		script := fmt.Sprintf(`tell application "Finder" to delete POSIX file "%s"`,
			strings.ReplaceAll(path, `"`, `\"`))
		return exec.Command("osascript", "-e", script).Run()
	default:
		if p, err := exec.LookPath("gio"); err == nil {
			return exec.Command(p, "trash", path).Run()
		}
		if p, err := exec.LookPath("trash-put"); err == nil {
			return exec.Command(p, path).Run()
		}
		return errors.New("lixeira indisponível (instale gio ou trash-cli)")
	}
}

// ----------------------------------------------------------------- terminal ao lado

type paneInfo struct {
	WindowID int    `json:"window_id"`
	TabID    int    `json:"tab_id"`
	PaneID   int    `json:"pane_id"`
	Title    string `json:"title"`
	IsActive bool   `json:"is_active"`
	Size     struct {
		Cols int `json:"cols"`
	} `json:"size"`
}

func weztermCLI() string {
	if c := os.Getenv("UPFLY_WEZTERM_CLI"); c != "" {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	if p, err := exec.LookPath("wezterm"); err == nil {
		return p
	}
	return ""
}

// targetPane escolhe o painel da mesma aba para onde mandar texto:
// prefere o Claude Code; senão, o maior painel que não seja este.
func targetPane() (int, error) {
	cli := weztermCLI()
	if cli == "" {
		return 0, errors.New("terminal não encontrado")
	}
	self, _ := strconv.Atoi(os.Getenv("WEZTERM_PANE"))
	cmd := exec.Command(cli, "cli", "list", "--format", "json")
	hideWindow(cmd)
	out, err := cmd.Output()
	if err != nil {
		return 0, errors.New("não foi possível falar com o terminal")
	}
	var panes []paneInfo
	if err := json.Unmarshal(out, &panes); err != nil {
		return 0, err
	}
	tab := -1
	for _, p := range panes {
		if p.PaneID == self {
			tab = p.TabID
		}
	}
	best, bestScore := -1, -1
	for _, p := range panes {
		if p.TabID != tab || p.PaneID == self {
			continue
		}
		score := p.Size.Cols
		if strings.Contains(strings.ToLower(p.Title), "claude") {
			score += 100000
		}
		if score > bestScore {
			best, bestScore = p.PaneID, score
		}
	}
	if best < 0 {
		return 0, errors.New("abra um terminal ao lado da barra de arquivos")
	}
	return best, nil
}

func sendToPane(pane int, text string, activate bool) error {
	cli := weztermCLI()
	cmd := exec.Command(cli, "cli", "send-text", "--pane-id", strconv.Itoa(pane), "--no-paste", text)
	hideWindow(cmd)
	if err := cmd.Run(); err != nil {
		return err
	}
	if activate {
		a := exec.Command(cli, "cli", "activate-pane", "--pane-id", strconv.Itoa(pane))
		hideWindow(a)
		_ = a.Run()
	}
	return nil
}

// shellPath converte o caminho para o shell do terminal (Git Bash usa /c/...).
func shellPath(p string) string {
	kind := os.Getenv("UPFLY_SHELL_KIND")
	if runtime.GOOS == "windows" && kind != "powershell" {
		p = filepath.ToSlash(p)
		if len(p) >= 2 && p[1] == ':' {
			p = "/" + strings.ToLower(p[:1]) + p[2:]
		}
	}
	return p
}

func shellQuote(p string) string {
	return "'" + strings.ReplaceAll(p, "'", `'\''`) + "'"
}

// mentionText gera a menção para o Claude Code: @caminho/relativo
func mentionText(root, path string) string {
	rel, err := filepath.Rel(root, path)
	if err != nil {
		rel = path
	}
	rel = filepath.ToSlash(rel)
	if strings.ContainsAny(rel, " \t") {
		return `@"` + rel + `" `
	}
	return "@" + rel + " "
}

func isWindows() bool { return runtime.GOOS == "windows" }
func isMac() bool     { return runtime.GOOS == "darwin" }
