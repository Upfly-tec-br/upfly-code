# Atualização

São três coisas que se atualizam de forma independente.

## 1. Upfly Code (automático)

O Upfly Code verifica sozinho se há versão nova no GitHub, ao abrir e a cada
6 horas. Quando há:

1. aparece o aviso **"Nova versão disponível"** com as opções **Atualizar
   agora**, **Ver o que mudou** e **Lembrar depois**;
2. a barra superior mostra um selo amarelo **⬆ Atualização X.Y.Z**.

Escolha **Atualizar agora**. No macOS e no Linux, a atualização roda numa aba e
as mudanças valem na hora. No Windows, ela roda numa janela à parte. Se a versão
nova trocar o motor ou o ícone, essa janela pede para você fechar o Upfly Code
e termina sozinha.

Para verificar a qualquer momento: `F1` → **Procurar atualização do Upfly Code**.

### Atualizar manualmente

Se preferir, baixe o pacote novo na página **Releases** do GitHub:

| Sistema | O que fazer |
|---|---|
| Windows | Extraia o pacote novo e dê dois cliques em **Atualizar Upfly Code.cmd** |
| macOS | Extraia o pacote novo, botão direito em **Atualizar Upfly Code.command** → Abrir |
| Linux | Extraia o pacote novo e rode `./update.sh` |

A atualização também atualiza o WezTerm e o Claude Code. Ela não reinstala o
WezTerm do zero e mantém os atalhos.

A versão instalada fica no arquivo `VERSION` da pasta de instalação.

## 2. Motor de terminal, Git Bash portátil e barra lateral

- **Windows:** o motor e o Git Bash portáteis são atualizados junto com os
  pacotes novos da Upfly. As versões ficam no topo do `install.ps1`.
- **macOS (Homebrew):** o script de atualização roda `brew upgrade --cask wezterm`.
- **Linux:** o script atualiza pelo gerenciador de pacotes (`apt`, `dnf`, `pacman`, `flatpak`).
- **Barra lateral (upfly-files):** é compilada junto com os pacotes a partir de
  `tools/upfly-files`. Atualiza sozinha a cada versão nova do Upfly Code.

## 3. Claude Code

Na instalação nativa, o Claude Code **se atualiza sozinho** em segundo plano.
Para forçar uma atualização: `claude update`.

## Para quem mantém o projeto: publicar uma versão

1. Altere o que precisar (normalmente `config/wezterm.lua` → tabela `BRAND`).
2. Aumente o número em `VERSION` (ex.: `1.0.0` → `1.1.0`).
3. Rode `bash tests/run-tests.sh` e `bash scripts/common/build-packages.sh`.
4. Distribua os arquivos de `installers/`.

Dica: para testar uma mudança na hora, edite o `wezterm.lua` **instalado**. O
terminal recarrega sozinho ao salvar.
