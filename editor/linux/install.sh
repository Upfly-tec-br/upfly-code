#!/usr/bin/env bash
# Upfly Code - instalador para Linux (editor com chat do Claude)
#
# Instala só para o seu usuário, sem pedir senha:
#   ~/.local/share/upfly-code/app      o aplicativo
#   ~/.local/bin/upfly-code            comando para abrir pelo terminal
#   menu de aplicativos                atalho "Upfly Code" com o ícone da Upfly
# e já deixa o português e o chat do Claude instalados.
#
# Uso: ./install.sh [--no-launch] [--wait-close] [--no-extensions]
#   --wait-close    espera o Upfly Code fechar antes de trocar os arquivos e
#                   abre de novo no fim (usado pela atualização automática)
# Opções antigas (--skip-wezterm, --no-claude) são aceitas e ignoradas, para
# que versões antigas consigam atualizar para esta.
set -euo pipefail

LAUNCH=1
WAIT_CLOSE=0
EXTENSIONS=1
LEGACY=0   # chamado pelo atualizador da versão antiga (terminal WezTerm)
for arg in "$@"; do
  case "$arg" in
    --no-launch) LAUNCH=0 ;;
    --wait-close) WAIT_CLOSE=1 ;;
    --no-extensions) EXTENSIONS=0 ;;
    --skip-wezterm) LEGACY=1 ;;
    --no-claude|--with-claude) ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "Opção desconhecida: $arg" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="$DATA_HOME/upfly-code"
APP_DIR="$INSTALL_DIR/app"
APPS_DIR="$DATA_HOME/applications"
ICONS_DIR="$DATA_HOME/icons/hicolor"
BIN_DIR="$HOME/.local/bin"
USER_DATA="$HOME/.upfly-code"
VERSION="$(tr -d '[:space:]' < "$PACKAGE_ROOT/VERSION")"
LOG="${TMPDIR:-/tmp}/upfly-code-install-$(id -u).log"
echo "Upfly Code $VERSION - instalação em $(date)" > "$LOG"

step() { printf '\033[36m  > %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m    %s\033[0m\n' "$*"; }
note() { printf '\033[2m    %s\033[0m\n' "$*"; }
fail() {
  printf '\n\033[31m  Não foi possível instalar o Upfly Code: %s\033[0m\n' "$1"
  printf '\033[33m  Detalhes para o suporte: %s\033[0m\n\n' "$LOG"
  exit 1
}

[ -x "$PACKAGE_ROOT/app/upfly-code" ] || fail "pacote incompleto (falta a pasta app)."
case "$(uname -m)" in x86_64|amd64|aarch64|arm64) ;; *) fail "processador não suportado: $(uname -m)" ;; esac

echo
printf '\033[1;38;2;0;128;255m  UPFLY CODE\033[0m  \033[2mversão %s\033[0m\n\n' "$VERSION"

app_running() { pgrep -f "$APP_DIR/upfly-code" >/dev/null 2>&1; }

if [ "$WAIT_CLOSE" = 1 ]; then
  step "Esperando o Upfly Code fechar..."
  for _ in $(seq 1 240); do app_running || break; sleep 0.5; done
fi

# 1. Aplicativo: copia para app.new e troca de uma vez.
step "Copiando o aplicativo..."
mkdir -p "$INSTALL_DIR"
rm -rf "$APP_DIR.new" "$APP_DIR.old"
cp -a "$PACKAGE_ROOT/app" "$APP_DIR.new" 2>>"$LOG" || fail "não foi possível copiar os arquivos."
[ -d "$APP_DIR" ] && mv "$APP_DIR" "$APP_DIR.old"
mv "$APP_DIR.new" "$APP_DIR"
rm -rf "$APP_DIR.old"
echo "$VERSION" > "$INSTALL_DIR/VERSION"

# Restos da versão antiga (terminal WezTerm): não são mais usados. Se quem
# chamou foi o atualizador antigo, a janela antiga ainda está aberta usando
# esses arquivos: ficam para a próxima instalação.
if [ "$LEGACY" = 0 ]; then
  rm -rf "$INSTALL_DIR/config" "$INSTALL_DIR/bin" "$INSTALL_DIR/tools" "$INSTALL_DIR/state" \
         "$INSTALL_DIR/branding" "$INSTALL_DIR/LICENSES" 2>/dev/null || true
fi
ok "Aplicativo em $APP_DIR"

