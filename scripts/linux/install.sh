#!/usr/bin/env bash
# Upfly Code - instalador para Linux
#
# (Nota técnica: o motor de terminal é o WezTerm oficial, MIT.)
#
# 1. Instala o motor de terminal: apt (repositório oficial), dnf (Copr),
#    pacman, Flatpak ou AppImage, nessa ordem de preferência.
# 2. Copia a configuração para ~/.local/share/upfly-code.
# 3. Cria o comando "upfly-code" e o atalho no menu de aplicativos
#    com o ícone da Upfly.
# 4. Instala o Claude Code (pule com --no-claude) e abre o Upfly Code
#    (pule com --no-launch), que ajuda a conectar a conta do Claude.
#
# Uso: ./install.sh [--no-claude] [--no-launch] [--skip-wezterm]
set -euo pipefail

WEZTERM_APPIMAGE_VERSION="20240203-110809-5046fc22"
WITH_CLAUDE=1
LAUNCH=1
SKIP_WEZTERM=0
for arg in "$@"; do
  case "$arg" in
    --with-claude) WITH_CLAUDE=1 ;;
    --no-claude) WITH_CLAUDE=0 ;;
    --no-launch) LAUNCH=0 ;;
    --skip-wezterm) SKIP_WEZTERM=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Opção desconhecida: $arg" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/upfly-code"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"
BIN_DIR="$HOME/.local/bin"
VERSION="$(tr -d '[:space:]' < "$PACKAGE_ROOT/VERSION")"

LOG="${TMPDIR:-/tmp}/upfly-code-install.log"
exec 3>&1   # saída original, para mensagens dentro de blocos redirecionados ao log
echo "Upfly Code $VERSION - instalação em $(date)" > "$LOG"

step() { printf '\033[36m  > %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m    %s\033[0m\n' "$*"; }
note() { printf '\033[2m    %s\033[0m\n' "$*"; }
fail() {
  printf '\n\033[31m  Não foi possível concluir a instalação do Upfly Code.\033[0m\n'
  printf '\033[33m  Detalhes para o suporte: %s\033[0m\n\n' "$LOG"
  exit 1
}

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

# Pede a senha uma vez, com mensagem do Upfly Code
ask_password() {
  [ -n "$SUDO" ] || return 0
  note "O Upfly Code precisa da sua senha para instalar componentes do sistema." >&3
  sudo -v -p "    Senha: " </dev/tty >&3 2>&3
}

# Retorna o comando do motor de terminal (WezTerm oficial)
find_wezterm() {
  if command -v wezterm >/dev/null 2>&1; then command -v wezterm; return 0; fi
  if [ -x "$INSTALL_DIR/terminal/wezterm" ]; then echo "$INSTALL_DIR/terminal/wezterm"; return 0; fi
  if command -v flatpak >/dev/null 2>&1 && flatpak info org.wezfurlong.wezterm >/dev/null 2>&1; then
    echo "flatpak run org.wezfurlong.wezterm"; return 0
  fi
  return 1
}

install_wezterm() {
  {
  if command -v apt-get >/dev/null 2>&1; then
    ask_password
    $SUDO apt-get update -q
    $SUDO apt-get install -y -q curl gpg
    curl -fsSL https://apt.fury.io/wez/gpg.key | $SUDO gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' \
      | $SUDO tee /etc/apt/sources.list.d/wezterm.list >/dev/null
    $SUDO chmod 644 /usr/share/keyrings/wezterm-fury.gpg
    $SUDO apt-get update -q
    $SUDO apt-get install -y wezterm && return 0
  elif command -v dnf >/dev/null 2>&1; then
    ask_password
    $SUDO dnf -y copr enable wezfurlong/wezterm-nightly && $SUDO dnf -y install wezterm && return 0
  elif command -v pacman >/dev/null 2>&1; then
    ask_password
    $SUDO pacman -S --needed --noconfirm wezterm ttf-nerd-fonts-symbols-mono && return 0
  fi
  if command -v flatpak >/dev/null 2>&1; then
    flatpak install -y --user flathub org.wezfurlong.wezterm && return 0
  fi
  } >>"$LOG" 2>&1
  note "Baixando os componentes (pode levar alguns minutos)..."
  mkdir -p "$INSTALL_DIR/terminal"
  curl -fsSL -o "$INSTALL_DIR/terminal/wezterm" \
    "https://github.com/wezterm/wezterm/releases/download/${WEZTERM_APPIMAGE_VERSION}/WezTerm-${WEZTERM_APPIMAGE_VERSION}-Ubuntu20.04.AppImage" \
    >>"$LOG" 2>&1 || return 1
  chmod +x "$INSTALL_DIR/terminal/wezterm"
  note "Se o Upfly Code não abrir, instale o pacote libfuse2 (veja docs/problemas-comuns.md)."
}

