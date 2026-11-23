#!/usr/bin/env bash
# Upfly Code - desinstalador para Linux.
# Remove o aplicativo, o comando e o atalho. Suas configurações e conversas
# ficam guardadas, a menos que use --tudo.
set -uo pipefail
ALL=0; [ "${1:-}" = "--tudo" ] && ALL=1
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

pkill -f "$DATA_HOME/upfly-code/app/upfly-code" 2>/dev/null || true
rm -rf "$DATA_HOME/upfly-code"
rm -f "$HOME/.local/bin/upfly-code" "$DATA_HOME/applications/UpflyCode.desktop" \
      "$DATA_HOME/icons/hicolor/256x256/apps/upfly-code.png" "$DATA_HOME/icons/hicolor/512x512/apps/upfly-code.png"
update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true
if [ "$ALL" = 1 ]; then
  rm -rf "$HOME/.upfly-code" "${XDG_CONFIG_HOME:-$HOME/.config}/Upfly Code"
fi
printf '\033[32m  Upfly Code removido.\033[0m\n'
[ "$ALL" = 1 ] || printf '\033[2m  Suas configurações ficaram guardadas. Para apagar tudo: uninstall.sh --tudo\033[0m\n'
