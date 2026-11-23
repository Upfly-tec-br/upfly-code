// Upfly Code - extensão embutida.
// Deixa o editor simples para qualquer pessoa: página inicial com botões
// grandes, chat do Claude sempre à direita, terminal embaixo, atalhos em
// português e aviso de atualização (GitHub Releases).
'use strict';

const vscode = require('vscode');
const https = require('https');
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');

const CLAUDE_EXT = 'anthropic.claude-code';
const PTBR_EXT = 'MS-CEINTL.vscode-language-pack-pt-BR';
const UPDATE_EVERY_MS = 60 * 60 * 1000; // 1 hora
const isMac = process.platform === 'darwin';
const MOD = isMac ? 'Cmd' : 'Ctrl';

let ctx;
let pkg;
let statusUpdate;
let homePanel;
let lastUpdateCheck = 0;
let pendingUpdate = null;

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------
function currentVersion() { return (pkg && pkg.version) || '0.0.0'; }

function isNewer(a, b) {
  const pa = String(a).replace(/^v/, '').split(/[.-]/).map((n) => parseInt(n, 10) || 0);
  const pb = String(b).replace(/^v/, '').split(/[.-]/).map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const x = pa[i] || 0, y = pb[i] || 0;
    if (x !== y) return x > y;
  }
  return false;
}

function getJson(url) {
  return new Promise((resolve, reject) => {
    const lib = url.startsWith('http:') ? http : https;
    const req = lib.get(url, {
      headers: { 'User-Agent': 'UpflyCode', Accept: 'application/vnd.github+json' },
      timeout: 15000,
    }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        res.resume();
        return resolve(getJson(res.headers.location));
      }
      if (res.statusCode !== 200) { res.resume(); return reject(new Error('HTTP ' + res.statusCode)); }
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (c) => { body += c; });
      res.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { reject(e); } });
    });
    req.on('timeout', () => req.destroy(new Error('timeout')));
    req.on('error', reject);
  });
}

// Os IDs dos comandos da extensão do Claude mudam entre versões: procuramos
// pelo nome, na ordem de preferência.
async function findCommand(patterns) {
  const all = await vscode.commands.getCommands(true);
  for (const p of patterns) {
    const hit = all.find((c) => p.test(c));
    if (hit) return hit;
  }
  return null;
}

function claudeInstalled() { return !!vscode.extensions.getExtension(CLAUDE_EXT); }

function hasFolder() {
  return !!(vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length);
}

function nonce() {
  let s = '';
  const c = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  for (let i = 0; i < 32; i++) s += c.charAt(Math.floor(Math.random() * c.length));
  return s;
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
}

// ---------------------------------------------------------------------------
// Claude
// ---------------------------------------------------------------------------
async function installExtension(id, label) {
  return vscode.window.withProgress({
    location: vscode.ProgressLocation.Notification,
    title: label,
  }, async () => {
    await vscode.commands.executeCommand('workbench.extensions.installExtension', id);
  });
}

async function ensureClaude({ interactive } = {}) {
  if (claudeInstalled()) return true;
  try {
    await installExtension(CLAUDE_EXT, 'Preparando o chat do Claude (só na primeira vez)...');
    return true;
  } catch (e) {
    const again = 'Tentar de novo';
    const pick = await vscode.window.showWarningMessage(
      'Não foi possível instalar o chat do Claude agora. Confira sua internet.',
      again);
    if (pick === again) return ensureClaude({ interactive });
    return false;
  }
}

async function openClaude() {
  if (!claudeInstalled()) {
    const ok = await ensureClaude({ interactive: true });
    if (!ok) return;
    // A extensão recém-instalada leva um instante para registrar os comandos.
    await new Promise((r) => setTimeout(r, 1500));
  }
  const cmd = await findCommand([
    /^claude-vscode\..*sidebar.*open/i,
    /^claude-vscode\..*open.*sidebar/i,
    /^claude-vscode\.sidebar/i,
    /^claude-vscode\..*focus/i,
    /^claude-vscode\..*editor.*open/i,
    /^claude-vscode\..*open/i,
  ]);
  if (cmd) {
    try { await vscode.commands.executeCommand(cmd); return; } catch (_) { /* tenta abaixo */ }
  }
  // Último recurso: mostra a barra da direita, onde o Claude fica.
  await vscode.commands.executeCommand('workbench.action.focusAuxiliaryBar');
}

