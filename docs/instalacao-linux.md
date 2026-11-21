# Instalação no Linux

Testado para Ubuntu/Debian, Fedora e Arch. Outras distribuições usam Flatpak ou
AppImage como alternativa.

## Passo a passo

```bash
tar -xzf UpflyCode-<versão>-linux.tar.gz
cd UpflyCode-<versão>
./install.sh                 # terminal + Claude Code (e abre o Upfly Code)
./install.sh --no-claude     # sem o Claude Code
```

O instalador pede sua senha (`sudo`) só para instalar o motor de terminal pelo
gerenciador de pacotes. Tudo do Upfly Code fica na sua pasta pessoal. A saída
técnica vai para `/tmp/upfly-code-install.log`.

Para a TI: o motor é o WezTerm oficial, instalado em ordem de preferência por:

| Distribuição | Método |
|---|---|
| Ubuntu, Debian, Mint, Pop!_OS | repositório apt oficial do WezTerm |
| Fedora | Copr `wezfurlong/wezterm-nightly` |
| Arch, Manjaro | `pacman -S wezterm` |
| Outras com Flatpak | Flathub `org.wezfurlong.wezterm` |
| Sem nada disso | AppImage em `~/.local/share/upfly-code/terminal/` (precisa de FUSE/`libfuse2`) |

Se o WezTerm já estiver instalado, ele é reaproveitado.

Depois, abra **Upfly Code** pelo menu de aplicativos ou rode `upfly-code`.

## O que é instalado

| Item | Onde |
|---|---|
| Configuração, fundo, ícones | `~/.local/share/upfly-code` |
| Comando | `~/.local/bin/upfly-code` (aceita uma pasta: `upfly-code ~/projetos/app`) |
| Barra lateral de arquivos | `~/.local/share/upfly-code/tools/upfly-files` (x86_64 e ARM64) |
| Atalho do menu | `~/.local/share/applications/upfly-code.desktop` |
| Ícones | `~/.local/share/icons/hicolor/{256x256,512x512}/apps/upfly-code.png` |
| Claude Code (opcional) | `~/.local/bin/claude` |

Se o comando `upfly-code` não for encontrado, adicione ao final do `~/.bashrc`
ou do `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```
