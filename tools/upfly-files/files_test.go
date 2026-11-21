package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestNaturalLess(t *testing.T) {
	if !naturalLess("file2", "file10") || naturalLess("file10", "file2") {
		t.Fatal("ordem natural incorreta")
	}
}

func TestTreeFoldersFirstAndHidden(t *testing.T) {
	dir := t.TempDir()
	os.MkdirAll(filepath.Join(dir, "src"), 0o755)
	os.MkdirAll(filepath.Join(dir, ".git"), 0o755)
	os.WriteFile(filepath.Join(dir, "b.txt"), nil, 0o644)
	os.WriteFile(filepath.Join(dir, "A.md"), nil, 0o644)
	os.WriteFile(filepath.Join(dir, ".env"), nil, 0o644)
	root := newRoot(dir)
	rows := flatten(root, false)
	var names []string
	for _, r := range rows {
		names = append(names, r.Name)
	}
	want := []string{"src", ".env", "A.md", "b.txt"}
	if len(names) != len(want) {
		t.Fatalf("esperado %v, veio %v", want, names)
	}
	for i := range want {
		if names[i] != want[i] {
			t.Fatalf("esperado %v, veio %v", want, names)
		}
	}
}

func TestRevealPath(t *testing.T) {
	dir := t.TempDir()
	deep := filepath.Join(dir, "a", "b", "c.txt")
	os.MkdirAll(filepath.Dir(deep), 0o755)
	os.WriteFile(deep, nil, 0o644)
	root := newRoot(dir)
	realDeep, _ := filepath.EvalSymlinks(deep)
	n := revealPath(root, realDeep, false)
	if n == nil || n.Name != "c.txt" {
		t.Fatal("não encontrou o arquivo")
	}
	rows := flatten(root, false)
	if len(rows) != 3 {
		t.Fatalf("pastas não foram abertas: %d linhas", len(rows))
	}
}

func TestMentionText(t *testing.T) {
	root := filepath.FromSlash("/p")
	if got := mentionText(root, filepath.FromSlash("/p/src/main.go")); got != "@src/main.go " {
		t.Fatalf("menção: %q", got)
	}
	if got := mentionText(root, filepath.FromSlash("/p/meus docs/a.md")); got != `@"meus docs/a.md" ` {
		t.Fatalf("menção com espaço: %q", got)
	}
}

func TestShellQuote(t *testing.T) {
	if got := shellQuote("/a/it's"); got != `'/a/it'\''s'` {
		t.Fatalf("aspas: %q", got)
	}
}

func TestGitStatus(t *testing.T) {
	if gitBin() == "" {
		t.Skip("git não instalado")
	}
	dir := t.TempDir()
	run := func(args ...string) {
		if _, err := runGit(dir, args...); err != nil {
			t.Fatal(err)
		}
	}
	run("init", "-q")
	os.WriteFile(filepath.Join(dir, "x.txt"), []byte("1"), 0o644)
	run("add", "x.txt")
	run("-c", "user.email=a@b", "-c", "user.name=t", "commit", "-qm", "i")
	os.WriteFile(filepath.Join(dir, "x.txt"), []byte("2"), 0o644)
	os.MkdirAll(filepath.Join(dir, "novo"), 0o755)
	os.WriteFile(filepath.Join(dir, "novo", "y.txt"), []byte("1"), 0o644)
	st := loadGit(dir)
	real, _ := filepath.EvalSymlinks(dir)
	if st == nil || st.Files[filepath.Join(real, "x.txt")] != 'M' || st.Files[filepath.Join(real, "novo", "y.txt")] != 'U' {
		t.Fatalf("status do git incorreto: %+v", st)
	}
	if st.Dirs[filepath.Join(real, "novo")] != 'U' {
		t.Fatal("pasta com arquivo novo não marcada")
	}
}