# 2. Comando e atalho no menu.
step "Criando o atalho no menu de aplicativos..."
mkdir -p "$BIN_DIR" "$APPS_DIR" "$ICONS_DIR/256x256/apps" "$ICONS_DIR/512x512/apps"
cat > "$BIN_DIR/upfly-code" <<LAUNCHER
#!/usr/bin/env bash
# Upfly Code. Aceita uma pasta ou arquivo: upfly-code ~/projetos/meu-app
APP="$APP_DIR"
EXTRA=()
# Ubuntu 23.10+ bloqueia o "sandbox" do Chromium para apps instalados sem
# senha. Nesse caso o Upfly Code abre sem ele (como o VS Code em .tar.gz).
if [ "\$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)" = 1 ] \\
   && [ ! -u "\$APP/chrome-sandbox" ]; then
  EXTRA+=(--no-sandbox)
fi
exec "\$APP/bin/upfly-code" "\${EXTRA[@]}" "\$@"
LAUNCHER
chmod +x "$BIN_DIR/upfly-code"

cp "$PACKAGE_ROOT/branding/icon-256.png" "$ICONS_DIR/256x256/apps/upfly-code.png"
cp "$PACKAGE_ROOT/branding/icon-512.png" "$ICONS_DIR/512x512/apps/upfly-code.png"

rm -f "$APPS_DIR/upfly-code.desktop"
cat > "$APPS_DIR/UpflyCode.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Upfly Code
GenericName=Editor com Claude
Comment=Seus arquivos, o terminal e o chat do Claude num lugar só
Exec=$BIN_DIR/upfly-code %F
Icon=upfly-code
Terminal=false
StartupNotify=true
StartupWMClass=UpflyCode
Categories=Development;IDE;TextEditor;
MimeType=inode/directory;text/plain;
Keywords=upfly;claude;editor;terminal;codigo;
Actions=nova-janela;

[Desktop Action nova-janela]
Name=Nova janela
Exec=$BIN_DIR/upfly-code --new-window
DESKTOP
update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
gtk-update-icon-cache -q -t "$ICONS_DIR" >/dev/null 2>&1 || true
ok "Atalho \"Upfly Code\" criado"

# 3. Primeira abertura simples: sem aviso de "pasta confiável" e sem a aba
#    de boas-vindas em inglês (só se a pessoa ainda não tem configurações).
SETTINGS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Upfly Code/User"
if [ ! -f "$SETTINGS_DIR/settings.json" ]; then
  mkdir -p "$SETTINGS_DIR"
  cat > "$SETTINGS_DIR/settings.json" <<'SETTINGS'
{
  "security.workspace.trust.enabled": false,
  "workbench.startupEditor": "none"
}
SETTINGS
fi

# Português desde a primeira abertura.
mkdir -p "$USER_DATA"
if [ ! -f "$USER_DATA/argv.json" ]; then
  printf '{\n\t"locale": "pt-br"\n}\n' > "$USER_DATA/argv.json"
elif ! grep -q '"locale"' "$USER_DATA/argv.json"; then
  sed -i '0,/{/s//{\n\t"locale": "pt-br",/' "$USER_DATA/argv.json"
fi

# 4. Português e chat do Claude já instalados (precisa de internet; se falhar,
#    o Upfly Code instala sozinho quando abrir).
CLI=("$APP_DIR/bin/upfly-code")
[ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)" = 1 ] && CLI+=(--no-sandbox)
# Pacotes que vêm dentro do instalador (português): funcionam sem internet.
for vsix in "$PACKAGE_ROOT"/extensions/*.vsix; do
  [ -f "$vsix" ] || continue
  "${CLI[@]}" --install-extension "$vsix" >>"$LOG" 2>&1 || true
done
# Índice de idiomas pronto antes da primeira abertura (abre já em português).
ELECTRON_RUN_AS_NODE=1 "$APP_DIR/upfly-code" "$PACKAGE_ROOT/scripts/common/languagepacks.js" \
  "$USER_DATA/extensions" "${XDG_CONFIG_HOME:-$HOME/.config}/Upfly Code" >>"$LOG" 2>&1 || true
if [ "$EXTENSIONS" = 1 ]; then
  step "Instalando o chat do Claude..."
  if "${CLI[@]}" --install-extension anthropic.claude-code >>"$LOG" 2>&1; then
    ok "Pronto"
  else
    note "Sem internet agora. O Upfly Code termina isso quando abrir."
  fi
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) note "Para abrir pelo terminal com o comando upfly-code, adicione $BIN_DIR ao PATH." ;;
esac

printf '\n\033[32m  Upfly Code %s instalado.\033[0m\n' "$VERSION"
note "Procure \"Upfly Code\" no menu de aplicativos."
if [ "$LEGACY" = 1 ]; then
  printf '\n\033[33m  O Upfly Code agora é um editor com o chat do Claude ao lado.\033[0m\n'
  printf '\033[33m  Feche esta janela e abra o Upfly Code de novo pelo menu de aplicativos.\033[0m\n'
fi
echo

if [ "$LAUNCH" = 1 ] || [ "$WAIT_CLOSE" = 1 ]; then
  if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    nohup "$BIN_DIR/upfly-code" >/dev/null 2>&1 &
  fi
fi
