#!/usr/bin/env bash
# Monta o pacote Windows do Upfly Code (roda no Windows, pelo Git Bash do
# GitHub Actions: precisa de python, 7z e rcedit-x64.exe).
# Uso: build-windows.sh <VSCodium-win32-x64-*.zip> <versão> <pasta-de-saída> <rcedit.exe> [pacotes.vsix...]
# Gera <saída>/UpflyCode-<versão>-windows.zip
set -euo pipefail

ZIP="$1"; VERSION="$2"; OUT="$3"; RCEDIT="$4"; shift 4
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

P="$OUT/win/UpflyCode-$VERSION"
rm -rf "$OUT/win"; mkdir -p "$P/app" "$P/scripts/windows" "$P/scripts/common" "$P/extensions"
7z x -y -o"$P/app" "$ZIP" >/dev/null
python -I "$REPO/editor/scripts/rebrand.py" "$P/app" windows "$VERSION" "$REPO"

# Ícone, nome e versão dentro do UpflyCode.exe (barra de tarefas, Explorer).
"$RCEDIT" "$P/app/UpflyCode.exe" \
  --set-icon "$REPO/branding/icon.ico" \
  --set-version-string ProductName "Upfly Code" \
  --set-version-string FileDescription "Upfly Code" \
  --set-version-string CompanyName "Upfly" \
  --set-version-string OriginalFilename "UpflyCode.exe" \
  --set-version-string InternalName "UpflyCode" \
  --set-file-version "$VERSION" --set-product-version "$VERSION"

cp "$REPO/editor/windows/install.ps1" "$REPO/editor/windows/uninstall.ps1" "$P/scripts/windows/"
cp "$REPO/editor/scripts/languagepacks.js" "$P/scripts/common/"
for v in "$@"; do cp "$v" "$P/extensions/"; done
echo "$VERSION" > "$P/VERSION"
printf '@echo off\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%%~dp0scripts\\windows\\install.ps1" %%*\r\n' > "$P/Instalar Upfly Code.cmd"
printf '@echo off\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%%~dp0scripts\\windows\\uninstall.ps1" %%*\r\n' > "$P/Desinstalar Upfly Code.cmd"
cp "$REPO/README.md" "$REPO/CHANGELOG.md" "$P/" 2>/dev/null || true
mkdir -p "$P/LICENSES" && cp "$REPO/LICENSES/"*.md "$P/LICENSES/"

(cd "$OUT/win" && 7z a -tzip -mx=7 "$OUT/UpflyCode-$VERSION-windows.zip" "UpflyCode-$VERSION" >/dev/null)
echo "Pacote: $OUT/UpflyCode-$VERSION-windows.zip"
