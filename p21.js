// --- p21.js — Prophet21 insights (Supabase cache-first, works from anywhere) ---

window.P21_PROXY_BASE = window.P21_PROXY_BASE || 'http://127.0.0.1:8787';
window.P21_FUNCTION_NAME = window.P21_FUNCTION_NAME || 'p21-order-insights';
window._p21WarmSet = window._p21WarmSet || new Set();

window.normalizeP21So = function(raw) {
  return String(raw || '').trim().replace(/^SO[#:\s-]*/i, '');
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

function refreshP21InBackground(so) {
  fetchP21FromEdgeFunction(so, true).catch(() => {});
}

window.fetchP21OrderInsights = async function(so, options) {
  const refresh = Boolean(options?.refresh);
  const soKey = window.normalizeP21So(so);
  if (!soKey) return { ok: false, message: 'SO number is required.' };

  if (!refresh) {
    const cached = await fetchP21FromCacheTable(so, true);
    if (cached?.ok) {
      if (cached.data.stale) refreshP21InBackground(so);
      return cached;
    }
  }

  const edge = await fetchP21FromEdgeFunction(so, refresh).catch(() => null);
  if (edge?.ok) return edge;

  const stale = await fetchP21FromCacheTable(so, true);
  if (stale?.ok) return stale;

  const local = await fetchP21FromLocalProxy(so);
  if (local?.ok) return local;

  return edge || local || {
    ok: false,
    offline: true,
    message: 'Prophet21 insights are not available yet. Data syncs from Swift network to Supabase automatically.'
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

window.formatP21OrderInsightsSection = function(result) {
  if (!result || !result.ok) {
    const hint = result?.offline
      ? 'Prophet21 data is syncing to Supabase from the Swift network. Cached insights appear here once synced.'
      : (result?.authError
        ? 'P21 authentication failed on the server. Contact an admin to verify Supabase P21 credentials.'
        : (result?.message || 'Prophet21 data unavailable.'));
    return `<p class="p21-status p21-status--warn" style="font-size:12px; color:#6b7280; margin:0 0 12px 0;">${hint}</p>`;
  }

  const payload = result.data;
  if (!payload.found) {
    return `<p class="p21-status" style="font-size:12px; color:#6b7280; margin:0 0 12px 0;">${payload.message || 'No matching Prophet21 order.'}</p>`;
  }

  const h = payload.header || {};
  const s = payload.summary || {};
  let html = `<div class="p21-insights-card">`;
  html += `<dl class="p21-insights-grid">`;
  html += `<div><dt>Customer</dt><dd>${window.formatP21Value(s.customer)}</dd></div>`;
  html += `<div><dt>Order #</dt><dd>${window.formatP21Value(h.orderNo)}</dd></div>`;
  html += `<div><dt>PO #</dt><dd>${window.formatP21Value(s.poNo)}</dd></div>`;
  html += `<div><dt>Order Date</dt><dd>${window.formatP21Value(s.orderDate)}</dd></div>`;
  html += `<div><dt>Status</dt><dd>${window.formatP21Value(s.status)}</dd></div>`;
  html += `<div><dt>Ship To</dt><dd>${window.formatP21Value(h.shipTo)}</dd></div>`;
  html += `<div><dt>Ship Via</dt><dd>${window.formatP21Value(h.shipVia)}</dd></div>`;
  html += `<div><dt>Warehouse</dt><dd>${window.formatP21Value(h.warehouse)}</dd></div>`;
  html += `<div><dt>Lines</dt><dd>${window.formatP21Value(s.lineCount)}</dd></div>`;
  html += `<div><dt>Total Qty Ordered</dt><dd>${window.formatP21Value(s.totalQtyOrdered)}</dd></div>`;
  html += `</dl>`;

  if (payload.lines && payload.lines.length) {
    html += `<div class="p21-lines-wrap"><table class="p21-lines-table"><thead><tr><th>Line</th><th>Item</th><th>Description</th><th>Qty</th><th>Shipped</th><th>UOM</th><th>Required</th></tr></thead><tbody>`;
    payload.lines.forEach(line => {
      html += `<tr>
        <td>${window.formatP21Value(line.lineNo)}</td>
        <td>${window.formatP21Value(line.itemId)}</td>
        <td>${window.formatP21Value(line.description)}</td>
        <td>${window.formatP21Value(line.qtyOrdered)}</td>
        <td>${window.formatP21Value(line.qtyShipped)}</td>
        <td>${window.formatP21Value(line.uom)}</td>
        <td>${window.formatP21Value(line.requiredDate)}</td>
      </tr>`;
    });
    html += `</tbody></table></div>`;
  }

  const staleNote = payload.stale ? ' (updating…)' : '';
  const cachedNote = payload.cached || result.via?.includes('cache') || result.via?.includes('stale') ? ' — synced copy' : '';
  const fetched = payload.fetchedAt ? ` · ${window.formatP21Value(payload.fetchedAt)}` : '';
  html += `<p class="p21-footnote">Prophet21 via <b>${window.formatP21Value(payload.matchedBy)}</b>${cachedNote}${staleNote}${fetched}.</p>`;
  html += `</div>`;
  return html;
};
