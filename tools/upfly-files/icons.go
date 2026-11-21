package main

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/gdamore/tcell/v2"
)

// Ícones Nerd Font (o motor do Upfly Code já inclui a fonte de símbolos).
// Com UPFLY_FILES_ASCII=1, usa caracteres simples.
type icon struct {
	glyph string
	color tcell.Color
}

var asciiMode = os.Getenv("UPFLY_FILES_ASCII") == "1"

var (
	colFolder = tcell.NewHexColor(0x5AAAFF)
	colDim    = tcell.NewHexColor(0x7A8BA8)
)

var iconsByExt = map[string]icon{
	".go":   {"", tcell.NewHexColor(0x00ADD8)},
	".js":   {"", tcell.NewHexColor(0xF1DD35)},
	".mjs":  {"", tcell.NewHexColor(0xF1DD35)},
	".cjs":  {"", tcell.NewHexColor(0xF1DD35)},
	".jsx":  {"", tcell.NewHexColor(0x61DAFB)},
	".ts":   {"", tcell.NewHexColor(0x3178C6)},
	".tsx":  {"", tcell.NewHexColor(0x3178C6)},
	".json": {"", tcell.NewHexColor(0xCBCB41)},
	".md":   {"", tcell.NewHexColor(0x519ABA)},
	".py":   {"", tcell.NewHexColor(0x3572A5)},
	".rs":   {"", tcell.NewHexColor(0xDEA584)},
	".html": {"", tcell.NewHexColor(0xE34C26)},
	".htm":  {"", tcell.NewHexColor(0xE34C26)},
	".css":  {"", tcell.NewHexColor(0x563D7C)},
	".scss": {"", tcell.NewHexColor(0xC6538C)},
	".lua":  {"", tcell.NewHexColor(0x51A0CF)},
	".java": {"", tcell.NewHexColor(0xCC3E44)},
	".php":  {"", tcell.NewHexColor(0xA074C4)},
	".rb":   {"", tcell.NewHexColor(0xCC342D)},
	".c":    {"", tcell.NewHexColor(0x599EFF)},
	".h":    {"", tcell.NewHexColor(0xA074C4)},
	".cpp":  {"", tcell.NewHexColor(0xF34B7D)},
	".swift": {"", tcell.NewHexColor(0xE37933)},
	".sql":  {"", tcell.NewHexColor(0xDAD8D8)},
	".yml":  {"", tcell.NewHexColor(0xCB171E)},
	".yaml": {"", tcell.NewHexColor(0xCB171E)},
	".toml": {"", tcell.NewHexColor(0x9C4221)},
	".ini":  {"", colDim},
	".sh":   {"", tcell.NewHexColor(0x89E051)},
	".bash": {"", tcell.NewHexColor(0x89E051)},
	".ps1":  {"", tcell.NewHexColor(0x4273CA)},
	".cmd":  {"", tcell.NewHexColor(0xC1F12E)},
	".bat":  {"", tcell.NewHexColor(0xC1F12E)},
	".png":  {"", tcell.NewHexColor(0xA074C4)},
	".jpg":  {"", tcell.NewHexColor(0xA074C4)},
	".jpeg": {"", tcell.NewHexColor(0xA074C4)},
	".gif":  {"", tcell.NewHexColor(0xA074C4)},
	".svg":  {"", tcell.NewHexColor(0xFFB13B)},
	".ico":  {"", tcell.NewHexColor(0xA074C4)},
	".webp": {"", tcell.NewHexColor(0xA074C4)},
	".pdf":  {"", tcell.NewHexColor(0xB30B00)},
	".zip":  {"", tcell.NewHexColor(0xECA517)},
	".gz":   {"", tcell.NewHexColor(0xECA517)},
	".7z":   {"", tcell.NewHexColor(0xECA517)},
	".txt":  {"", colDim},
	".log":  {"", colDim},
	".csv":  {"", tcell.NewHexColor(0x89E051)},
	".xlsx": {"", tcell.NewHexColor(0x207245)},
	".docx": {"", tcell.NewHexColor(0x185ABD)},
	".exe":  {"", colDim},
	".lock": {"", colDim},
	".hjson": {"", tcell.NewHexColor(0xCBCB41)},
	".vue":  {"", tcell.NewHexColor(0x41B883)},
	".dart": {"", tcell.NewHexColor(0x03589C)},
	".kt":   {"", tcell.NewHexColor(0x7F52FF)},
	".cs":   {"", tcell.NewHexColor(0x596706)},
}

var iconsByName = map[string]icon{
	"dockerfile":    {"", tcell.NewHexColor(0x458EE6)},
	"readme.md":     {"", tcell.NewHexColor(0x519ABA)},
	"license":       {"", tcell.NewHexColor(0xCBCB41)},
	".gitignore":    {"", tcell.NewHexColor(0xF54D27)},
	".gitattributes": {"", tcell.NewHexColor(0xF54D27)},
	".env":          {"", tcell.NewHexColor(0xFAF743)},
	"package.json":  {"", tcell.NewHexColor(0xCB3837)},
	"claude.md":     {"", tcell.NewHexColor(0xD97757)},
	"version":       {"", colDim},
}

func fileIcon(n *Node) icon {
	if asciiMode {
		if n.IsDir {
			return icon{"", colFolder}
		}
		return icon{"", colDim}
	}
	if n.IsDir {
		name := strings.ToLower(n.Name)
		switch name {
		case ".github":
			return icon{"", colFolder}
		case ".git":
			return icon{"", colFolder}
		}
		if n.Expanded {
			return icon{"", colFolder}
		}
		return icon{"", colFolder}
	}
	lname := strings.ToLower(n.Name)
	if ic, ok := iconsByName[lname]; ok {
		return ic
	}
	if strings.HasPrefix(lname, ".env") {
		return iconsByName[".env"]
	}
	if ic, ok := iconsByExt[strings.ToLower(filepath.Ext(n.Name))]; ok {
		return ic
	}
	return icon{"", colDim}
}

func chevron(open bool) string {
	if asciiMode {
		if open {
			return "▾"
		}
		return "▸"
	}
	if open {
		return ""
	}
	return ""
}
