// --- p21.js — Prophet21 insights (cache-first + on-demand publish from Swift proxy) ---

window.P21_PROXY_BASE = window.P21_PROXY_BASE || 'http://127.0.0.1:8787';
window.P21_FUNCTION_NAME = window.P21_FUNCTION_NAME || 'p21-order-insights';
window.P21_PUBLISH_FUNCTION_NAME = window.P21_PUBLISH_FUNCTION_NAME || 'p21-publish';
window.P21_WEB_URL = window.P21_WEB_URL || 'https://swiftsupply.epicordistribution.com/Prophet21/#/';
window._p21WarmSet = window._p21WarmSet || new Set();
window._p21PublishSet = window._p21PublishSet || new Set();

window.normalizeP21So = function(raw) {
  return String(raw || '').trim().replace(/^SO[#:\s-]*/i, '');
};

window.buildP21OpenUrl = function(so) {
  const base = (window.P21_WEB_URL || 'https://swiftsupply.epicordistribution.com/Prophet21/#/').replace(/\/?$/, '/');
  const soKey = window.normalizeP21So(so);
  // SPA root; SO is shown in Order History for copy/search in P21
  return soKey ? base : base;
};

function p21SupabaseConfig() {
  if (typeof SUPABASE_URL === 'undefined' || typeof SUPABASE_ANON_KEY === 'undefined') return null;
  return { url: SUPABASE_URL, key: SUPABASE_ANON_KEY };
}

function p21FunctionUrl(name) {
  const cfg = p21SupabaseConfig();
  if (!cfg) return null;
  const fn = (name || window.P21_FUNCTION_NAME || 'p21-order-insights').replace(/^\/+/, '');
  return `${cfg.url}/functions/v1/${fn}`;
}

async function fetchP21FromCacheTable(so, allowStale) {
  if (typeof supabaseClient === 'undefined') return null;
  const soKey = window.normalizeP21So(so);
  if (!soKey) return null;

  const { data, error } = await supabaseClient
    .from('p21_order_cache')
    .select('payload, fetched_at, expires_at, source')
    .eq('so_key', soKey)
    .maybeSingle();

  if (error || !data?.payload) return null;

  const expired = new Date(data.expires_at).getTime() < Date.now();
  if (expired && !allowStale) return null;

  return {
    ok: true,
    data: {
      ...data.payload,
      cached: true,
      stale: expired,
      fetchedAt: data.fetched_at,
      source: data.source || data.payload.source
    },
    via: expired ? 'db-stale' : 'db-cache'
  };
}

async function fetchP21FromEdgeFunction(so, refresh) {
  const url = p21FunctionUrl(window.P21_FUNCTION_NAME);
  const cfg = p21SupabaseConfig();
  if (!url || !cfg) return null;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      apikey: cfg.key,
      Authorization: `Bearer ${cfg.key}`
    },
    body: JSON.stringify({ so, refresh: Boolean(refresh) })
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    return {
      ok: false,
      offline: response.status >= 502,
      authError: response.status === 401,
      message: data.message || `Prophet21 service unavailable (${response.status}).`
    };
  }
  return { ok: true, data, via: data.cached ? 'edge-cache' : 'edge-live' };
}

async function fetchP21FromLocalProxy(so) {
  const base = (window.P21_PROXY_BASE || '').replace(/\/+$/, '');
  const target = `${base}/api/order/${encodeURIComponent(String(so || '').trim())}`;
  try {
    const response = await fetch(target, { headers: { Accept: 'application/json' } });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      return {
        ok: false,
        offline: response.status === 502 || response.status === 503,
        authError: response.status === 401,
        message: data.message || `Local P21 proxy failed (${response.status}).`
      };
    }
    return { ok: true, data, via: 'local-proxy' };
  } catch (e) {
    return { ok: false, offline: true, message: 'Local P21 proxy unreachable.' };
  }
}