// ---------------------------------------------------------------------------
// Português
// ---------------------------------------------------------------------------
function argvPath() {
  // ~/.upfly-code/argv.json (dataFolderName do product.json)
  let dataFolder = '.upfly-code';
  try {
    const product = JSON.parse(fs.readFileSync(path.join(vscode.env.appRoot, 'product.json'), 'utf8'));
    if (product.dataFolderName) dataFolder = product.dataFolderName;
  } catch (_) { /* usa o padrão */ }
  return path.join(os.homedir(), dataFolder, 'argv.json');
}

function setLocaleInArgv(locale) {
  const file = argvPath();
  let text = '';
  try { text = fs.readFileSync(file, 'utf8'); } catch (_) { text = '{\n}\n'; }
  if (/"locale"\s*:/.test(text)) {
    text = text.replace(/"locale"\s*:\s*"[^"]*"/, `"locale": "${locale}"`);
  } else {
    const i = text.lastIndexOf('}');
    const before = text.slice(0, i).replace(/\s*$/, '');
    const needsComma = /[}\]"\d\w]\s*$/.test(before) && !/{\s*$/.test(before);
    text = before + (needsComma ? ',' : '') + `\n\t"locale": "${locale}"\n` + text.slice(i);
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text);
}

async function ensurePortuguese() {
  if (vscode.env.language.toLowerCase().startsWith('pt')) return;
  if (ctx.globalState.get('upfly.ptbrAsked')) return;
  await ctx.globalState.update('upfly.ptbrAsked', true);
  try {
    if (!vscode.extensions.getExtension(PTBR_EXT)) {
      await installExtension(PTBR_EXT, 'Instalando o português...');
    }
    setLocaleInArgv('pt-br');
    vscode.window.showInformationMessage(
      'Pronto! Feche e abra o Upfly Code para ver tudo em português.');
  } catch (_) { /* sem internet: tenta de novo na próxima abertura */
    await ctx.globalState.update('upfly.ptbrAsked', false);
  }
}

// ---------------------------------------------------------------------------
// Layout parecido com o Trae: arquivos à esquerda, Claude à direita,
// terminal embaixo.
// ---------------------------------------------------------------------------
async function arrangeLayout() {
  if (!hasFolder()) return;
  try { await vscode.commands.executeCommand('workbench.view.explorer'); } catch (_) {}
  if (claudeInstalled()) {
    try { await openClaude(); } catch (_) {}
  }
  if (vscode.window.terminals.length === 0) {
    const t = vscode.window.createTerminal({ name: 'Terminal' });
    t.show(true);
  }
}

// ---------------------------------------------------------------------------
// Página inicial
// ---------------------------------------------------------------------------
async function recentFolders() {
  try {
    const r = await vscode.commands.executeCommand('_workbench.getRecentlyOpened');
    return (r && r.workspaces || [])
      .map((w) => w.folderUri || (w.workspace && w.workspace.configPath))
      .filter((u) => u && u.scheme === 'file')
      .slice(0, 6);
  } catch (_) { return []; }
}

