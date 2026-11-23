# Publicar uma versão

1. Escreva as novidades no topo do `CHANGELOG.md`, num título `## X.Y.Z`.
2. Mude o arquivo `VERSION` para `X.Y.Z` na branch `main`. Mande o `VERSION` por
   último (ou tudo num commit só): é ele que dispara a publicação.
3. O GitHub Actions ("Publicar versão"):
   - roda os testes e uma instalação de teste em Windows, macOS e Linux;
   - gera os pacotes dos três sistemas;
   - cria a Release `vX.Y.Z` com os pacotes e as notas do CHANGELOG.
4. Em até uma hora, quem tem o Upfly Code aberto recebe a pergunta para atualizar.
   O site (https://upfly.tec.br) já baixa a versão nova, porque os botões apontam
   para `releases/latest/download/UpflyCode-<sistema>`.

## Testar antes de publicar

Todo push na branch `editor` roda o mesmo processo, sem publicar. Os pacotes
ficam na aba **Actions** do GitHub, na execução, em **Artifacts** (14 dias).

## Arquivos da Release

| Arquivo | Para quem |
| - | - |
| `UpflyCode-windows.zip` | Windows 10/11 (64 bits) |
| `UpflyCode-macos.zip` | Mac com Apple Silicon |
| `UpflyCode-macos-intel.zip` | Mac com Intel |
| `UpflyCode-linux.tar.gz` | Linux x64 |
| `UpflyCode-linux-arm64.tar.gz` | Linux ARM |

Também vão cópias com a versão no nome (`UpflyCode-X.Y.Z-...`).

## Atualizar a base (VSCodium)

Mude `editor/VSCODIUM_VERSION` para a versão desejada de
https://github.com/VSCodium/vscodium/releases e publique uma versão nova do
Upfly Code. O português é sempre baixado na versão mais nova do Open VSX.
