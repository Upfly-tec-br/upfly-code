package main

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// GitState guarda o status do Git (como as cores do VS Code).
type GitState struct {
	Branch string
	Files  map[string]byte // caminho absoluto -> 'M','A','U','D','R','!'
	Dirs   map[string]byte // pastas que contêm mudanças
}

func gitBin() string {
	if g := os.Getenv("UPFLY_GIT"); g != "" {
		if _, err := os.Stat(g); err == nil {
			return g
		}
	}
	if p, err := exec.LookPath("git"); err == nil {
		return p
	}
	return ""
}

func runGit(dir string, args ...string) ([]byte, error) {
	bin := gitBin()
	if bin == "" {
		return nil, os.ErrNotExist
	}
	cmd := exec.Command(bin, append([]string{"-C", dir}, args...)...)
	hideWindow(cmd)
	return cmd.Output()
}

func loadGit(root string) *GitState {
	top, err := runGit(root, "rev-parse", "--show-toplevel")
	if err != nil {
		return nil
	}
	repo := filepath.Clean(strings.TrimSpace(string(top)))
	st := &GitState{Files: map[string]byte{}, Dirs: map[string]byte{}}
	if b, err := runGit(root, "rev-parse", "--abbrev-ref", "HEAD"); err == nil {
		st.Branch = strings.TrimSpace(string(b))
	}
	out, err := runGit(root, "status", "--porcelain=v1", "-z", "--untracked-files=all")
	if err != nil {
		return st
	}
	parts := bytes.Split(out, []byte{0})
	for i := 0; i < len(parts); i++ {
		p := parts[i]
		if len(p) < 4 {
			continue
		}
		x, y := p[0], p[1]
		rel := string(p[3:])
		if x == 'R' || x == 'C' {
			i++ // próximo item é o nome antigo
		}
		var code byte
		switch {
		case x == '?' && y == '?':
			code = 'U'
		case x == 'U' || y == 'U' || (x == 'A' && y == 'A') || (x == 'D' && y == 'D'):
			code = '!'
		case x == 'D' || y == 'D':
			code = 'D'
		case x == 'A':
			code = 'A'
		case x == 'R':
			code = 'R'
		default:
			code = 'M'
		}
		abs := filepath.Join(repo, filepath.FromSlash(strings.TrimSuffix(rel, "/")))
		st.Files[abs] = code
		for d := filepath.Dir(abs); len(d) >= len(repo); d = filepath.Dir(d) {
			if prev, ok := st.Dirs[d]; !ok || rank(code) > rank(prev) {
				st.Dirs[d] = code
			}
			if d == filepath.Dir(d) {
				break
			}
		}
	}
	return st
}

func rank(c byte) int {
	switch c {
	case '!':
		return 4
	case 'M':
		return 3
	case 'D':
		return 2
	default:
		return 1
	}
}
