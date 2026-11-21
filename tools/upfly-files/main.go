// upfly-files — barra lateral de arquivos do Upfly Code.
//
// Árvore de pastas no estilo do VS Code/Trae: clique para abrir pastas,
// duplo clique ou Enter para abrir arquivos, clique direito para o menu,
// cores do Git, criar/renomear/excluir (para a Lixeira) e integração com o
// Claude Code (@mencionar arquivo) e com o terminal ao lado (cd).
//
// Uso: upfly-files [pasta]
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gdamore/tcell/v2"
	"github.com/rivo/uniseg"
)

const version = "1.0.0"

// ----------------------------------------------------------------- cores
var (
	colText     = tcell.NewHexColor(0xC9D6EA)
	colTitle    = tcell.NewHexColor(0xFFFFFF)
	colAccent   = tcell.NewHexColor(0x0080FF)
	colCyan     = tcell.NewHexColor(0x00D4FF)
	colSelBg    = tcell.NewHexColor(0x0E2A54)
	colSelBgDim = tcell.NewHexColor(0x16233A)
	colHoverBg  = tcell.NewHexColor(0x111B2E)
	colGuide    = tcell.NewHexColor(0x26324A)
	colMenuBg   = tcell.NewHexColor(0x0F1626)
	colMenuSel  = tcell.NewHexColor(0x0E3A75)
	colBar      = tcell.NewHexColor(0x0A0F1C)
	colGitM     = tcell.NewHexColor(0xE2C08D)
	colGitU     = tcell.NewHexColor(0x73C991)
	colGitD     = tcell.NewHexColor(0xC74E39)
	colGitC     = tcell.NewHexColor(0xE4676B)
	colWarn     = tcell.NewHexColor(0xFFC857)
)

func gitColor(c byte) tcell.Color {
	switch c {
	case 'M':
		return colGitM
	case 'U', 'A', 'R':
		return colGitU
	case 'D':
		return colGitD
	case '!':
		return colGitC
	}
	return colText
}

// ----------------------------------------------------------------- estado

type mode int

const (
	modeNormal mode = iota
	modeInput
	modeConfirm
	modeMenu
	modeFilter
	modeHelp
)

type menuItem struct {
	label string
	key   string
	run   func()
	sep   bool
}

type App struct {
	s          tcell.Screen
	root       *Node
	rows       []*Node
	sel        int
	top        int
	hover      int
	showHidden bool
	git        *GitState
	focused    bool

	mode        mode
	prompt      string
	input       []rune
	onSubmit    func(string)
	confirmText string
	onConfirm   func()

	menu     []menuItem
	menuX    int
	menuY    int
	menuSel  int
	menuW    int

	filterAll []string
	matches   []string
	filterSel int

	msg     string
	msgErr  bool
	msgTime time.Time

	lastClickRow  int
	lastClickTime time.Time
	prevButtons   tcell.ButtonMask
}

const headerRows = 2

func (a *App) treeHeight() int {
	_, h := a.s.Size()
	return h - headerRows - 1
}

func (a *App) refreshRows() {
	var selPath string
	if a.sel >= 0 && a.sel < len(a.rows) {
		selPath = a.rows[a.sel].Path
	}
	a.rows = flatten(a.root, a.showHidden)
	a.sel = 0
	for i, r := range a.rows {
		if r.Path == selPath {
			a.sel = i
			break
		}
	}
	if a.sel >= len(a.rows) {
		a.sel = len(a.rows) - 1
	}
	a.ensureVisible()
}

func (a *App) ensureVisible() {
	h := a.treeHeight()
	if a.sel < a.top {
		a.top = a.sel
	}
	if a.sel >= a.top+h {
		a.top = a.sel - h + 1
	}
	maxTop := len(a.rows) - h
	if maxTop < 0 {
		maxTop = 0
	}
	if a.top > maxTop {
		a.top = maxTop
	}
	if a.top < 0 {
		a.top = 0
	}
}

func (a *App) selected() *Node {
	if a.sel >= 0 && a.sel < len(a.rows) {
		return a.rows[a.sel]
	}
	return nil
}

func (a *App) selectPath(p string) {
	n := revealPath(a.root, p, a.showHidden)
	a.rows = flatten(a.root, a.showHidden)
	if n == nil {
		return
	}
	for i, r := range a.rows {
		if r == n {
			a.sel = i
			break
		}
	}
	a.ensureVisible()
}

func (a *App) flash(msg string, isErr bool) {
	a.msg, a.msgErr, a.msgTime = msg, isErr, time.Now()
}

// ----------------------------------------------------------------- desenho

func (a *App) put(x, y int, text string, st tcell.Style, maxX int) int {
	g := uniseg.NewGraphemes(text)
	for g.Next() {
		runes := g.Runes()
		w := g.Width()
		if w == 0 {
			continue
		}
		if x+w > maxX {
			break
		}
		a.s.SetContent(x, y, runes[0], runes[1:], st)
		if w == 2 {
			a.s.SetContent(x+1, y, ' ', nil, st) // célula de continuação
		}
		x += w
	}
	return x
}

