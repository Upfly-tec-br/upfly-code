#!/usr/bin/env bash
# Upfly Code - gera os pacotes de distribuição por sistema operacional.
#
#   installers/windows/UpflyCode-<versão>-windows.zip
#   installers/macos/UpflyCode-<versão>-macos.zip
#   installers/linux/UpflyCode-<versão>-linux.tar.gz
#
# Uso: scripts/common/build-packages.sh
# Requisitos: bash, zip, tar, Go 1.22+ (para compilar a barra lateral)
#   UPFLY_GO_MIRRORS=1  usa os espelhos do GitHub para golang.org/x (redes restritas)
#   UPFLY_UPDATE_REPO   repositório das atualizações (preenchido pelo GitHub Actions)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
NAME="UpflyCode-$VERSION"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------- barra lateral (Go)
BIN="$WORK/bin"
mkdir -p "$BIN"
build_files() { # $1 GOOS  $2 GOARCH  $3 saída
  (
    cd "$ROOT/tools/upfly-files"
    export CGO_ENABLED=0 GOOS="$1" GOARCH="$2"
    if [ "${UPFLY_GO_MIRRORS:-}" = "1" ]; then
      GOPROXY=direct GOSUMDB=off GOFLAGS=-mod=mod \
        go build -modfile=go.mirror.mod -trimpath -ldflags "-s -w" -o "$3" .
    else
      GOFLAGS=-mod=mod go build -trimpath -ldflags "-s -w" -o "$3" .
    fi
  )
}
echo "Compilando a barra lateral de arquivos..."
if [ "${UPFLY_GO_MIRRORS:-}" != "1" ]; then
  (cd "$ROOT/tools/upfly-files" && GOFLAGS=-mod=mod go mod tidy)
fi
build_files windows amd64 "$BIN/upfly-files-windows-amd64.exe"
build_files darwin  arm64 "$BIN/upfly-files-darwin-arm64"
build_files darwin  amd64 "$BIN/upfly-files-darwin-amd64"
build_files linux   amd64 "$BIN/upfly-files-linux-amd64"
build_files linux   arm64 "$BIN/upfly-files-linux-arm64"

common_tree() { # $1 = destino, $2 = sistema
  local dest="$1" os="$2"
  mkdir -p "$dest/scripts" "$dest/docs" "$dest/tools"
  cp "$ROOT/VERSION" "$ROOT/README.md" "$ROOT/CHANGELOG.md" "$dest/"
  cp -R "$ROOT/config" "$ROOT/branding" "$ROOT/LICENSES" "$dest/"
  cp -R "$ROOT/scripts/$os" "$dest/scripts/"
  cp "$ROOT/docs/"*.md "$dest/docs/"
  # Repositório de onde virão as atualizações (preenchido pelo GitHub Actions)
  if [ -n "${UPFLY_UPDATE_REPO:-}" ]; then
    echo "$UPFLY_UPDATE_REPO" > "$dest/config/update-repo.txt"
  fi
}

crlf() { sed -i 's/\r\?$/\r/' "$1"; }

# ---------------------------------------------------------------- Windows
W="$WORK/windows/$NAME"
common_tree "$W" windows
[ -f "$ROOT/vendor/windows/rcedit-x64.exe" ] || { echo "Falta vendor/windows/rcedit-x64.exe. Rode scripts/common/fetch-tools.sh" >&2; exit 1; }
cp "$BIN/upfly-files-windows-amd64.exe" "$W/tools/upfly-files.exe"
cp "$ROOT/tools/windows/upfly-taskbar.cs" "$W/tools/"
cp "$ROOT/vendor/windows/rcedit-x64.exe" "$W/tools/"
cat > "$W/Instalar Upfly Code.cmd" <<'EOF'
@echo off
title Instalador Upfly Code
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\install.ps1"
pause
EOF
cat > "$W/Atualizar Upfly Code.cmd" <<'EOF'
@echo off
title Atualizador Upfly Code
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\update.ps1"
pause
EOF
cat > "$W/Desinstalar Upfly Code.cmd" <<'EOF'
@echo off
title Desinstalador Upfly Code
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\uninstall.ps1"
pause
EOF
for f in "$W"/*.cmd "$W"/scripts/windows/*.ps1 "$W"/config/shell/*.ps1; do crlf "$f"; done
mkdir -p "$ROOT/installers/windows"
rm -f "$ROOT/installers/windows/$NAME-windows.zip"
(cd "$WORK/windows" && zip -qr "$ROOT/installers/windows/$NAME-windows.zip" "$NAME")

# ---------------------------------------------------------------- macOS
M="$WORK/macos/$NAME"
common_tree "$M" macos
cp "$BIN/upfly-files-darwin-arm64" "$M/tools/upfly-files-arm64"
cp "$BIN/upfly-files-darwin-amd64" "$M/tools/upfly-files-amd64"
cat > "$M/Instalar Upfly Code.command" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")" && bash scripts/macos/install.sh
read -r -p "Pressione Enter para fechar..."
EOF
cat > "$M/Atualizar Upfly Code.command" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")" && bash scripts/macos/update.sh
read -r -p "Pressione Enter para fechar..."
EOF
cat > "$M/Desinstalar Upfly Code.command" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")" && bash scripts/macos/uninstall.sh
read -r -p "Pressione Enter para fechar..."
EOF
chmod +x "$M"/*.command "$M"/scripts/macos/*.sh "$M"/config/shell/*.sh "$M"/tools/*
mkdir -p "$ROOT/installers/macos"
rm -f "$ROOT/installers/macos/$NAME-macos.zip"
(cd "$WORK/macos" && zip -qry "$ROOT/installers/macos/$NAME-macos.zip" "$NAME")

# ---------------------------------------------------------------- Linux
L="$WORK/linux/$NAME"
common_tree "$L" linux
cp "$BIN/upfly-files-linux-amd64" "$L/tools/upfly-files-x86_64"
cp "$BIN/upfly-files-linux-arm64" "$L/tools/upfly-files-aarch64"
for action in install update uninstall; do
  printf '#!/usr/bin/env bash\ncd "$(dirname "$0")" && exec bash scripts/linux/%s.sh "$@"\n' "$action" > "$L/$action.sh"
done
chmod +x "$L"/*.sh "$L"/scripts/linux/*.sh "$L"/config/shell/*.sh "$L"/tools/*
mkdir -p "$ROOT/installers/linux"
tar -C "$WORK/linux" -czf "$ROOT/installers/linux/$NAME-linux.tar.gz" "$NAME"

echo "Pacotes gerados:"
ls -lh "$ROOT"/installers/*/"$NAME"*
