const rawContactsData = [];

window.normalizePersonKey = function(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/@.*$/, '')
    .replace(/[._\-]+/g, ' ')
    .replace(/[^a-z0-9\s]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
};

window.findContactByPmName = function(pmName) {
  if (!pmName || typeof rawContactsData === 'undefined' || !Array.isArray(rawContactsData)) return null;
  const key = window.normalizePersonKey(pmName);
  if (!key) return null;
  const words = key.split(' ').filter(Boolean);
  let best = null;
  let bestScore = 0;
  for (const c of rawContactsData) {
    if (!c || !c.email || String(c.email).toLowerCase() === 'n/a') continue;
    const nameKey = window.normalizePersonKey(c.name);
    const emailLocal = window.normalizePersonKey(String(c.email).split('@')[0]);
    let score = 0;
    if (nameKey === key || emailLocal === key) score = 100;
    else if (words.length >= 2 && words.every(w => nameKey.includes(w))) score = 85;
    else if (nameKey && (nameKey.includes(key) || key.includes(nameKey))) score = 55;
    else continue;
    if (/project\s*manager/i.test(c.designation || '')) score += 10;
    if (score > bestScore) { bestScore = score; best = c; }
  }
  return bestScore >= 55 ? best : null;
};
