#!/usr/bin/env bash
# Upfly Code - atualização (macOS)
# - Atualiza o motor de terminal (WezTerm, via Homebrew se instalado por ele).
# - Atualiza o Claude Code, se instalado.
# - Se executado de dentro de um pacote novo, reaplica a configuração.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/Library/Application Support/UpflyCode"
LOG="${TMPDIR:-/tmp}/upfly-code-update.log"
echo "Upfly Code - atualização em $(date)" > "$LOG"

echo
printf '\033[1;38;2;0;128;255m  UPFLY CODE\033[0m\n'
printf '\033[2m  Atualizador para macOS\033[0m\n\n'

printf '\033[36m  > Atualizando o Upfly Code...\033[0m\n'
if command -v brew >/dev/null 2>&1 && brew list --cask wezterm >/dev/null 2>&1; then
  brew upgrade --cask wezterm >>"$LOG" 2>&1 || true
fi

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
  printf '\033[2m    Para receber a versão nova, baixe o pacote novo e abra "Atualizar Upfly Code.command".\033[0m\n\n'
  printf '\033[32m  Upfly Code atualizado.\033[0m\n\n'
fi
