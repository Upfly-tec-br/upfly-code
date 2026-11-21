#!/usr/bin/env bash
# Upfly Code - instalador para macOS
# (Nota técnica: o motor de terminal é o WezTerm oficial, MIT.)
#
# 1. Instala o motor de terminal (Homebrew; sem Homebrew, o .zip oficial).
# 2. Copia a configuração para ~/Library/Application Support/UpflyCode.
# 3. Cria o aplicativo "Upfly Code" em ~/Applications, com o ícone da Upfly.
#    É um atalho que abre o WezTerm oficial com a configuração Upfly; o
#    WezTerm.app (assinado pelo autor) não é modificado.
# 4. Instala o Claude Code (pule com --no-claude) e abre o Upfly Code
#    (pule com --no-launch), que ajuda a conectar a conta do Claude.
#
# Uso: ./install.sh [--no-claude] [--no-launch] [--skip-wezterm]
set -euo pipefail

WEZTERM_ZIP_VERSION="20240203-110809-5046fc22"
WITH_CLAUDE=1
LAUNCH=1
SKIP_WEZTERM=0
for arg in "$@"; do
  case "$arg" in
    --with-claude) WITH_CLAUDE=1 ;;
    --no-claude) WITH_CLAUDE=0 ;;
    --no-launch) LAUNCH=0 ;;
    --skip-wezterm) SKIP_WEZTERM=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Opção desconhecida: $arg" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_DIR="$HOME/Library/Application Support/UpflyCode"
APP_DIR="$HOME/Applications/Upfly Code.app"
VERSION="$(tr -d '[:space:]' < "$PACKAGE_ROOT/VERSION")"
LOG="${TMPDIR:-/tmp}/upfly-code-install.log"
echo "Upfly Code $VERSION - instalação em $(date)" > "$LOG"

step() { printf '\033[36m  > %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m    %s\033[0m\n' "$*"; }
note() { printf '\033[2m    %s\033[0m\n' "$*"; }
fail() {
  printf '\n\033[31m  Não foi possível concluir a instalação do Upfly Code.\033[0m\n'
  printf '\033[33m  Detalhes para o suporte: %s\033[0m\n\n' "$LOG"
  exit 1
}
trap fail ERR

find_wezterm_app() {
  local c
  for c in "/Applications/WezTerm.app" "$HOME/Applications/WezTerm.app"; do
    if [ -x "$c/Contents/MacOS/wezterm-gui" ]; then echo "$c"; return 0; fi
  done
  return 1
}

install_wezterm() {
  if command -v brew >/dev/null 2>&1; then
    brew install --cask wezterm >>"$LOG" 2>&1 || true
    if find_wezterm_app >/dev/null; then return 0; fi
    echo "Homebrew não concluiu; usando o .zip oficial." >>"$LOG"
  fi
  note "Baixando os componentes (pode levar alguns minutos)..."
  local tmp zip
  tmp="$(mktemp -d)"
  zip="$tmp/terminal.zip"
  curl -fsSL -o "$zip" \
    "https://github.com/wezterm/wezterm/releases/download/${WEZTERM_ZIP_VERSION}/WezTerm-macos-${WEZTERM_ZIP_VERSION}.zip"
  (cd "$tmp" && unzip -q terminal.zip)
  mkdir -p "$HOME/Applications"
  local app
  app="$(find "$tmp" -maxdepth 3 -name 'WezTerm.app' -type d | head -n1)"
  [ -n "$app" ] || { echo "app não encontrado no .zip" >>"$LOG"; fail; }
  rm -rf "$HOME/Applications/WezTerm.app"
  mv "$app" "$HOME/Applications/WezTerm.app"
  rm -rf "$tmp"
}

echo
printf '\033[1;38;2;0;128;255m  UPFLY CODE %s\033[0m\n' "$VERSION"
printf '\033[2m  Instalador para macOS\033[0m\n\n'

# 1. Motor de terminal
step "Instalando o Upfly Code..."
if ! WEZ_APP="$(find_wezterm_app)"; then
  if [ "$SKIP_WEZTERM" = 1 ]; then
    echo "motor não encontrado e --skip-wezterm usado" >>"$LOG"; fail
  fi
  install_wezterm
  WEZ_APP="$(find_wezterm_app)" || fail
fi
echo "motor: $WEZ_APP" >>"$LOG"

# 2. Arquivos
step "Aplicando a identidade visual Upfly..."
mkdir -p "$INSTALL_DIR"/{config,branding,bin,LICENSES,tools,state}
cp "$PACKAGE_ROOT/config/wezterm.lua" \
   "$PACKAGE_ROOT/config/starship.toml" "$INSTALL_DIR/config/"
