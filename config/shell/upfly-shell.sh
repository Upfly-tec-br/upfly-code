#!/bin/sh
# Upfly Code - linha de boas-vindas discreta e abre o shell.
# Instalado em <pasta do Upfly Code>/bin/upfly-shell.sh
#
# Rodado pelo bash (modo padrão, Git Bash no Windows): reabre o mesmo bash como login.
# Rodado pelo /bin/sh (modo "system"): abre o shell do usuário ($SHELL).

printf '\033[38;2;0;128;255m▲\033[0m \033[2mUpfly Code  ·  F1 menu  ·  Ctrl+Shift+O abrir pasta  ·  Ctrl+Shift+E arquivos  ·  Ctrl+Shift+A Claude\033[0m\n\n'

# Claude Code (instalação nativa) fica em ~/.local/bin
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH"; export PATH ;; esac

if [ -n "${BASH:-}" ]; then
  # Informa a pasta atual ao terminal (OSC 7), para a barra lateral, o Claude
  # e as novas abas abrirem no lugar certo - inclusive no Git Bash do Windows.
  # Texto literal de propósito: é avaliado pelo bash a cada prompt.
  # shellcheck disable=SC2016,SC2089,SC2090
  UPFLY_OSC7='printf "\033]7;file://%s%s\033\\" "${HOSTNAME:-localhost}" "$(if command -v cygpath >/dev/null 2>&1; then printf /%s "$(cygpath -m "$PWD")"; else printf %s "$PWD"; fi)"'
  PROMPT_COMMAND="${UPFLY_OSC7}${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
  # shellcheck disable=SC2090
  export PROMPT_COMMAND
  exec "$BASH" -l
fi

SHELL_BIN="${SHELL:-/bin/bash}"
[ -x "$SHELL_BIN" ] || SHELL_BIN=/bin/sh
exec "$SHELL_BIN" -l
