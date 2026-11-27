#!/usr/bin/env bash
# Baixa o que o pacote de um sistema precisa, para editor/.cache:
#   - VSCodium (versão em editor/VSCODIUM_VERSION), MIT
#   - pacote de português do Brasil (Open VSX), MIT
#   - Material Icon Theme, ícones dos arquivos (Open VSX), MIT
# Uso: fetch-deps.sh <linux-x64|linux-arm64|win32-x64|darwin-arm64|darwin-x64>
set -euo pipefail

TARGET="$1"
EDITOR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="$EDITOR/.cache"; mkdir -p "$CACHE"
V="$(tr -d '[:space:]' < "$EDITOR/VSCODIUM_VERSION")"

case "$TARGET" in
  linux-*) FILE="VSCodium-$TARGET-$V.tar.gz" ;;
  *)       FILE="VSCodium-$TARGET-$V.zip" ;;
esac
if [ ! -s "$CACHE/$FILE" ]; then
  echo "Baixando $FILE..."
  curl -fL --retry 3 -o "$CACHE/$FILE.part" "https://github.com/VSCodium/vscodium/releases/download/$V/$FILE"
  mv "$CACHE/$FILE.part" "$CACHE/$FILE"
fi
echo "$CACHE/$FILE"

# Extensões que vêm dentro do instalador: a versão mais nova do Open VSX.
openvsx() { # <publicador/nome> <arquivo> <rótulo>
  local out="$CACHE/$2" url
  if [ ! -s "$out" ]; then
    url="$(curl -fsSL "https://open-vsx.org/api/$1" \
           | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).files.download))')"
    echo "Baixando $3: $url" >&2
    curl -fL --retry 3 -o "$out.part" "$url"
    mv "$out.part" "$out"
  fi
  echo "$out"
}
openvsx MS-CEINTL/vscode-language-pack-pt-BR pt-br.vsix "o português"
openvsx PKief/material-icon-theme material-icon-theme.vsix "os ícones dos arquivos"
