#!/usr/bin/env bash
# Monta o pacote macOS do Upfly Code (roda num Mac: precisa de ditto e codesign).
# Uso: build-macos.sh <VSCodium-darwin-<arch>-*.zip> <versão> <pasta-de-saída> [pacotes.vsix...]
# Gera <saída>/UpflyCode-<versão>-macos-<arch>.zip
set -euo pipefail

ZIP="$1"; VERSION="$2"; OUT="$3"; shift 3
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCH="arm64"; case "$ZIP" in *x64*) ARCH="x64" ;; esac

P="$OUT/mac-$ARCH/UpflyCode-$VERSION"
rm -rf "$OUT/mac-$ARCH"; mkdir -p "$P/scripts/macos" "$P/scripts/common" "$P/extensions"
ditto -x -k "$ZIP" "$P"
python3 -I "$REPO/editor/scripts/rebrand.py" "$P" macos "$VERSION" "$REPO"

# Mudamos arquivos dentro do .app: assina de novo (assinatura local, sem Apple ID).
codesign --force --deep --sign - "$P/Upfly Code.app"
codesign --verify --deep "$P/Upfly Code.app"

cp "$REPO/editor/macos/install.sh" "$REPO/editor/macos/uninstall.sh" "$P/scripts/macos/"
cp "$REPO/editor/scripts/languagepacks.js" "$P/scripts/common/"
chmod +x "$P/scripts/macos/"*.sh
for v in "$@"; do cp "$v" "$P/extensions/"; done
echo "$VERSION" > "$P/VERSION"
echo "$ARCH" > "$P/ARCH"
printf '#!/bin/bash\ncd "$(dirname "$0")" && bash scripts/macos/install.sh\n' > "$P/Instalar Upfly Code.command"
printf '#!/bin/bash\ncd "$(dirname "$0")" && bash scripts/macos/uninstall.sh\n' > "$P/Desinstalar Upfly Code.command"
chmod +x "$P/"*.command
cp "$REPO/README.md" "$REPO/CHANGELOG.md" "$P/" 2>/dev/null || true
mkdir -p "$P/LICENSES" && cp "$REPO/LICENSES/"*.md "$P/LICENSES/"

(cd "$OUT/mac-$ARCH" && ditto -c -k --keepParent "UpflyCode-$VERSION" "$OUT/UpflyCode-$VERSION-macos-$ARCH.zip")
echo "Pacote: $OUT/UpflyCode-$VERSION-macos-$ARCH.zip"