echo
printf '\033[1;38;2;0;128;255m  UPFLY CODE %s\033[0m\n' "$VERSION"
printf '\033[2m  Instalador para Linux\033[0m\n\n'

# 1. Motor de terminal
step "Instalando o Upfly Code..."
if ! WEZ_CMD="$(find_wezterm)"; then
  if [ "$SKIP_WEZTERM" = 1 ]; then
    echo "motor não encontrado e --skip-wezterm usado" >>"$LOG"; fail
  fi
  install_wezterm || fail
  WEZ_CMD="$(find_wezterm)" || fail
fi
echo "motor: $WEZ_CMD" >>"$LOG"

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
case "$(uname -m)" in
  x86_64|amd64)  FARCH=x86_64 ;;
  aarch64|arm64) FARCH=aarch64 ;;
  *) FARCH="" ;;
esac
if [ -n "$FARCH" ] && [ -f "$PACKAGE_ROOT/tools/upfly-files-$FARCH" ]; then
  cp "$PACKAGE_ROOT/tools/upfly-files-$FARCH" "$INSTALL_DIR/tools/upfly-files"
  chmod +x "$INSTALL_DIR/tools/upfly-files"
else
  note "Arquitetura $(uname -m) sem barra lateral incluída."
fi
rm -f "$INSTALL_DIR/tools/broot"; rm -rf "$INSTALL_DIR/config/broot"

# 3. Comando e atalho no menu
step "Criando atalho no menu de aplicativos..."
mkdir -p "$BIN_DIR" "$APPS_DIR" "$ICONS_DIR/256x256/apps" "$ICONS_DIR/512x512/apps"
cat > "$BIN_DIR/upfly-code" <<LAUNCHER
#!/usr/bin/env bash
# Upfly Code: abre o motor de terminal com a configuração Upfly.
# Aceita uma pasta: upfly-code ~/projetos/meu-app
DIR="\$HOME"
if [ -n "\${1:-}" ] && [ -d "\$1" ]; then DIR="\$(cd "\$1" && pwd)"; fi
exec ${WEZ_CMD} --config-file "${INSTALL_DIR}/config/wezterm.lua" \\
  start --always-new-process --class UpflyCode --cwd "\$DIR"
LAUNCHER
chmod +x "$BIN_DIR/upfly-code"

cp "$PACKAGE_ROOT/branding/icon-256.png" "$ICONS_DIR/256x256/apps/upfly-code.png"
cp "$PACKAGE_ROOT/branding/icon-512.png" "$ICONS_DIR/512x512/apps/upfly-code.png"

cat > "$APPS_DIR/upfly-code.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Upfly Code
GenericName=Terminal
Comment=Terminal da Upfly
Exec=${BIN_DIR}/upfly-code %f
Icon=upfly-code
Terminal=false
Categories=System;TerminalEmulator;Development;
Keywords=terminal;shell;claude;upfly;
StartupWMClass=UpflyCode
MimeType=inode/directory;
DESKTOP
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q "$ICONS_DIR" >/dev/null 2>&1 || true
ok "Atalho criado: Upfly Code"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) note "Para abrir pelo terminal com o comando upfly-code, adicione $BIN_DIR ao PATH." ;;
esac

# 4. Claude Code (opcional)
if [ "$WITH_CLAUDE" = 1 ]; then
  if command -v claude >/dev/null 2>&1 || [ -x "$HOME/.local/bin/claude" ]; then
    ok "Claude Code já estava instalado."
  else
    step "Instalando o Claude Code..."
    if curl -fsSL https://claude.ai/install.sh 2>>"$LOG" | bash >>"$LOG" 2>&1; then
      ok "Claude Code instalado."
    else
      note "Não foi possível instalar o Claude Code agora. O Upfly Code vai oferecer de novo ao abrir."
    fi
  fi
fi

echo
printf '\033[32m  Upfly Code instalado com sucesso!\033[0m\n'
printf '  Abra "Upfly Code" pelo menu de aplicativos.\n'
printf '\033[2m  Ctrl+Shift+O abre uma pasta  ·  Ctrl+Shift+E mostra os arquivos\033[0m\n\n'
printf '\033[2m  Inclui componentes de código aberto. Licenças em LICENSES.\033[0m\n\n'
if [ "$LAUNCH" = 1 ] && { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }; then
  printf '\033[36m  Abrindo o Upfly Code... na primeira vez ele ajuda você a conectar sua conta do Claude.\033[0m\n\n'
  nohup "$BIN_DIR/upfly-code" >/dev/null 2>&1 &
fi
