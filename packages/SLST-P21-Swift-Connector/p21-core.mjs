/** Shared Prophet21 OData fetch logic (Node proxy + connector service). */

export function normalizeSo(raw) {
  return String(raw || '').trim().replace(/^SO[#:\s-]*/i, '');
}

export function odataEscape(value) {
  return String(value).replace(/'/g, "''");
}

export function pickFirst(row, keys) {
  for (const key of keys) {
    if (row[key] != null && row[key] !== '') return row[key];
  }
  return null;
}

export function summarizeHeader(row) {
  if (!row) return null;
  return {
    orderNo: pickFirst(row, ['order_no', 'OrderNo', 'order_number']),
    customerId: pickFirst(row, ['customer_id', 'CustomerId']),
    customerName: pickFirst(row, ['customer_name', 'CustomerName', 'ship_to_name', 'ShipToName']),
    poNo: pickFirst(row, ['po_no', 'PoNo', 'customer_po_no', 'CustomerPoNo', 'po_number']),
    orderDate: pickFirst(row, ['order_date', 'OrderDate', 'date_created', 'DateCreated']),
    status: pickFirst(row, ['order_status', 'OrderStatus', 'status', 'Status', 'delete_flag']),
    shipTo: pickFirst(row, ['ship_to_name', 'ShipToName', 'ship2_name']),
    shipVia: pickFirst(row, ['ship_via', 'ShipVia', 'carrier_id']),
    warehouse: pickFirst(row, ['source_loc_id', 'SourceLocId', 'location_id', 'LocationId']),
    projectId: pickFirst(row, ['project_id', 'ProjectId']),
    taker: pickFirst(row, ['taker', 'Taker', 'taken_by', 'TakenBy'])
  };
}

export function summarizeLine(row) {
  return {
    lineNo: pickFirst(row, ['line_no', 'LineNo', 'oe_line_number']),
    itemId: pickFirst(row, ['item_id', 'ItemId', 'inv_mast_uid']),
    description: pickFirst(row, ['item_desc', 'ItemDesc', 'extended_desc', 'ExtendedDesc', 'description']),
    qtyOrdered: pickFirst(row, ['qty_ordered', 'QtyOrdered', 'unit_quantity', 'UnitQuantity']),
    qtyShipped: pickFirst(row, ['qty_shipped', 'QtyShipped']),
    uom: pickFirst(row, ['unit_of_measure', 'UnitOfMeasure', 'sales_uom']),
    unitPrice: pickFirst(row, ['unit_price', 'UnitPrice']),
    extendedPrice: pickFirst(row, ['extended_price', 'ExtendedPrice']),
    requiredDate: pickFirst(row, ['required_date', 'RequiredDate', 'promise_date', 'PromiseDate'])
  };
}

export async function getAccessToken(baseUrl, username, password, tokenState) {
  if (!username || !password) {
    const err = new Error('P21 credentials missing.');
    err.code = 'CONFIG';
    throw err;
  }
  if (tokenState.accessToken && Date.now() < tokenState.expiresAt - 60_000) {
    return tokenState.accessToken;
  }
  const response = await fetch(`${baseUrl}/api/security/token/v2`, {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password })
  });
  if (!response.ok) {
    const err = new Error(`P21 authentication failed (${response.status}).`);
    err.code = 'AUTH';
    throw err;
  }
  const data = await response.json();
  const token = data.AccessToken || data.access_token || data.accessToken;
  if (!token) {
    const err = new Error('P21 token response missing AccessToken.');
    err.code = 'AUTH';
    throw err;
  }
  tokenState.accessToken = token;
  tokenState.expiresAt = Date.now() + Number(data.ExpiresInSeconds || data.expires_in || 3600) * 1000;
  return token;
}

export async function odataQuery(baseUrl, token, resourceType, resourceName, filter, top = 25) {
  const params = new URLSearchParams();
  if (filter) params.set('$filter', filter);
  params.set('$top', String(top));
  const url = `${baseUrl}/odataservice/odata/${resourceType}/${resourceName}?${params.toString()}`;
  const response = await fetch(url, {
    headers: { Accept: 'application/json', Authorization: `Bearer ${token}` }
  });
  if (!response.ok) {
    const text = await response.text();
    const err = new Error(`OData ${resourceName} failed (${response.status}): ${text.slice(0, 200)}`);
    err.code = response.status === 401 || response.status === 403 ? 'AUTH' : 'ODATA';
    throw err;
  }
  const data = await response.json();
  return data.value || data.d?.results || [];
}

export async function findOrderHeader(baseUrl, token, so) {
  const esc = odataEscape(so);
  const headerViews = ['p21_view_oe_hdr', 'oe_hdr'];
  const filters = [`order_no eq '${esc}'`, `po_no eq '${esc}'`, `customer_po_no eq '${esc}'`];
  if (/^\d+$/.test(so)) filters.unshift(`order_no eq ${so}`);

  for (const view of headerViews) {
    for (const filter of filters) {
      try {
        const rows = await odataQuery(baseUrl, token, 'view', view, filter, 5);
        if (rows.length) return { row: rows[0], view, matchedBy: filter.split(' ')[0] };
      } catch (e) {
        if (e.code === 'ODATA' && /404|not found/i.test(String(e.message))) continue;
        throw e;
      }
    }
  }
  return null;
}

export async function findOrderLines(baseUrl, token, orderNo) {
  if (orderNo == null || orderNo === '') return [];
  const esc = odataEscape(String(orderNo));
  const lineViews = ['p21_view_oe_line', 'p21_view_oe_detail', 'oe_line'];
  const filters = [`order_no eq '${esc}'`];
  if (/^\d+$/.test(String(orderNo))) filters.unshift(`order_no eq ${orderNo}`);

  for (const view of lineViews) {
    for (const filter of filters) {
      try {
        const rows = await odataQuery(baseUrl, token, 'view', view, filter, 100);
        if (rows.length) return rows;
      } catch (e) {
        if (e.code === 'ODATA' && /404|not found/i.test(String(e.message))) continue;
        throw e;
      }
    }
  }
  return [];
}

export async function fetchOrderInsights(config, soRaw, tokenState = { accessToken: null, expiresAt: 0 }) {
  const baseUrl = (config.baseUrl || '').replace(/\/+$/, '');
  const so = normalizeSo(soRaw);
  if (!so) {
    const err = new Error('SO number is required.');
    err.code = 'BAD_REQUEST';
    throw err;
  }

  const token = await getAccessToken(baseUrl, config.username, config.password, tokenState);
  const headerHit = await findOrderHeader(baseUrl, token, so);
  if (!headerHit) {
    return { so, found: false, message: `No Prophet21 order found for SO ${so}.`, source: 'live' };
  }

  const header = summarizeHeader(headerHit.row);
  const orderNo = header.orderNo || so;
  const lineRows = await findOrderLines(baseUrl, token, orderNo);
  const lines = lineRows.map(summarizeLine);
  return {
    so,
    found: true,
    matchedBy: headerHit.matchedBy,
    sourceView: headerHit.view,
    source: 'live',
    header,
    lines,
    summary: {
      customer: header.customerName || header.customerId || '—',
      orderDate: header.orderDate || '—',
      status: header.status ?? '—',
      poNo: header.poNo || '—',
      lineCount: lines.length,
      totalQtyOrdered: lines.reduce((sum, line) => sum + (Number(line.qtyOrdered) || 0), 0)
    }
  };
}
