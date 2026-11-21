# Avisos de terceiros — Upfly Code

O Upfly Code é uma **configuração e um conjunto de instaladores** criados pela
Upfly para uso interno. Ele não contém nem modifica o código ou os binários
dos programas abaixo: os instaladores baixam as versões oficiais diretamente
das fontes de cada projeto.

---

## WezTerm

- Site: https://wezterm.org — código: https://github.com/wezterm/wezterm
- Uso no Upfly Code: motor de terminal, baixado dos canais oficiais (releases
  no GitHub, Homebrew, repositórios apt/Copr ou Flathub). No Windows, o
  instalador cria uma cópia do executável chamada `UpflyCode.exe` com o ícone
  e o nome da Upfly; o executável original e este aviso de copyright são
  mantidos.
- Licença: MIT

```
MIT License

Copyright (c) 2018-Present Wez Furlong

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

O WezTerm inclui as fontes JetBrains Mono, Noto Color Emoji e Roboto,
distribuídas sob a SIL Open Font License 1.1 (o texto acompanha o próprio
WezTerm). O Upfly Code usa a fonte padrão do WezTerm e não redistribui fontes.

## Barra lateral de arquivos (upfly-files)

- Programa da Upfly (`tools/upfly-files`), compilado com as bibliotecas
  tcell (Apache 2.0), encoding (Apache 2.0), go-colorful (MIT), uniseg (MIT),
  golang.org/x/sys, x/term e x/text (BSD-3) e a biblioteca padrão do Go (BSD-3).
- Os textos completos dessas licenças estão em
  [upfly-files-THIRD-PARTY.txt](upfly-files-THIRD-PARTY.txt).

## rcedit (somente no instalador do Windows)

- Código: https://github.com/electron/rcedit — Copyright (c) 2013 GitHub Inc.
- Uso no Upfly Code: ferramenta usada na instalação para aplicar o ícone e o
  nome da Upfly na cópia `UpflyCode.exe` do motor. Incluída no pacote.
- Licença: MIT (mesmo texto da licença do WezTerm acima, com o aviso
  "Copyright (c) 2013 GitHub Inc.").

## Git for Windows / Git Bash (somente Windows, quando não instalado)

- Site: https://gitforwindows.org — licença GPL v2 (e licenças dos componentes)
- Uso no Upfly Code: a versão portátil oficial é **baixada da fonte oficial**
  durante a instalação, sem modificações e sem redistribuição pela Upfly.

## Claude Code (opcional)

- Site: https://code.claude.com — © Anthropic PBC
- Uso no Upfly Code: instalado **somente se o usuário escolher**, pelo
  instalador oficial da Anthropic. Software proprietário, sujeito aos termos
  da Anthropic. Exige conta paga do Claude ou conta do Claude Console.

## Starship (opcional, não instalado automaticamente)

- Site: https://starship.rs — licença ISC
- Uso no Upfly Code: apenas um arquivo de configuração (`config/starship.toml`).

## Ativos da Upfly

Logo, símbolo, ícones derivados e a imagem de fundo `branding/background*.jpg`
pertencem à Upfly. A imagem de fundo é original, gerada pelo script
`scripts/common/generate-assets.py`.
