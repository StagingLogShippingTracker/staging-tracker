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
    message: 'Prophet21 insights are not cached yet. On a Swift-network PC with the local P21 proxy running, open this order to publish insights for everyone.'
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

window.formatP21OrderInsightsSection = function(result) {
  const so = result?.so || result?.data?.so || '';
  const openLink = window.formatP21OpenLink(so);

  if (!result || !result.ok) {
    const hint = result?.offline
      ? 'No cached Prophet21 data for this SO yet. On a Swift-network PC with the local P21 proxy running, open this order once to publish insights for the whole team.'
      : (result?.authError
        ? 'P21 authentication failed. Contact an admin to verify credentials on the Swift-network proxy.'
        : (result?.message || 'Prophet21 data unavailable.'));
    return `<p class="p21-status p21-status--warn" style="font-size:12px; color:#6b7280; margin:0 0 8px 0;">${hint}</p>${openLink}`;
  }

  const payload = result.data;
  if (!payload.found) {
    return `<p class="p21-status" style="font-size:12px; color:#6b7280; margin:0 0 8px 0;">${payload.message || 'No matching Prophet21 order.'}</p>${openLink}`;
  }

  const h = payload.header || {};
  const s = payload.summary || {};
  let html = `<div class="p21-insights-card">`;
  html += openLink;
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
  const viaLabel = result.via === 'local-proxy'
    ? 'live proxy (published for all users)'
    : (payload.cached || result.via?.includes('cache') || result.via?.includes('stale') ? 'synced copy' : window.formatP21Value(payload.matchedBy));
  const fetched = payload.fetchedAt ? ` · ${window.formatP21Value(payload.fetchedAt)}` : '';
  html += `<p class="p21-footnote">Prophet21 via <b>${viaLabel}</b>${staleNote}${fetched}.</p>`;
  html += `</div>`;
  return html;
};
