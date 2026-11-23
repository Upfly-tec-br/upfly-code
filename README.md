# Upfly Code

Terminal da Upfly para Windows, macOS e Linux, com a identidade visual da Upfly,
Git Bash como shell padrão, abertura de pastas, barra lateral de arquivos e
integração com o Claude Code.

Motor de terminal: [WezTerm](https://wezterm.org) (licença MIT). Barra lateral
de arquivos: `upfly-files`, feita pela Upfly (`tools/upfly-files`). Uso interno
da Upfly, sem fins comerciais.

---

## Para quem só quer instalar

1. Baixe o pacote do seu sistema na página **Releases** deste repositório no GitHub:
   - Windows: `UpflyCode-<versão>-windows.zip`
   - macOS: `UpflyCode-<versão>-macos.zip`
   - Linux: `UpflyCode-<versão>-linux.tar.gz`
2. Extraia e dê dois cliques em **Instalar Upfly Code**. No Linux, rode `./install.sh`.
3. Abra **Upfly Code** pelo menu do sistema.

Passo a passo e dúvidas comuns: [Windows](docs/instalacao-windows.md),
[macOS](docs/instalacao-macos.md), [Linux](docs/instalacao-linux.md).

## Primeiros passos

**Não decorou nenhum atalho? Aperte `F1` ou clique com o botão direito.** Abre o
menu do Upfly Code, em português, com tudo o que ele faz. É só digitar para
procurar (por exemplo, "claude" ou "pasta") e apertar Enter.

1. Aperte **Ctrl+Shift+O** para **abrir uma pasta**. A lista mostra:
   - **Procurar pasta no computador...**, que abre a janela de pastas do sistema;
   - **Digitar ou colar um caminho...**;
   - suas pastas recentes;
   - os projetos encontrados em `Documentos/GitHub` (padrão do GitHub Desktop),
     `projetos`, `Projects`, `code`, `dev`...
2. A pasta abre numa aba nova, com os **arquivos na barra lateral à esquerda**,
   como no Trae. **Ctrl+Shift+E** mostra ou esconde a barra.
3. **Ctrl+Shift+A** abre o **Claude** ao lado, na pasta do projeto.
   Na barra lateral, aperte **@** num arquivo para citá-lo no Claude.

Na primeira vez, o Upfly Code oferece **instalar o Claude Code e entrar na sua
conta**. É só escolher a opção e fazer o login no navegador. Enquanto faltar,
aparece "Conectar o Claude: aperte F1" na barra de cima.

No Windows, também dá para clicar com o botão direito numa pasta e escolher
**"Abrir no Upfly Code"**. No macOS e no Linux, rode `upfly-code <pasta>`.

## Atalhos

| Atalho | O que faz |
|---|---|
| `F1`, `Ctrl+Shift+P` ou botão direito | **Menu com tudo**, em português |
| `Ctrl+Shift+O` | **Abrir pasta** (recentes, projetos, procurar, digitar caminho) |
| `Ctrl+Shift+E` | **Mostrar/esconder os arquivos** (barra lateral) |
| `Ctrl+Shift+A` | **Abrir o Claude** ao lado |
| `Ctrl+C` / `Ctrl+V` | Copiar (com texto selecionado) / colar. No Mac: `Cmd+C` / `Cmd+V` |
| `Ctrl+Shift+T` / `Ctrl+Shift+W` | Nova aba / fechar aba |
| `Ctrl+Shift+F` | Procurar texto |
| `Ctrl+Shift+K` | Limpar a tela |
| `Ctrl+=` / `Ctrl+-` | Aumentar / diminuir a letra |
| `F11` | Tela cheia |

Sem texto selecionado, `Ctrl+C` interrompe o programa, como sempre no terminal.
Para colar uma **imagem** no Claude Code, use `Ctrl+Shift+V`.

Os atalhos antigos com `Ctrl+Espaço` (por exemplo `Ctrl+Espaço`, `C` para o
Claude numa aba nova) continuam funcionando.

**Na barra lateral de arquivos** (funciona como no VS Code/Trae):

| Ação | Como |
|---|---|
| Abrir/fechar pasta | clique (ou → ←) |
| Abrir arquivo no editor (Trae, VS Code ou Cursor) | duplo clique ou `Enter` |
| Menu com todas as ações | **clique direito** |
| **Citar o arquivo no Claude Code** (`@arquivo`) | `@` ou menu → "Mencionar no Claude" |
| Levar o terminal até a pasta (`cd`) | `c` ou menu → "Terminal nesta pasta" |
| Novo arquivo / nova pasta | `a` / `A` |
| Renomear / enviar à Lixeira | `F2` / `Delete` |
| Buscar arquivo pelo nome | `/` |
| Copiar caminho | `y` (relativo: `Y`) |
| Ajuda | `?` |

As cores seguem o Git: amarelo = modificado, verde = novo, vermelho = apagado,
e uma bolinha nas pastas com mudanças.

`Shift+Enter` quebra linha dentro do Claude Code sem configuração extra.

## Atualizações

O Upfly Code procura versões novas no GitHub ao abrir e a cada 6 horas. Quando
encontra uma, mostra o aviso **"Atualizar agora"** e um selo amarelo na barra
superior. Também dá para atualizar pelo menu (`F1`).

Para publicar uma versão nova, mude o arquivo `VERSION` e envie. O GitHub gera
os pacotes sozinho. Veja [docs/publicar-versao.md](docs/publicar-versao.md).

---

## Decisões técnicas

### 1. O que é personalizado por configuração
Tudo fica no `config/wezterm.lua`, carregado com `--config-file`. Isso inclui:
- cores, fundo e título da janela;
- shell padrão (Git Bash / bash);
- abrir pasta e barra lateral;
- atalhos e o menu em português (F1);
- integração com o Claude Code.

A configuração pessoal de quem já usa o WezTerm (`~/.wezterm.lua`) não é afetada.

### 2. O que mexe no executável
- **Windows:** o instalador usa o WezTerm **portátil** oficial (sem pedir
  administrador) e cria ao lado uma **cópia** chamada `UpflyCode.exe`, com o
  ícone e o nome da Upfly aplicados pelo `rcedit`. O `wezterm-gui.exe` original
  fica intacto. Como o motor redefine o ícone da janela ao abrir, um pequeno
  programa (`bin\upfly-taskbar.exe`, compilado na instalação) aplica nas janelas
  o ID de aplicativo "Upfly.UpflyCode" e o ícone da Upfly. É isso que faz a barra
  de tarefas mostrar o ícone certo.
- **macOS:** não mexemos no `WezTerm.app`, porque isso quebraria a assinatura
  digital do autor. O app "Upfly Code" é um lançador com o ícone da Upfly. Com a
  janela aberta, o Dock mostra o WezTerm.
- **Linux:** com `--class UpflyCode`, a janela usa o ícone e o nome da Upfly.

### 3. Pontos de licença e marca
- WezTerm e rcedit são MIT, e as bibliotecas da barra lateral são Apache 2.0/MIT/BSD: uso, cópia e modificação são permitidos, desde que se mantenham os avisos de copyright ([LICENSES/](LICENSES/README.md)).
- O Git for Windows (GPLv2) e o WezTerm são baixados das fontes oficiais, sem redistribuição nossa.
- O rcedit e a barra lateral vão dentro do pacote, com os avisos de licença.
- O `UpflyCode.exe` mantém, nas propriedades do arquivo, o crédito "motor WezTerm (c) Wez Furlong, licença MIT".
- Não usamos o nome nem o logo do WezTerm como marca da Upfly.

### 4. Solução adotada
Usamos os motores oficiais e a configuração da Upfly. A cópia renomeada só
existe no Windows. Não fazemos fork nem recompilação.

---

## Estrutura

```text
upfly-code/
├── README.md
├── VERSION                     versão do Upfly Code
├── LICENSES/                   avisos de terceiros e regras de marca
├── branding/                   logos, ícones (.ico/.icns/.png) e fundo
├── config/
│   ├── wezterm.lua             a configuração (edite a tabela BRAND)
│   ├── starship.toml           prompt opcional
│   └── shell/                  boas-vindas (sh e PowerShell)
├── scripts/
│   ├── common/                 gerar assets, baixar ferramentas, gerar pacotes
│   ├── windows/                install / update / uninstall / create-shortcut (.ps1)
│   ├── macos/                  install / update / uninstall (.sh)
│   └── linux/                  install / update / uninstall (.sh)
├── tools/
│   ├── upfly-files/            barra lateral de arquivos (Go)
│   └── windows/                ícone na barra de tarefas (C#, compilado na instalação)
├── vendor/                     rcedit (baixado por fetch-tools.sh, fora do Git)
├── installers/                 pacotes gerados (publicados nas Releases, fora do Git)
├── .github/workflows/          publicação automática de versões
├── CHANGELOG.md                novidades de cada versão
├── docs/                       manuais em português
└── tests/                      validações automáticas
```

## Para quem mantém o projeto

```bash
# trocar cor principal ou variar o fundo (gera ícones e fundo de novo)
python3 scripts/common/generate-assets.py --primary 0080FF --seed 7

# baixar/atualizar o rcedit (versão no topo do script)
bash scripts/common/fetch-tools.sh

# validar tudo
bash tests/run-tests.sh

# gerar os pacotes localmente (o GitHub faz isso sozinho ao mudar VERSION)
bash scripts/common/build-packages.sh
```

Para publicar uma versão, siga [docs/publicar-versao.md](docs/publicar-versao.md).

As versões do motor (WezTerm) e do Git portátil ficam no topo dos instaladores.

Placeholders ainda pendentes: `[EMAIL_SUPORTE]` em `config/wezterm.lua` e
`docs/problemas-comuns.md`. Também falta a versão vetorial do logo
(`branding/logo.svg`), que deve vir do designer.

Página de download: https://upfly.tec.br (repositório
[Upfly-tec-br/upfly-site](https://github.com/Upfly-tec-br/upfly-site), publicado pelo Easypanel).

Suporte: https://www.upfly.tec.br
