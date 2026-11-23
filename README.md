# Upfly Code

Editor da Upfly para Windows, macOS e Linux: seus arquivos à esquerda, o
**chat do Claude** à direita e o terminal embaixo, tudo em português e com a
identidade visual da Upfly. Parecido com o Trae, feito para qualquer pessoa
conseguir usar.

Base: [VSCodium](https://vscodium.com) (código aberto do VS Code, licença MIT).
Chat: extensão oficial do [Claude Code](https://code.claude.com/docs/pt/vs-code),
instalada pelo Open VSX. Uso interno da Upfly, sem fins comerciais.

---

## Para quem só quer instalar

1. Baixe em **https://upfly.tec.br** (ou na página **Releases** deste repositório):
   - Windows: `UpflyCode-windows.zip`
   - Mac com Apple Silicon (M1, M2...): `UpflyCode-macos.zip`
   - Mac com Intel: `UpflyCode-macos-intel.zip`
   - Linux: `UpflyCode-linux.tar.gz`
2. Extraia e dê dois cliques em **Instalar Upfly Code**. No Linux, rode `./install.sh`.
3. Abra **Upfly Code** pelo menu do sistema.

Não pede senha de administrador. Passo a passo: [Windows](docs/instalacao-windows.md),
[macOS](docs/instalacao-macos.md), [Linux](docs/instalacao-linux.md).

## Primeiros passos

1. Na página inicial, clique em **Abrir uma pasta** (ou `Ctrl+O`). Os arquivos
   aparecem à esquerda e o terminal embaixo.
2. O **chat do Claude** abre à direita (`Ctrl+Shift+A`). Na primeira vez, clique
   em **Sign in** e entre com sua conta Claude (precisa de assinatura Pro, Max,
   Team ou Enterprise). Depois é só escrever o que precisa, em português.
3. Não lembra de um atalho? Aperte **F1** e escreva o que quer fazer. O ícone da
   **Upfly** na barra da esquerda também mostra as ações principais.

| Atalho | O que faz |
| - | - |
| `Ctrl+O` | Abrir uma pasta |
| `Ctrl+P` | Procurar um arquivo pelo nome |
| `Ctrl+Shift+A` | Abrir o chat do Claude |
| `Alt+K` | Mandar o trecho selecionado para o Claude |
| `` Ctrl+' `` | Mostrar ou esconder o terminal |
| `Ctrl+B` | Mostrar ou esconder os arquivos |
| `F1` | Procurar qualquer comando |

No Mac, use `Cmd` no lugar de `Ctrl`.

## Atualizações

O Upfly Code confere se há versão nova ao abrir e a cada hora. Quando há, ele
pergunta se você quer atualizar. Clicando em **Atualizar agora**, ele fecha, se
atualiza e abre de novo sozinho. Detalhes em [docs/atualizacao.md](docs/atualizacao.md).

---

## Para quem desenvolve

```
editor/
  extension/        extensão Upfly embutida: página inicial, painel, tema,
                    atalhos, layout tipo Trae e aviso de atualização
  scripts/
    fetch-deps.sh   baixa o VSCodium (versão em editor/VSCODIUM_VERSION) e o português
    rebrand.py      transforma o VSCodium no Upfly Code (nome, ícones, pastas)
    build-*.sh      monta o pacote de cada sistema
    languagepacks.js  deixa o português pronto antes da primeira abertura
  linux/ macos/ windows/   instaladores e desinstaladores
tests/run-tests.sh  testes (inclui instalação e atualização simuladas no Linux)
```

- Testar: `bash tests/run-tests.sh` (como usuário comum; `UPFLY_QUICK=1` só faz as checagens rápidas).
- Pacote de teste: todo push na branch `editor` gera os pacotes dos 3 sistemas
  no GitHub Actions (aba Actions, "artifacts").
- Publicar: veja [docs/publicar-versao.md](docs/publicar-versao.md).
- Atualizar a base (VSCodium): mude `editor/VSCODIUM_VERSION` para uma versão de
  https://github.com/VSCodium/vscodium/releases e publique uma versão nova.

Licenças de terceiros: [LICENSES](LICENSES/README.md).
