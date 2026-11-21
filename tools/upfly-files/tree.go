package main

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Node é um arquivo ou pasta na árvore.
type Node struct {
	Name     string
	Path     string
	IsDir    bool
	Expanded bool
	Loaded   bool
	Children []*Node
	Parent   *Node
	Depth    int
	dirMod   time.Time
}

// Arquivos que nunca aparecem (como no VS Code)
var alwaysHidden = map[string]bool{
	".git": true, ".DS_Store": true, "Thumbs.db": true, "desktop.ini": true,
	".svn": true, ".hg": true,
}

// Pastas pesadas: aparecem, mas apagadas
var heavyDirs = map[string]bool{
	"node_modules": true, "dist": true, "build": true, "target": true, ".next": true,
	"vendor": true, "__pycache__": true, ".venv": true, "venv": true, "bin": false,
}

func newRoot(path string) *Node {
	abs, err := filepath.Abs(path)
	if err != nil {
		abs = path
	}
	// caminho real (macOS: /var -> /private/var), para casar com o Git
	if real, err := filepath.EvalSymlinks(abs); err == nil {
		abs = real
	}
	name := filepath.Base(abs)
	if name == "" || name == "." || name == string(filepath.Separator) {
		name = abs
	}
	return &Node{Name: name, Path: abs, IsDir: true, Expanded: true, Depth: -1}
}

// load lê o conteúdo da pasta, preservando o estado das subpastas abertas.
func (n *Node) load(showHidden bool) {
	if !n.IsDir {
		return
	}
	entries, err := os.ReadDir(n.Path)
	if st, e := os.Stat(n.Path); e == nil {
		n.dirMod = st.ModTime()
	}
	n.Loaded = true
	if err != nil {
		n.Children = nil
		return
	}
	old := map[string]*Node{}
	for _, c := range n.Children {
		old[c.Name] = c
	}
	var kids []*Node
	for _, e := range entries {
		name := e.Name()
		if alwaysHidden[name] {
			continue
		}
		full := filepath.Join(n.Path, name)
		info, ierr := e.Info()
		if ierr != nil {
			continue
		}
		if !showHidden && isSystemHidden(full, info) {
			continue
		}
		isDir := e.IsDir()
		if info.Mode()&os.ModeSymlink != 0 {
			if st, serr := os.Stat(full); serr == nil {
				isDir = st.IsDir()
			}
		}
		if prev, ok := old[name]; ok && prev.IsDir == isDir {
			kids = append(kids, prev)
			continue
		}
		kids = append(kids, &Node{Name: name, Path: full, IsDir: isDir, Parent: n, Depth: n.Depth + 1})
	}
	sort.SliceStable(kids, func(i, j int) bool {
		if kids[i].IsDir != kids[j].IsDir {
			return kids[i].IsDir
		}
		return naturalLess(strings.ToLower(kids[i].Name), strings.ToLower(kids[j].Name))
	})
	n.Children = kids
}

// changed diz se a pasta mudou no disco desde a última leitura.
func (n *Node) changed() bool {
	st, err := os.Stat(n.Path)
	if err != nil {
		return true
	}
	return !st.ModTime().Equal(n.dirMod)
}

// flatten devolve as linhas visíveis (pastas abertas).
func flatten(root *Node, showHidden bool) []*Node {
	var out []*Node
	var walk func(n *Node)
	walk = func(n *Node) {
		if n.IsDir && n.Expanded {
			if !n.Loaded {
				n.load(showHidden)
			}
			for _, c := range n.Children {
				out = append(out, c)
				walk(c)
			}
		}
	}
	walk(root)
	return out
}

// revealPath abre as pastas até o caminho e devolve o nó.
func revealPath(root *Node, target string, showHidden bool) *Node {
	rel, err := filepath.Rel(root.Path, target)
	if err != nil || strings.HasPrefix(rel, "..") {
		return nil
	}
	cur := root
	if rel == "." {
		return root
	}
	for _, part := range strings.Split(rel, string(filepath.Separator)) {
		if !cur.Loaded {
			cur.load(showHidden)
		}
		cur.Expanded = true
		var next *Node
		for _, c := range cur.Children {
			if c.Name == part {
				next = c
				break
			}
		}
		if next == nil {
			return nil
		}
		cur = next
	}
	return cur
}

// naturalLess compara "file2" < "file10".
func naturalLess(a, b string) bool {
	for a != "" && b != "" {
		ad, bd := isDigit(a[0]), isDigit(b[0])
		if ad && bd {
			ai, bi := 0, 0
			for ai < len(a) && isDigit(a[ai]) {
				ai++
			}
			for bi < len(b) && isDigit(b[bi]) {
				bi++
			}
			na, nb := strings.TrimLeft(a[:ai], "0"), strings.TrimLeft(b[:bi], "0")
			if len(na) != len(nb) {
				return len(na) < len(nb)
			}
			if na != nb {
				return na < nb
			}
			a, b = a[ai:], b[bi:]
			continue
		}
		if a[0] != b[0] {
			return a[0] < b[0]
		}
		a, b = a[1:], b[1:]
	}
	return len(a) < len(b)
}

func isDigit(c byte) bool { return c >= '0' && c <= '9' }

// walkAll lista todos os caminhos (para o filtro), com limites de segurança.
func walkAll(root string, showHidden bool, limit int) []string {
	var out []string
	var walk func(dir string, depth int)
	walk = func(dir string, depth int) {
		if len(out) >= limit || depth > 12 {
			return
		}
		entries, err := os.ReadDir(dir)
		if err != nil {
			return
		}
		for _, e := range entries {
			name := e.Name()
			if alwaysHidden[name] || name == "node_modules" {
				continue
			}
			full := filepath.Join(dir, name)
			if info, err := e.Info(); err == nil && !showHidden && isSystemHidden(full, info) {
				continue
			}
			out = append(out, full)
			if len(out) >= limit {
				return
			}
			if e.IsDir() {
				walk(full, depth+1)
			}
		}
	}
	walk(root, 0)
	return out
}
