#!/usr/bin/env python3
"""Transforma um VSCodium já extraído no Upfly Code.

Uso: rebrand.py <pasta-do-vscodium> <linux|windows|macos> <versão> <raiz-do-repo>

- linux/windows: <pasta> é a raiz extraída (onde fica resources/app).
- macos: <pasta> é a pasta que contém VSCodium.app.

Não recompila nada: muda o product.json (nome, pastas de dados, ícones),
renomeia o executável, troca os ícones e embute a extensão Upfly
(editor/extension) como extensão interna.
"""
import base64
import hashlib
import json
import os
import plistlib
import re
import shutil
import sys

NAME = "Upfly Code"
DATA_FOLDER = ".upfly-code"


def edit_product(app_dir, os_name):
    p = os.path.join(app_dir, "product.json")
    with open(p, encoding="utf-8") as f:
        prod = json.load(f)
    prod.update({
        "nameShort": NAME,
        "nameLong": NAME,
        "applicationName": "upfly-code",
        "dataFolderName": DATA_FOLDER,
        "serverDataFolderName": ".upfly-code-server",
        "sharedDataFolderName": ".upfly-code-shared",
        "urlProtocol": "upfly-code",
        "linuxIconName": "upfly-code",
        "linuxDesktopName": "UpflyCode.desktop",
        "darwinBundleIdentifier": "br.tec.upfly.code",
        "win32AppUserModelId": "Upfly.UpflyCode",
        "win32MutexName": "upflycode",
        "win32DirName": NAME,
        "win32NameVersion": NAME,
        "win32RegValueName": "UpflyCode",
        "win32ShellNameShort": NAME,
        "win32TunnelMutex": "upflycode-tunnel",
        "win32TunnelServiceMutex": "upflycode-tunnelservice",
        "tunnelApplicationName": "upfly-code-tunnel",
        "serverApplicationName": "upfly-code-server",
        "reportIssueUrl": "https://github.com/Upfly-tec-br/upfly-code/issues/new",
        "documentationUrl": "https://upfly.tec.br",
        "releaseNotesUrl": "https://github.com/Upfly-tec-br/upfly-code/releases",
    })
    # Sem o atualizador do VSCodium: quem atualiza é a extensão Upfly.
    # (O defaultChatAgent precisa continuar: sem ele a janela não desenha.
    # O chat embutido fica desligado por chat.disableAIFeatures.)
    for k in ("updateUrl", "downloadUrl"):
        prod.pop(k, None)
    # O Claude Code e o português podem ser atualizados pela loja (Open VSX).
    with open(p, "w", encoding="utf-8") as f:
        json.dump(prod, f, indent=2, ensure_ascii=False)
        f.write("\n")

    pk = os.path.join(app_dir, "package.json")
    with open(pk, encoding="utf-8") as f:
        pkg = json.load(f)
    # No Linux o nome do app vira a "classe" da janela (StartupWMClass).
    pkg["name"] = "UpflyCode"
    pkg["productName"] = NAME
    pkg["desktopName"] = "UpflyCode.desktop"
    with open(pk, "w", encoding="utf-8") as f:
        json.dump(pkg, f, indent=2, ensure_ascii=False)
        f.write("\n")