/** Publish a proxy/live payload into Supabase so all users can read it. */
window.publishP21OrderInsights = function(so, payload) {
  const soKey = window.normalizeP21So(so);
  if (!soKey || !payload || typeof payload.found !== 'boolean') return;
  if (window._p21PublishSet.has(soKey)) return;

  const url = p21FunctionUrl(window.P21_PUBLISH_FUNCTION_NAME);
  const cfg = p21SupabaseConfig();
  if (!url || !cfg) return;

  window._p21PublishSet.add(soKey);
  fetch(url, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      apikey: cfg.key,
      Authorization: `Bearer ${cfg.key}`
    },
    body: JSON.stringify({ so: soKey, payload })
  })
    .then((res) => {
      if (!res.ok) window._p21PublishSet.delete(soKey);
    })
    .catch(() => window._p21PublishSet.delete(soKey));
};

window.fetchP21OrderInsights = async function(so, options) {
  const refresh = Boolean(options?.refresh);
  const soKey = window.normalizeP21So(so);
  if (!soKey) return { ok: false, message: 'SO number is required.', so: soKey };

  if (!refresh) {
    const cached = await fetchP21FromCacheTable(so, true);
    if (cached?.ok && !cached.data.stale) {
      return { ...cached, so: soKey };
    }
  }

  // On Swift WiFi with local proxy: fetch live, then publish for all users
  const local = await fetchP21FromLocalProxy(so);
  if (local?.ok && local.data) {
    if (local.data.found) {
      window.publishP21OrderInsights(soKey, local.data);
    }
    return { ...local, so: soKey };
  }

  const edge = await fetchP21FromEdgeFunction(so, refresh).catch(() => null);
  if (edge?.ok) return { ...edge, so: soKey };

  const stale = await fetchP21FromCacheTable(so, true);
  if (stale?.ok) return { ...stale, so: soKey };

  return edge || local || {
    ok: false,
    offline: true,
    so: soKey,
    message: 'Prophet21 insights are not cached yet. Enter/submit this SO to pull Order Entry fields, or wait for cache sync.'
  };
};

window.warmP21CacheForOrders = function(soList) {
  if (!Array.isArray(soList) || !soList.length) return;
  const url = p21FunctionUrl(window.P21_FUNCTION_NAME);
  const cfg = p21SupabaseConfig();
  if (!url || !cfg) return;

  const unique = [...new Set(soList.map(window.normalizeP21So).filter(Boolean))];
  unique.forEach(soKey => {
    if (window._p21WarmSet.has(soKey)) return;
    window._p21WarmSet.add(soKey);
    fetch(url, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        apikey: cfg.key,
        Authorization: `Bearer ${cfg.key}`
      },
      body: JSON.stringify({ so: soKey, refresh: false })
    }).catch(() => window._p21WarmSet.delete(soKey));
  });
};

window.formatP21Value = function(value) {
  if (value == null || value === '') return '—';
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(value)) {
    const d = new Date(value);
    if (!Number.isNaN(d.getTime())) return d.toLocaleString();
  }
  return String(value);
};

window.formatP21OpenLink = function(so) {
  const soKey = window.normalizeP21So(so);
  const href = window.buildP21OpenUrl(soKey);
  const label = soKey ? `Open SO ${soKey} in Prophet21` : 'Open Prophet21';
  return `<p class="p21-open-link" style="margin:8px 0 12px 0;">
    <a href="${href}" target="_blank" rel="noopener noreferrer" class="btn btn-toolbar" style="display:inline-flex; text-decoration:none;">${label}</a>
    <span style="display:block; font-size:11px; color:#9ca3af; margin-top:4px;">Requires Swift WiFi/VPN. Search or paste the SO in P21 if the app opens to the home screen.</span>
  </p>`;
};

window.formatP21Date = function(value) {
  if (value == null || value === '') return '—';
  const s = String(value);
  const d = new Date(s.includes('T') ? s : s.replace(' ', 'T'));
  if (!Number.isNaN(d.getTime())) {
    return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
  }
  return s;
};