async function showHome() {
  if (homePanel) { homePanel.reveal(vscode.ViewColumn.One); await renderHome(); return; }
  homePanel = vscode.window.createWebviewPanel('upfly.home', 'Início', vscode.ViewColumn.One, {
    enableScripts: true,
    localResourceRoots: [vscode.Uri.joinPath(ctx.extensionUri, 'media')],
  });
  homePanel.iconPath = vscode.Uri.joinPath(ctx.extensionUri, 'media', 'icon.png');
  homePanel.onDidDispose(() => { homePanel = undefined; });
  homePanel.webview.onDidReceiveMessage(async (m) => {
    switch (m && m.cmd) {
      case 'openFolder': return vscode.commands.executeCommand('upfly.openFolder');
      case 'openRecent': return vscode.commands.executeCommand('vscode.openFolder', vscode.Uri.parse(m.uri));
      case 'claude': return openClaude();
      case 'terminal': return vscode.commands.executeCommand('upfly.newTerminal');
      case 'shortcuts': return vscode.commands.executeCommand('upfly.shortcuts');
      case 'update': return pendingUpdate ? runUpdate(pendingUpdate) : checkForUpdates({ manual: true });
      case 'newFile': return vscode.commands.executeCommand('workbench.action.files.newUntitledFile');
    }
  });
  await renderHome();
}

