#!/usr/bin/env bash
# Upfly Code - desinstalação (Linux)
# Remove configuração, comando upfly-code, atalho do menu e ícones.
# Mantém o motor de terminal (WezTerm) e o Claude Code, a menos que use
# --remove-wezterm.
set -uo pipefail

REMOVE_WEZTERM=0
[ "${1:-}" = "--remove-wezterm" ] && REMOVE_WEZTERM=1

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

echo
printf '\033[1;38;2;0;128;255m  UPFLY CODE\033[0m\n'
printf '\033[2m  Desinstalador para Linux\033[0m\n\n'
printf '\033[36m  > Removendo o Upfly Code...\033[0m\n'
rm -f "$HOME/.local/bin/upfly-code"
rm -f "$DATA/applications/upfly-code.desktop"
rm -f "$DATA/icons/hicolor/256x256/apps/upfly-code.png" "$DATA/icons/hicolor/512x512/apps/upfly-code.png"
rm -rf "$DATA/upfly-code"
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$DATA/applications" >/dev/null 2>&1 || true

if [ "$REMOVE_WEZTERM" = 1 ]; then
  {
  if command -v apt-get >/dev/null 2>&1 && dpkg -s wezterm >/dev/null 2>&1; then
    $SUDO apt-get remove -y wezterm
  elif command -v dnf >/dev/null 2>&1 && rpm -q wezterm >/dev/null 2>&1; then
    $SUDO dnf -y remove wezterm
  elif command -v pacman >/dev/null 2>&1 && pacman -Q wezterm >/dev/null 2>&1; then
    $SUDO pacman -R --noconfirm wezterm
  elif command -v flatpak >/dev/null 2>&1 && flatpak info org.wezfurlong.wezterm >/dev/null 2>&1; then
    flatpak uninstall -y org.wezfurlong.wezterm
  fi
  } >/dev/null 2>&1
fi

printf '\n\033[32m  Upfly Code removido.\033[0m\n'
[ "$REMOVE_WEZTERM" = 1 ] || printf '\033[2m  O Claude Code e os componentes de terminal foram mantidos.\033[0m\n'
echo
