#!/usr/bin/env bash
# Upfly Code - validações automáticas.
# Requisitos: bash, lua (5.3+), opcional: shellcheck, pwsh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
section() { printf '\n\033[36m## %s\033[0m\n' "$*"; }
pass() { printf '  ok   %s\n' "$*"; }
fail() { printf '  \033[31mFALHA\033[0m %s\n' "$*"; FAIL=$((FAIL + 1)); }

LUA="$(command -v lua5.4 || command -v lua5.3 || command -v lua || true)"

section "Arquivos obrigatórios"
for f in VERSION README.md LICENSES/THIRD-PARTY-NOTICES.md config/wezterm.lua \
         config/starship.toml config/update-repo.txt config/shell/self-update.sh config/shell/self-update.ps1 config/shell/upfly-shell.sh config/shell/upfly-shell.ps1 \
         branding/logo.png branding/symbol.png branding/icon.ico branding/icon.icns \
         branding/icon.png branding/icon-256.png branding/icon-512.png branding/background.jpg \
         scripts/windows/install.ps1 scripts/windows/uninstall.ps1 scripts/windows/update.ps1 \
         scripts/windows/create-shortcut.ps1 scripts/macos/install.sh scripts/macos/uninstall.sh \
         scripts/macos/update.sh scripts/linux/install.sh scripts/linux/uninstall.sh scripts/linux/update.sh \
         docs/instalacao-windows.md docs/instalacao-macos.md docs/instalacao-linux.md \
         docs/atualizacao.md docs/desinstalacao.md docs/problemas-comuns.md \
         vendor/windows/rcedit-x64.exe tools/upfly-files/main.go tools/upfly-files/go.mod \
         tools/windows/upfly-taskbar.cs LICENSES/upfly-files-THIRD-PARTY.txt; do
  [ -s "$ROOT/$f" ] && pass "$f" || fail "$f ausente"
done
grep -q "Copyright (c) 2018-Present Wez Furlong" "$ROOT/LICENSES/THIRD-PARTY-NOTICES.md" \
  && pass "aviso de copyright do WezTerm presente" || fail "aviso de copyright do WezTerm ausente"

section "Configuração Lua"
if [ -n "$LUA" ]; then
  if (cd "$ROOT" && "$LUA" tests/config_test.lua "$ROOT"); then pass "config_test.lua"; else fail "config_test.lua"; fi
else
  echo "  (lua não instalado - teste pulado)"
fi

section "Scripts shell"
for f in "$ROOT"/scripts/*/*.sh "$ROOT"/config/shell/*.sh "$ROOT"/tests/*.sh; do
  bash -n "$f" && pass "sintaxe $(basename "$(dirname "$f")")/$(basename "$f")" || fail "sintaxe $f"
done
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning "$ROOT"/scripts/*/*.sh "$ROOT"/config/shell/*.sh; then
    pass "shellcheck sem avisos"
  else
    fail "shellcheck"
  fi
fi

section "Scripts PowerShell"
for f in "$ROOT"/scripts/windows/*.ps1 "$ROOT"/config/shell/*.ps1; do
  head -c3 "$f" | od -An -tx1 | grep -q "ef bb bf" && pass "UTF-8 com BOM: $(basename "$f")" \
    || fail "$(basename "$f") sem BOM (acentos quebram no Windows PowerShell 5.1)"
done
if command -v pwsh >/dev/null 2>&1; then
  for f in "$ROOT"/scripts/windows/*.ps1 "$ROOT"/config/shell/upfly-shell.ps1; do
    out=$(pwsh -NoProfile -Command "\$e=\$null; [void][System.Management.Automation.Language.Parser]::ParseFile('$f',[ref]\$null,[ref]\$e); if(\$e){\$e|%{\$_.ToString()}; exit 1}" 2>&1) \
      && pass "parse $(basename "$f")" || fail "parse $(basename "$f"): $out"
  done
else
  echo "  (pwsh não instalado - análise sintática pulada)"
fi

section "Barra lateral de arquivos (Go)"
if command -v go >/dev/null 2>&1; then
  GOARGS=()
  GOENV=(GOFLAGS=-mod=mod)
  if [ "${UPFLY_GO_MIRRORS:-}" = "1" ]; then
    GOARGS=(-modfile=go.mirror.mod); GOENV+=(GOPROXY=direct GOSUMDB=off)
  fi
  if (cd "$ROOT/tools/upfly-files" && env "${GOENV[@]}" go vet "${GOARGS[@]}" ./... && env "${GOENV[@]}" go test "${GOARGS[@]}" ./...) >/tmp/upfly-go-test.log 2>&1; then
    pass "go vet + go test"
  else
    fail "Go: $(tail -15 /tmp/upfly-go-test.log)"
  fi
  for t in windows/amd64 darwin/arm64 darwin/amd64 linux/amd64 linux/arm64; do
    if (cd "$ROOT/tools/upfly-files" && env "${GOENV[@]}" CGO_ENABLED=0 GOOS="${t%/*}" GOARCH="${t#*/}" \
        go build "${GOARGS[@]}" -o /dev/null .) >/tmp/upfly-go-build.log 2>&1; then
      pass "compila para $t"
    else
      fail "compilação $t: $(tail -5 /tmp/upfly-go-build.log)"
    fi
  done
else
  echo "  (Go não instalado - testes da barra lateral pulados)"
fi