window.formatP21OrderInsightsSection = function(result) {
  const so = result?.so || result?.data?.so || '';

  if (!result || !result.ok) {
    const hint = result?.offline
      ? 'No Prophet21 data for this SO yet. Submitting a staging/shipping entry with this SO will pull Order Entry fields automatically.'
      : (result?.authError
        ? 'P21 authentication failed. Check Edge Function P21 credentials.'
        : (result?.message || 'Prophet21 data unavailable.'));
    return `<p class="p21-status p21-status--warn" style="font-size:12px; color:#6b7280; margin:0 0 8px 0;">${hint}</p>`;
  }

  const payload = result.data;
  if (!payload.found) {
    return `<p class="p21-status" style="font-size:12px; color:#6b7280; margin:0 0 8px 0;">${payload.message || 'No matching Prophet21 order.'}</p>`;
  }

  const h = payload.header || {};
  const s = payload.summary || {};
  // PM comes from Order Entry "Taker" (or PO buyer when matchedBy=purchase_po)
  const pm = h.taker || s.taker || h.pm || s.pm || '';
  const isPurchasePo = payload.matchedBy === 'purchase_po' || h.purchasePo || s.purchasePo;
  const orderLabel = isPurchasePo ? 'PO' : 'Order Number';
  const poLabel = isPurchasePo ? 'PO detail' : 'PO';
  let html = `<div class="p21-insights-card">`;
  html += `<dl class="p21-insights-grid">`;
  html += `<div><dt>${orderLabel}</dt><dd>${window.formatP21Value(isPurchasePo ? (h.poNo || s.poNo || h.orderNo || so) : (h.orderNo || so))}</dd></div>`;
  html += `<div><dt>Customer</dt><dd>${window.formatP21Value(h.customerName || s.customer)}</dd></div>`;
  if (!isPurchasePo) {
    html += `<div><dt>${poLabel}</dt><dd>${window.formatP21Value(h.poNo || s.poNo)}</dd></div>`;
    html += `<div><dt>Project</dt><dd>${window.formatP21Value(h.projectId || s.projectId)}</dd></div>`;
    html += `<div><dt>Required Date</dt><dd>${window.formatP21Date(h.requiredDate || s.requiredDate)}</dd></div>`;
  } else if (h.linkedSo || s.linkedSo) {
    html += `<div><dt>Linked SO</dt><dd>${window.formatP21Value(h.linkedSo || s.linkedSo)}</dd></div>`;
  }
  html += `<div><dt>PM</dt><dd>${window.formatP21Value(pm)}</dd></div>`;
  html += `</dl>`;

  const staleNote = payload.stale ? ' (updating…)' : '';
  const viaLabel = result.via === 'local-proxy'
    ? 'local connector'
    : (payload.matchedBy === 'purchase_po'
      ? 'Purchase Order'
      : (payload.source === 'interactive'
        ? 'Order Entry'
        : (payload.cached || result.via?.includes('cache') || result.via?.includes('stale') ? 'synced copy' : window.formatP21Value(payload.matchedBy || payload.source))));
  const fetched = payload.fetchedAt ? ` · ${window.formatP21Value(payload.fetchedAt)}` : '';
  html += `<p class="p21-footnote">Prophet21 via <b>${viaLabel}</b>${staleNote}${fetched}.</p>`;
  html += `</div>`;
  return html;
};

/** Fire-and-forget: pull Order Entry into cache after a site entry is saved. */
window.warmP21AfterSubmit = function(so) {
  const soKey = window.normalizeP21So(so);
  if (!soKey || typeof window.fetchP21OrderInsights !== 'function') return;
  window.fetchP21OrderInsights(soKey, { refresh: true }).catch(() => {});
};

