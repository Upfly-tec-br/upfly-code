# Problemas comuns

## O chat do Claude não aparece

- Aperte `Ctrl+Shift+A` (no Mac, `Cmd+Shift+A`). Se o chat ainda não estiver
  instalado, o Upfly Code instala na hora (precisa de internet).
- Ou use o ícone da **Upfly** na barra da esquerda > **Conversar com o Claude**.
- Ainda nada? `F1` > **Upfly: Instalar ou reparar o Claude**.

## O Claude pede para entrar de novo ou dá erro 403

O chat usa a sua conta Claude. É preciso ter uma assinatura **Pro, Max, Team ou
Enterprise** (ou uma conta do Claude Console). Clique em **Sign in** no chat e
entre de novo no navegador.

## No Windows, o Claude diz que precisa do Git Bash

Rode o instalador de novo: ele instala o Git Bash portátil quando o Git não está
instalado. Se você instalou o Git depois, feche e abra o Upfly Code.

## Está em inglês

Feche todas as janelas do Upfly Code e abra de novo. Se continuar, rode o
instalador de novo (ele reinstala o português).

## "Restricted Mode" / "Modo Restrito" aparece

Clique em **Gerenciar** > **Confiar**. O instalador desliga esse aviso, mas ele
volta se a configuração `security.workspace.trust.enabled` for ligada.

## No Linux, o aplicativo não abre

Rode `upfly-code --verbose` no terminal e mande o que aparecer para o suporte.
No Ubuntu 23.10 ou mais novo, o atalho já usa `--no-sandbox` (veja
[instalação no Linux](instalacao-linux.md)).

## No Mac: "não pode ser aberto porque é de um desenvolvedor não identificado"

Abra o Finder em **Aplicativos** do seu usuário (`~/Applications`), clique com o
botão direito em **Upfly Code** > **Abrir** e confirme. Só é preciso uma vez.

## A atualização não funcionou

Veja [atualização](atualizacao.md#se-a-atualização-falhar).

## Onde ficam os registros para o suporte

- Instalação: `/tmp/upfly-code-install-<número>.log` (Linux e Mac) ou
  `%TEMP%\upfly-code-install.log` (Windows).
- Do aplicativo: `F1` > **Abrir pasta de logs**.