def svg_with_png(png_path, opacity=1.0):
    with open(png_path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    return ('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            'width="256" height="256" viewBox="0 0 256 256">'
            f'<image width="256" height="256" opacity="{opacity}" '
            f'xlink:href="data:image/png;base64,{b64}" href="data:image/png;base64,{b64}"/></svg>\n')


def replace_product_icons(app_dir, repo):
    """Ícone da barra de título e marca d'água do editor vazio (arquivos não
    verificados pelo checksum do VS Code)."""
    icon = svg_with_png(os.path.join(repo, "branding", "icon-256.png"))
    # Marca d'água do editor vazio: nenhuma (a imagem de fundo já faz esse papel).
    mark = '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1" viewBox="0 0 1 1"/>\n'
    out = os.path.join(app_dir, "out")
    for dirpath, _, files in os.walk(out):
        for name in files:
            p = os.path.join(dirpath, name)
            if name == "code-icon.svg":
                open(p, "w").write(icon)
            elif name.startswith("letterpress-") and name.endswith(".svg"):
                open(p, "w").write(mark)


BACKGROUND_CSS = """
/* Upfly Code: imagem de fundo da Upfly, clareando por cima de tudo, sem
   bloquear cliques. */
.monaco-workbench::after {
  content: ""; position: absolute; inset: 0; z-index: 2000; pointer-events: none;
  background: url("../../media/upfly-background.jpg") center / cover no-repeat;
  mix-blend-mode: screen; opacity: .22;
}
"""


def add_background(app_dir, repo):
    """Imagem de fundo (como no terminal antigo). O CSS do editor é conferido
    por checksum: atualizamos o valor no product.json para não aparecer o
    aviso de instalação corrompida."""
    out = os.path.join(app_dir, "out")
    shutil.copy(os.path.join(repo, "branding", "background-1080p.jpg"),
                os.path.join(out, "media", "upfly-background.jpg"))
    rel = "vs/workbench/workbench.desktop.main.css"
    css = os.path.join(out, rel)
    with open(css, "a", encoding="utf-8") as f:
        f.write(BACKGROUND_CSS)
    with open(css, "rb") as f:
        digest = base64.b64encode(hashlib.sha256(f.read()).digest()).decode().rstrip("=")
    pj = os.path.join(app_dir, "product.json")
    with open(pj, encoding="utf-8") as f:
        prod = json.load(f)
    if rel in prod.get("checksums", {}):
        prod["checksums"][rel] = digest
    with open(pj, "w", encoding="utf-8") as f:
        json.dump(prod, f, indent=2, ensure_ascii=False)
        f.write("\n")


def embed_extension(app_dir, repo, version):
    src = os.path.join(repo, "editor", "extension")
    dst = os.path.join(app_dir, "extensions", "upfly")
    shutil.rmtree(dst, ignore_errors=True)
    shutil.copytree(src, dst)
    pj = os.path.join(dst, "package.json")
    with open(pj, encoding="utf-8") as f:
        pkg = json.load(f)
    pkg["version"] = version
    with open(pj, "w", encoding="utf-8") as f:
        json.dump(pkg, f, indent=2, ensure_ascii=False)
        f.write("\n")
    shutil.copy(os.path.join(repo, "branding", "logo-inverted.png"), os.path.join(dst, "media", "logo.png"))
    shutil.copy(os.path.join(repo, "branding", "icon-256.png"), os.path.join(dst, "media", "icon.png"))
    for sh in ("self-update.sh",):
        os.chmod(os.path.join(dst, "bin", sh), 0o755)


def patch_text(path, old, new):
    with open(path, encoding="utf-8") as f:
        s = f.read()
    s = s.replace(old, new)
    with open(path, "w", encoding="utf-8") as f:
        f.write(s)


def linux(root, repo, version):
    app_dir = os.path.join(root, "resources", "app")
    edit_product(app_dir, "linux")
    embed_extension(app_dir, repo, version)
    replace_product_icons(app_dir, repo)
    add_background(app_dir, repo)
    os.rename(os.path.join(root, "codium"), os.path.join(root, "upfly-code"))
    old_bin = os.path.join(root, "bin", "codium")
    new_bin = os.path.join(root, "bin", "upfly-code")
    os.rename(old_bin, new_bin)
    with open(new_bin, encoding="utf-8") as f:
        s = f.read()
    s = re.sub(r'(ELECTRON="\$VSCODE_PATH/)codium"', r'\1upfly-code"', s)
    s = s.replace('"$VSCODE_PATH/codium"', '"$VSCODE_PATH/upfly-code"')
    with open(new_bin, "w", encoding="utf-8") as f:
        f.write(s)
    for extra in ("codium-tunnel",):
        p = os.path.join(root, "bin", extra)
        if os.path.exists(p):
            os.remove(p)
    icon = os.path.join(app_dir, "resources", "linux", "code.png")
    if os.path.exists(icon):
        shutil.copy(os.path.join(repo, "branding", "icon-512.png"), icon)


def windows(root, repo, version):
    app_dir = os.path.join(root, "resources", "app")
    edit_product(app_dir, "windows")
    embed_extension(app_dir, repo, version)
    replace_product_icons(app_dir, repo)
    add_background(app_dir, repo)
    os.rename(os.path.join(root, "VSCodium.exe"), os.path.join(root, "UpflyCode.exe"))
    old_cmd = os.path.join(root, "bin", "codium.cmd")
    new_cmd = os.path.join(root, "bin", "upfly-code.cmd")
    os.rename(old_cmd, new_cmd)
    patch_text(new_cmd, "VSCodium.exe", "UpflyCode.exe")
    old_sh = os.path.join(root, "bin", "codium")
    if os.path.exists(old_sh):
        new_sh = os.path.join(root, "bin", "upfly-code")
        os.rename(old_sh, new_sh)
        patch_text(new_sh, "VSCodium.exe", "UpflyCode.exe")
    for extra in ("codium-tunnel.exe",):
        p = os.path.join(root, "bin", extra)
        if os.path.exists(p):
            os.remove(p)
    ico = os.path.join(app_dir, "resources", "win32", "code.ico")
    if os.path.exists(ico):
        shutil.copy(os.path.join(repo, "branding", "icon.ico"), ico)
    # O ícone e o nome dentro do UpflyCode.exe são aplicados com rcedit
    # pelo build-packages.sh (precisa do Windows ou do wine).


def macos(root, repo, version):
    old = os.path.join(root, "VSCodium.app")
    new = os.path.join(root, NAME + ".app")
    os.rename(old, new)
    res = os.path.join(new, "Contents", "Resources")
    app_dir = os.path.join(res, "app")
    edit_product(app_dir, "macos")
    embed_extension(app_dir, repo, version)
    replace_product_icons(app_dir, repo)
    add_background(app_dir, repo)
    shutil.copy(os.path.join(repo, "branding", "icon.icns"), os.path.join(res, "VSCodium.icns"))
    plist = os.path.join(new, "Contents", "Info.plist")
    with open(plist, "rb") as f:
        info = plistlib.load(f)
    info.update({
        "CFBundleName": NAME,
        "CFBundleDisplayName": NAME,
        "CFBundleIdentifier": "br.tec.upfly.code",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": version,
    })
    for scheme in info.get("CFBundleURLTypes", []):
        scheme["CFBundleURLSchemes"] = ["upfly-code"]
        scheme["CFBundleURLName"] = NAME
    with open(plist, "wb") as f:
        plistlib.dump(info, f)
    old_cli = os.path.join(app_dir, "bin", "codium")
    if os.path.exists(old_cli):
        os.rename(old_cli, os.path.join(app_dir, "bin", "upfly-code"))


def main():
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    root, os_name, version, repo = sys.argv[1:]
    {"linux": linux, "windows": windows, "macos": macos}[os_name](root, os.path.abspath(repo), version)
    print(f"Upfly Code {version} ({os_name}) pronto em {root}")


if __name__ == "__main__":
    main()
