#!/usr/bin/env bash
# Testes do Upfly Code (editor com chat do Claude).
#   bash tests/run-tests.sh            checagens rápidas + pacote Linux + instalação simulada
#   UPFLY_QUICK=1 bash tests/run-tests.sh   só as checagens rápidas
# A instalação simulada precisa rodar como usuário comum (não root).
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"
FAILS=0
TOUT="$(mktemp)"; UNIT="$(mktemp --suffix=.js 2>/dev/null || mktemp)"
trap 'rm -f "$TOUT" "$UNIT"' EXIT
ok()   { printf '  \033[32mok\033[0m   %s\n' "$*"; }
bad()  { printf '  \033[31mFALHA\033[0m %s\n' "$*"; FAILS=$((FAILS+1)); }
skip() { printf '  \033[33m--\033[0m   %s\n' "$*"; }
sec()  { printf '\n\033[36m## %s\033[0m\n' "$*"; }
check() { local name="$1"; shift; if "$@" >"$TOUT" 2>&1; then ok "$name"; else bad "$name"; sed 's/^/       /' "$TOUT" | head -15; fi; }

# ---------------------------------------------------------------------------
sec "Arquivos"
for f in VERSION CHANGELOG.md README.md editor/VSCODIUM_VERSION \
         editor/extension/package.json editor/extension/extension.js \
         editor/extension/themes/upfly-dark.json editor/extension/bin/self-update.sh editor/extension/bin/self-update.ps1 \
         editor/scripts/rebrand.py editor/scripts/languagepacks.js editor/scripts/make-vsix.py \
         editor/scripts/build-linux.sh editor/scripts/build-windows.sh editor/scripts/build-macos.sh editor/scripts/fetch-deps.sh \
         editor/linux/install.sh editor/windows/install.ps1 editor/macos/install.sh \
         branding/icon.ico branding/icon.icns branding/icon-256.png branding/icon-512.png branding/logo-inverted.png; do
  [ -f "$f" ] && ok "$f" || bad "$f ausente"
done

