# Licenças e marcas

## Resumo

| Componente | Dono | Licença | Como entra no Upfly Code |
|---|---|---|---|
| WezTerm (motor) | Wez Furlong | MIT | Binário oficial baixado na instalação. No Windows, cópia `UpflyCode.exe` com ícone/nome da Upfly |
| upfly-files (barra lateral) | Upfly | Uso interno; bibliotecas Apache 2.0/MIT/BSD | Compilado e incluído no pacote |
| rcedit | GitHub Inc. | MIT | Ferramenta do instalador do Windows |
| Git for Windows | Projeto Git for Windows | GPL v2 | Baixado da fonte oficial, só se faltar |
| Configuração, scripts e docs do Upfly Code | Upfly | Uso interno | Este repositório |
| Logo, ícones e fundo | Upfly | Todos os direitos reservados | `branding/` |
| Claude Code | Anthropic | Proprietária | Opcional, instalador oficial |

O texto completo das licenças de terceiros está em
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). Ele é copiado para a pasta de
instalação de cada computador.

## Regras que este projeto segue

1. **Modificação mínima do WezTerm.** Não recompilamos. No Windows, criamos uma
   **cópia** do executável (`UpflyCode.exe`) só com ícone e nome trocados, o que
   a licença MIT permite. O original fica ao lado e o crédito ao autor aparece
   nas propriedades do arquivo. No macOS, o `WezTerm.app` não é alterado, para
   não quebrar a assinatura digital.
2. **"Upfly Code" é o nome da nossa configuração, não do terminal.** Sempre que
   possível, aparece junto da frase "baseado no WezTerm".
3. **Não usamos o logo do WezTerm** nos materiais da Upfly.
4. **Os avisos de copyright do WezTerm são mantidos** (MIT exige isso para
   cópias do software; incluímos mesmo sem redistribuir o binário, por clareza).
5. Uso **interno, sem venda**.

Se um dia a Upfly quiser distribuir um binário renomeado (fork), a licença MIT
permite, desde que o aviso de copyright seja mantido. Ainda assim, convém
evitar o nome "WezTerm" no produto final e pedir orientação jurídica antes.
