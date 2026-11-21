#!/usr/bin/env bash
# Upfly Code - autoatualização pelo GitHub (macOS e Linux).
# Chamado pelo botão "Atualizar agora". Baixa o pacote da última release e
# reaplica a configuração (o motor de terminal não é trocado com ele aberto).
set -uo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(head -n1 "$INSTALL_DIR/config/update-repo.txt" | tr -d '[:space:]')"
CURRENT="$(head -n1 "$INSTALL_DIR/VERSION" | tr -d '[:space:]')"
LOG="${TMPDIR:-/tmp}/upfly-code-update.log"
API="${UPFLY_UPDATE_API:-https://api.github.com}"   # sobrescrito só nos testes
echo "Upfly Code - autoatualização em $(date)" > "$LOG"

case "$(uname -s)" in
  Darwin) SUFFIX="-macos.zip"; OS=macos ;;
  *)      SUFFIX="-linux.tar.gz"; OS=linux ;;
esac

fail() {
  printf '\n\033[31m  Não foi possível atualizar: %s\033[0m\n' "$1"
  printf '\033[33m  Detalhes para o suporte: %s\033[0m\n\n' "$LOG"
  read -r -p "  Pressione Enter para fechar " _
  exit 1
}

echo
printf '\033[1;38;2;0;128;255m  UPFLY CODE\033[0m\n'
printf '\033[2m  Atualização\033[0m\n\n'

case "$REPO" in ""|*"["*) fail "repositório de atualizações não configurado." ;; esac

printf '\033[36m  > Procurando a versão mais recente...\033[0m\n'
JSON="$(curl -fsSL --max-time 20 -H 'Accept: application/vnd.github+json' -H 'User-Agent: UpflyCode' \
  "$API/repos/$REPO/releases/latest" 2>>"$LOG")" || fail "sem conexão com o GitHub."
LATEST="$(printf '%s' "$JSON" | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -n1)"
URL="$(printf '%s' "$JSON" | grep -o '"browser_download_url": *"[^"]*'"$SUFFIX"'"' | head -n1 | sed 's/.*: *"\([^"]*\)"/\1/')"
[ -n "$URL" ] || fail "a versão ${LATEST:-nova} não tem pacote para este sistema."
printf '    Versão instalada: %s  ·  nova: %s\n' "$CURRENT" "$LATEST"

printf '\033[36m  > Baixando...\033[0m\n'
WORK="$(mktemp -d)"
FILE="$WORK/pacote$SUFFIX"
curl -fsSL -o "$FILE" "$URL" 2>>"$LOG" || fail "não foi possível baixar o pacote."
if [ "$OS" = macos ]; then
  (cd "$WORK" && unzip -q "$FILE") || fail "pacote corrompido."
else
  tar -xzf "$FILE" -C "$WORK" || fail "pacote corrompido."
fi
INSTALLER="$(find "$WORK" -path "*/scripts/$OS/install.sh" | head -n1)"
[ -n "$INSTALLER" ] || fail "pacote baixado está incompleto."

printf '\033[36m  > Instalando...\033[0m\n'
bash "$INSTALLER" --skip-wezterm --no-claude --no-launch || fail "o instalador encontrou um erro."
rm -rf "$WORK" 2>/dev/null || true

printf '\033[32m  Upfly Code atualizado para a versão %s.\033[0m\n' "$LATEST"
printf '\033[2m  As mudanças já valem nesta janela. Pode fechar esta aba.\033[0m\n\n'
read -r -p "  Pressione Enter para fechar " _
