import fs from 'fs';
import path from 'path';

const root = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const pages = ['index.html', 'stage.html', 'ship.html', 'reports.html', 'contacts.html', 'notifications.html'];

const jsFiles = fs.readdirSync(root).filter(f => f.endsWith('.js'));
const jsContent = jsFiles.map(f => fs.readFileSync(path.join(root, f), 'utf8')).join('\n');
const defined = new Set([...jsContent.matchAll(/window\.(\w+)\s*=\s*(?:async\s+)?function/g)].map(m => m[1]));

const handlerRe = /window\.(\w+)\s*\(/g;
const inlineRe = /on(?:click|input|change|submit)\s*=\s*["']([^"']+)["']/gi;

let issues = 0;

for (const page of pages) {
  const html = fs.readFileSync(path.join(root, page), 'utf8');
  const scripts = [...html.matchAll(/<script src="([^"]+\.js)/g)].map(m => m[1].split('?')[0]);
  const handlers = new Set();
  for (const m of html.matchAll(handlerRe)) handlers.add(m[1]);
  for (const m of html.matchAll(inlineRe)) {
    for (const wm of m[1].matchAll(/window\.(\w+)/g)) handlers.add(wm[1]);
  }

  const pageJs = scripts.map(s => {
    const p = path.join(root, s);
    return fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : '';
  }).join('\n');
  const pageDefined = new Set([...pageJs.matchAll(/window\.(\w+)\s*=\s*(?:async\s+)?function/g)].map(m => m[1]));

  const missing = [...handlers].filter(h => !pageDefined.has(h) && !defined.has(h)).sort();
  console.log(`\n=== ${page} (${scripts.length} scripts, ${handlers.size} handlers) ===`);
  if (missing.length) {
    issues += missing.length;
    console.log('MISSING:', missing.join(', '));
  } else {
    console.log('OK — all inline handlers resolve to a loaded script');
  }
}

console.log(`\n${issues ? `Found ${issues} unresolved handler(s)` : 'All pages passed handler audit'}`);
process.exit(issues ? 1 : 0);