async function renderHome() {
  if (!homePanel) return;
  const w = homePanel.webview;
  const n = nonce();
  const logo = w.asWebviewUri(vscode.Uri.joinPath(ctx.extensionUri, 'media', 'logo.png'));
  const recents = await recentFolders();
  const recentHtml = recents.length
    ? recents.map((u) => {
      const name = path.basename(u.fsPath) || u.fsPath;
      const dir = u.fsPath.replace(os.homedir(), '~');
      return `<button class="recent" data-uri="${esc(u.toString())}"><span class="rname">📁 ${esc(name)}</span><span class="rpath">${esc(dir)}</span></button>`;
    }).join('')
    : '<p class="muted">As pastas que você abrir vão aparecer aqui.</p>';
  const claudeState = claudeInstalled()
    ? '<span class="ok">● pronto</span>'
    : '<span class="warn">● será instalado ao clicar</span>';
  const upd = pendingUpdate
    ? `<button class="banner" data-cmd="update">⬆ Nova versão ${esc(pendingUpdate.version)} disponível. Clique para atualizar.</button>`
    : '';

  w.html = `<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${w.cspSource}; style-src 'unsafe-inline'; script-src 'nonce-${n}';">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { font-family: var(--vscode-font-family); color: #DCE6F5; background: #0C1222; margin: 0; }
  .wrap { max-width: 860px; margin: 0 auto; padding: 40px 32px 60px; }
  header { display: flex; align-items: center; gap: 18px; margin-bottom: 8px; }
  header img { height: 56px; }
  h1 { font-size: 28px; margin: 0; color: #fff; font-weight: 600; }
  .sub { color: #8FA3C4; font-size: 15px; margin: 4px 0 28px; }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 14px; }
  .card { text-align: left; background: #111829; border: 1px solid #26324F; border-radius: 12px; padding: 18px 18px 16px;
          color: #DCE6F5; cursor: pointer; font: inherit; transition: border-color .15s, background .15s; }
  .card:hover, .card:focus { border-color: #0080FF; background: #141E36; outline: none; }
  .card.primary { background: linear-gradient(135deg, #0066D6, #0080FF); border-color: #1A90FF; color: #fff; }
  .card.primary:hover { background: linear-gradient(135deg, #0A72E6, #1A90FF); }
  .ic { font-size: 26px; display: block; margin-bottom: 10px; }
  .t { font-size: 17px; font-weight: 600; display: block; }
  .d { font-size: 13px; opacity: .8; display: block; margin-top: 4px; line-height: 1.4; }
  .k { display: inline-block; margin-top: 10px; font-size: 12px; padding: 2px 8px; border-radius: 6px; background: #0A0F1C66; border: 1px solid #ffffff22; }
  h2 { font-size: 15px; color: #8FA3C4; font-weight: 600; margin: 34px 0 12px; text-transform: uppercase; letter-spacing: .06em; }
  .recents { display: flex; flex-direction: column; gap: 6px; }
  .recent { display: flex; justify-content: space-between; gap: 16px; background: transparent; border: 1px solid transparent; border-radius: 8px;
            padding: 10px 12px; color: #DCE6F5; cursor: pointer; font: inherit; text-align: left; }
  .recent:hover, .recent:focus { background: #141C30; border-color: #26324F; outline: none; }
  .rname { font-weight: 600; } .rpath { color: #6B7894; font-size: 13px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .muted { color: #6B7894; }
  .ok { color: #3DDC97; font-size: 12px; } .warn { color: #FFC857; font-size: 12px; }
  .banner { width: 100%; margin-bottom: 22px; padding: 14px 16px; border-radius: 10px; border: none; cursor: pointer; font: inherit;
            font-weight: 600; font-size: 15px; background: #FFC857; color: #0A0F1C; text-align: left; }
  .tips { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 8px 24px; font-size: 14px; color: #C9D6EA; }
  .tips kbd { background: #1B2540; border: 1px solid #2A3758; border-radius: 5px; padding: 1px 7px; font-family: inherit; font-size: 12px; color: #fff; }
  a.more { color: #4DB2FF; cursor: pointer; text-decoration: none; font-size: 14px; display: inline-block; margin-top: 12px; }
</style></head><body><div class="wrap">
  ${upd}
  <header><img src="${logo}" alt=""><div><h1>Olá! O que vamos fazer hoje?</h1></div></header>
  <p class="sub">Abra a pasta do seu projeto e converse com o Claude ao lado. Ele lê, cria e corrige arquivos para você.</p>
  <div class="grid">
    <button class="card primary" data-cmd="openFolder"><span class="ic">📂</span><span class="t">Abrir uma pasta</span>
      <span class="d">Escolha a pasta do projeto. Os arquivos aparecem à esquerda.</span><span class="k">${MOD}+O</span></button>
    <button class="card" data-cmd="claude"><span class="ic">✨</span><span class="t">Conversar com o Claude ${claudeState}</span>
      <span class="d">Peça o que precisa em português. Na primeira vez ele pede para entrar com sua conta Claude.</span><span class="k">${MOD}+Shift+A</span></button>
    <button class="card" data-cmd="terminal"><span class="ic">⌨️</span><span class="t">Abrir o terminal</span>
      <span class="d">Para quem quer digitar comandos. Fica embaixo da tela.</span><span class="k">Ctrl+'</span></button>
  </div>
  <h2>Pastas recentes</h2>
  <div class="recents">${recentHtml}</div>
  <h2>Atalhos que mais ajudam</h2>
  <div class="tips">
    <div><kbd>${MOD}+P</kbd> procurar um arquivo pelo nome</div>
    <div><kbd>${MOD}+Shift+A</kbd> abrir o chat do Claude</div>
    <div><kbd>F1</kbd> procurar qualquer comando</div>
    <div><kbd>${MOD}+S</kbd> salvar (já salva sozinho)</div>
    <div><kbd>${MOD}+Shift+F</kbd> procurar texto em tudo</div>
    <div><kbd>${MOD}+B</kbd> mostrar ou esconder os arquivos</div>
  </div>
  <a class="more" data-cmd="shortcuts">Ver todos os atalhos →</a>
</div>
<script nonce="${n}">
  const vscode = acquireVsCodeApi();
  document.querySelectorAll('[data-cmd]').forEach((el) => el.addEventListener('click', () => vscode.postMessage({ cmd: el.dataset.cmd })));
  document.querySelectorAll('.recent').forEach((el) => el.addEventListener('click', () => vscode.postMessage({ cmd: 'openRecent', uri: el.dataset.uri })));
</script></body></html>`;
}

