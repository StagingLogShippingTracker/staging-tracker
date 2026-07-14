/**
 * map-p21-ui.mjs — headless login + network capture for Prophet21 web UI.
 * Usage: node map-p21-ui.mjs [optionalSO]
 * Reads credentials from .env in this folder. Headed mode if P21_HEADED=1.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadEnv(file) {
  const map = {};
  if (!fs.existsSync(file)) return map;
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    if (!line || line.trim().startsWith('#') || !line.includes('=')) continue;
    const i = line.indexOf('=');
    map[line.slice(0, i).trim()] = line.slice(i + 1).trim().replace(/^["']|["']$/g, '');
  }
  return map;
}

const env = loadEnv(path.join(__dirname, '.env'));
const user = env.P21_USERNAME;
const pass = env.P21_PASSWORD;
const so = String(process.argv[2] || env.P21_TEST_SO || '').trim();
const uiUrl = (env.P21_WEB_URL || 'https://swiftsupply.epicordistribution.com/Prophet21/#/').replace(/\/?$/, '/');
const headed = process.env.P21_HEADED === '1' || env.P21_HEADED === '1';

if (!user || !pass) {
  console.error('Missing P21_USERNAME / P21_PASSWORD in .env');
  process.exit(1);
}

const interesting = [];
function note(kind, url, status, preview) {
  const u = String(url);
  if (!/api|odata|sales|order|entity|transaction|interactive|uiserver|token|session|view/i.test(u)) return;
  interesting.push({ kind, status, url: u.slice(0, 300), preview: String(preview || '').slice(0, 240) });
}

const browser = await chromium.launch({ headless: !headed });
const context = await browser.newContext({
  viewport: { width: 1400, height: 900 },
  ignoreHTTPSErrors: true
});
const page = await context.newPage();

page.on('response', async (res) => {
  try {
    const url = res.url();
    const ct = res.headers()['content-type'] || '';
    let preview = '';
    if (/json|xml|text/i.test(ct) && res.status() < 500) {
      preview = (await res.text().catch(() => '')).slice(0, 240);
    }
    note('resp', url, res.status(), preview);
  } catch {
    /* ignore */
  }
});

console.log('OPEN', uiUrl);
await page.goto(uiUrl, { waitUntil: 'domcontentloaded', timeout: 90_000 });
await page.waitForTimeout(2500);

const shotDir = path.join(__dirname, '_ui-map');
fs.mkdirSync(shotDir, { recursive: true });
await page.screenshot({ path: path.join(shotDir, '01-before-login.png'), fullPage: true });

// Try common login field patterns
const userSel = [
  'input[name="username"]',
  'input[name="Username"]',
  'input[id*="user" i]',
  'input[placeholder*="user" i]',
  'input[type="email"]',
  'input[type="text"]'
];
const passSel = [
  'input[name="password"]',
  'input[name="Password"]',
  'input[type="password"]'
];

async function firstVisible(sels) {
  for (const s of sels) {
    const loc = page.locator(s).first();
    if (await loc.count() && (await loc.isVisible().catch(() => false))) return loc;
  }
  return null;
}

let userBox = await firstVisible(userSel);
let passBox = await firstVisible(passSel);

// Frames?
if (!userBox || !passBox) {
  for (const frame of page.frames()) {
    if (frame === page.mainFrame()) continue;
    for (const s of userSel) {
      const loc = frame.locator(s).first();
      if (await loc.count() && (await loc.isVisible().catch(() => false))) {
        userBox = loc;
        break;
      }
    }
    for (const s of passSel) {
      const loc = frame.locator(s).first();
      if (await loc.count() && (await loc.isVisible().catch(() => false))) {
        passBox = loc;
        break;
      }
    }
  }
}

const htmlDump = await page.content();
fs.writeFileSync(path.join(shotDir, '01-before-login.html'), htmlDump);
console.log('TITLE', await page.title());
console.log('URL', page.url());
console.log('HAS_USER', Boolean(userBox), 'HAS_PASS', Boolean(passBox));

if (userBox && passBox) {
  await userBox.fill(user);
  await passBox.fill(pass);
  const submit = page.locator('button[type="submit"], input[type="submit"], button:has-text("Log"), button:has-text("Sign"), button:has-text("Login")').first();
  if (await submit.count()) await submit.click();
  else await passBox.press('Enter');
  await page.waitForTimeout(5000);
  await page.screenshot({ path: path.join(shotDir, '02-after-login.png'), fullPage: true });
  fs.writeFileSync(path.join(shotDir, '02-after-login.html'), await page.content());
  console.log('AFTER_LOGIN_URL', page.url());
  console.log('AFTER_LOGIN_TITLE', await page.title());
} else {
  console.log('LOGIN_FIELDS_NOT_FOUND — dumping inputs');
  const inputs = await page.locator('input').evaluateAll((els) =>
    els.map((e) => ({ type: e.type, name: e.name, id: e.id, placeholder: e.placeholder, visible: !!(e.offsetParent || e.getClientRects().length) }))
  );
  console.log(JSON.stringify(inputs, null, 2));
}

if (so) {
  console.log('TRY_SO', so);
  // Type SO into any search/order field if present
  const search = page.locator('input[placeholder*="order" i], input[placeholder*="search" i], input[name*="order" i]').first();
  if (await search.count()) {
    await search.fill(so);
    await search.press('Enter');
    await page.waitForTimeout(4000);
    await page.screenshot({ path: path.join(shotDir, '03-after-so.png'), fullPage: true });
  }
}

const local = await page.evaluate(() => {
  const out = { localStorage: {}, sessionStorage: {} };
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      out.localStorage[k] = String(localStorage.getItem(k) || '').slice(0, 200);
    }
  } catch { /* */ }
  try {
    for (let i = 0; i < sessionStorage.length; i++) {
      const k = sessionStorage.key(i);
      out.sessionStorage[k] = String(sessionStorage.getItem(k) || '').slice(0, 200);
    }
  } catch { /* */ }
  return out;
});
fs.writeFileSync(path.join(shotDir, 'storage.json'), JSON.stringify(local, null, 2));
fs.writeFileSync(path.join(shotDir, 'network.json'), JSON.stringify(interesting, null, 2));
console.log('CAPTURED_NET', interesting.length);
interesting.slice(0, 40).forEach((x) => console.log(`${x.status} ${x.url}`));

await browser.close();
console.log('DONE →', shotDir);
