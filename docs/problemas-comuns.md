# Problemas comuns

Suporte: https://www.upfly.tec.br · [EMAIL_SUPORTE]

## O terminal abre sem o fundo ou sem as cores

O WezTerm abriu sem a configuração da Upfly. Possíveis causas:

- **Você abriu o "WezTerm" em vez do "Upfly Code".** Use o atalho Upfly Code.
- **Erro no `wezterm.lua`.** Se alguém editou o arquivo e ele ficou com erro,
  o WezTerm mostra uma mensagem e usa a configuração padrão. Reinstale ou
  desfaça a edição.
- **Arquivo de fundo ausente.** Confira se `branding/background.jpg` existe na pasta de instalação.

## A barra lateral de arquivos (Ctrl+Shift+E) não abre

- Aparece "Explorador de arquivos não instalado": rode o instalador de novo.
- **Windows:** algum antivírus pode bloquear o `upfly-files.exe`. Libere a pasta
  `%LOCALAPPDATA%\UpflyCode\tools`.
- **macOS:** se aparecer "não é possível verificar o desenvolvedor", rode
  `xattr -dr com.apple.quarantine ~/Library/Application\ Support/UpflyCode/tools`.
- Para fechar a barra, aperte Ctrl+Shift+E de novo ou `q` dentro dela.

## A barra lateral mostra quadradinhos no lugar dos ícones

A fonte de ícones vem com o motor do Upfly Code. Se trocou a fonte no
`wezterm.lua`, volte `font = nil` ou use uma "Nerd Font". Outra saída é usar
ícones simples: adicione `UPFLY_FILES_ASCII = '1'` em
`config.set_environment_variables`.

## Duplo clique na barra lateral abre o arquivo no programa errado

A barra procura nesta ordem: Trae, VS Code, Cursor. Para escolher um editor, mude
`editor = 'auto'` no `wezterm.lua`, por exemplo para `editor = 'code'`. Para
abrir com o programa padrão do sistema, use o clique direito → "Abrir com o
programa padrão".

## "@ Mencionar no Claude" não faz nada

A barra manda o texto para o painel ao lado na mesma aba. Abra o Claude Code ao
lado com Ctrl+Shift+A e tente de novo.

## "Procurar pasta no computador" não abre a janela

- **Linux:** a janela de pastas usa o `zenity` (GNOME) ou o `kdialog` (KDE).
  Sem eles, o Upfly Code pede para você digitar o caminho. Para ter a janela:
  `sudo apt install zenity`.
- **Windows:** a janela pode abrir atrás do Upfly Code. Olhe a barra de tarefas.

## O ícone da barra de tarefas (Windows) ainda é o do WezTerm

1. Desafixe da barra de tarefas qualquer atalho antigo do Upfly Code ou do WezTerm.
2. Rode o instalador da versão nova e abra pelo atalho **Upfly Code** do Menu Iniciar.
3. O ícone troca cerca de 1 segundo depois de a janela abrir: é quando o
   `upfly-taskbar.exe` aplica o ícone da Upfly.
4. Se não trocar, abra o log `%TEMP%\upfly-code-install.log` e procure por
   "helper" ou "ícone não aplicado". O antivírus pode ter bloqueado o programa.
   Libere a pasta `%LOCALAPPDATA%\UpflyCode` e rode o instalador de novo.

## Quero o PowerShell (ou o zsh no Mac) como padrão

No `wezterm.lua` instalado, troque `shell = 'bash'` por `shell = 'system'`.
Os outros shells continuam disponíveis no menu (F1) → **Nova aba com…**.

## O fundo atrapalha a leitura

Aperte `CTRL+Espaço` e depois `b` para desligar o fundo na janela atual. Para
mudar o padrão, edite no `wezterm.lua` instalado:

```lua
background_enabled    = true,  -- false desliga
background_brightness = 0.55,  -- menor = mais escuro
background_overlay    = 0.35,  -- maior = mais escuro
```

## Conectar o Claude Code

Aperte `F1` e escolha **Conectar o Claude**. O Upfly Code:
- instala o Claude Code, se faltar, pelo instalador oficial da Anthropic;
- abre o Claude Code, que leva você ao navegador para entrar na conta.

É preciso ter um plano pago do Claude (Pro, Max, Team ou Enterprise) ou uma
conta do Claude Console. Para conferir a instalação: `claude doctor`.

## Ctrl+Espaço não faz nada

Só os atalhos antigos usam Ctrl+Espaço; o menu (F1) faz tudo o que eles fazem.
Se quiser usá-los, saiba que outro programa pode estar usando esse atalho. Os casos mais comuns são a troca de
idioma do teclado no macOS ou no Linux e alguns IMEs no Windows. Você pode:
- desativar o atalho no outro programa; ou
- trocar o LEADER no `wezterm.lua`, por exemplo:
  `config.leader = { key = 'a', mods = 'CTRL|ALT', timeout_milliseconds = 1500 }`

## Windows: "a execução de scripts foi desabilitada neste sistema"

Use os arquivos `.cmd` do pacote, que já liberam a execução só para o instalador.
Se a política da empresa bloquear até isso, peça à TI para rodar:
`powershell -ExecutionPolicy Bypass -File scripts\windows\install.ps1`

## Windows: o winget pede administrador e eu não tenho

Cancele o pedido. O instalador passa a usar o WezTerm portátil oficial, que não
precisa de administrador.

## Windows: caracteres estranhos na mensagem de boas-vindas

Use o PowerShell 7 (`winget install Microsoft.PowerShell`). O Upfly Code usa o
PowerShell 7 automaticamente quando ele está instalado.

## macOS: "não é possível abrir porque é de um desenvolvedor não identificado"

Clique com o botão direito no arquivo `.command` e escolha **Abrir**. Ou vá em
Ajustes do Sistema → Privacidade e Segurança → **Abrir Mesmo Assim**.

## Linux: o AppImage não abre

Instale o FUSE. No Ubuntu 22.04 ou mais novo: `sudo apt install libfuse2`.

## Linux com Flatpak: sem fundo

O Flatpak isola o aplicativo e pode não ter acesso à pasta
`~/.local/share/upfly-code`. Libere o acesso:
`flatpak override --user --filesystem=~/.local/share/upfly-code org.wezfurlong.wezterm`

## Não recebo aviso quando o Claude Code termina

O Upfly Code mostra um aviso na tela quando uma aba **em segundo plano** toca o sino.
Para o Claude Code tocar o sino ao terminar ou ao pedir permissão, adicione em
`~/.claude/settings.json`:

```json
{ "preferredNotifChannel": "terminal_bell" }
```

## Prompt personalizado (opcional)

O arquivo `config/starship.toml` deixa o prompt com as cores da Upfly. Para usar:
1. Instale o Starship: https://starship.rs
2. Ative no seu shell. Por exemplo, no `~/.bashrc`: `eval "$(starship init bash)"`;
   no PowerShell, no `$PROFILE`: `Invoke-Expression (&starship init powershell)`.
3. Dentro do Upfly Code, a variável `STARSHIP_CONFIG` já aponta para o arquivo da Upfly.
