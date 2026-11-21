#!/usr/bin/env bash
# Upfly Code - atualização (Linux)
# - Atualiza o motor de terminal (WezTerm) pelo gerenciador de pacotes usado na instalação.
# - Atualiza o Claude Code, se instalado.
# - Se executado de dentro de um pacote novo, reaplica a configuração.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/upfly-code"
LOG="${TMPDIR:-/tmp}/upfly-code-update.log"
echo "Upfly Code - atualização em $(date)" > "$LOG"
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

echo
printf '\033[1;38;2;0;128;255m  UPFLY CODE\033[0m\n'
printf '\033[2m  Atualizador para Linux\033[0m\n\n'
printf '\033[36m  > Atualizando o Upfly Code...\033[0m\n'

needs_sudo=0
if command -v apt-get >/dev/null 2>&1 && dpkg -s wezterm >/dev/null 2>&1; then needs_sudo=1
elif command -v dnf >/dev/null 2>&1 && rpm -q wezterm >/dev/null 2>&1; then needs_sudo=1
elif command -v pacman >/dev/null 2>&1 && pacman -Q wezterm >/dev/null 2>&1; then needs_sudo=1
fi
if [ "$needs_sudo" = 1 ] && [ -n "$SUDO" ]; then
  printf '\033[2m    O Upfly Code precisa da sua senha para atualizar componentes do sistema.\033[0m\n'
  sudo -v -p "    Senha: "
fi

{
if command -v apt-get >/dev/null 2>&1 && dpkg -s wezterm >/dev/null 2>&1; then
  $SUDO apt-get update -q && $SUDO apt-get install -y --only-upgrade wezterm || true
elif command -v dnf >/dev/null 2>&1 && rpm -q wezterm >/dev/null 2>&1; then
  $SUDO dnf -y upgrade wezterm || true
elif command -v pacman >/dev/null 2>&1 && pacman -Q wezterm >/dev/null 2>&1; then
  $SUDO pacman -S --needed --noconfirm wezterm || true
elif command -v flatpak >/dev/null 2>&1 && flatpak info org.wezfurlong.wezterm >/dev/null 2>&1; then
  flatpak update -y org.wezfurlong.wezterm || true
fi
} >>"$LOG" 2>&1

if command -v claude >/dev/null 2>&1; then
  printf '\033[36m  > Atualizando o Claude Code...\033[0m\n'
  claude update >>"$LOG" 2>&1 || true
fi

if [ -f "$SCRIPT_DIR/install.sh" ]; then
  old="$(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo nenhuma)"
  new="$(cat "$SCRIPT_DIR/../../VERSION")"
  printf '\033[36m  > Versão %s -> %s\033[0m\n' "$old" "$new"
  bash "$SCRIPT_DIR/install.sh" --skip-wezterm --no-launch
else
  printf '\033[2m    Para receber a versão nova, baixe o pacote novo e rode ./update.sh de dentro dele.\033[0m\n\n'
  printf '\033[32m  Upfly Code atualizado.\033[0m\n\n'
fi