// ---------------------------------------------------------------------------
// Atalhos
// ---------------------------------------------------------------------------
function showShortcuts() {
  const panel = vscode.window.createWebviewPanel('upfly.shortcuts', 'Atalhos', vscode.ViewColumn.Active, {});
  const rows = [
    ['Arquivos', [
      [`${MOD}+O`, 'Abrir uma pasta'],
      [`${MOD}+P`, 'Procurar um arquivo pelo nome'],
      [`${MOD}+N`, 'Novo arquivo'],
      [`${MOD}+S`, 'Salvar (o Upfly Code também salva sozinho)'],
      [`${MOD}+B`, 'Mostrar ou esconder a lista de arquivos'],
      [`${MOD}+Shift+F`, 'Procurar um texto em todos os arquivos'],
      [`${MOD}+W`, 'Fechar a aba atual'],
    ]],
    ['Claude', [
      [`${MOD}+Shift+A`, 'Abrir o chat do Claude'],
      [`${MOD}+Esc`, 'Alternar entre o arquivo e o chat'],
      [`${isMac ? 'Option' : 'Alt'}+K`, 'Mandar o trecho selecionado para o Claude'],
      [`${MOD}+Shift+Esc`, 'Nova conversa em uma aba'],
    ]],
    ['Terminal', [
      ['Ctrl+\'', 'Mostrar ou esconder o terminal'],
      ['Ctrl+Shift+\'', 'Novo terminal'],
      [`${MOD}+C / ${MOD}+V`, 'Copiar e colar (no terminal, com texto selecionado)'],
    ]],
    ['Geral', [
      ['F1', 'Procurar qualquer comando ou configuração'],
      [`${MOD}+Z`, 'Desfazer'],
      [`${MOD}+=` + ' / ' + `${MOD}+-`, 'Aumentar ou diminuir o tamanho de tudo'],
    ]],
  ];
  const body = rows.map(([title, list]) => `<h2>${esc(title)}</h2><table>${
    list.map(([k, d]) => `<tr><td><kbd>${esc(k)}</kbd></td><td>${esc(d)}</td></tr>`).join('')}</table>`).join('');
  panel.webview.html = `<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline';">
<style>
  body { font-family: var(--vscode-font-family); background: #0C1222; color: #DCE6F5; padding: 28px 36px; max-width: 760px; }
  h1 { color: #fff; font-size: 24px; font-weight: 600; } h2 { color: #00D4FF; font-size: 15px; margin-top: 26px; }
  table { border-collapse: collapse; width: 100%; } td { padding: 7px 10px; border-bottom: 1px solid #1B2540; font-size: 14px; }
  td:first-child { width: 210px; }
  kbd { background: #1B2540; border: 1px solid #2A3758; border-radius: 5px; padding: 2px 8px; font-family: inherit; color: #fff; font-size: 13px; }
</style></head><body><h1>Atalhos do Upfly Code</h1>
<p>Não precisa decorar: aperte <kbd>F1</kbd> e escreva o que quer fazer, em português.</p>${body}</body></html>`;
}

// ---------------------------------------------------------------------------
// Painel "O que você quer fazer?" (ícone da Upfly na barra da esquerda)
// ---------------------------------------------------------------------------
class ActionsProvider {
  constructor() { this._ev = new vscode.EventEmitter(); this.onDidChangeTreeData = this._ev.event; }
  refresh() { this._ev.fire(); }
  getTreeItem(i) { return i; }
  getChildren() {
    const item = (label, cmd, icon, desc) => {
      const t = new vscode.TreeItem(label);
      t.command = { command: cmd, title: label };
      t.iconPath = new vscode.ThemeIcon(icon);
      if (desc) t.description = desc;
      return t;
    };
    const list = [
      item('Página inicial', 'upfly.home', 'home'),
      item('Abrir uma pasta', 'upfly.openFolder', 'folder-opened', `${MOD}+O`),
      item('Procurar arquivo pelo nome', 'upfly.findFile', 'search', `${MOD}+P`),
      item('Conversar com o Claude', 'upfly.openClaude', 'sparkle', `${MOD}+Shift+A`),
      item('Abrir terminal', 'upfly.newTerminal', 'terminal', 'Ctrl+\''),
      item('Ver atalhos', 'upfly.shortcuts', 'keyboard'),
    ];
    list.push(pendingUpdate
      ? item(`Atualizar para a versão ${pendingUpdate.version}`, 'upfly.checkUpdate', 'cloud-download', 'nova!')
      : item('Procurar atualização', 'upfly.checkUpdate', 'cloud-download', `versão ${currentVersion()}`));
    return list;
  }
}
let actions;

