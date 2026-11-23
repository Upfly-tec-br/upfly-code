# Atualização

O Upfly Code confere se há versão nova:
- uns segundos depois de abrir;
- a cada hora, enquanto está aberto;
- quando você volta para a janela depois de mais de uma hora longe.

Quando há versão nova, aparece uma janela perguntando se você quer atualizar:

- **Atualizar agora:** o Upfly Code baixa a versão nova, fecha, se atualiza e
  abre de novo sozinho, na mesma pasta. Leva menos de um minuto.
- **O que mudou:** abre as novidades da versão.
- **Depois:** fica um aviso amarelo na barra de baixo ("Atualizar para X").
  Clique nele quando quiser.

Para procurar na hora: ícone da **Upfly** na barra da esquerda >
**Procurar atualização** (ou `F1` e escreva "atualização").

Suas configurações, pastas recentes e conversas com o Claude continuam depois
da atualização.

## Vindo da versão 1.x (terminal)

A versão 1.x mostra o aviso de atualização como antes. Depois de atualizar,
feche a janela antiga e abra o **Upfly Code** de novo pelo menu: ele abre já
como o editor novo.

## Se a atualização falhar

Baixe o pacote em https://upfly.tec.br e rode o instalador por cima. Nada se
perde. O registro da última tentativa fica em:
- Linux e Mac: `/tmp/upfly-code-update-<número>.log`
- Windows: `%TEMP%\upfly-code-update.log`