section "Instalação simulada (Linux)"
TMPHOME="$(mktemp -d)"
FAKEBIN="$TMPHOME/fakebin"
mkdir -p "$FAKEBIN"
printf '#!/bin/sh\necho "wezterm $*"\n' > "$FAKEBIN/wezterm"; chmod +x "$FAKEBIN/wezterm"
if UPFLY_SKIP_TOOL_INIT=1 HOME="$TMPHOME" XDG_DATA_HOME="" PATH="$FAKEBIN:$PATH" bash "$ROOT/scripts/linux/install.sh" --no-claude --no-launch >"$TMPHOME/out" 2>&1; then
  pass "install.sh concluiu"
  if grep -qi "wezterm" "$TMPHOME/out"; then fail "a tela do instalador menciona WezTerm"; else pass "tela do instalador só fala em Upfly Code"; fi
  for f in .local/share/upfly-code/config/wezterm.lua .local/share/upfly-code/branding/background.jpg \
           .local/share/upfly-code/bin/upfly-shell.sh .local/bin/upfly-code \
           .local/share/applications/UpflyCode.desktop .local/share/icons/hicolor/512x512/apps/upfly-code.png \
           .local/share/upfly-code/config/update-repo.txt .local/share/upfly-code/state; do
    [ -e "$TMPHOME/$f" ] && pass "criado ~/$f" || fail "não criado ~/$f"
  done
  grep -q '^StartupWMClass=UpflyCode$' "$TMPHOME/.local/share/applications/UpflyCode.desktop" \
    && pass "atalho ligado à janela (UpflyCode)" || fail "atalho sem StartupWMClass=UpflyCode"
  if grep -q '^NoDisplay=true$' "$TMPHOME/.local/share/applications/org.wezfurlong.wezterm.desktop" 2>/dev/null; then
    pass "só um aplicativo no menu (motor escondido)"
  else
    fail "o atalho do motor continua aparecendo no menu"
  fi
  out="$(HOME="$TMPHOME" PATH="$FAKEBIN:$PATH" "$TMPHOME/.local/bin/upfly-code")"
  case "$out" in
    *"--config-file $TMPHOME/.local/share/upfly-code/config/wezterm.lua start --always-new-process --class UpflyCode --cwd $TMPHOME"*)
      pass "upfly-code chama o WezTerm com a configuração Upfly" ;;
    *) fail "upfly-code: $out" ;;
  esac
  out2="$(HOME="$TMPHOME" PATH="$FAKEBIN:$PATH" "$TMPHOME/.local/bin/upfly-code" "$ROOT/docs")"
  case "$out2" in *"--cwd $ROOT/docs"*) pass "upfly-code <pasta> abre na pasta" ;; *) fail "upfly-code <pasta>: $out2" ;; esac
  banner="$(cd "$TMPHOME" && HOME="$TMPHOME" SHELL=/bin/true TERM=xterm COLUMNS=120 \
    sh "$TMPHOME/.local/share/upfly-code/bin/upfly-shell.sh" 2>&1)"
  case "$banner" in
    *"Upfly Code"*"Claude"*) pass "boas-vindas exibidas" ;;
    *) fail "boas-vindas: $banner" ;;
  esac
  [ "$(printf '%s\n' "$banner" | grep -c .)" -le 1 ] && pass "boas-vindas ocupam só 1 linha" || fail "boas-vindas grandes demais"
  # Autoatualização: release falsa 9.9.9 servida por file://
  FAKE="$TMPHOME/fake-release"; PKG="$FAKE/UpflyCode-9.9.9"
  mkdir -p "$PKG/scripts" "$PKG/vendor" "$FAKE/api/repos/upfly/upfly-code/releases"
  cp -R "$ROOT/config" "$ROOT/branding" "$ROOT/LICENSES" "$PKG/"
  cp -R "$ROOT/scripts/linux" "$PKG/scripts/"
  echo 9.9.9 > "$PKG/VERSION"
  tar -C "$FAKE" -czf "$FAKE/UpflyCode-9.9.9-linux.tar.gz" UpflyCode-9.9.9
  printf '{"tag_name": "v9.9.9", "assets": [{"browser_download_url": "file://%s"}]}' \
    "$FAKE/UpflyCode-9.9.9-linux.tar.gz" > "$FAKE/api/repos/upfly/upfly-code/releases/latest"
  echo "upfly/upfly-code" > "$TMPHOME/.local/share/upfly-code/config/update-repo.txt"
  upd="$(UPFLY_SKIP_TOOL_INIT=1 UPFLY_UPDATE_API="file://$FAKE/api" HOME="$TMPHOME" XDG_DATA_HOME="" PATH="$FAKEBIN:$PATH" \
    bash "$TMPHOME/.local/share/upfly-code/bin/self-update.sh" </dev/null 2>&1)"
  if [ "$(cat "$TMPHOME/.local/share/upfly-code/VERSION")" = "9.9.9" ]; then
    pass "autoatualização baixa a release e instala a versão nova"
  else
    fail "autoatualização: $(printf '%s' "$upd" | sed 's/\x1b\[[0-9;]*m//g' | tail -5)"
  fi
  if HOME="$TMPHOME" XDG_DATA_HOME="" bash "$TMPHOME/.local/share/upfly-code/bin/uninstall.sh" >/dev/null 2>&1 \
     && [ ! -e "$TMPHOME/.local/share/upfly-code" ] && [ ! -e "$TMPHOME/.local/bin/upfly-code" ] \
     && [ ! -e "$TMPHOME/.local/share/applications/org.wezfurlong.wezterm.desktop" ]; then
    pass "uninstall.sh removeu tudo"
  else
    fail "uninstall.sh"
  fi
else
  fail "install.sh: $(tail -5 "$TMPHOME/out")"
fi
rm -rf "$TMPHOME"

echo
if [ "$FAIL" -gt 0 ]; then printf '\033[31m%d falha(s)\033[0m\n' "$FAIL"; exit 1; fi
printf '\033[32mTodos os testes passaram.\033[0m\n'
