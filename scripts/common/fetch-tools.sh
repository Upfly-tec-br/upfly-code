#!/usr/bin/env bash
# Upfly Code - baixa as ferramentas de terceiros que vão dentro dos pacotes.
#
#   vendor/windows/rcedit-x64.exe   aplica ícone e nome no UpflyCode.exe (rcedit, MIT)
#
# Uso: scripts/common/fetch-tools.sh
# Para atualizar, mude a versão abaixo e rode de novo.
set -euo pipefail

RCEDIT_VERSION="2.0.0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
V="$ROOT/vendor"
mkdir -p "$V/windows"

echo "Baixando rcedit $RCEDIT_VERSION..."
curl -fsSL -o "$V/windows/rcedit-x64.exe" \
  "https://github.com/electron/rcedit/releases/download/v${RCEDIT_VERSION}/rcedit-x64.exe"

{
  echo "rcedit $RCEDIT_VERSION  https://github.com/electron/rcedit (MIT)"
  echo
  (cd "$V" && find . -type f ! -name VERSIONS.txt | sort | xargs sha256sum)
} > "$V/VERSIONS.txt"
cat "$V/VERSIONS.txt"
