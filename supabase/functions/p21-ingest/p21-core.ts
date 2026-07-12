import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

export type Json = Record<string, unknown>;

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-p21-sync-key',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const tokenState = { accessToken: '' as string, expiresAt: 0 };

export function normalizeSo(raw: string) {
  return String(raw || '').trim().replace(/^SO[#:\s-]*/i, '');
}

export function odataEscape(value: string) {
  return String(value).replace(/'/g, "''");
}

export function pickFirst(row: Json, keys: string[]) {
  for (const key of keys) {
    const val = row[key];
    if (val != null && val !== '') return val;
  }
  return null;
}

export function serviceClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
}

export function loadP21Config(): Record<string, string> {
  const cfg: Record<string, string> = {};
  for (const key of ['P21_BASE_URL', 'P21_USERNAME', 'P21_PASSWORD', 'P21_CONNECTOR_URL', 'P21_SYNC_KEY']) {
    const val = Deno.env.get(key);
    if (val) cfg[key] = val;
  }
  return cfg;
}

export async function assertSyncKey(req: Request) {
  const expected = Deno.env.get('P21_SYNC_KEY') || '';
  if (!expected) throw new Error('P21 sync key is not configured.');
  const provided = req.headers.get('x-p21-sync-key') || '';
  if (!provided || provided !== expected) {
    const err = new Error('Unauthorized sync request.');
    (err as Error & { status: number }).status = 401;
    throw err;
  }
}

async function getP21Token(baseUrl: string, username: string, password: string) {
  if (tokenState.accessToken && Date.now() < tokenState.expiresAt - 60_000) {
    return tokenState.accessToken;
  }
  const response = await fetch(`${baseUrl}/api/security/token/v2`, {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  });
  if (!response.ok) throw new Error(`P21 authentication failed (${response.status})`);
  const data = await response.json();
  const token = data.AccessToken || data.access_token || data.accessToken;
  if (!token) throw new Error('P21 token response missing AccessToken');
  tokenState.accessToken = token;
  tokenState.expiresAt = Date.now() + Number(data.ExpiresInSeconds || data.expires_in || 3600) * 1000;
  return token;
}

async function odataQuery(baseUrl: string, token: string, resourceType: string, resourceName: string, filter?: string, top = 25) {
  const params = new URLSearchParams();
  if (filter) params.set('$filter', filter);
  params.set('$top', String(top));
  const url = `${baseUrl}/odataservice/odata/${resourceType}/${resourceName}?${params.toString()}`;
  const response = await fetch(url, {
    headers: { Accept: 'application/json', Authorization: `Bearer ${token}` },
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`OData ${resourceName} failed (${response.status}): ${text.slice(0, 180)}`);
  }
  const data = await response.json();
  return data.value || data.d?.results || [];
}

async function findOrderHeader(baseUrl: string, token: string, so: string) {
  const esc = odataEscape(so);
  const views = ['p21_view_oe_hdr', 'oe_hdr'];
  const filters = [`order_no eq '${esc}'`, `po_no eq '${esc}'`, `customer_po_no eq '${esc}'`];
  if (/^\d+$/.test(so)) filters.unshift(`order_no eq ${so}`);

  for (const view of views) {
    for (const filter of filters) {
      try {
        const rows = await odataQuery(baseUrl, token, 'view', view, filter, 5);
        if (rows.length) return { row: rows[0], view, matchedBy: filter.split(' ')[0] };
      } catch (e) {
        if (!/404|not found/i.test(String(e))) throw e;
      }
    }
  }
  return null;
}

async function findOrderLines(baseUrl: string, token: string, orderNo: unknown) {
  if (orderNo == null || orderNo === '') return [];
  const esc = odataEscape(String(orderNo));
  const views = ['p21_view_oe_line', 'p21_view_oe_detail', 'oe_line'];
  const filters = [`order_no eq '${esc}'`];
  if (/^\d+$/.test(String(orderNo))) filters.unshift(`order_no eq ${orderNo}`);

  for (const view of views) {
    for (const filter of filters) {
      try {
        const rows = await odataQuery(baseUrl, token, 'view', view, filter, 100);
        if (rows.length) return rows;
      } catch (e) {
        if (!/404|not found/i.test(String(e))) throw e;
      }
    }
  }
  return [];
}

export async function fetchLiveInsights(soRaw: string, cfg: Record<string, string>) {
  const connector = cfg.P21_CONNECTOR_URL?.replace(/\/+$/, '');
  if (connector) {
    const response = await fetch(`${connector}/api/order/${encodeURIComponent(soRaw)}`, {
      headers: { Accept: 'application/json' },
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.message || `Connector error (${response.status})`);
    return { ...data, source: 'connector' };
  }

  const baseUrl = (cfg.P21_BASE_URL || 'https://swiftsupply.epicordistribution.com/Prophet21').replace(/\/+$/, '');
  const username = cfg.P21_USERNAME || '';
  const password = cfg.P21_PASSWORD || '';
  if (!username || !password) throw new Error('P21 credentials are not configured on the server.');

  const so = normalizeSo(soRaw);
  if (!so) throw new Error('SO number is required');

  const token = await getP21Token(baseUrl, username, password);
  const hit = await findOrderHeader(baseUrl, token, so);
  if (!hit) {
    return { so, found: false, message: `No Prophet21 order found for SO ${so}.`, source: 'live' };
  }

  const row = hit.row as Json;
  const header = {
    orderNo: pickFirst(row, ['order_no', 'OrderNo']),
    customerId: pickFirst(row, ['customer_id', 'CustomerId']),
    customerName: pickFirst(row, ['customer_name', 'CustomerName', 'ship_to_name', 'ShipToName']),
    poNo: pickFirst(row, ['po_no', 'PoNo', 'customer_po_no', 'CustomerPoNo']),
    orderDate: pickFirst(row, ['order_date', 'OrderDate', 'date_created', 'DateCreated']),
    status: pickFirst(row, ['order_status', 'OrderStatus', 'status', 'Status']),
    shipTo: pickFirst(row, ['ship_to_name', 'ShipToName']),
    shipVia: pickFirst(row, ['ship_via', 'ShipVia', 'carrier_id']),
    warehouse: pickFirst(row, ['source_loc_id', 'SourceLocId', 'location_id', 'LocationId']),
  };
  const orderNo = header.orderNo || so;
  const lineRows = await findOrderLines(baseUrl, token, orderNo);
  const lines = lineRows.map((line: Json) => ({
    lineNo: pickFirst(line, ['line_no', 'LineNo']),
    itemId: pickFirst(line, ['item_id', 'ItemId']),
    description: pickFirst(line, ['item_desc', 'ItemDesc', 'extended_desc', 'ExtendedDesc', 'description']),
    qtyOrdered: pickFirst(line, ['qty_ordered', 'QtyOrdered', 'unit_quantity', 'UnitQuantity']),
    qtyShipped: pickFirst(line, ['qty_shipped', 'QtyShipped']),
    uom: pickFirst(line, ['unit_of_measure', 'UnitOfMeasure', 'sales_uom']),
    requiredDate: pickFirst(line, ['required_date', 'RequiredDate', 'promise_date', 'PromiseDate']),
  }));

  return {
    so,
    found: true,
    matchedBy: hit.matchedBy,
    sourceView: hit.view,
    source: 'live',
    header,
    lines,
    summary: {
      customer: header.customerName || header.customerId || '—',
      orderDate: header.orderDate || '—',
      status: header.status ?? '—',
      poNo: header.poNo || '—',
      lineCount: lines.length,
      totalQtyOrdered: lines.reduce((sum: number, l: Json) => sum + (Number(l.qtyOrdered) || 0), 0),
    },
  };
}

export async function readCacheRow(supabase: SupabaseClient, soKey: string, allowStale = false) {
  const { data, error } = await supabase.from('p21_order_cache').select('*').eq('so_key', soKey).maybeSingle();
  if (error) throw error;
  if (!data) return null;
  const expired = new Date(data.expires_at).getTime() < Date.now();
  if (expired && !allowStale) return null;
  return { ...data, stale: expired };
}

export async function writeCacheRow(supabase: SupabaseClient, soRaw: string, payload: Json, source = 'live') {
  const soKey = normalizeSo(soRaw);
  const expires = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  const { error } = await supabase.from('p21_order_cache').upsert({
    so_key: soKey,
    so_raw: soRaw,
    found: Boolean(payload.found),
    payload,
    matched_by: (payload.matchedBy as string) || null,
    source: (payload.source as string) || source,
    fetched_at: new Date().toISOString(),
    expires_at: expires,
  });
  if (error) throw error;
}

export async function collectTrackerSos(supabase: SupabaseClient) {
  const [st, sh] = await Promise.all([
    supabase.from('staging').select('so'),
    supabase.from('shipped').select('so'),
  ]);
  const rows = [...(st.data || []), ...(sh.data || [])];
  return [...new Set(rows.map((r) => normalizeSo(String(r.so || ''))).filter(Boolean))];
}
