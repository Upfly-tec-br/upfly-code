#!/usr/bin/env bash
# Upfly Code - desinstalação (macOS)
# Remove configuração, aplicativo "Upfly Code" e o comando upfly-code.
# Mantém o motor de terminal (WezTerm) e o Claude Code, a menos que use
# --remove-wezterm.
set -uo pipefail

REMOVE_WEZTERM=0
[ "${1:-}" = "--remove-wezterm" ] && REMOVE_WEZTERM=1

INSTALL_DIR="$HOME/Library/Application Support/UpflyCode"
APP_DIR="$HOME/Applications/Upfly Code.app"

echo
printf '\033[1;38;2;0;128;255m  UPFLY CODE\033[0m\n'
printf '\033[2m  Desinstalador para macOS\033[0m\n\n'
printf '\033[36m  > Removendo o Upfly Code...\033[0m\n'
rm -rf "$APP_DIR"
if [ -L "$HOME/.local/bin/upfly-code" ] || grep -q "Upfly Code" "$HOME/.local/bin/upfly-code" 2>/dev/null; then
  rm -f "$HOME/.local/bin/upfly-code"
fi
rm -rf "$INSTALL_DIR"

if [ "$REMOVE_WEZTERM" = 1 ]; then
  if command -v brew >/dev/null 2>&1 && brew list --cask wezterm >/dev/null 2>&1; then
    brew uninstall --cask wezterm >/dev/null 2>&1
  elif [ -d "$HOME/Applications/WezTerm.app" ]; then
    rm -rf "$HOME/Applications/WezTerm.app"
  fi
fi

printf '\n\033[32m  Upfly Code removido.\033[0m\n'
[ "$REMOVE_WEZTERM" = 1 ] || printf '\033[2m  O Claude Code e os componentes de terminal foram mantidos.\033[0m\n'
echo