func strWidth(s string) int { return uniseg.StringWidth(s) }

func truncate(s string, w int) string {
	if w <= 0 {
		return ""
	}
	if strWidth(s) <= w {
		return s
	}
	out := ""
	g := uniseg.NewGraphemes(s)
	cur := 0
	for g.Next() {
		gw := g.Width()
		if cur+gw > w-1 {
			break
		}
		out += g.Str()
		cur += gw
	}
	return out + "…"
}

func (a *App) fill(y int, st tcell.Style) {
	w, _ := a.s.Size()
	for x := 0; x < w; x++ {
		a.s.SetContent(x, y, ' ', nil, st)
	}
}

func (a *App) draw() {
	a.s.Clear()
	w, h := a.s.Size()
	base := tcell.StyleDefault.Foreground(colText)

	// Cabeçalho
	head := tcell.StyleDefault.Foreground(colDim)
	a.put(1, 0, "EXPLORADOR", head.Bold(true), w)
	hint := "? ajuda"
	a.put(w-strWidth(hint)-1, 0, hint, head, w)
	title := strings.ToUpper(a.root.Name)
	x := a.put(1, 1, chevron(true)+" ", tcell.StyleDefault.Foreground(colAccent), w)
	x = a.put(x, 1, truncate(title, w-x-2), tcell.StyleDefault.Foreground(colTitle).Bold(true), w)
	if a.git != nil && a.git.Branch != "" && x+4 < w {
		branch := "  " + a.git.Branch
		if asciiMode {
			branch = "  " + a.git.Branch
		}
		a.put(x, 1, truncate(branch, w-x-1), tcell.StyleDefault.Foreground(colAccent), w)
	}

	// Árvore
	th := a.treeHeight()
	if len(a.rows) == 0 {
		a.put(2, headerRows, "(pasta vazia)", tcell.StyleDefault.Foreground(colDim).Italic(true), w)
	}
	for i := 0; i < th; i++ {
		idx := a.top + i
		if idx >= len(a.rows) {
			break
		}
		y := headerRows + i
		n := a.rows[idx]
		rowSt := base
		switch {
		case idx == a.sel && a.focused:
			rowSt = rowSt.Background(colSelBg)
			a.fill(y, rowSt)
		case idx == a.sel:
			rowSt = rowSt.Background(colSelBgDim)
			a.fill(y, rowSt)
		case idx == a.hover:
			rowSt = rowSt.Background(colHoverBg)
			a.fill(y, rowSt)
		}
		// guias de indentação
		x := 1
		for d := 0; d < n.Depth; d++ {
			a.put(x, y, "│", rowSt.Foreground(colGuide), w)
			x += 2
		}
		if n.IsDir {
			x = a.put(x, y, chevron(n.Expanded), rowSt.Foreground(colDim), w)
		} else {
			x = a.put(x, y, " ", rowSt, w)
		}
		x++
		ic := fileIcon(n)
		if ic.glyph != "" {
			x = a.put(x, y, ic.glyph, rowSt.Foreground(ic.color), w)
			x++
		}
		// nome + status git
		nameSt := rowSt
		var badge string
		badgeCol := colText
		if a.git != nil {
			if n.IsDir {
				if c, ok := a.git.Dirs[n.Path]; ok {
					badge, badgeCol = "•", gitColor(c)
					nameSt = nameSt.Foreground(badgeCol)
				}
			} else if c, ok := a.git.Files[n.Path]; ok {
				badge, badgeCol = string(rune(c)), gitColor(c)
				nameSt = nameSt.Foreground(badgeCol)
				if c == 'D' {
					nameSt = nameSt.StrikeThrough(true)
				}
			}
		}
		if n.IsDir && heavyDirs[n.Name] {
			nameSt = nameSt.Foreground(colDim)
		}
		right := 1
		if badge != "" {
			right = 3
		}
		a.put(x, y, truncate(n.Name, w-x-right), nameSt, w-right+1)
		if badge != "" {
			a.put(w-2, y, badge, rowSt.Foreground(badgeCol), w)
		}
	}

	// Rodapé
	a.drawFooter(w, h)

	switch a.mode {
	case modeMenu:
		a.drawMenu(w, h)
	case modeHelp:
		a.drawHelp(w, h)
	case modeFilter:
		a.drawFilter(w, h)
	}
	a.s.Show()
}

