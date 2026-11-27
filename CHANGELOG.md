# Novidades do Upfly Code

## 2.1.0

- **Continua de onde você parou:** ao abrir o Upfly Code, ele já abre o último
  projeto e a última conversa com o Claude nesse projeto, em vez de um chat vazio.
  Dá para desligar em Configurações, procurando por "Upfly".
- **Ícones nos arquivos:** o Material Icon Theme já vem instalado e ligado, com
  um ícone para cada tipo de arquivo e pasta.
- As pastas aparecem uma por linha na lista de arquivos (sem juntar
  `src/app/components` numa linha só).

## 2.0.2

- Sem o ícone no meio da tela quando nenhum arquivo está aberto: fica só a imagem de fundo.

## 2.0.1

- **A imagem de fundo da Upfly voltou**, suave, sem atrapalhar a leitura.
- O chat do Claude não abre mais sozinho na página inicial (sem pasta aberta).
  Antes, ele perguntava em inglês, a cada janela, se você confiava na sua pasta
  pessoal. Agora ele abre quando você abre uma pasta de projeto.
- A página inicial explica a pergunta "Trust folder" do Claude.

## 2.0.0

O Upfly Code agora é um **editor com o chat do Claude ao lado**, parecido com o Trae.

- **Chat do Claude de verdade:** a extensão oficial do Claude Code fica sempre à
  direita, com balões de conversa, anexos e revisão das mudanças. Entra com a
  sua conta Claude, sem chave de API.
- **Arquivos à esquerda, terminal embaixo:** abriu uma pasta, já fica tudo no
  lugar. Clique num arquivo para ver e editar.
- **Página inicial simples:** botões grandes para abrir uma pasta, conversar com
  o Claude ou abrir o terminal, mais as pastas recentes e os atalhos que mais ajudam.
- **Tudo em português desde a primeira abertura**, com o tema e o logo da Upfly.
- **Painel "O que você quer fazer?"** (ícone da Upfly na barra da esquerda) e
  página **Atalhos** (`Ctrl+K Ctrl+H`). `F1` procura qualquer comando.
- **Atualização com um clique:** o Upfly Code confere ao abrir e a cada hora.
  Quando há versão nova, pergunta se você quer atualizar, fecha, se atualiza e
  abre de novo sozinho.
- **Instalação sem senha** nos três sistemas. No Windows, instala o Git Bash
  portátil se o Git não estiver instalado (o Claude precisa dele).
- Pacotes separados para Mac Intel (`UpflyCode-macos-intel.zip`) e Linux ARM
  (`UpflyCode-linux-arm64.tar.gz`).
- Quem tem a versão 1.x recebe esta atualização pelo botão de sempre. Depois
  de atualizar, feche a janela antiga e abra o Upfly Code de novo.

## 1.4.0

- **Tudo em português e fácil de usar:**
  - **F1** (ou **Ctrl+Shift+P**, ou o **botão direito do mouse**) abre o menu do
    Upfly Code com tudo o que ele faz: abrir pasta, arquivos, Claude, copiar,
    colar, dividir a tela, procurar, tamanho da letra, atualizar. É só digitar
    para procurar.
  - **Ctrl+C copia** quando há texto selecionado e **Ctrl+V cola**, como em
    qualquer programa. Sem seleção, Ctrl+C interrompe o programa, como sempre.
  - **Ctrl+Shift+A** abre o Claude ao lado.
  - Avisos de fechar aba e o "Nova aba com…" agora são em português. As telas
    do motor que só existiam em inglês foram desligadas.
  - A barra de cima mostra "Menu: F1" e, quando falta, "Conectar o Claude: aperte F1".
  - No Windows, o Git Bash e o Git falam português.
- **Um aplicativo só:** no Linux e no Mac, o motor de terminal não aparece mais
  como um segundo aplicativo ("WezTerm") no menu, no Launchpad ou no Dock.
  A janela fica ligada ao Upfly Code, com o ícone e o nome certos.

## 1.3.0

- **Nova barra lateral de arquivos**, no estilo do VS Code e do Trae
  (`Ctrl+Shift+E`). Tem:
  - pastas que abrem com um clique e ícones por tipo de arquivo;
  - cores do Git e menu de clique direito;
  - criar, renomear e excluir (envia para a Lixeira) e busca por nome (`/`);
  - **@ para citar o arquivo no Claude Code**;
  - abrir o arquivo no Trae, VS Code ou Cursor com duplo clique.
  Arquivos de sistema do Windows ficam ocultos.
- **Ícone da Upfly na barra de tarefas do Windows**, também com a janela aberta.
- As abas e a janela não mostram mais "wezterm".
- **Conexão fácil com o Claude:**
  - o instalador já instala o Claude Code e abre o Upfly Code no final;
  - ao abrir, o Upfly Code oferece "Entrar com minha conta Claude";
  - um selo na barra avisa se ainda falta conectar;
  - `Ctrl+Espaço`, `K` conecta a qualquer momento.

## 1.2.0

- **Atualização automática:** o Upfly Code verifica novas versões no GitHub ao
  abrir e a cada 6 horas. Quando há uma, aparece o aviso com o botão
  **"Atualizar agora"** e um selo amarelo na barra superior.
- Atualizar manualmente: `Ctrl+Espaço` e depois `U`, ou `Ctrl+Shift+P` →
  "Upfly: verificar/instalar atualização".

## 1.1.0

- Ícone e nome "Upfly Code" também na barra de tarefas do Windows (`UpflyCode.exe`).
- Instalação no Windows sem pedir administrador.
- Git Bash como shell padrão nos três sistemas.
- **Abrir pasta** (`Ctrl+Shift+O`): recentes, projetos do GitHub Desktop,
  janela de pastas do sistema ou caminho digitado.
- **Barra lateral de arquivos** (`Ctrl+Shift+E`).
- Windows: "Abrir no Upfly Code" no clique direito das pastas.

## 1.0.0

- Primeira versão: identidade visual Upfly, fundo, atalhos, integração com o
  Claude Code e instaladores para Windows, macOS e Linux.
