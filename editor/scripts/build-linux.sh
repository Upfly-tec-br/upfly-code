#!/usr/bin/env bash
# Monta o pacote Linux do Upfly Code a partir de um .tar.gz do VSCodium.
# Uso: build-linux.sh <VSCodium-linux-*.tar.gz> <versão> <pasta-de-saída> [pacotes.vsix...]
# Gera <saída>/UpflyCode-<versão>/ e <saída>/UpflyCode-<versão>-linux-<arch>.tar.gz
set -euo pipefail

TARBALL="$1"; VERSION="$2"; OUT="$3"; shift 3
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCH="x64"; case "$TARBALL" in *arm64*) ARCH="arm64" ;; esac

P="$OUT/UpflyCode-$VERSION"
rm -rf "$P"; mkdir -p "$P/app" "$P/scripts/linux" "$P/scripts/common" "$P/branding" "$P/extensions"
tar -xzf "$TARBALL" -C "$P/app"
python3 -I "$REPO/editor/scripts/rebrand.py" "$P/app" linux "$VERSION" "$REPO"

cp "$REPO/editor/linux/install.sh" "$REPO/editor/linux/uninstall.sh" "$P/scripts/linux/"
chmod +x "$P/scripts/linux/"*.sh
cp "$REPO/editor/scripts/languagepacks.js" "$P/scripts/common/"
printf '#!/usr/bin/env bash\nexec bash "$(dirname "$0")/scripts/linux/install.sh" "$@"\n' > "$P/install.sh"
printf '#!/usr/bin/env bash\nexec bash "$(dirname "$0")/scripts/linux/uninstall.sh" "$@"\n' > "$P/uninstall.sh"
chmod +x "$P/install.sh" "$P/uninstall.sh"
cp "$REPO/branding/icon-256.png" "$REPO/branding/icon-512.png" "$P/branding/"
for v in "$@"; do cp "$v" "$P/extensions/"; done
echo "$VERSION" > "$P/VERSION"
cp "$REPO/README.md" "$REPO/CHANGELOG.md" "$P/" 2>/dev/null || true
mkdir -p "$P/LICENSES"
cp "$REPO/LICENSES/"*.md "$P/LICENSES/"

tar -C "$OUT" -czf "$OUT/UpflyCode-$VERSION-linux-$ARCH.tar.gz" "UpflyCode-$VERSION"
echo "Pacote: $OUT/UpflyCode-$VERSION-linux-$ARCH.tar.gz"
