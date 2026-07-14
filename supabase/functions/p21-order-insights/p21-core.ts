import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

export type Json = Record<string, unknown>;

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-p21-sync-key',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const tokenState = { accessToken: '' as string, expiresAt: 0 };

export function normalizeSo(raw: string) {
  return String(raw || '').trim().replace(/^SO[#:\s-]*/i, '').replace(/^PO[#:\s-]*/i, '');
}

/** Swift purchase orders typically start with 4 (e.g. 4276832). */
export function isPurchasePo(raw: string) {
  const key = normalizeSo(raw);
  return /^\d+$/.test(key) && key.startsWith('4') && key.length >= 6;
}

/** "Karpiak, Ben " → "Ben Karpiak"; leave "Ben Karpiak" / "BEN.KARPIAK" alone for later name match. */
export function formatPersonDisplayName(raw: unknown) {
  const s = String(raw || '').replace(/\s+/g, ' ').trim();
  if (!s) return '';
  if (s.includes(',')) {
    const [last, ...rest] = s.split(',');
    const first = rest.join(',').trim();
    if (first && last.trim()) return `${first} ${last.trim()}`.replace(/\s+/g, ' ').trim();
  }
  if (s.includes('.') && !s.includes(' ')) {
    return s.split('.').filter(Boolean).map((p) => p.charAt(0).toUpperCase() + p.slice(1).toLowerCase()).join(' ');
  }
  return s;
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

export function canFetchLiveP21(cfg: Record<string, string>) {
  if (cfg.P21_CONNECTOR_URL?.trim()) return true;
  const allow = cfg.P21_ALLOW_CLOUD_LIVE || Deno.env.get('P21_ALLOW_CLOUD_LIVE') || '';
  if (allow === '0') return false;
  if (allow === '1') return true;
  return Boolean(cfg.P21_CONSUMER_KEY || (cfg.P21_USERNAME && cfg.P21_PASSWORD));
}

export function loadP21ConfigFromEnv(): Record<string, string> {
  const cfg: Record<string, string> = {};
  for (const key of ['P21_BASE_URL', 'P21_USERNAME', 'P21_PASSWORD', 'P21_CONSUMER_KEY', 'P21_CONNECTOR_URL', 'P21_SYNC_KEY', 'P21_ALLOW_CLOUD_LIVE']) {
    const val = Deno.env.get(key);
    if (val) cfg[key] = val;
  }
  return cfg;
}

/** Prefer Edge secrets; fall back to private.p21_edge_secrets via service-role RPC when Management secrets scopes are unavailable. */
export async function loadP21Config(supabase?: SupabaseClient): Promise<Record<string, string>> {
  const cfg = loadP21ConfigFromEnv();
  const hasLiveCreds = Boolean(cfg.P21_CONSUMER_KEY || (cfg.P21_USERNAME && cfg.P21_PASSWORD) || cfg.P21_CONNECTOR_URL);
  if (hasLiveCreds) return cfg;
  const client = supabase || serviceClient();
  try {
    const { data, error } = await client.rpc('p21_edge_secrets_get');
    if (error) {
      console.error('p21_edge_secrets_get failed', error.message);
      return cfg;
    }
    if (data && typeof data === 'object') {
      for (const [k, v] of Object.entries(data as Record<string, unknown>)) {
        if (typeof v === 'string' && v && !cfg[k]) cfg[k] = v;
      }
    }
  } catch (e) {
    console.error('p21_edge_secrets_get error', e);
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

async function getP21Token(baseUrl: string, username: string, password: string, consumerKey?: string) {
  if (tokenState.accessToken && Date.now() < tokenState.expiresAt - 60_000) {
    return tokenState.accessToken;
  }

  // Consumer Key bypasses user OData Application Security / Dataservice Permission checks.
  const body = consumerKey
    ? { ClientSecret: consumerKey, GrantType: 'client_credentials' }
    : { username, password };

  if (!consumerKey && (!username || !password)) {
    throw new Error('P21 credentials are not configured on the server.');
  }

  const response = await fetch(`${baseUrl}/api/security/token/v2`, {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
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

type InteractiveHeader = {
  orderNo: unknown;
  customerId: unknown;
  customerName: unknown;
  poNo: unknown;
  projectId: unknown;
  requiredDate: unknown;
  taker: unknown;
  orderDate?: unknown;
  status?: unknown;
  shipTo?: unknown;
  warehouse?: unknown;
  linkedSo?: unknown;
  soCustomer?: unknown;
  purchasePo?: boolean;
};

function slimInsights(so: string, header: InteractiveHeader, matchedBy: string, source: string) {
  const purchasePo = Boolean(header.purchasePo) || matchedBy === 'purchase_po';
  const linkedSo = header.linkedSo ? String(header.linkedSo) : '';
  const soCustomer = header.soCustomer ? String(header.soCustomer) : '';
  let poDisplay = header.poNo ?? null;
  if (purchasePo) {
    if (linkedSo && soCustomer) {
      poDisplay = `${so} (for ${soCustomer} SO# ${linkedSo})`;
    } else if (linkedSo) {
      poDisplay = `${so} (SO# ${linkedSo})`;
    } else {
      poDisplay = so;
    }
  }

  return {
    so,
    found: true,
    matchedBy,
    source,
    header: {
      orderNo: header.orderNo || so,
      customerId: header.customerId ?? null,
      customerName: header.customerName ?? null,
      poNo: poDisplay,
      projectId: header.projectId ?? null,
      requiredDate: header.requiredDate ?? null,
      taker: header.taker ?? null,
      orderDate: header.orderDate ?? null,
      status: header.status ?? null,
      shipTo: header.shipTo ?? null,
      warehouse: header.warehouse ?? null,
      linkedSo: linkedSo || null,
      soCustomer: soCustomer || null,
      purchasePo,
    },
    // Line breakdown intentionally omitted for Order History display
    lines: [] as Json[],
    summary: {
      customer: header.customerName || header.customerId || '—',
      poNo: poDisplay || '—',
      projectId: header.projectId || '—',
      requiredDate: header.requiredDate || '—',
      taker: header.taker || '—',
      pm: header.taker || '—',
      orderDate: header.orderDate || '—',
      status: header.status ?? '—',
      linkedSo: linkedSo || '—',
      soCustomer: soCustomer || '—',
      purchasePo,
      lineCount: 0,
      totalQtyOrdered: 0,
    },
  };
}

function parseInteractiveBlocks(data: unknown): Array<{ name: string; rows: Record<string, unknown>[] }> {
  const blocks = Array.isArray(data)
    ? data
    : (data && typeof data === 'object' && Array.isArray((data as Json).Data)
      ? (data as Json).Data as unknown[]
      : []);
  const out: Array<{ name: string; rows: Record<string, unknown>[] }> = [];
  for (const block of blocks) {
    if (!block || typeof block !== 'object') continue;
    const b = block as Json;
    const name = String(b.Name || '');
    const cols = Array.isArray(b.Columns) ? b.Columns as string[] : [];
    const rows = Array.isArray(b.Data) ? b.Data as unknown[][] : [];
    if (!name || !cols.length) continue;
    const mappedRows = rows.map((row) => {
      const mapped: Record<string, unknown> = {};
      cols.forEach((c, i) => {
        mapped[c] = row?.[i];
      });
      return mapped;
    });
    out.push({ name, rows: mappedRows });
  }
  return out;
}

function parseInteractiveDatawindows(data: unknown): Record<string, Record<string, unknown>> {
  const out: Record<string, Record<string, unknown>> = {};
  for (const block of parseInteractiveBlocks(data)) {
    if (block.rows[0]) out[block.name] = block.rows[0];
  }
  return out;
}

/** Candidate linked sales-order numbers from PO document-link / note grids (not commitment txn #s). */
function findLinkedSoCandidates(blocks: Array<{ name: string; rows: Record<string, unknown>[] }>, poKey: string): string[] {
  const keys = [
    'sales_order_number',
    'sales_order_no',
    'sales_order',
    'oe_order_no',
    'linked_order_no',
    'order_no',
    'document_no',
    'document_id',
  ];
  const found: string[] = [];
  const push = (v: unknown) => {
    const s = String(v || '').trim();
    if (!/^\d{6,8}$/.test(s) || s === poKey || s.startsWith('4')) return;
    if (!found.includes(s)) found.push(s);
  };
  for (const block of blocks) {
    const n = block.name.toLowerCase();
    // Skip commitment / allocation grids — those transaction_numbers are not Carmen SOs
    if (/commit|alloc|inv/.test(n)) continue;
    for (const row of block.rows) {
      const docType = String(row.document_type || row.doc_type || row.source_type || row.type || '').toLowerCase();
      const looksLikeOrderDoc = !docType || /order|oe|sales/.test(docType);
      for (const k of keys) {
        if (row[k] == null) continue;
        if (k === 'document_no' || k === 'document_id' || k === 'order_no') {
          if (!looksLikeOrderDoc && !/doc|link|order/.test(n)) continue;
        }
        push(row[k]);
      }
    }
  }
  return found;
}

function headerFromOrderRow(row: Record<string, unknown> | undefined): InteractiveHeader | null {
  if (!row) return null;
  return {
    orderNo: row.order_no ?? null,
    customerId: row.customer_id ?? null,
    customerName: row.customer_name ?? null,
    poNo: row.po_no ?? null,
    projectId: row.ufc_oe_hdr_ud_project ?? row.project_id ?? null,
    requiredDate: row.requested_date ?? row.required_date ?? null,
    taker: row.taker_name || row.taker || null,
    orderDate: row.order_date ?? null,
    status: row.validation_status ?? row.cancel_flag ?? null,
    shipTo: row.ship_to_name ?? null,
    warehouse: row.sales_loc_id ?? row.source_loc_id ?? null,
  };
}

let interactiveLock: Promise<unknown> = Promise.resolve();

function withInteractiveLock<T>(fn: () => Promise<T>): Promise<T> {
  const run = interactiveLock.then(fn, fn);
  interactiveLock = run.then(() => undefined, () => undefined);
  return run;
}

async function interactiveApi(
  uiBase: string,
  token: string,
  method: string,
  path: string,
  body?: unknown,
) {
  const headers: Record<string, string> = {
    Accept: 'application/json',
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
  const response = await fetch(`${uiBase}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : (typeof body === 'string' ? body : JSON.stringify(body)),
  });
  const text = await response.text();
  let json: unknown = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  return { status: response.status, text, json };
}

async function ensureInteractiveSession(uiBase: string, token: string) {
  const createBody = {
    SessionType: 'Auto',
    ResponseWindowHandlingEnabled: false,
    ClientPlatformApp: 'SLST-OrderInsights',
    SessionTimeout: 300,
  };
  let res = await interactiveApi(uiBase, token, 'POST', '/api/ui/interactive/sessions', createBody);
  if (res.status === 409) {
    await interactiveApi(uiBase, token, 'DELETE', '/api/ui/interactive/sessions');
    res = await interactiveApi(uiBase, token, 'POST', '/api/ui/interactive/sessions', createBody);
  }
  if (res.status !== 200 && res.status !== 201) {
    throw new Error(`Interactive session failed (${res.status})`);
  }
}

/**
 * Purchase Order Entry (ServiceName=PurchaseOrder).
 * Discovered path: set po_no on tp_1_dw_1 with a valid TabName (DOCUMENT_LINK works)
 * → vendor_name = supplier (Customer), buyer_name = PM.
 * Linked sales-order number from Report for Carmen is not on this window; when/if
 * a linked SO is provided later, format becomes: PO (for {soCustomer} SO# {linkedSo}).
 */
async function retrieveViaPurchasePo(baseUrl: string, token: string, poKey: string) {
  const uiBase = `${baseUrl}/uiserver0`;
  return withInteractiveLock(async () => {
    await ensureInteractiveSession(uiBase, token);

    const open = await interactiveApi(uiBase, token, 'POST', '/api/ui/interactive/v2/window', {
      ServiceName: 'PurchaseOrder',
    });
    const wid = open.json && typeof open.json === 'object'
      ? String((open.json as Json).WindowId || '')
      : '';
    if (!wid) throw new Error(`Open Purchase Order failed (${open.status})`);

    try {
      await interactiveApi(uiBase, token, 'POST', '/api/ui/interactive/v2/tools', {
        WindowId: wid,
        ToolName: 'Quick.Clear',
      });

      const tabCandidates = ['DOCUMENT_LINK', 'TABPAGE_1', 'TABPAGE_CONTACT', 'SHIP_TO', 'TOTALS'];
      let headerRow: Record<string, unknown> | undefined;
      let allBlocks: Array<{ name: string; rows: Record<string, unknown>[] }> = [];

      for (const tab of tabCandidates) {
        const change = await interactiveApi(uiBase, token, 'PUT', '/api/ui/interactive/v2/change', {
          WindowId: wid,
          List: [{
            TabName: tab,
            FieldName: 'po_no',
            Value: poKey,
            DatawindowName: 'tp_1_dw_1',
            Row: 1,
          }],
        });
        if (change.status !== 200) continue;

        const dataRes = await interactiveApi(uiBase, token, 'GET', `/api/ui/interactive/v2/data?id=${wid}`);
        const stateRes = await interactiveApi(uiBase, token, 'GET', `/api/ui/interactive/v2/window?id=${wid}`);
        const blocks = [
          ...parseInteractiveBlocks(dataRes.json),
          ...parseInteractiveBlocks(
            stateRes.json && typeof stateRes.json === 'object'
              ? (stateRes.json as Json).Data
              : null,
          ),
        ];
        // Prefer later duplicate names from window state
        const byName = new Map<string, { name: string; rows: Record<string, unknown>[] }>();
        for (const b of blocks) byName.set(b.name, b);
        allBlocks = [...byName.values()];
        const headerDw = byName.get('tp_1_dw_1');
        const row = headerDw?.rows?.[0];
        if (row && String(row.po_no || '') === poKey) {
          headerRow = row;
          break;
        }
      }

      if (!headerRow) {
        return {
          so: poKey,
          found: false,
          message: `No Prophet21 Purchase Order match for ${poKey}.`,
          source: 'interactive',
          lines: [],
        };
      }

      const supplier = String(
        headerRow.vendor_name
          || headerRow.vendor_supplier_name
          || headerRow.division_name
          || '',
      ).trim();
      const buyer = formatPersonDisplayName(headerRow.buyer_name || headerRow.buyer_id);
      const requiredDate = headerRow.required_date ?? null;
      const orderDate = headerRow.order_date ?? null;
      const status = headerRow.status ?? null;
      const warehouse = headerRow.location_name || headerRow.location_id || null;
      const vendorId = headerRow.vendor_id || headerRow.vendor_supplier_id || null;
      const linkedCandidates = findLinkedSoCandidates(allBlocks, poKey);

      // Close PO before Optional Order Entry enrich (same Interactive session)
      try {
        await interactiveApi(uiBase, token, 'POST', '/api/ui/interactive/v2/tools', {
          WindowId: wid,
          ToolName: 'Quick.Close',
        });
      } catch { /* ignore */ }
      try {
        await interactiveApi(uiBase, token, 'DELETE', `/api/ui/interactive/v2/window?id=${wid}`);
      } catch { /* ignore */ }

      let linkedSo = '';
      let soCustomer = '';
      let soTaker = '';
      for (const candidate of linkedCandidates.slice(0, 3)) {
        try {
          const soHit = await retrieveViaInteractiveUnlocked(uiBase, token, candidate);
          if (soHit?.found && soHit.header?.customerName) {
            linkedSo = String(soHit.header.orderNo || candidate);
            soCustomer = String(soHit.header.customerName || '');
            soTaker = formatPersonDisplayName(soHit.header.taker);
            break;
          }
        } catch (e) {
          console.error('linked SO enrich failed', candidate, e);
        }
      }

      const header: InteractiveHeader = {
        orderNo: poKey,
        customerId: vendorId,
        customerName: supplier || null,
        poNo: poKey,
        projectId: null,
        requiredDate,
        // Prefer linked-SO taker; otherwise PO buyer (matches Carmen PM for sample 4276832)
        taker: soTaker || buyer || null,
        orderDate,
        status,
        shipTo: null,
        warehouse,
        linkedSo: linkedSo || null,
        soCustomer: soCustomer || null,
        purchasePo: true,
      };

      return slimInsights(poKey, header, 'purchase_po', 'interactive');
    } finally {
      try {
        await interactiveApi(uiBase, token, 'POST', '/api/ui/interactive/v2/tools', {
          WindowId: wid,
          ToolName: 'Quick.Close',
        });
      } catch { /* ignore */ }
      try {
        await interactiveApi(uiBase, token, 'DELETE', `/api/ui/interactive/v2/window?id=${wid}`);
      } catch { /* ignore */ }
    }
  });
}

/** Inner Order retrieve — caller must already hold interactive lock / session. */
async function retrieveViaInteractiveUnlocked(uiBase: string, token: string, so: string) {
  const open = await interactiveApi(uiBase, token, 'POST', '/api/ui/interactive/v2/window', {
    ServiceName: 'Order',
  });
  const wid = open.json && typeof open.json === 'object'
    ? String((open.json as Json).WindowId || '')
    : '';
  if (!wid) return { so, found: false, header: null as InteractiveHeader | null };

  try {
    await interactiveApi(uiBase, token, 'POST', '/api/ui/interactive/v2/tools', {
      WindowId: wid,
      ToolName: 'Quick.Clear',
    });
    await interactiveApi(uiBase, token, 'PUT', '/api/ui/interactive/v2/change', {
      WindowId: wid,
      List: [{
        TabName: 'Order',
        FieldName: 'order_no',
        Value: so,
        DatawindowName: 'order',
        Row: 1,
      }],
    });
    const dataRes = await interactiveApi(uiBase, token, 'GET', `/api/ui/interactive/v2/data?id=${wid}`);
    const stateRes = await interactiveApi(uiBase, token, 'GET', `/api/ui/interactive/v2/window?id=${wid}`);
    const dws = {
      ...parseInteractiveDatawindows(dataRes.json),
      ...parseInteractiveDatawindows(
        stateRes.json && typeof stateRes.json === 'object'
          ? (stateRes.json as Json).Data
          : null,
      ),
    };
    const header = headerFromOrderRow(dws.order);
    const looksLoaded = Boolean(
      header && (String(header.orderNo || '') === so || header.customerId || header.customerName),
    );
    if (!looksLoaded || !header) return { so, found: false, header: null };
    return { so, found: true, header };
  } finally {
    try {
      await interactiveApi(uiBase, token, 'POST', '/api/ui/interactive/v2/tools', {
        WindowId: wid,
        ToolName: 'Quick.Close',
      });
    } catch { /* ignore */ }
    try {
      await interactiveApi(uiBase, token, 'DELETE', `/api/ui/interactive/v2/window?id=${wid}`);
    } catch { /* ignore */ }
  }
}

async function retrieveViaInteractive(baseUrl: string, token: string, so: string) {
  const uiBase = `${baseUrl}/uiserver0`;
  return withInteractiveLock(async () => {
    await ensureInteractiveSession(uiBase, token);

    const open = await interactiveApi(uiBase, token, 'POST', '/api/ui/interactive/v2/window', {
      ServiceName: 'Order',
    });
    const wid = open.json && typeof open.json === 'object'
      ? String((open.json as Json).WindowId || '')
      : '';
    if (!wid) throw new Error(`Open Order Entry failed (${open.status})`);

    try {
      await interactiveApi(uiBase, token, 'POST', '/api/ui/interactive/v2/tools', {
        WindowId: wid,
        ToolName: 'Quick.Clear',
      });

      const tryField = async (fieldName: string) => {
        await interactiveApi(uiBase, token, 'PUT', '/api/ui/interactive/v2/change', {
          WindowId: wid,
          List: [{
            TabName: 'Order',
            FieldName: fieldName,
            Value: so,
            DatawindowName: 'order',
            Row: 1,
          }],
        });
        const dataRes = await interactiveApi(uiBase, token, 'GET', `/api/ui/interactive/v2/data?id=${wid}`);
        const stateRes = await interactiveApi(uiBase, token, 'GET', `/api/ui/interactive/v2/window?id=${wid}`);
        const dws = {
          ...parseInteractiveDatawindows(dataRes.json),
          ...parseInteractiveDatawindows(
            stateRes.json && typeof stateRes.json === 'object'
              ? (stateRes.json as Json).Data
              : null,
          ),
        };
        return headerFromOrderRow(dws.order);
      };

      let header = await tryField('order_no');
      let matchedBy = 'order_no';
      const looksLoaded = Boolean(
        header && (String(header.orderNo || '') === so || header.customerId || header.customerName),
      );
      if (!looksLoaded) {
        header = await tryField('po_no');
        matchedBy = 'po_no';
      }

      if (!header || !(header.customerId || header.customerName || String(header.orderNo || '') === so)) {
        return {
          so,
          found: false,
          message: `No Prophet21 Order Entry match for ${so}.`,
          source: 'interactive',
          lines: [],
        };
      }

      return slimInsights(so, header, matchedBy, 'interactive');
    } finally {
      try {
        await interactiveApi(uiBase, token, 'POST', '/api/ui/interactive/v2/tools', {
          WindowId: wid,
          ToolName: 'Quick.Close',
        });
      } catch { /* ignore */ }
      try {
        await interactiveApi(uiBase, token, 'DELETE', `/api/ui/interactive/v2/window?id=${wid}`);
      } catch { /* ignore */ }
    }
  });
}

async function fetchViaOData(baseUrl: string, token: string, so: string) {
  const hit = await findOrderHeader(baseUrl, token, so);
  if (!hit) {
    return { so, found: false, message: `No Prophet21 order found for SO ${so}.`, source: 'odata', lines: [] };
  }

  const row = hit.row as Json;
  const header: InteractiveHeader = {
    orderNo: pickFirst(row, ['order_no', 'OrderNo']),
    customerId: pickFirst(row, ['customer_id', 'CustomerId']),
    customerName: pickFirst(row, ['customer_name', 'CustomerName', 'ship_to_name', 'ShipToName']),
    poNo: pickFirst(row, ['po_no', 'PoNo', 'customer_po_no', 'CustomerPoNo']),
    projectId: pickFirst(row, ['project_id', 'ProjectId', 'job_name']),
    requiredDate: pickFirst(row, ['required_date', 'RequiredDate', 'requested_date', 'promise_date']),
    taker: pickFirst(row, ['taker', 'Taker', 'taken_by']),
    orderDate: pickFirst(row, ['order_date', 'OrderDate']),
    status: pickFirst(row, ['order_status', 'OrderStatus', 'status']),
    shipTo: pickFirst(row, ['ship_to_name', 'ShipToName']),
    warehouse: pickFirst(row, ['source_loc_id', 'SourceLocId', 'location_id']),
  };
  return slimInsights(so, header, String(hit.matchedBy), 'odata');
}

export async function fetchLiveInsights(soRaw: string, cfg: Record<string, string>) {
  const connector = cfg.P21_CONNECTOR_URL?.replace(/\/+$/, '');
  if (connector) {
    const response = await fetch(`${connector}/api/order/${encodeURIComponent(soRaw)}`, {
      headers: { Accept: 'application/json' },
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.message || `Connector error (${response.status})`);
    // Normalize connector payloads to slim Order History shape
    if (data?.found && data.header) {
      return slimInsights(
        normalizeSo(soRaw),
        {
          orderNo: data.header.orderNo,
          customerId: data.header.customerId,
          customerName: data.header.customerName,
          poNo: data.header.poNo,
          projectId: data.header.projectId,
          requiredDate: data.header.requiredDate,
          taker: data.header.taker,
          orderDate: data.header.orderDate,
          status: data.header.status,
          shipTo: data.header.shipTo,
          warehouse: data.header.warehouse,
        },
        String(data.matchedBy || 'connector'),
        'connector',
      );
    }
    return { ...data, lines: [], source: data.source || 'connector' };
  }

  const baseUrl = (cfg.P21_BASE_URL || 'https://swiftsupply-api.epicordistribution.com').replace(/\/+$/, '');
  const username = cfg.P21_USERNAME || '';
  const password = cfg.P21_PASSWORD || '';
  const consumerKey = cfg.P21_CONSUMER_KEY || '';
  if (!consumerKey && (!username || !password)) throw new Error('P21 credentials are not configured on the server.');

  const so = normalizeSo(soRaw);
  if (!so) throw new Error('SO number is required');

  const token = await getP21Token(baseUrl, username, password, consumerKey || undefined);

  // Swift purchase orders (typically 4xxxxxx) → PurchaseOrder Interactive first
  if (isPurchasePo(so)) {
    try {
      const poHit = await retrieveViaPurchasePo(baseUrl, token, so);
      if (poHit?.found) return poHit;
    } catch (e) {
      console.error('purchase PO retrieve failed', e);
    }
  }

  // Prefer Interactive Order Entry (works without OData Dataservice rights)
  try {
    const interactive = await retrieveViaInteractive(baseUrl, token, so);
    if (interactive.found) return interactive;
  } catch (e) {
    // Fall through to OData when Interactive is unavailable
    console.error('interactive retrieve failed', e);
  }

  try {
    return await fetchViaOData(baseUrl, token, so);
  } catch (e) {
    throw new Error(
      `Prophet21 live lookup failed (${e instanceof Error ? e.message : String(e)}). Interactive and OData paths unavailable.`,
    );
  }
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