cp "$PACKAGE_ROOT/config/shell/upfly-shell.sh" "$PACKAGE_ROOT/config/shell/self-update.sh" "$INSTALL_DIR/bin/"
cp "$PACKAGE_ROOT/config/update-repo.txt" "$INSTALL_DIR/config/"
cp "$SCRIPT_DIR/update.sh" "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/bin/"
chmod +x "$INSTALL_DIR/bin/"*.sh
cp -R "$PACKAGE_ROOT/branding/." "$INSTALL_DIR/branding/"
cp -R "$PACKAGE_ROOT/LICENSES/." "$INSTALL_DIR/LICENSES/"
cp "$PACKAGE_ROOT/VERSION" "$INSTALL_DIR/"

# Barra lateral de arquivos (upfly-files)
step "Instalando a barra lateral de arquivos..."
case "$(uname -m)" in arm64) FARCH=arm64 ;; *) FARCH=amd64 ;; esac
if [ -f "$PACKAGE_ROOT/tools/upfly-files-$FARCH" ]; then
  cp "$PACKAGE_ROOT/tools/upfly-files-$FARCH" "$INSTALL_DIR/tools/upfly-files"
  chmod +x "$INSTALL_DIR/tools/upfly-files"
  xattr -dr com.apple.quarantine "$INSTALL_DIR/tools" 2>/dev/null || true
fi
rm -f "$INSTALL_DIR/tools/broot"; rm -rf "$INSTALL_DIR/config/broot"

# 3. Aplicativo "Upfly Code" (launcher com ícone próprio)
step "Criando o aplicativo Upfly Code..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$PACKAGE_ROOT/branding/icon.icns" "$APP_DIR/Contents/Resources/icon.icns"
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Upfly Code</string>
  <key>CFBundleDisplayName</key><string>Upfly Code</string>
  <key>CFBundleIdentifier</key><string>br.tec.upfly.code</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleExecutable</key><string>upfly-code</string>
  <key>CFBundleIconFile</key><string>icon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
cat > "$APP_DIR/Contents/MacOS/upfly-code" <<LAUNCHER
#!/bin/bash
# Upfly Code: abre o motor de terminal (sem modificá-lo) com a configuração Upfly.
WEZ="${WEZ_APP}"
[ -d "\$WEZ" ] || WEZ="/Applications/WezTerm.app"
[ -d "\$WEZ" ] || WEZ="\$HOME/Applications/WezTerm.app"
# Aceita uma pasta: upfly-code ~/projetos/meu-app
DIR="\$HOME"
if [ -n "\${1:-}" ] && [ -d "\$1" ]; then DIR="\$(cd "\$1" && pwd)"; fi
exec open -n -a "\$WEZ" --args --config-file "${INSTALL_DIR}/config/wezterm.lua" \\
  start --always-new-process --cwd "\$DIR"
LAUNCHER
chmod +x "$APP_DIR/Contents/MacOS/upfly-code"
touch "$APP_DIR"
ok "Aplicativo criado em Aplicativos (~/Applications)"

# Comando de terminal opcional
mkdir -p "$HOME/.local/bin"
ln -sf "$APP_DIR/Contents/MacOS/upfly-code" "$HOME/.local/bin/upfly-code"

# 4. Claude Code (opcional)
if [ "$WITH_CLAUDE" = 1 ]; then
  if command -v claude >/dev/null 2>&1 || [ -x "$HOME/.local/bin/claude" ]; then
    ok "Claude Code já estava instalado."
  else
    step "Instalando o Claude Code..."
    if curl -fsSL https://claude.ai/install.sh | bash >>"$LOG" 2>&1; then
      ok "Claude Code instalado."
    else
      note "Não foi possível instalar o Claude Code agora. O Upfly Code vai oferecer de novo ao abrir."
    fi
  fi
fi

echo
printf '\033[32m  Upfly Code instalado com sucesso!\033[0m\n'
printf '  Abra "Upfly Code" pelo Launchpad, Spotlight ou pela pasta Aplicativos.\n'
printf '\033[2m  Ctrl+Shift+O abre uma pasta  ·  Ctrl+Shift+E mostra os arquivos\033[0m\n\n'
printf '\033[2m  Inclui componentes de código aberto. Licenças em LICENSES.\033[0m\n\n'
if [ "$LAUNCH" = 1 ]; then
  printf '\033[36m  Abrindo o Upfly Code... na primeira vez ele ajuda você a conectar sua conta do Claude.\033[0m\n\n'
  "$APP_DIR/Contents/MacOS/upfly-code" >/dev/null 2>&1 &
fi
