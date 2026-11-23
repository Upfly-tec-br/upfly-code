# Componentes de terceiros

## Incluídos no pacote do Upfly Code

### VSCodium / Code - OSS (base do editor)

https://github.com/VSCodium/vscodium e https://github.com/microsoft/vscode

```
MIT License

Copyright (c) 2015 - present Microsoft Corporation
Copyright (c) 2018 - present VSCodium contributors

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

O editor usa o Electron e o Chromium; as licenças deles vêm dentro do
aplicativo (`LICENSES.chromium.html` e `resources/app/LICENSE.txt`).

### Pacote de idioma Português (Brasil)

`MS-CEINTL.vscode-language-pack-pt-BR`, https://github.com/microsoft/vscode-loc,
licença MIT, Copyright (c) Microsoft Corporation.

## Baixados durante a instalação (não vêm no pacote)

- **Claude Code para VS Code** (`anthropic.claude-code`), da Anthropic, pelo
  Open VSX. Uso sujeito aos termos da Anthropic: https://www.anthropic.com/legal
- **Git for Windows** (PortableGit), só no Windows e só se o Git não estiver
  instalado. Licença GPLv2: https://github.com/git-for-windows/git
