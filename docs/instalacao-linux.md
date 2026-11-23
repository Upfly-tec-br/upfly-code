# Instalar no Linux

Funciona em Ubuntu, Debian, Fedora, Mint e outras distribuições, em
computadores comuns (x64) e ARM. Não pede senha.

1. Baixe `UpflyCode-linux.tar.gz` em https://upfly.tec.br (para ARM:
   `UpflyCode-linux-arm64.tar.gz`, na página Releases).
2. Extraia: clique com o botão direito no arquivo e escolha **Extrair aqui**.
3. Abra um terminal na pasta extraída e rode:

   ```
   ./install.sh
   ```

4. O Upfly Code abre sozinho. Depois, procure **Upfly Code** no menu de aplicativos.

O instalador:
- coloca o aplicativo em `~/.local/share/upfly-code`;
- cria o atalho no menu e o comando `upfly-code` (ex.: `upfly-code ~/projetos/meu-site`);
- deixa o português e o chat do Claude instalados.

No Ubuntu 23.10 ou mais novo, o Upfly Code abre com a opção `--no-sandbox`,
igual ao VS Code baixado em `.tar.gz`, porque o sistema bloqueia o recurso
"sandbox" do Chromium para apps instalados sem senha.

Problemas? Veja [problemas comuns](problemas-comuns.md).
