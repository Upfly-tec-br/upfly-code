#!/usr/bin/env bash
# Upfly Code - instalador para macOS
# (Nota técnica: o motor de terminal é o WezTerm oficial, MIT.)
#
# 1. Baixa o motor de terminal (WezTerm oficial, .zip do GitHub).
# 2. Copia a configuração para ~/Library/Application Support/UpflyCode.
# 3. Cria o aplicativo "Upfly Code" em ~/Applications: é o motor com nome,
#    ícone e configuração da Upfly. Assim só aparece UM aplicativo (Upfly Code)
#    no Launchpad e no Dock, com o ícone certo.
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

# Coloca uma cópia do motor (WezTerm.app oficial) em $1
get_engine() {
  local dest="$1" tmp app
  tmp="$(mktemp -d)"
  note "Baixando os componentes (pode levar alguns minutos)..."
  if curl -fsSL -o "$tmp/terminal.zip" \
      "https://github.com/wezterm/wezterm/releases/download/${WEZTERM_ZIP_VERSION}/WezTerm-macos-${WEZTERM_ZIP_VERSION}.zip" \
      >>"$LOG" 2>&1 && (cd "$tmp" && unzip -q terminal.zip) >>"$LOG" 2>&1; then
    app="$(find "$tmp" -maxdepth 3 -name 'WezTerm.app' -type d | head -n1)"
  fi
  if [ -z "${app:-}" ]; then
    # sem internet: reaproveita um WezTerm já instalado
    for c in "/Applications/WezTerm.app" "$HOME/Applications/WezTerm.app"; do
      [ -x "$c/Contents/MacOS/wezterm-gui" ] && app="$c" && break
    done
  fi
  [ -n "${app:-}" ] || { echo "motor não obtido" >>"$LOG"; rm -rf "$tmp"; return 1; }
  rm -rf "$dest"
  ditto "$app" "$dest"
  rm -rf "$tmp"
}

echo
printf '\033[1;38;2;0;128;255m  UPFLY CODE %s\033[0m\n' "$VERSION"
printf '\033[2m  Instalador para macOS\033[0m\n\n'

# 1. Motor de terminal (vira o próprio "Upfly Code.app")
step "Instalando o Upfly Code..."
mkdir -p "$HOME/Applications"
if [ "$SKIP_WEZTERM" = 1 ] && [ -x "$APP_DIR/Contents/MacOS/wezterm-gui" ]; then
  echo "motor mantido: $APP_DIR" >>"$LOG"
else
  get_engine "$APP_DIR" || fail
fi

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

# 3. Nome, ícone e configuração da Upfly no aplicativo
step "Aplicando nome e ícone do Upfly Code..."
PLIST="$APP_DIR/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy
cp "$PACKAGE_ROOT/branding/icon.icns" "$APP_DIR/Contents/Resources/upfly.icns"
pset() { $PB -c "Set :$1 $2" "$PLIST" 2>/dev/null || $PB -c "Add :$1 string $2" "$PLIST"; }
pset CFBundleName "Upfly Code"
pset CFBundleDisplayName "Upfly Code"
pset CFBundleIdentifier "br.tec.upfly.code"
pset CFBundleIconFile "upfly.icns"
$PB -c "Delete :CFBundleIconName" "$PLIST" 2>/dev/null || true
$PB -c "Delete :LSEnvironment" "$PLIST" 2>/dev/null || true
$PB -c "Add :LSEnvironment dict" "$PLIST"
$PB -c "Add :LSEnvironment:WEZTERM_CONFIG_FILE string ${INSTALL_DIR}/config/wezterm.lua" "$PLIST"
$PB -c "Add :CFBundleDevelopmentRegion string pt-BR" "$PLIST" 2>/dev/null \
  || $PB -c "Set :CFBundleDevelopmentRegion pt-BR" "$PLIST"
{
  xattr -dr com.apple.quarantine "$APP_DIR" || true
  # o nome e o ícone mudaram: assina de novo, só para este Mac
  codesign --force --deep --sign - "$APP_DIR"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR" || true
} >>"$LOG" 2>&1
touch "$APP_DIR"
ok "Aplicativo criado em Aplicativos (~/Applications)"

# Comando de terminal: upfly-code [pasta]
mkdir -p "$HOME/.local/bin"
rm -f "$HOME/.local/bin/upfly-code"
cat > "$HOME/.local/bin/upfly-code" <<LAUNCHER
#!/bin/bash
# Upfly Code: abre o aplicativo, opcionalmente numa pasta.
DIR="\$HOME"
if [ -n "\${1:-}" ] && [ -d "\$1" ]; then DIR="\$(cd "\$1" && pwd)"; fi
exec open -n -a "${APP_DIR}" --args start --always-new-process --cwd "\$DIR"
LAUNCHER
chmod +x "$HOME/.local/bin/upfly-code"

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
printf '\033[2m  Dentro dele, aperte F1 (ou clique com o botão direito) para ver o menu\033[0m\n\n'
printf '\033[2m  Inclui componentes de código aberto. Licenças em LICENSES.\033[0m\n\n'
if [ "$LAUNCH" = 1 ]; then
  printf '\033[36m  Abrindo o Upfly Code... na primeira vez ele ajuda você a conectar sua conta do Claude.\033[0m\n\n'
  open -n -a "$APP_DIR" >/dev/null 2>&1 &
fi
