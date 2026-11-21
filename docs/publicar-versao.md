# Publicar uma nova versão (para quem mantém o projeto)

O GitHub monta e publica os pacotes sozinho. Você só precisa mudar o número da
versão e enviar.

## Passo a passo (GitHub Desktop)

1. Faça as mudanças que quiser. Normalmente elas ficam em `config/wezterm.lua`
   (tabela `BRAND`), nos ícones ou nos scripts.
2. Abra o `CHANGELOG.md` e escreva no topo o que mudou, com um título no formato
   `## 1.3.0`. Esse texto aparece no botão "Ver o que mudou".
3. No arquivo `VERSION`, troque o número, por exemplo de `1.2.0` para `1.3.0`.
4. No GitHub Desktop, escreva um resumo (ex.: "Versão 1.3.0"), clique em
   **Commit to main** e depois em **Push origin**.
5. Pronto. Em alguns minutos aparece a versão nova em **Releases** no GitHub.
   Acompanhe na aba **Actions** do repositório.

Em até 6 horas, ou na próxima vez que alguém abrir o Upfly Code, aparece o aviso
**"Nova versão disponível — Atualizar agora"**.

## Como numerar

- `1.2.0` → `1.2.1`: correção pequena.
- `1.2.0` → `1.3.0`: novidade.
- `1.2.0` → `2.0.0`: mudança grande.

## Se a publicação falhar

Abra a aba **Actions** no GitHub, clique na execução com o X vermelho e veja
qual etapa falhou. O mais comum é algum teste falhar. Rode
`bash tests/run-tests.sh` no seu computador (no Git Bash) para ver o erro.
Depois de corrigir, faça um novo commit e push. Se a versão não mudou, use o
botão **Run workflow** em Actions → "Publicar versão".

## O que o GitHub faz por baixo

O arquivo `.github/workflows/release.yml`:

1. baixa as ferramentas incluídas (`scripts/common/fetch-tools.sh`);
2. roda os testes;
3. gera os pacotes (`scripts/common/build-packages.sh`), já configurando este
   repositório como fonte das atualizações;
4. cria a Release `v<versão>` com os 3 pacotes e as notas do `CHANGELOG.md`.

O botão de atualizar dos computadores consulta
`https://api.github.com/repos/<organização>/upfly-code/releases/latest`. Por isso
o repositório precisa ser **público**.
