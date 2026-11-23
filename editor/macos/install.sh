#!/usr/bin/env bash
# Upfly Code - instalador para macOS (editor com chat do Claude)
#
# Instala só para o seu usuário, sem pedir senha:
#   ~/Applications/Upfly Code.app   o aplicativo (aparece no Launchpad)
#   ~/.local/bin/upfly-code         comando para abrir pelo terminal
# e já deixa o português e o chat do Claude instalados.
#
# Uso: ./install.sh [--no-launch] [--wait-close] [--no-extensions]
# Opções antigas (--skip-wezterm, --no-claude) são aceitas e ignoradas.
set -euo pipefail

LAUNCH=1; WAIT_CLOSE=0; EXTENSIONS=1; LEGACY=0
for arg in "$@"; do
  case "$arg" in
    --no-launch) LAUNCH=0 ;;
    --wait-close) WAIT_CLOSE=1 ;;
    --no-extensions) EXTENSIONS=0 ;;
    --skip-wezterm) LEGACY=1 ;;
    --no-claude|--with-claude) ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Opção desconhecida: $arg" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_APP="$PACKAGE_ROOT/Upfly Code.app"
APP_DIR="$HOME/Applications/Upfly Code.app"
BIN_DIR="$HOME/.local/bin"
USER_DATA="$HOME/.upfly-code"
SUPPORT="$HOME/Library/Application Support/Upfly Code"
VERSION="$(tr -d '[:space:]' < "$PACKAGE_ROOT/VERSION")"
PKG_ARCH="$(tr -d '[:space:]' < "$PACKAGE_ROOT/ARCH" 2>/dev/null || echo arm64)"
LOG="${TMPDIR:-/tmp}/upfly-code-install-$(id -u).log"
echo "Upfly Code $VERSION - instalação em $(date)" > "$LOG"

step() { printf '\033[36m  > %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m    %s\033[0m\n' "$*"; }
note() { printf '\033[2m    %s\033[0m\n' "$*"; }
fail() {
  printf '\n\033[31m  Não foi possível instalar o Upfly Code: %s\033[0m\n' "$1"
  printf '\033[33m  Detalhes para o suporte: %s\033[0m\n\n' "$LOG"
  exit 1
}

echo
printf '\033[1;38;2;0;128;255m  UPFLY CODE\033[0m  \033[2mversão %s\033[0m\n\n' "$VERSION"

# Mac com processador Intel e pacote para Apple Silicon (ou o contrário):
# baixa o pacote certo e instala por ele.
MACHINE="$(uname -m)"; [ "$MACHINE" = x86_64 ] && MACHINE=x64
if [ "$MACHINE" != "$PKG_ARCH" ] && [ -z "${UPFLY_NO_ARCH_SWITCH:-}" ]; then
  REPO="Upfly-tec-br/upfly-code"
  NAME="UpflyCode-macos.zip"; [ "$MACHINE" = x64 ] && NAME="UpflyCode-macos-intel.zip"
  step "Baixando a versão certa para este Mac ($MACHINE)..."
  WORK="$(mktemp -d)"
  curl -fsSL -o "$WORK/p.zip" "https://github.com/$REPO/releases/latest/download/$NAME" 2>>"$LOG" \
    || fail "não foi possível baixar $NAME."
  (cd "$WORK" && ditto -x -k p.zip .) || fail "pacote corrompido."
  INST="$(find "$WORK" -path '*/scripts/macos/install.sh' | head -n1)"
  [ -n "$INST" ] || fail "pacote incompleto."
  UPFLY_NO_ARCH_SWITCH=1 exec bash "$INST" "$@"
fi

[ -d "$SRC_APP" ] || fail "pacote incompleto (falta o Upfly Code.app)."

if [ "$WAIT_CLOSE" = 1 ]; then
  step "Esperando o Upfly Code fechar..."
  for _ in $(seq 1 360); do pgrep -f "$APP_DIR/Contents/MacOS/" >/dev/null 2>&1 || break; sleep 0.5; done
fi

step "Copiando o aplicativo..."
mkdir -p "$HOME/Applications"
rm -rf "$APP_DIR.new"
ditto "$SRC_APP" "$APP_DIR.new" 2>>"$LOG" || fail "não foi possível copiar o aplicativo."
xattr -dr com.apple.quarantine "$APP_DIR.new" 2>/dev/null || true
rm -rf "$APP_DIR"
mv "$APP_DIR.new" "$APP_DIR"
# Restos da versão antiga (terminal WezTerm). Se quem chamou foi o
# atualizador antigo, a janela antiga ainda usa esses arquivos.
[ "$LEGACY" = 1 ] || rm -rf "$HOME/.local/share/upfly-code" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR" >/dev/null 2>&1 || true
ok "Aplicativo em ~/Applications/Upfly Code.app"

mkdir -p "$BIN_DIR"
ln -sf "$APP_DIR/Contents/Resources/app/bin/upfly-code" "$BIN_DIR/upfly-code"

# Primeira abertura simples e em português
if [ ! -f "$SUPPORT/User/settings.json" ]; then
  mkdir -p "$SUPPORT/User"
  printf '{\n  "security.workspace.trust.enabled": false,\n  "workbench.startupEditor": "none"\n}\n' > "$SUPPORT/User/settings.json"
fi
mkdir -p "$USER_DATA"
if [ ! -f "$USER_DATA/argv.json" ]; then
  printf '{\n\t"locale": "pt-br"\n}\n' > "$USER_DATA/argv.json"
elif ! grep -q '"locale"' "$USER_DATA/argv.json"; then
  sed -i '' '1,/{/s/{/{\
	"locale": "pt-br",/' "$USER_DATA/argv.json"
fi

CLI="$APP_DIR/Contents/Resources/app/bin/upfly-code"
ELECTRON="$APP_DIR/Contents/MacOS/$(defaults read "$APP_DIR/Contents/Info" CFBundleExecutable 2>/dev/null || echo Electron)"
for vsix in "$PACKAGE_ROOT"/extensions/*.vsix; do
  [ -f "$vsix" ] || continue
  "$CLI" --install-extension "$vsix" >>"$LOG" 2>&1 || true
done
ELECTRON_RUN_AS_NODE=1 "$ELECTRON" "$PACKAGE_ROOT/scripts/common/languagepacks.js" \
  "$USER_DATA/extensions" "$SUPPORT" >>"$LOG" 2>&1 || true
if [ "$EXTENSIONS" = 1 ]; then
  step "Instalando o chat do Claude..."
  if "$CLI" --install-extension anthropic.claude-code >>"$LOG" 2>&1; then ok "Pronto"
  else note "Sem internet agora. O Upfly Code termina isso quando abrir."; fi
fi

printf '\n\033[32m  Upfly Code %s instalado.\033[0m\n' "$VERSION"
note "Ele está no Launchpad e em Aplicativos do seu usuário."
if [ "$LEGACY" = 1 ]; then
  printf '\n\033[33m  O Upfly Code agora é um editor com o chat do Claude ao lado.\033[0m\n'
  printf '\033[33m  Feche esta janela (Cmd+Q) e abra o Upfly Code de novo.\033[0m\n'
fi
echo
if [ "$LAUNCH" = 1 ] || [ "$WAIT_CLOSE" = 1 ]; then open "$APP_DIR"; fi