/** Normalize P21 taker / contact names for fuzzy match (CHRIS.ACORN ↔ Chris Acorn). */
window.normalizePersonKey = function(s) {
  return String(s || '')
    .toLowerCase()
    .replace(/@.*$/, '')
    .replace(/[._\-]+/g, ' ')
    .replace(/[^a-z0-9\s]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
};

window.extractP21TakerName = function(payload) {
  const h = payload?.header || {};
  const s = payload?.summary || {};
  return String(h.taker || s.taker || h.pm || s.pm || h.takerName || s.takerName || '').trim();
};

/**
 * Match Prophet21 Taker/PM to an employee in rawContactsData (employees.js / contacts).
 * Returns the contact object or null.
 */
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
    if (score > bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return bestScore >= 55 ? best : null;
};

/**
 * Prefill a PM email (or SMS roster select) from Prophet21 taker for an SO.
 * Options: { emailId, chkId, btnId, selectId, autoCheck }
 */
window.autofillPmEmailFromSo = async function(so, opts) {
  opts = opts || {};
  const soKey = window.normalizeP21So(so);
  if (!soKey) return null;

  let result;
  try {
    result = await window.fetchP21OrderInsights(soKey, { refresh: Boolean(opts.refresh) });
  } catch (_) {
    return null;
  }
  if (!result?.ok || !result.data?.found) return null;

  const taker = window.extractP21TakerName(result.data);
  const contact = window.findContactByPmName(taker);
  if (!contact) return { ok: false, taker, contact: null, email: null };

  const emailId = opts.emailId;
  const chkId = opts.chkId;
  const btnId = opts.btnId;
  const selectId = opts.selectId;

  if (emailId) {
    const el = document.getElementById(emailId);
    if (el) el.value = contact.email;
  }

  if (selectId) {
    const sel = document.getElementById(selectId);
    if (sel && sel.tagName === 'SELECT') {
      const want = window.normalizePersonKey(contact.name);
      const opt = Array.from(sel.options).find(o =>
        window.normalizePersonKey(o.value) === want || window.normalizePersonKey(o.textContent) === want
      );
      if (opt) sel.value = opt.value;
      else if (typeof PM_SMS_ROSTER !== 'undefined' && PM_SMS_ROSTER[contact.name]) {
        sel.value = contact.name;
      }
    }
  }

  if (opts.autoCheck && chkId) {
    const chk = document.getElementById(chkId);
    if (chk) {
      chk.checked = true;
      if (typeof window.togglePMEmail === 'function' && emailId) {
        window.togglePMEmail(true, emailId, btnId);
      }
    }
  }

  return { ok: true, taker, contact, email: contact.email };
};

/** Lookup customer (and cache insights) from Prophet21 for an SO/PO typed in site forms. */
window.lookupP21ForSoField = async function(soRaw) {
  const soKey = window.normalizeP21So(soRaw);
  if (!soKey) return { ok: false, customer: '', orderNo: '', taker: '', payload: null };
  try {
    const result = await window.fetchP21OrderInsights(soKey, { refresh: true });
    if (!result?.ok || !result.data?.found) {
      return { ok: false, customer: '', orderNo: soKey, taker: '', payload: result?.data || null, message: result?.message || result?.data?.message };
    }
    const h = result.data.header || {};
    const s = result.data.summary || {};
    const taker = window.extractP21TakerName(result.data);
    return {
      ok: true,
      customer: String(h.customerName || s.customer || '').trim(),
      orderNo: String(h.orderNo || soKey).trim(),
      linkedSo: String(h.linkedSo || s.linkedSo || '').trim(),
      soCustomer: String(h.soCustomer || s.soCustomer || '').trim(),
      purchasePo: !!(result.data.matchedBy === 'purchase_po' || h.purchasePo || s.purchasePo),
      taker,
      contact: window.findContactByPmName(taker),
      payload: result.data
    };
  } catch (e) {
    return { ok: false, customer: '', orderNo: soKey, taker: '', message: e.message || String(e) };
  }
};