func (a *App) drawFooter(w, h int) {
	y := h - 1
	bar := tcell.StyleDefault.Background(colBar).Foreground(colDim)
	a.fill(y, bar)
	switch a.mode {
	case modeInput:
		x := a.put(1, y, a.prompt+" ", bar.Foreground(colCyan), w)
		x = a.put(x, y, string(a.input), bar.Foreground(colTitle), w)
		a.s.ShowCursor(x, y)
		return
	case modeConfirm:
		a.put(1, y, truncate(a.confirmText+"  (s/N)", w-2), bar.Foreground(colWarn), w)
		return
	}
	a.s.HideCursor()
	if a.msg != "" && time.Since(a.msgTime) < 4*time.Second {
		st := bar.Foreground(colGitU)
		if a.msgErr {
			st = bar.Foreground(colGitC)
		}
		a.put(1, y, truncate(a.msg, w-2), st, w)
		return
	}
	hint := "? ajuda · botão direito: menu"
	if w > 60 {
		hint = "Enter abrir · botão direito: menu · @ citar no Claude · / buscar · ? ajuda"
	}
	a.put(1, y, truncate(hint, w-2), bar, w)
}

func (a *App) drawBox(x, y, bw, bh int, st tcell.Style) {
	for j := 0; j < bh; j++ {
		for i := 0; i < bw; i++ {
			r := ' '
			switch {
			case j == 0 && i == 0:
				r = '╭'
			case j == 0 && i == bw-1:
				r = '╮'
			case j == bh-1 && i == 0:
				r = '╰'
			case j == bh-1 && i == bw-1:
				r = '╯'
			case j == 0 || j == bh-1:
				r = '─'
			case i == 0 || i == bw-1:
				r = '│'
			}
			bst := st
			if r != ' ' {
				bst = st.Foreground(colGuide)
			}
			a.s.SetContent(x+i, y+j, r, nil, bst)
		}
	}
}

func (a *App) menuGeometry(w, h int) (x, y, bw, bh int) {
	bw = a.menuW + 4
	if bw > w {
		bw = w
	}
	bh = len(a.menu) + 2
	x, y = a.menuX, a.menuY
	if x+bw > w {
		x = w - bw
	}
	if y+bh > h-1 {
		y = h - 1 - bh
	}
	if x < 0 {
		x = 0
	}
	if y < 0 {
		y = 0
	}
	return
}

func (a *App) drawMenu(w, h int) {
	x, y, bw, bh := a.menuGeometry(w, h)
	st := tcell.StyleDefault.Background(colMenuBg).Foreground(colText)
	a.drawBox(x, y, bw, bh, st)
	for i, it := range a.menu {
		yy := y + 1 + i
		if it.sep {
			for xx := x + 1; xx < x+bw-1; xx++ {
				a.s.SetContent(xx, yy, '─', nil, st.Foreground(colGuide))
			}
			continue
		}
		rs := st
		if i == a.menuSel {
			rs = st.Background(colMenuSel).Foreground(colTitle)
			for xx := x + 1; xx < x+bw-1; xx++ {
				a.s.SetContent(xx, yy, ' ', nil, rs)
			}
		}
		a.put(x+2, yy, truncate(it.label, bw-4-strWidth(it.key)-1), rs, x+bw-1)
		if it.key != "" {
			a.put(x+bw-2-strWidth(it.key), yy, it.key, rs.Foreground(colDim), x+bw-1)
		}
	}
}

var helpLines = []string{
	"MOUSE",
	" clique      abre/fecha pasta",
	" 2 cliques   abre o arquivo",
	" botão dir.  menu de ações",
	"",
	"TECLADO",
	" ↑↓ →←    navegar",
	" Enter    abrir",
	" @        citar no Claude",
	" c        cd no terminal",
	" a / A    novo arq. / pasta",
	" F2       renomear",
	" Del      enviar à Lixeira",
	" /        buscar",
	" y / Y    copiar caminho",
	" o        programa padrão",
	" x        mostrar na pasta",
	" .        mostrar ocultos",
	" z        recolher tudo",
	" F5       atualizar",
	" q        fechar a barra",
}

func (a *App) drawHelp(w, h int) {
	bw := 0
	for _, l := range helpLines {
		if strWidth(l) > bw {
			bw = strWidth(l)
		}
	}
	bw += 4
	if bw > w {
		bw = w
	}
	bh := len(helpLines) + 2
	if bh > h {
		bh = h
	}
	x, y := (w-bw)/2, (h-bh)/2
	st := tcell.StyleDefault.Background(colMenuBg).Foreground(colText)
	a.drawBox(x, y, bw, bh, st)
	for i, l := range helpLines {
		if i+1 >= bh-1 {
			break
		}
		ls := st
		if l != "" && !strings.HasPrefix(l, " ") {
			ls = st.Foreground(colCyan).Bold(true)
		}
		a.put(x+2, y+1+i, truncate(l, bw-4), ls, x+bw-1)
	}
}