// ---------------------------------------------------------------------------
// Atualizações
// ---------------------------------------------------------------------------
function assetSuffix() {
  if (process.platform === 'win32') return '-windows.zip';
  if (process.platform === 'darwin') return process.arch === 'x64' ? '-macos-intel.zip' : '-macos.zip';
  return process.arch === 'arm64' ? '-linux-arm64.tar.gz' : '-linux.tar.gz';
}

async function fetchLatest() {
  const repo = pkg.upfly && pkg.upfly.updateRepo;
  if (!repo) return null;
  // UPFLY_UPDATE_API só é usado nos testes automáticos.
  const api = process.env.UPFLY_UPDATE_API || 'https://api.github.com';
  const data = await getJson(`${api}/repos/${repo}/releases/latest`);
  if (!data || !data.tag_name) return null;
  const suffix = assetSuffix();
  const asset = (data.assets || []).find((a) => a.name === 'UpflyCode' + suffix)
    || (data.assets || []).find((a) => a.name.endsWith(suffix));
  return {
    version: data.tag_name.replace(/^v/, ''),
    notesUrl: data.html_url,
    url: asset && asset.browser_download_url,
  };
}

function setUpdateBadge() {
  if (pendingUpdate) {
    statusUpdate.text = `$(cloud-download) Atualizar para ${pendingUpdate.version}`;
    statusUpdate.tooltip = 'Há uma versão nova do Upfly Code. Clique para atualizar.';
    statusUpdate.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
    statusUpdate.show();
  } else {
    statusUpdate.hide();
  }
  if (actions) actions.refresh();
  if (homePanel) renderHome();
}

async function checkForUpdates({ manual } = {}) {
  lastUpdateCheck = Date.now();
  let info;
  try { info = await fetchLatest(); } catch (e) {
    if (manual) vscode.window.showWarningMessage('Não foi possível procurar atualizações agora. Confira sua internet.');
    return;
  }
  if (info && info.url && isNewer(info.version, currentVersion())) {
    pendingUpdate = info;
    setUpdateBadge();
    const alreadyAsked = ctx.globalState.get('upfly.updateAsked') === info.version;
    if (manual || !alreadyAsked) {
      await ctx.globalState.update('upfly.updateAsked', info.version);
      askToUpdate(info);
    }
  } else {
    pendingUpdate = null;
    setUpdateBadge();
    if (manual) vscode.window.showInformationMessage(`Você já está na versão mais recente (${currentVersion()}).`);
  }
}

async function askToUpdate(info) {
  const now = { title: 'Atualizar agora' };
  const notes = { title: 'O que mudou' };
  const later = { title: 'Depois', isCloseAffordance: true };
  // Janela no meio da tela: ninguém deixa passar. "Depois" deixa o aviso
  // amarelo na barra de baixo, para atualizar quando quiser.
  const pick = await vscode.window.showInformationMessage(
    `Há uma versão nova do Upfly Code: ${info.version}`,
    {
      modal: true,
      detail: `Você está usando a versão ${currentVersion()}. A atualização leva menos de um minuto: `
        + 'o Upfly Code fecha, se atualiza e abre de novo sozinho. Seus arquivos e conversas continuam onde estão.',
    },
    now, notes, later);
  if (pick === now) runUpdate(info);
  else if (pick === notes) vscode.env.openExternal(vscode.Uri.parse(info.notesUrl));
  // "Depois": o aviso amarelo continua na barra de baixo.
}

