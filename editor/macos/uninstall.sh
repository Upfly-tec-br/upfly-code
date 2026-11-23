#!/usr/bin/env bash
# Upfly Code - desinstalador para macOS.
# Remove o aplicativo e o comando. Suas configurações e conversas ficam
# guardadas, a menos que use --tudo.
set -uo pipefail
ALL=0; [ "${1:-}" = "--tudo" ] && ALL=1
APP_DIR="$HOME/Applications/Upfly Code.app"
pkill -f "$APP_DIR/Contents/MacOS/" 2>/dev/null || true
rm -rf "$APP_DIR"
rm -f "$HOME/.local/bin/upfly-code"
if [ "$ALL" = 1 ]; then
  rm -rf "$HOME/.upfly-code" "$HOME/Library/Application Support/Upfly Code"
fi
printf '\033[32m  Upfly Code removido.\033[0m\n'
[ "$ALL" = 1 ] || printf '\033[2m  Suas configurações ficaram guardadas. Para apagar tudo: uninstall.sh --tudo\033[0m\n'