func (a *App) drawFilter(w, h int) {
	th := a.treeHeight()
	st := tcell.StyleDefault.Foreground(colText)
	for y := headerRows; y < headerRows+th; y++ {
		a.fill(y, tcell.StyleDefault)
	}
	if len(a.matches) == 0 {
		a.put(2, headerRows, "nenhum arquivo encontrado", st.Foreground(colDim).Italic(true), w)
	}
	for i := 0; i < th && i < len(a.matches); i++ {
		y := headerRows + i
		p := a.matches[i]
		rel, _ := filepath.Rel(a.root.Path, p)
		rs := st
		if i == a.filterSel {
			rs = st.Background(colSelBg)
			a.fill(y, rs)
		}
		n := &Node{Name: filepath.Base(p), Path: p}
		if fi, err := os.Stat(p); err == nil {
			n.IsDir = fi.IsDir()
		}
		ic := fileIcon(n)
		x := a.put(1, y, ic.glyph, rs.Foreground(ic.color), w)
		x = a.put(x+1, y, n.Name, rs.Foreground(colTitle), w)
		dir := filepath.ToSlash(filepath.Dir(rel))
		if dir != "." {
			a.put(x+1, y, truncate(dir, w-x-2), rs.Foreground(colDim), w)
		}
	}
	y := h - 1
	bar := tcell.StyleDefault.Background(colBar)
	a.fill(y, bar)
	x := a.put(1, y, "/ ", bar.Foreground(colCyan), w)
	x = a.put(x, y, string(a.input), bar.Foreground(colTitle), w)
	a.s.ShowCursor(x, y)
}

// ----------------------------------------------------------------- ações

func (a *App) currentDir() string {
	n := a.selected()
	if n == nil {
		return a.root.Path
	}
	if n.IsDir {
		return n.Path
	}
	return filepath.Dir(n.Path)
}

func (a *App) reloadDir(dir string) {
	var find func(n *Node) *Node
	find = func(n *Node) *Node {
		if n.Path == dir {
			return n
		}
		for _, c := range n.Children {
			if c.IsDir && strings.HasPrefix(dir, c.Path) {
				if r := find(c); r != nil {
					return r
				}
			}
		}
		return nil
	}
	if n := find(a.root); n != nil {
		n.load(a.showHidden)
	}
	a.refreshRows()
}

func (a *App) activate(n *Node) {
	if n == nil {
		return
	}
	if n.IsDir {
		n.Expanded = !n.Expanded
		a.refreshRows()
		return
	}
	if name, err := openInEditor(n.Path); err != nil {
		a.flash("Não foi possível abrir: "+err.Error(), true)
	} else {
		a.flash("Abrindo no "+name+"…", false)
	}
}

func (a *App) mention(n *Node) {
	if n == nil {
		return
	}
	pane, err := targetPane()
	if err != nil {
		a.flash(err.Error(), true)
		return
	}
	if err := sendToPane(pane, mentionText(a.root.Path, n.Path), true); err != nil {
		a.flash("Não foi possível enviar ao terminal", true)
		return
	}
	a.flash("Mencionado: "+n.Name, false)
}

func (a *App) cdHere(dir string) {
	pane, err := targetPane()
	if err != nil {
		a.flash(err.Error(), true)
		return
	}
	if err := sendToPane(pane, "cd "+shellQuote(shellPath(dir))+"\r", true); err != nil {
		a.flash("Não foi possível enviar ao terminal", true)
		return
	}
	a.flash("Terminal em: "+filepath.Base(dir), false)
}

func (a *App) copyPath(p string) {
	a.s.SetClipboard([]byte(p))
	a.flash("Caminho copiado", false)
}

func (a *App) askInput(prompt, initial string, fn func(string)) {
	a.mode = modeInput
	a.prompt = prompt
	a.input = []rune(initial)
	a.onSubmit = fn
}

func (a *App) askConfirm(text string, fn func()) {
	a.mode = modeConfirm
	a.confirmText = text
	a.onConfirm = fn
}

func validName(name string) bool {
	name = strings.TrimSpace(name)
	return name != "" && name != "." && name != ".." && !strings.ContainsAny(name, `<>:"|?*`)
}

func (a *App) newFile(dir string) {
	a.askInput("Novo arquivo:", "", func(name string) {
		if !validName(strings.ReplaceAll(name, "/", "")) {
			a.flash("Nome inválido", true)
			return
		}
		p := filepath.Join(dir, filepath.FromSlash(strings.TrimSpace(name)))
		if _, err := os.Stat(p); err == nil {
			a.flash("Já existe", true)
			return
		}
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			a.flash(err.Error(), true)
			return
		}
		f, err := os.Create(p)
		if err != nil {
			a.flash(err.Error(), true)
			return
		}
		f.Close()
		a.reloadDir(dir)
		a.selectPath(p)
		a.flash("Criado: "+filepath.Base(p), false)
	})
}

func (a *App) newFolder(dir string) {
	a.askInput("Nova pasta:", "", func(name string) {
		if !validName(strings.ReplaceAll(name, "/", "")) {
			a.flash("Nome inválido", true)
			return
		}
		p := filepath.Join(dir, filepath.FromSlash(strings.TrimSpace(name)))
		if err := os.MkdirAll(p, 0o755); err != nil {
			a.flash(err.Error(), true)
			return
		}
		a.reloadDir(dir)
		a.selectPath(p)
		a.flash("Pasta criada", false)
	})
}