function runUpdate(info) {
  const bin = path.join(ctx.extensionPath, 'bin');
  const appRoot = vscode.env.appRoot; // .../resources/app
  let shellPath, shellArgs;
  if (process.platform === 'win32') {
    shellPath = 'powershell.exe';
    shellArgs = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(bin, 'self-update.ps1'),
      '-Url', info.url, '-Version', info.version, '-AppRoot', appRoot];
  } else {
    shellPath = '/bin/bash';
    shellArgs = [path.join(bin, 'self-update.sh'), info.url, info.version, appRoot];
  }
  const term = vscode.window.createTerminal({ name: 'Atualização do Upfly Code', shellPath, shellArgs });
  term.show();
  const sub = vscode.window.onDidCloseTerminal(async (t) => {
    if (t !== term) return;
    sub.dispose();
    if (t.exitStatus && t.exitStatus.code === 0) {
      // O script deixou a troca preparada: ela acontece quando o app fecha,
      // e o app abre sozinho de novo.
      await vscode.commands.executeCommand('workbench.action.quit');
    }
  });
}

function scheduleUpdates() {
  setTimeout(() => checkForUpdates().catch(() => {}), Number(process.env.UPFLY_UPDATE_DELAY_MS) || 8000);
  const timer = setInterval(() => checkForUpdates().catch(() => {}), UPDATE_EVERY_MS);
  ctx.subscriptions.push({ dispose: () => clearInterval(timer) });
  // Voltou para a janela depois de muito tempo? Confere de novo.
  ctx.subscriptions.push(vscode.window.onDidChangeWindowState((s) => {
    if (s.focused && Date.now() - lastUpdateCheck > UPDATE_EVERY_MS) checkForUpdates().catch(() => {});
  }));
}

// ---------------------------------------------------------------------------
async function activate(context) {
  ctx = context;
  pkg = context.extension.packageJSON;

  const reg = (id, fn) => context.subscriptions.push(vscode.commands.registerCommand(id, fn));
  reg('upfly.home', showHome);
  reg('upfly.openFolder', () => vscode.commands.executeCommand('workbench.action.files.openFolder'));
  reg('upfly.findFile', () => vscode.commands.executeCommand('workbench.action.quickOpen'));
  reg('upfly.openClaude', openClaude);
  reg('upfly.setupClaude', () => ensureClaude({ interactive: true }));
  reg('upfly.newTerminal', () => { const t = vscode.window.createTerminal({ name: 'Terminal' }); t.show(); });
  reg('upfly.shortcuts', showShortcuts);
  reg('upfly.checkUpdate', () => (pendingUpdate ? runUpdate(pendingUpdate) : checkForUpdates({ manual: true })));

  actions = new ActionsProvider();
  context.subscriptions.push(vscode.window.registerTreeDataProvider('upfly.actions', actions));

  const claudeBtn = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 1000);
  claudeBtn.text = '$(sparkle) Claude';
  claudeBtn.tooltip = `Conversar com o Claude (${MOD}+Shift+A)`;
  claudeBtn.command = 'upfly.openClaude';
  claudeBtn.show();
  const homeBtn = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 1001);
  homeBtn.text = '$(home) Início';
  homeBtn.tooltip = 'Página inicial do Upfly Code';
  homeBtn.command = 'upfly.home';
  homeBtn.show();
  statusUpdate = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 1000);
  statusUpdate.command = 'upfly.checkUpdate';
  context.subscriptions.push(claudeBtn, homeBtn, statusUpdate);

  if (!hasFolder()) await showHome();

  // Primeiro uso: português e chat do Claude, sem a pessoa precisar procurar.
  ensurePortuguese().catch(() => {});
  arrangeLayout().catch(() => {});
  if (!claudeInstalled()) {
    ensureClaude().then((ok) => { if (ok && hasFolder()) openClaude(); }).catch(() => {});
  }
  context.subscriptions.push(vscode.extensions.onDidChange(() => { if (homePanel) renderHome(); }));

  scheduleUpdates();
}

function deactivate() {}

module.exports = { activate, deactivate, _test: { isNewer, setLocaleInArgv } };
