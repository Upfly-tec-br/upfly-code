// Upfly Code - cria o índice de idiomas (languagepacks.json) logo na
// instalação, para o app abrir em português já na primeira vez.
// (Sem isso o editor só monta o índice depois de abrir uma vez em inglês.)
//
// Rodar com o Node embutido no app:
//   ELECTRON_RUN_AS_NODE=1 <app> languagepacks.js <pasta-extensões> <pasta-dados-do-usuário>
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const [extDir, userDataDir] = process.argv.slice(2);
if (!extDir || !userDataDir) { console.error('uso: languagepacks.js <extensões> <dados>'); process.exit(2); }

const out = path.join(userDataDir, 'languagepacks.json');
let index = {};
try { index = JSON.parse(fs.readFileSync(out, 'utf8')); } catch (_) { index = {}; }

let dirs = [];
try { dirs = fs.readdirSync(extDir); } catch (_) { process.exit(0); }

// Fica com a versão mais nova de cada pacote.
const best = new Map();
for (const d of dirs) {
  const pj = path.join(extDir, d, 'package.json');
  let pkg;
  try { pkg = JSON.parse(fs.readFileSync(pj, 'utf8')); } catch (_) { continue; }
  const locs = pkg.contributes && pkg.contributes.localizations;
  if (!Array.isArray(locs) || !locs.length) continue;
  const id = `${pkg.publisher}.${pkg.name}`.toLowerCase();
  const prev = best.get(id);
  const newer = (a, b) => {
    const pa = a.split('.').map(Number), pb = b.split('.').map(Number);
    for (let i = 0; i < 3; i++) if ((pa[i] || 0) !== (pb[i] || 0)) return (pa[i] || 0) > (pb[i] || 0);
    return false;
  };
  if (!prev || newer(pkg.version, prev.pkg.version)) best.set(id, { dir: path.join(extDir, d), pkg, id });
}

for (const { dir, pkg, id } of best.values()) {
  for (const loc of pkg.contributes.localizations) {
    const lang = String(loc.languageId).toLowerCase();
    const translations = {};
    for (const t of loc.translations || []) translations[t.id] = path.join(dir, t.path);
    index[lang] = {
      hash: crypto.createHash('md5').update(id + pkg.version).digest('hex'),
      extensions: [{ extensionIdentifier: { id }, version: pkg.version }],
      translations,
      label: loc.localizedLanguageName || loc.languageName || lang,
    };
  }
}

fs.mkdirSync(userDataDir, { recursive: true });
fs.writeFileSync(out, JSON.stringify(index));
console.log('Idiomas prontos:', Object.keys(index).join(', ') || 'nenhum');