func (a *App) rename(n *Node) {
	if n == nil {
		return
	}
	a.askInput("Renomear para:", n.Name, func(name string) {
		name = strings.TrimSpace(name)
		if !validName(name) || strings.ContainsAny(name, `/\`) {
			a.flash("Nome inválido", true)
			return
		}
		if name == n.Name {
			return
		}
		np := filepath.Join(filepath.Dir(n.Path), name)
		if _, err := os.Stat(np); err == nil && !strings.EqualFold(np, n.Path) {
			a.flash("Já existe um item com esse nome", true)
			return
		}
		if err := os.Rename(n.Path, np); err != nil {
			a.flash(err.Error(), true)
			return
		}
		a.reloadDir(filepath.Dir(n.Path))
		a.selectPath(np)
		a.flash("Renomeado", false)
	})
}

func (a *App) remove(n *Node) {
	if n == nil {
		return
	}
	a.askConfirm(fmt.Sprintf("Enviar \"%s\" para a Lixeira?", n.Name), func() {
		if err := moveToTrash(n.Path, n.IsDir); err != nil {
			a.flash("Não foi possível excluir: "+err.Error(), true)
			return
		}
		a.reloadDir(filepath.Dir(n.Path))
		a.flash("Enviado para a Lixeira", false)
	})
}

func (a *App) collapseAll() {
	var walk func(n *Node)
	walk = func(n *Node) {
		for _, c := range n.Children {
			c.Expanded = false
			walk(c)
		}
	}
	walk(a.root)
	a.refreshRows()
}

func (a *App) toggleHidden() {
	a.showHidden = !a.showHidden
	var walk func(n *Node)
	walk = func(n *Node) {
		if n.Loaded {
			n.load(a.showHidden)
			for _, c := range n.Children {
				walk(c)
			}
		}
	}
	walk(a.root)
	a.refreshRows()
	if a.showHidden {
		a.flash("Mostrando arquivos ocultos", false)
	} else {
		a.flash("Ocultando arquivos ocultos", false)
	}
}

func revealLabel() string {
	switch {
	case isWindows():
		return "Mostrar no Explorer"
	case isMac():
		return "Mostrar no Finder"
	}
	return "Abrir pasta no gerenciador"
}

func (a *App) openMenu(n *Node, x, y int) {
	var items []menuItem
	root := a.root
	if n == nil {
		items = []menuItem{
			{label: "Novo arquivo…", key: "a", run: func() { a.newFile(root.Path) }},
			{label: "Nova pasta…", key: "A", run: func() { a.newFolder(root.Path) }},
			{sep: true},
			{label: "Terminal nesta pasta", key: "c", run: func() { a.cdHere(root.Path) }},
			{label: revealLabel(), key: "x", run: func() { _ = reveal(root.Path) }},
			{sep: true},
			{label: "Recolher tudo", key: "z", run: a.collapseAll},
			{label: "Mostrar/ocultar ocultos", key: ".", run: a.toggleHidden},
			{label: "Atualizar", key: "F5", run: a.fullRefresh},
		}
	} else if n.IsDir {
		items = []menuItem{
			{label: "Novo arquivo…", key: "a", run: func() { a.newFile(n.Path) }},
			{label: "Nova pasta…", key: "A", run: func() { a.newFolder(n.Path) }},
			{sep: true},
			{label: "Terminal nesta pasta", key: "c", run: func() { a.cdHere(n.Path) }},
			{label: "Mencionar no Claude", key: "@", run: func() { a.mention(n) }},
			{label: "Abrir no editor", key: "e", run: func() { a.editor(n) }},
			{label: revealLabel(), key: "x", run: func() { _ = reveal(n.Path) }},
			{sep: true},
			{label: "Copiar caminho", key: "y", run: func() { a.copyPath(n.Path) }},
			{label: "Copiar caminho relativo", key: "Y", run: func() { a.copyPath(relPath(root.Path, n.Path)) }},
			{sep: true},
			{label: "Renomear…", key: "F2", run: func() { a.rename(n) }},
			{label: "Excluir", key: "Del", run: func() { a.remove(n) }},
		}
	} else {
		items = []menuItem{
			{label: "Abrir no editor", key: "Enter", run: func() { a.editor(n) }},
			{label: "Abrir com o programa padrão", key: "o", run: func() { a.openWithDefault(n) }},
			{label: "Mencionar no Claude", key: "@", run: func() { a.mention(n) }},
			{label: revealLabel(), key: "x", run: func() { _ = reveal(n.Path) }},
			{sep: true},
			{label: "Copiar caminho", key: "y", run: func() { a.copyPath(n.Path) }},
			{label: "Copiar caminho relativo", key: "Y", run: func() { a.copyPath(relPath(root.Path, n.Path)) }},
			{sep: true},
			{label: "Renomear…", key: "F2", run: func() { a.rename(n) }},
			{label: "Excluir", key: "Del", run: func() { a.remove(n) }},
		}
	}
	a.menu = items
	a.menuW = 0
	for _, it := range items {
		if l := strWidth(it.label) + strWidth(it.key) + 3; l > a.menuW {
			a.menuW = l
		}
	}
	a.menuX, a.menuY = x, y
	a.menuSel = 0
	a.mode = modeMenu
}

func (a *App) editor(n *Node) {
	if name, err := openInEditor(n.Path); err != nil {
		a.flash("Não foi possível abrir: "+err.Error(), true)
	} else {
		a.flash("Abrindo no "+name+"…", false)
	}
}

func (a *App) openWithDefault(n *Node) {
	if err := openDefault(n.Path); err != nil {
		a.flash("Não foi possível abrir: "+err.Error(), true)
	}
}

func relPath(root, p string) string {
	r, err := filepath.Rel(root, p)
	if err != nil {
		return p
	}
	return filepath.ToSlash(r)
}

func (a *App) fullRefresh() {
	var walk func(n *Node)
	walk = func(n *Node) {
		if n.Loaded {
			n.load(a.showHidden)
			for _, c := range n.Children {
				walk(c)
			}
		}
	}
	walk(a.root)
	a.refreshRows()
	go a.refreshGit()
	a.flash("Atualizado", false)
}

func (a *App) refreshGit() {
	st := loadGit(a.root.Path)
	a.s.PostEvent(tcell.NewEventInterrupt(st))
}

// ----------------------------------------------------------------- filtro

func (a *App) startFilter() {
	a.mode = modeFilter
	a.input = nil
	a.filterSel = 0
	a.filterAll = walkAll(a.root.Path, a.showHidden, 20000)
	a.updateMatches()
}

func (a *App) updateMatches() {
	q := strings.ToLower(string(a.input))
	a.matches = a.matches[:0]
	type scored struct {
		p string
		s int
	}
	var res []scored
	for _, p := range a.filterAll {
		name := strings.ToLower(filepath.Base(p))
		rel := strings.ToLower(filepath.ToSlash(relPath(a.root.Path, p)))
		score := -1
		switch {
		case q == "":
			score = 0
		case strings.HasPrefix(name, q):
			score = 3
		case strings.Contains(name, q):
			score = 2
		case strings.Contains(rel, q):
			score = 1
		case fuzzy(rel, q):
			score = 0
		}
		if score >= 0 {
			res = append(res, scored{p, score})
		}
	}
	// melhores primeiro, mantendo a ordem do disco entre iguais
	for s := 3; s >= 0; s-- {
		for _, r := range res {
			if r.s == s {
				a.matches = append(a.matches, r.p)
				if len(a.matches) > 500 {
					break
				}
			}
		}
	}
	if a.filterSel >= len(a.matches) {
		a.filterSel = len(a.matches) - 1
	}
	if a.filterSel < 0 {
		a.filterSel = 0
	}
}

func fuzzy(s, q string) bool {
	i := 0
	for _, r := range s {
		if i < len(q) && byte(r) == q[i] {
			i++
		}
	}
	return i == len(q)
}

// ----------------------------------------------------------------- eventos

func (a *App) handleKey(ev *tcell.EventKey) bool {
	switch a.mode {
	case modeHelp:
		a.mode = modeNormal
		return true
	case modeInput:
		switch ev.Key() {
		case tcell.KeyEscape:
			a.mode = modeNormal
		case tcell.KeyEnter:
			a.mode = modeNormal
			if fn := a.onSubmit; fn != nil {
				fn(string(a.input))
			}
		case tcell.KeyBackspace, tcell.KeyBackspace2:
			if len(a.input) > 0 {
				a.input = a.input[:len(a.input)-1]
			}
		case tcell.KeyCtrlU:
			a.input = nil
		case tcell.KeyRune:
			a.input = append(a.input, ev.Rune())
		}
		return true
	case modeConfirm:
		a.mode = modeNormal
		if ev.Key() == tcell.KeyRune && (ev.Rune() == 's' || ev.Rune() == 'S' || ev.Rune() == 'y' || ev.Rune() == 'Y') {
			if a.onConfirm != nil {
				a.onConfirm()
			}
		} else {
			a.flash("Cancelado", false)
		}
		return true
	case modeMenu:
		switch ev.Key() {
		case tcell.KeyEscape:
			a.mode = modeNormal
		case tcell.KeyUp:
			a.moveMenu(-1)
		case tcell.KeyDown:
			a.moveMenu(1)
		case tcell.KeyEnter:
			a.runMenu(a.menuSel)
		}
		return true
	case modeFilter:
		switch ev.Key() {
		case tcell.KeyEscape:
			a.mode = modeNormal
			a.s.HideCursor()
		case tcell.KeyEnter:
			a.mode = modeNormal
			a.s.HideCursor()
			if a.filterSel < len(a.matches) {
				p := a.matches[a.filterSel]
				a.selectPath(p)
			}
		case tcell.KeyUp:
			if a.filterSel > 0 {
				a.filterSel--
			}
		case tcell.KeyDown:
			if a.filterSel < len(a.matches)-1 {
				a.filterSel++
			}
		case tcell.KeyBackspace, tcell.KeyBackspace2:
			if len(a.input) > 0 {
				a.input = a.input[:len(a.input)-1]
				a.updateMatches()
			}
		case tcell.KeyRune:
			a.input = append(a.input, ev.Rune())
			a.filterSel = 0
			a.updateMatches()
		}
		return true
	}

	n := a.selected()
	switch ev.Key() {
	case tcell.KeyUp:
		a.move(-1)
	case tcell.KeyDown:
		a.move(1)
	case tcell.KeyPgUp:
		a.move(-a.treeHeight())
	case tcell.KeyPgDn:
		a.move(a.treeHeight())
	case tcell.KeyHome:
		a.sel = 0
		a.ensureVisible()
	case tcell.KeyEnd:
		a.sel = len(a.rows) - 1
		a.ensureVisible()
	case tcell.KeyRight:
		if n != nil && n.IsDir {
			if !n.Expanded {
				n.Expanded = true
				a.refreshRows()
			} else {
				a.move(1)
			}
		}
	case tcell.KeyLeft:
		if n != nil {
			if n.IsDir && n.Expanded {
				n.Expanded = false
				a.refreshRows()
			} else if n.Parent != nil && n.Parent != a.root {
				a.selectPath(n.Parent.Path)
			}
		}
	case tcell.KeyEnter:
		a.activate(n)
	case tcell.KeyF2:
		a.rename(n)
	case tcell.KeyDelete:
		a.remove(n)
	case tcell.KeyF5:
		a.fullRefresh()
	case tcell.KeyCtrlF:
		a.startFilter()
	case tcell.KeyEscape:
		a.msg = ""
	case tcell.KeyRune:
		switch ev.Rune() {
		case 'k':
			a.move(-1)
		case 'j':
			a.move(1)
		case ' ':
			a.activate(n)
		case '@':
			a.mention(n)
		case 'c':
			a.cdHere(a.currentDir())
		case 'a', 'n':
			a.newFile(a.currentDir())
		case 'A', 'N':
			a.newFolder(a.currentDir())
		case 'r':
			a.rename(n)
		case 'd':
			a.remove(n)
		case '/':
			a.startFilter()
		case 'y':
			if n != nil {
				a.copyPath(n.Path)
			}
		case 'Y':
			if n != nil {
				a.copyPath(relPath(a.root.Path, n.Path))
			}
		case 'o':
			if n != nil {
				a.openWithDefault(n)
			}
		case 'e':
			if n != nil {
				a.editor(n)
			}
		case 'x':
			if n != nil {
				_ = reveal(n.Path)
			}
		case '.':
			a.toggleHidden()
		case 'z':
			a.collapseAll()
		case 'R':
			a.fullRefresh()
		case 'm':
			if n != nil {
				a.openMenu(n, 4, headerRows+a.sel-a.top+1)
			}
		case '?':
			a.mode = modeHelp
		case 'q':
			return false
		}
	}
	return true
}

func (a *App) move(d int) {
	if len(a.rows) == 0 {
		return
	}
	a.sel += d
	if a.sel < 0 {
		a.sel = 0
	}
	if a.sel >= len(a.rows) {
		a.sel = len(a.rows) - 1
	}
	a.ensureVisible()
}

func (a *App) moveMenu(d int) {
	for i := 0; i < len(a.menu); i++ {
		a.menuSel = (a.menuSel + d + len(a.menu)) % len(a.menu)
		if !a.menu[a.menuSel].sep {
			return
		}
	}
}

func (a *App) runMenu(i int) {
	a.mode = modeNormal
	if i >= 0 && i < len(a.menu) && !a.menu[i].sep && a.menu[i].run != nil {
		a.menu[i].run()
	}
}

func (a *App) rowAt(y int) int {
	if y < headerRows || y >= headerRows+a.treeHeight() {
		return -1
	}
	idx := a.top + y - headerRows
	if idx >= len(a.rows) {
		return -1
	}
	return idx
}

func (a *App) handleMouse(ev *tcell.EventMouse) {
	x, y := ev.Position()
	btn := ev.Buttons()
	pressed := btn &^ a.prevButtons
	a.prevButtons = btn & (tcell.Button1 | tcell.Button2 | tcell.Button3)

	if btn&tcell.WheelUp != 0 {
		a.scroll(-3)
		return
	}
	if btn&tcell.WheelDown != 0 {
		a.scroll(3)
		return
	}

	w, h := a.s.Size()
	switch a.mode {
	case modeMenu:
		mx, my, bw, bh := a.menuGeometry(w, h)
		inside := x >= mx && x < mx+bw && y > my && y < my+bh-1
		if inside {
			a.menuSel = y - my - 1
		}
		if pressed&(tcell.Button1|tcell.Button3) != 0 {
			if inside && !a.menu[a.menuSel].sep {
				a.runMenu(a.menuSel)
			} else if !inside {
				a.mode = modeNormal
			}
		}
		return
	case modeHelp:
		if pressed != 0 {
			a.mode = modeNormal
		}
		return
	case modeFilter:
		if pressed&tcell.Button1 != 0 {
			if y >= headerRows && y-headerRows < len(a.matches) {
				a.filterSel = y - headerRows
				a.mode = modeNormal
				a.s.HideCursor()
				a.selectPath(a.matches[a.filterSel])
			}
		}
		return
	case modeInput, modeConfirm:
		return
	}

	row := a.rowAt(y)
	a.hover = row
	if pressed&tcell.Button1 != 0 {
		if y == 0 && x >= w-8 {
			a.mode = modeHelp
			return
		}
		if y == 1 {
			a.collapseAll()
			return
		}
		if row < 0 {
			return
		}
		now := time.Now()
		double := row == a.lastClickRow && now.Sub(a.lastClickTime) < 450*time.Millisecond
		a.lastClickRow, a.lastClickTime = row, now
		a.sel = row
		n := a.rows[row]
		if n.IsDir {
			n.Expanded = !n.Expanded
			a.refreshRows()
		} else if double {
			a.activate(n)
		}
		return
	}
	if pressed&tcell.Button3 != 0 {
		if row >= 0 {
			a.sel = row
			a.openMenu(a.rows[row], x, y)
		} else {
			a.openMenu(nil, x, y)
		}
	}
}

func (a *App) scroll(d int) {
	if a.mode == modeFilter {
		return
	}
	a.top += d
	a.ensureScrollBounds()
}

func (a *App) ensureScrollBounds() {
	h := a.treeHeight()
	maxTop := len(a.rows) - h
	if maxTop < 0 {
		maxTop = 0
	}
	if a.top > maxTop {
		a.top = maxTop
	}
	if a.top < 0 {
		a.top = 0
	}
}

// pollChanges recarrega pastas abertas que mudaram no disco.
func (a *App) pollChanges() bool {
	changed := false
	var walk func(n *Node)
	walk = func(n *Node) {
		if !n.IsDir || !n.Loaded {
			return
		}
		if n.Expanded && n.changed() {
			n.load(a.showHidden)
			changed = true
		}
		for _, c := range n.Children {
			if c.IsDir && c.Expanded {
				walk(c)
			}
		}
	}
	walk(a.root)
	if changed {
		a.refreshRows()
	}
	return changed
}

type tick struct{}

func run(dir string) error {
	s, err := tcell.NewScreen()
	if err != nil {
		return err
	}
	if err := s.Init(); err != nil {
		return err
	}
	defer s.Fini()
	s.EnableMouse(tcell.MouseMotionEvents)
	s.EnableFocus()
	s.SetStyle(tcell.StyleDefault)

	a := &App{s: s, root: newRoot(dir), hover: -1, lastClickRow: -1, focused: true}
	a.root.load(a.showHidden)
	a.refreshRows()
	go a.refreshGit()

	go func() {
		t := time.NewTicker(1500 * time.Millisecond)
		g := 0
		for range t.C {
			s.PostEvent(tcell.NewEventInterrupt(tick{}))
			g++
			if g%3 == 0 {
				a.refreshGit()
			}
		}
	}()

	a.draw()
	for {
		ev := s.PollEvent()
		switch ev := ev.(type) {
		case *tcell.EventResize:
			s.Sync()
			a.ensureVisible()
		case *tcell.EventKey:
			if !a.handleKey(ev) {
				return nil
			}
		case *tcell.EventMouse:
			a.handleMouse(ev)
		case *tcell.EventFocus:
			a.focused = ev.Focused
		case *tcell.EventInterrupt:
			switch d := ev.Data().(type) {
			case *GitState:
				a.git = d
			case tick:
				if a.mode == modeNormal {
					a.pollChanges()
				}
			}
		case nil:
			return nil
		}
		a.draw()
	}
}

func main() {
	dir := "."
	for _, arg := range os.Args[1:] {
		switch arg {
		case "--version", "-v":
			fmt.Println("upfly-files", version)
			return
		case "--help", "-h":
			fmt.Println("upfly-files [pasta] — barra lateral de arquivos do Upfly Code")
			return
		default:
			dir = arg
		}
	}
	if st, err := os.Stat(dir); err != nil || !st.IsDir() {
		fmt.Fprintln(os.Stderr, "Pasta não encontrada:", dir)
		os.Exit(1)
	}
	if err := run(dir); err != nil {
		fmt.Fprintln(os.Stderr, "upfly-files:", err)
		os.Exit(1)
	}
}