sec "Sintaxe"
check "extension.js" node --check editor/extension/extension.js
check "languagepacks.js" node --check editor/scripts/languagepacks.js
for j in editor/extension/package.json editor/extension/themes/*.json; do
  check "$j é JSON válido" node -e "JSON.parse(require('fs').readFileSync('$j','utf8'))"
done
check "rebrand.py / make-vsix.py" python3 -c "import ast,sys; [ast.parse(open(f).read(),f) for f in sys.argv[1:]]" editor/scripts/rebrand.py editor/scripts/make-vsix.py
for s in editor/linux/*.sh editor/macos/*.sh editor/scripts/*.sh editor/extension/bin/*.sh; do
  check "bash -n $s" bash -n "$s"
done
if command -v shellcheck >/dev/null 2>&1; then
  check "shellcheck" shellcheck -S error editor/linux/*.sh editor/macos/*.sh editor/scripts/*.sh editor/extension/bin/*.sh
else skip "shellcheck não instalado"; fi
for p in editor/windows/*.ps1 editor/extension/bin/*.ps1; do
  if head -c3 "$p" | od -An -tx1 | grep -q 'ef bb bf'; then ok "$p tem BOM (acentos no PowerShell 5)"; else bad "$p sem BOM"; fi
done
if command -v pwsh >/dev/null 2>&1; then
  for p in editor/windows/*.ps1 editor/extension/bin/*.ps1; do
    check "PowerShell lê $p" pwsh -NoProfile -Command "\$e=\$null; [void][System.Management.Automation.Language.Parser]::ParseFile('$p',[ref]\$null,[ref]\$e); if (\$e) { \$e; exit 1 }"
  done
else skip "pwsh não instalado (checado no Windows do GitHub Actions)"; fi

sec "Extensão Upfly"
check "textos em português e atalhos" node -e "
const p=require('./editor/extension/package.json');
const t=p.contributes.commands.map(c=>c.title).join(' ');
if(/wezterm/i.test(JSON.stringify(p))) throw 'fala em wezterm';
for (const w of ['Conversar com o Claude','Abrir uma pasta','Procurar atualização']) if(!t.includes(w)) throw 'falta '+w;
const kb=p.contributes.keybindings.map(k=>k.key);
for (const k of ['ctrl+shift+a','ctrl+o']) if(!kb.includes(k)) throw 'falta atalho '+k;
const d=p.contributes.configurationDefaults;
if(d['claudeCode.preferredLocation']!=='sidebar') throw 'Claude não fica à direita';
if(d['workbench.colorTheme']!=='Upfly Escuro') throw 'tema';
if(!p.capabilities.untrustedWorkspaces.supported) throw 'desliga em modo restrito';
"
cat > "$UNIT" <<'EOF'
const Module = require('module');
const fs = require('fs'), os = require('os'), path = require('path');
const orig = Module._load;
Module._load = function (req, ...a) { return req === 'vscode' ? { env: { appRoot: '/nao/existe' } } : orig.call(this, req, ...a); };
const { _test } = require(process.argv[2]);
const assert = require('assert');
assert(_test.isNewer('2.0.1', '2.0.0'));
assert(_test.isNewer('v2.1.0', '2.0.9'));
assert(_test.isNewer('2.0.10', '2.0.9'));
assert(!_test.isNewer('2.0.0', '2.0.0'));
assert(!_test.isNewer('1.4.0', '2.0.0'));
const home = fs.mkdtempSync(path.join(os.tmpdir(), 'upfly-home-'));
os.homedir = () => home;
fs.mkdirSync(path.join(home, '.upfly-code'));
const argv = path.join(home, '.upfly-code', 'argv.json');
fs.writeFileSync(argv, '// comentário\n{\n\t"enable-crash-reporter": false\n}\n');
_test.setLocaleInArgv('pt-br');
let t = fs.readFileSync(argv, 'utf8');
assert(/"enable-crash-reporter": false,\s*\n\t"locale": "pt-br"/.test(t), t);
_test.setLocaleInArgv('en');
t = fs.readFileSync(argv, 'utf8');
assert(t.includes('"locale": "en"') && !t.includes('pt-br'), t);
console.log('ok');
EOF
check "comparação de versões e idioma no argv.json" node "$UNIT" "$REPO/editor/extension/extension.js"

[ -n "${UPFLY_QUICK:-}" ] && { echo; [ "$FAILS" = 0 ] && printf '\033[32mTodos os testes passaram.\033[0m\n' || printf '\033[31m%s falha(s)\033[0m\n' "$FAILS"; exit "$FAILS"; }

# ---------------------------------------------------------------------------
sec "Pacote Linux"
if [ "$(id -u)" = 0 ]; then
  skip "rodando como root: pacote e instalação simulada pulados (rode como usuário comum)"
else
  V="$(tr -d '[:space:]' < VERSION)"
  OUT="$(mktemp -d)"
  TARBALL="${UPFLY_VSCODIUM_TARBALL:-}"
  PT="${UPFLY_PTBR_VSIX:-}"
  if [ -z "$TARBALL" ]; then
    mapfile -t DEPS < <(bash editor/scripts/fetch-deps.sh linux-x64 | tail -2)
    TARBALL="${DEPS[0]}"; PT="${DEPS[1]}"
  fi
  check "build-linux.sh" bash editor/scripts/build-linux.sh "$TARBALL" "$V" "$OUT" $PT
  P="$OUT/UpflyCode-$V"
  PROD="$P/app/resources/app/product.json"
  check "product.json com a marca Upfly" node -e "
    const p=require('$PROD');
    if(p.nameShort!=='Upfly Code'||p.applicationName!=='upfly-code'||p.dataFolderName!=='.upfly-code') throw JSON.stringify(p.nameShort);
    if(p.updateUrl) throw 'atualizador do VSCodium ativo';
    if(!p.defaultChatAgent) throw 'sem defaultChatAgent a janela não desenha';"
  check "extensão Upfly embutida com a versão $V" node -e "
    const p=require('$P/app/resources/app/extensions/upfly/package.json'); if(p.version!=='$V') throw p.version;"
  check "executável renomeado" test -x "$P/app/upfly-code" -a -x "$P/app/bin/upfly-code" -a ! -e "$P/app/codium"
  check "imagem de fundo com checksum certo (sem aviso de instalação corrompida)" node -e "
    const fs=require('fs'),c=require('crypto');
    const prod=require('$PROD'); const rel='vs/workbench/workbench.desktop.main.css';
    const css=fs.readFileSync('$P/app/resources/app/out/'+rel);
    if(!css.toString().includes('upfly-background.jpg')) throw 'sem imagem';
    if(!fs.existsSync('$P/app/resources/app/out/media/upfly-background.jpg')) throw 'sem arquivo';
    const d=c.createHash('sha256').update(css).digest('base64').replace(/=+$/,'');
    if(prod.checksums[rel]!==d) throw 'checksum';"
  check "ícone da barra de título trocado" grep -q 'data:image/png;base64' "$P/app/resources/app/out/media/code-icon.svg"

  sec "Instalação simulada (Linux)"
  H="$(mktemp -d)"
  export HOME="$H" XDG_DATA_HOME="$H/.local/share" XDG_CONFIG_HOME="$H/.config"
  check "install.sh concluiu" bash "$P/install.sh" --no-launch --no-extensions
  check "aplicativo instalado" test -x "$H/.local/share/upfly-code/app/upfly-code"
  check "comando upfly-code" test -x "$H/.local/bin/upfly-code"
  check "atalho no menu ligado à janela (UpflyCode)" grep -q '^StartupWMClass=UpflyCode$' "$H/.local/share/applications/UpflyCode.desktop"
  check "ícone instalado" test -f "$H/.local/share/icons/hicolor/512x512/apps/upfly-code.png"
  check "abre em português (argv.json)" grep -q '"locale": "pt-br"' "$H/.upfly-code/argv.json"
  check "sem aviso de pasta confiável" grep -q '"security.workspace.trust.enabled": false' "$H/.config/Upfly Code/User/settings.json"
  if [ -n "$PT" ]; then
    check "português instalado sem internet" bash -c "ls -d '$H'/.upfly-code/extensions/ms-ceintl.vscode-language-pack-pt-br-*"
    check "índice de idiomas pronto antes de abrir" grep -q '"pt-br"' "$H/.config/Upfly Code/languagepacks.json"
  fi
  check "CLI responde a versão" bash -c "'$H/.local/share/upfly-code/app/bin/upfly-code' --version | head -1 | grep -q '\\.'"

  sec "Atualização automática (Linux)"
  V2="99.0.0"
  check "pacote de teste $V2" bash editor/scripts/build-linux.sh "$TARBALL" "$V2" "$OUT"
  PORT=$((20000 + RANDOM % 20000))
  ( cd "$OUT" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 ) >/dev/null 2>&1 &
  SRV=$!
  sleep 1
  check "self-update.sh prepara a troca" bash "$H/.local/share/upfly-code/app/resources/app/extensions/upfly/bin/self-update.sh" \
    "http://127.0.0.1:$PORT/UpflyCode-$V2-linux-x64.tar.gz" "$V2" "/x" </dev/null
  for _ in $(seq 1 120); do [ "$(cat "$H/.local/share/upfly-code/VERSION" 2>/dev/null)" = "$V2" ] && break; sleep 1; done
  check "versão nova instalada sozinha" grep -qx "$V2" "$H/.local/share/upfly-code/VERSION"
  kill "$SRV" 2>/dev/null

  check "uninstall.sh removeu tudo" bash -c "bash '$P/uninstall.sh' && test ! -e '$H/.local/share/upfly-code' && test ! -e '$H/.local/bin/upfly-code'"
  rm -rf "$OUT" "$H"
fi

echo
if [ "$FAILS" = 0 ]; then printf '\033[32mTodos os testes passaram.\033[0m\n'; else printf '\033[31m%s falha(s)\033[0m\n' "$FAILS"; fi
exit "$FAILS"
