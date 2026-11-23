#!/usr/bin/env bash
# Upfly Code - atualização automática (Linux e macOS).
# Chamado pelo botão "Atualizar agora": baixa a versão nova e deixa a troca
# preparada. A troca acontece assim que o Upfly Code fecha, e ele abre de novo.
# Uso: self-update.sh <url-do-pacote> <versão> <appRoot>
set -uo pipefail

URL="${1:?}"; VERSION="${2:-nova}"
LOG="${TMPDIR:-/tmp}/upfly-code-update-$(id -u).log"
echo "Upfly Code - atualização para $VERSION em $(date)" > "$LOG"

fail() {
  printf '\n\033[31m  Não foi possível atualizar: %s\033[0m\n' "$1"
  printf '\033[33m  Detalhes para o suporte: %s\033[0m\n\n' "$LOG"
  read -r -p "  Pressione Enter para fechar " _
  exit 1
}

echo
printf '\033[1;38;2;0;128;255m  UPFLY CODE\033[0m\n'
printf '\033[2m  Atualizando para a versão %s\033[0m\n\n' "$VERSION"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/upfly-update.XXXXXX")"
case "$URL" in *.zip) FILE="$WORK/pacote.zip" ;; *) FILE="$WORK/pacote.tar.gz" ;; esac

printf '\033[36m  > Baixando...\033[0m\n'
curl -fL --progress-bar -o "$FILE" "$URL" 2>&1 | tee -a "$LOG" >/dev/null
[ -s "$FILE" ] || fail "não foi possível baixar o pacote. Confira sua internet."

printf '\033[36m  > Preparando...\033[0m\n'
case "$FILE" in
  *.zip) if command -v ditto >/dev/null 2>&1; then (cd "$WORK" && ditto -x -k "$FILE" .) 2>>"$LOG" || fail "pacote corrompido."
         else (cd "$WORK" && unzip -q "$FILE") 2>>"$LOG" || fail "pacote corrompido."; fi ;;
  *)     tar -xzf "$FILE" -C "$WORK" 2>>"$LOG" || fail "pacote corrompido." ;;
esac
case "$(uname -s)" in Darwin) OS=macos ;; *) OS=linux ;; esac
INSTALLER="$(find "$WORK" -path "*/scripts/$OS/install.sh" | head -n1)"
[ -n "$INSTALLER" ] || fail "o pacote baixado está incompleto."

# Roda separado deste app: espera ele fechar, troca os arquivos e reabre.
DETACH=(nohup)
command -v setsid >/dev/null 2>&1 && DETACH=(setsid nohup)
"${DETACH[@]}" bash "$INSTALLER" --wait-close --no-extensions >>"$LOG" 2>&1 </dev/null &
disown || true

printf '\n\033[32m  Tudo pronto. O Upfly Code vai fechar e abrir de novo na versão %s.\033[0m\n\n' "$VERSION"
sleep 2
exit 0
