# Instalação no macOS

## Passo a passo

1. Baixe `UpflyCode-<versão>-macos.zip` e dê dois cliques para extrair.
2. Na pasta extraída, **clique com o botão direito** em **Instalar Upfly Code.command**
   e depois em **Abrir**. O Claude Code também é instalado.
3. Na primeira vez, o macOS avisa que o arquivo veio da internet. Clique em **Abrir**.
   Se não aparecer essa opção, vá em **Ajustes do Sistema → Privacidade e Segurança**
   e clique em **Abrir Mesmo Assim**.
4. O Terminal do macOS abre e faz a instalação.
5. Ao final aparece **"Upfly Code instalado com sucesso!"** e o Upfly Code abre.
   Na primeira vez, escolha **Entrar com minha conta Claude** e faça o login no navegador.

Se algo der errado, envie ao suporte o arquivo de log indicado na tela.

Abra **Upfly Code** pelo Launchpad, pelo Spotlight (`⌘ + Espaço`, digite "Upfly")
ou em `~/Applications`. Para deixar no Dock, arraste o app para lá.

## O que é instalado

| Item | Onde |
|---|---|
| Motor de terminal (WezTerm, código aberto, sem alterações) | `/Applications/WezTerm.app` ou `~/Applications/WezTerm.app` |
| Configuração, fundo, ícones | `~/Library/Application Support/UpflyCode` |
| App "Upfly Code" (lançador com ícone da Upfly) | `~/Applications/Upfly Code.app` |
| Comando de terminal | `~/.local/bin/upfly-code` (aceita uma pasta: `upfly-code ~/projetos/app`) |
| Barra lateral de arquivos | `~/Library/Application Support/UpflyCode/tools/upfly-files` |
| Claude Code (opcional) | `~/.local/bin/claude` |

## Sobre o ícone no Dock

O "Upfly Code" é um lançador: ele abre o WezTerm oficial com a configuração da
Upfly. Por isso, **com a janela aberta, o Dock mostra o ícone do WezTerm**. Trocar
esse ícone exigiria modificar o WezTerm.app, o que quebraria a assinatura digital
dele. Não fazemos isso.

## Shell padrão: bash

Para ser igual nos três sistemas, o Upfly Code abre o **bash** (o mesmo do Git
Bash no Windows), e não o zsh, que é o padrão do macOS. Se você tem configurações
no `~/.zshrc` (PATH, aliases), copie as que precisar para o `~/.bash_profile`. Para
usar o zsh, mude `shell = 'bash'` para `shell = 'system'` no `wezterm.lua` instalado.

## Teclas no Mac

Os atalhos usam **Control** (não Command): `Control+Shift+O` abre pasta,
`Control+Shift+E` mostra os arquivos, `Control+Espaço` e depois `c` abre o Claude Code.
Se `Control+Espaço` estiver trocando o idioma do teclado, desative esse atalho em
**Ajustes do Sistema → Teclado → Atalhos de Teclado → Fontes de Entrada**.

## Instalação pela linha de comando (TI)

```bash
bash scripts/macos/install.sh   # opções: --no-claude --no-launch --skip-wezterm
```
