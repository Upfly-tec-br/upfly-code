# Desinstalação

A desinstalação remove o Upfly Code: configuração, fundo, ícones, atalhos,
barra lateral e, no Windows, o menu "Abrir no Upfly Code". O **Claude Code é
mantido**.

- **Windows:** toda a pasta `%LOCALAPPDATA%\UpflyCode` é apagada, incluindo o
  motor portátil e o Git Bash portátil. Um Git for Windows instalado à parte não
  é tocado.
- **macOS/Linux:** o WezTerm instalado pelo sistema é mantido, a menos que você
  use `--remove-wezterm`.

| Sistema | Remover Upfly Code | Remover também o WezTerm |
|---|---|---|
| Windows | **Desinstalar Upfly Code.cmd** (no pacote) ou `%LOCALAPPDATA%\UpflyCode\bin\uninstall.ps1` | (já incluído) |
| macOS | **Desinstalar Upfly Code.command** ou `~/Library/Application Support/UpflyCode/bin/uninstall.sh` | `uninstall.sh --remove-wezterm` |
| Linux | `./uninstall.sh` (no pacote) ou `~/.local/share/upfly-code/bin/uninstall.sh` | `uninstall.sh --remove-wezterm` |

## Remover o Claude Code

Siga a documentação oficial: https://code.claude.com/docs/en/setup

Resumo para a instalação nativa:

- macOS/Linux: `rm -f ~/.local/bin/claude && rm -rf ~/.local/share/claude`
- Windows (PowerShell):
  `Remove-Item "$env:USERPROFILE\.local\bin\claude.exe" -Force; Remove-Item "$env:USERPROFILE\.local\share\claude" -Recurse -Force`

As configurações e o histórico do Claude Code ficam em `~/.claude`. Só apague
essa pasta se quiser perder esses dados.
