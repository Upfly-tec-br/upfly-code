# Instalação no Windows

Requisitos: Windows 10 (versão 1809 ou mais nova) ou Windows 11, 64 bits.
**Não precisa de administrador.**

## Passo a passo

1. Baixe `UpflyCode-<versão>-windows.zip`.
2. Clique com o botão direito no arquivo e escolha **Extrair tudo...**. Não rode de dentro do zip.
3. Abra a pasta extraída e dê dois cliques em **Instalar Upfly Code.cmd**.
   O Claude Code também é instalado.
4. Se o Windows mostrar "O Windows protegeu o computador", clique em
   **Mais informações → Executar assim mesmo**.
5. Aguarde. Na primeira instalação são baixados o terminal e, se você ainda não
   tiver, o Git Bash, cerca de 130 MB no total.
6. No fim aparece **"Upfly Code instalado com sucesso!"** e o Upfly Code abre
   sozinho. Na primeira vez, ele mostra **"Conectar o Upfly Code ao Claude"**.
   Escolha **Entrar com minha conta Claude** e faça o login no navegador.

Abra **Upfly Code** pelo Menu Iniciar, pela Área de Trabalho ou clicando com o
botão direito numa pasta → **Abrir no Upfly Code**. No Windows 11, essa opção
fica em **Mostrar mais opções**.

Se algo der errado, o instalador mostra o caminho de um arquivo de log
(`%TEMP%\upfly-code-install.log`). Envie esse arquivo ao suporte.

## O que é instalado

Tudo fica em `%LOCALAPPDATA%\UpflyCode`:

| Pasta | O que é |
|---|---|
| `terminal\UpflyCode.exe` | O Upfly Code. É o motor WezTerm portátil, com ícone e nome da Upfly |
| `git\` | Git Bash portátil, só se você não tinha o Git for Windows |
| `tools\upfly-files.exe` | Barra lateral de arquivos |
| `bin\upfly-taskbar.exe` | Põe o ícone da Upfly na barra de tarefas |
| `config\`, `branding\`, `bin\` | Configuração, fundo, ícones e scripts |
| `state\recent.txt` | Suas pastas recentes |

Também são criados:
- atalhos no Menu Iniciar e na Área de Trabalho;
- o item "Abrir no Upfly Code" no clique direito das pastas.

O Claude Code vai para `%USERPROFILE%\.local\bin\claude.exe`.

## Shell padrão: Git Bash

O Upfly Code usa o **Git Bash** em todos os sistemas, para os comandos serem os
mesmos no Windows, no Mac e no Linux. Se você já tem o Git for Windows, ele é
reaproveitado. Se não tem, o instalador coloca uma versão portátil só para o Upfly Code.

O PowerShell e o CMD continuam disponíveis no menu (**F1**) → **Nova aba com…**. Para voltar ao
PowerShell como padrão, mude `shell = 'bash'` para `shell = 'system'` no arquivo
`%LOCALAPPDATA%\UpflyCode\config\wezterm.lua`.

## Se você instalou uma versão anterior

A versão 1.0 instalava o WezTerm pelo `winget`. A 1.1 usa a versão portátil
própria, então aquela instalação não é mais necessária. Se você não usa o
WezTerm fora do Upfly Code, pode removê-la: `winget uninstall wez.wezterm`.

## Instalação pela linha de comando (TI)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\windows\install.ps1
# opções: -NoClaude  -NoLaunch  -NoDesktopShortcut  -NoContextMenu  -SkipGit
```
