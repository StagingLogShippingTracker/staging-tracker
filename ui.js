window.getUrgencyWeight = function(dbStatus) {
  const s = window.getFormattedStatus(dbStatus).toLowerCase();
  if (s.includes('today')) return 50;
  if (s.includes('tomorrow')) return 40;
  if (s.includes('partial')) return 30;
  if (s.includes('future')) return 20;
  if (s.includes('corp pick')) return 10;
  return 0; // Awaiting Instructions
};

window.adjustCount = function(id, amt) { if($('#'+id)) $('#'+id).value = Math.max(0, (parseInt($('#'+id).value)||0) + amt); };
window.adjustEditCount = function(id, amt) { window.adjustCount(id, amt); };

window.formatWeight = function(input) {
  let value = input.value.replace(/[^0-9.]/g, ''); let parts = value.split('.');
  if (parts[0]) parts[0] = parseInt(parts[0], 10).toLocaleString('en-US');
  input.value = parts.slice(0, 2).join('.');
};

window.formatContainer = function(count, type) {
  if(!count || count === 0) return '';
  if(count === 1) return `1 ${type}`;
  if(type === 'Box') return `${count} Boxes`;
  if(type === 'Pipe/Rod' || type === 'Other') return `${count} ${type}`;
  return `${count} ${type}s`;
};

window.parseContainerString = function(typeStr) {
  let sk = 0, bx = 0, cr = 0, pi = 0, ot = 0; if(!typeStr) return { sk, bx, cr, pi, ot };
  const matchSk = typeStr.match(/(\d+)\s*Skid/); if(matchSk) sk = parseInt(matchSk[1]);
  const matchBx = typeStr.match(/(\d+)\s*Box/);  if(matchBx) bx = parseInt(matchBx[1]);
  const matchCr = typeStr.match(/(\d+)\s*Crate/);if(matchCr) cr = parseInt(matchCr[1]);
  const matchPi = typeStr.match(/(\d+)\s*Pipe\/Rod/);if(matchPi) pi = parseInt(matchPi[1]);
  const matchOt = typeStr.match(/(\d+)\s*Other/);if(matchOt) ot = parseInt(matchOt[1]);
  return { sk, bx, cr, pi, ot };
};

window.getDynamicType = function(prefix) {
  const sk = parseInt($(`#${prefix}_skid`) ? $(`#${prefix}_skid`).value : 0)||0;
  const bx = parseInt($(`#${prefix}_box`) ? $(`#${prefix}_box`).value : 0)||0;
  const cr = parseInt($(`#${prefix}_crate`) ? $(`#${prefix}_crate`).value : 0)||0;
  const pi = parseInt($(`#${prefix}_pipe`) ? $(`#${prefix}_pipe`).value : 0)||0;
  const ot = parseInt($(`#${prefix}_other`) ? $(`#${prefix}_other`).value : 0)||0;
  let typeParts = []; 
  if(sk) typeParts.push(window.formatContainer(sk, 'Skid'));
  if(bx) typeParts.push(window.formatContainer(bx, 'Box'));
  if(cr) typeParts.push(window.formatContainer(cr, 'Crate'));
  if(pi) typeParts.push(window.formatContainer(pi, 'Pipe/Rod'));
  if(ot) typeParts.push(window.formatContainer(ot, 'Other'));
  return typeParts.join(', ') || '1 Skid';
};

window.getDynamicQty = function(prefix) {
  const sk = parseInt($(`#${prefix}_skid`) ? $(`#${prefix}_skid`).value : 0)||0;
  const bx = parseInt($(`#${prefix}_box`) ? $(`#${prefix}_box`).value : 0)||0;
  const cr = parseInt($(`#${prefix}_crate`) ? $(`#${prefix}_crate`).value : 0)||0;
  const pi = parseInt($(`#${prefix}_pipe`) ? $(`#${prefix}_pipe`).value : 0)||0;
  const ot = parseInt($(`#${prefix}_other`) ? $(`#${prefix}_other`).value : 0)||0;
  return sk+bx+cr+pi+ot;
};

window.sortStagingEntries = function(entries, sortMode) {
  const sorted = [...entries];
  sorted.sort((a, b) => {
    if (sortMode === 'date_desc') return new Date(b.entry_date) - new Date(a.entry_date);
    if (sortMode === 'date_asc') return new Date(a.entry_date) - new Date(b.entry_date);
    if (sortMode === 'customer') return (a.customer||'').localeCompare(b.customer||'');
    if (sortMode === 'location') return (a.location||'').localeCompare(b.location||'');
    if (sortMode === 'status') return window.getFormattedStatus(a.status).localeCompare(window.getFormattedStatus(b.status));
    if (sortMode === 'so') return (a.so||'').localeCompare(b.so||'');
    const uA = window.getUrgencyWeight(a.status);
    const uB = window.getUrgencyWeight(b.status);
    if (uA !== uB) return uB - uA;
    return new Date(b.entry_date) - new Date(a.entry_date);
  });
  return sorted;
};

window.STAGING_STATUS_COLORS = [
  { match: 'partial', label: 'Partial', color: '#ffedd5' },
  { match: 'today', label: 'Ship Today', color: '#fee2e2' },
  { match: 'tomorrow', label: 'Ship Tomorrow', color: '#fef9c3' },
  { match: 'future', label: 'Ship On Future Date', color: '#dbeafe' },
  { match: 'corp pick', label: 'Corp Pick', color: '#dcfce7' },
  { match: 'customer pick', label: 'Customer Pick-Up', color: '#f3e8ff' },
];

window.getRowColor = function(dbStatus) {
  const s = window.getFormattedStatus(dbStatus).toLowerCase();
  for (const item of window.STAGING_STATUS_COLORS) {
    if (s.includes(item.match)) return item.color;
  }
  return '';
};

window.labeledCell = function(label, content, className = '', style = '') {
  const cls = className ? ` class="${className}"` : '';
  const sty = style ? ` style="${style}"` : '';
  return `<td data-label="${label}"${cls}${sty}>${content}</td>`;
};

window.toggleQuickActions = function(btn) {
  const panel = document.querySelector('.quick-search-actions');
  if (!panel) return;
  const open = panel.classList.toggle('is-open');
  if (btn) btn.setAttribute('aria-expanded', open ? 'true' : 'false');
};

window.renderStagingStatusLegend = function() {
  const el = document.getElementById('stagingStatusLegend');
  if (!el) return;
  const items = [
    ...window.STAGING_STATUS_COLORS,
    { label: 'Awaiting Instructions', color: '#ffffff' },
  ];
  el.innerHTML = items.map(({ label, color }) =>
    `<span class="staging-status-legend__item"><span class="staging-status-legend__swatch" style="background:${color};"></span>${label}</span>`
  ).join('');
};

window.renderTables = function() {
  const q = $('#q') ? $('#q').value.toLowerCase() : ''; const canEdit = !!currentUser;
  const fStaging = appData.staging.filter(o => (o.so||'').toLowerCase().includes(q) || (o.customer||'').toLowerCase().includes(q) || (o.location||'').toLowerCase().includes(q));
  const sortMode = $('#sortToggle') ? $('#sortToggle').value : 'urgency';
  const sortedStaging = window.sortStagingEntries(fStaging, sortMode);
  const fShipped = appData.shipped.filter(o => (o.so||'').toLowerCase().includes(q) || (o.customer||'').toLowerCase().includes(q) || (o.location||'').toLowerCase().includes(q));

  if($('#tblStaging')) {
    const sBody = $('#tblStaging').querySelector('tbody'); 
    if(sBody) {
      sBody.innerHTML = ''; const limitStaging = $('#stageLimitNotice') ? 20 : 999999;
      // Inject dynamic CSS to ensure cell backgrounds don't hide the row color, 
      // while safely preserving the hover-darken effect using a CSS overlay gradient
      if (!document.getElementById('status-row-styles')) {
        document.head.insertAdjacentHTML('beforeend', `<style id="status-row-styles">
          tr.status-row td { background-color: inherit !important; }
          tr.status-row:hover td { background-image: linear-gradient(rgba(0,0,0,0.04), rgba(0,0,0,0.04)) !important; }
        </style>`);
      }

      sortedStaging.slice(0, limitStaging).forEach(o => {
        const picBtn = (o.photo_urls && o.photo_urls.length > 0) ? `<button class="btn" style="padding:4px 8px; font-size:12px; margin-right:4px; height:auto;" onclick="window.openPhotoViewer('${o.id}')">View</button>` : '';
        const editBtn = canEdit ? `<button class="btn-edit" onclick="window.openUniversalEditor('staging', '${o.id}')">Edit</button>` : `<span style="color:#94a3b8; font-size:11px;">Read-Only</span>`;
        const chkBox = canEdit ? `<input type="checkbox" onchange="if(this.checked){ window.triggerShipModal('${o.id}'); this.checked=false; }">` : `<span style="color:#9ca3af;">—</span>`;
        const commentBtn = o.comments ? `<button class="btn" style="padding:4px 8px; font-size:12px; background:#8b5cf6; color:#fff; height:auto;" onclick="window.openCommentModal('staging', '${o.id}')">See</button>` : (canEdit ? `<button class="btn" style="padding:4px 8px; font-size:12px; background:#e2e8f0; color:#475569; height:auto;" onclick="window.openCommentModal('staging', '${o.id}')">Add</button>` : `<span style="color:#9ca3af;">—</span>`);
        const batchChk = `<input type="checkbox" style="width:18px;height:18px;" onchange="window.toggleBatchSelect('${o.id}', this.checked)" ${batchSelectedIds.has(o.id) ? 'checked' : ''}>`;

        const rowBg = window.getRowColor(o.status);
        const trClass = rowBg ? `class="status-row"` : '';
        const trStyle = rowBg ? `style="background-color: ${rowBg};"` : '';
        const stickyStyle = rowBg ? `background-color: inherit;` : `background:#f8fafc;`;

        sBody.insertAdjacentHTML('beforeend', `<tr ${trClass} ${trStyle}>
          ${window.labeledCell('Select', batchChk, 'show-in-batch', 'text-align:center;')}
          ${window.labeledCell('Edit', editBtn, 'hide-in-batch')}
          ${window.labeledCell('Photo(s)', picBtn, 'hide-in-batch')}
          ${window.labeledCell('SO', `<a class="so-link" onclick="event.stopPropagation(); window.openOrderHistory('${o.so}')">${o.so}</a>`)}
          ${window.labeledCell('Customer', o.customer)}
          ${window.labeledCell('Entry Date', new Date(o.entry_date).toLocaleString(), 'col-low-priority')}
          ${window.labeledCell('Containers', o.type)}
          ${window.labeledCell('Location', `<b>${o.location}</b>`)}
          ${window.labeledCell('Weight', o.weight || '—')}
          ${window.labeledCell('Comments', commentBtn, 'hide-in-batch')}
          ${window.labeledCell('Status', `<span style="font-weight:bold; color:#475569;">${window.getFormattedStatus(o.status)}</span>`)}
          ${window.labeledCell('Staged By', o.staged_by || '—', 'col-low-priority')}
          ${window.labeledCell('Ship', chkBox, 'hide-in-batch', `text-align:center; ${stickyStyle} border-left:1px solid #e2e8f0;`)}
        </tr>`);
      });
    }
  }

  if($('#tblShipped')) {
    const shBody = $('#tblShipped').querySelector('tbody'); 
    if(shBody) {
      shBody.innerHTML = ''; const limitShipped = $('#shippedLimitNotice') ? 20 : 999999;
      fShipped.slice(0, limitShipped).forEach(o => {
        const isRet = (o.carrier === 'RETURNED TO STOCK' || o.carrier === 'CONSOLIDATED'); const rowClass = isRet ? 'class="grey-strike"' : '';
        const picBtn = (o.photo_urls && o.photo_urls.length > 0) ? `<button class="btn" style="padding:4px 8px; font-size:12px; margin-right:4px; height:auto;" onclick="window.openPhotoViewer('${o.id}')">View</button>` : '';
        const editBtn = canEdit ? `<button class="btn-edit" onclick="window.openUniversalEditor('shipped', '${o.id}')">Edit</button>` : `<span style="color:#94a3b8; font-size:11px;">Read-Only</span>`;
        const commentBtn = o.comments ? `<button class="btn" style="padding:4px 8px; font-size:12px; background:#8b5cf6; color:#fff; height:auto;" onclick="window.openCommentModal('shipped', '${o.id}')">See</button>` : (canEdit ? `<button class="btn" style="padding:4px 8px; font-size:12px; background:#e2e8f0; color:#475569; height:auto;" onclick="window.openCommentModal('shipped', '${o.id}')">Add</button>` : `<span style="color:#9ca3af;">—</span>`);

        const batchChk = `<input type="checkbox" style="width:18px;height:18px;" onchange="window.toggleBatchSelect('${o.id}', this.checked)" ${batchSelectedIds.has(o.id) ? 'checked' : ''}>`;

        shBody.insertAdjacentHTML('beforeend', `<tr ${rowClass}>
          ${window.labeledCell('Select', batchChk, 'show-in-batch', 'text-align:center;')}
          ${window.labeledCell('Edit', editBtn, 'hide-in-batch')}
          ${window.labeledCell('Photo(s)', picBtn, 'hide-in-batch')}
          ${window.labeledCell('SO', `<a class="so-link" onclick="event.stopPropagation(); window.openOrderHistory('${o.so}')">${o.so}</a>`)}
          ${window.labeledCell('Customer', o.customer)}
          ${window.labeledCell('Containers', o.type)}
          ${window.labeledCell('Carrier', `<b>${o.carrier || '—'}</b>`)}
          ${window.labeledCell('Location', o.location)}
          ${window.labeledCell('Weight', o.weight || '—')}
          ${window.labeledCell('Comments', commentBtn)}
          ${window.labeledCell('Shipped At', new Date(o.shipped_at).toLocaleString(), 'col-low-priority')}
          ${window.labeledCell('Shipped By', o.shipped_by || '—', 'col-low-priority')}
          ${window.labeledCell("PM'd Email", o.pmd_email ? o.pmd_email + (isRet ? '' : '<span class="green-check"> ✓</span>') : '—', 'col-low-priority')}
        </tr>`);
      });
    }
  }

  const sumByType = t => appData.staging.reduce((acc, c) => {
    if (!c.type?.includes(t)) return acc;
    const m = c.type.match(new RegExp(`(\\d+)\\s*${t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`));
    return acc + (parseInt(m?.[1], 10) || 0);
  }, 0);
  const uniqueSOs = new Set(appData.staging.map(o => o.so).filter(x => x !== null && x !== ''));
  
  if($('#kOrders')) $('#kOrders').textContent = uniqueSOs.size; 
  if($('#kContainers')) $('#kContainers').textContent = appData.staging.reduce((acc, c) => acc + (parseInt(c.qty) || 0), 0);
  if($('#kSkids')) $('#kSkids').textContent = sumByType('Skid'); 
  if($('#kBoxes')) $('#kBoxes').textContent = sumByType('Box'); 
  if($('#kCrates')) $('#kCrates').textContent = sumByType('Crate'); 
  if($('#kPipe')) $('#kPipe').textContent = sumByType('Pipe/Rod'); 
  if($('#kOther')) $('#kOther').textContent = sumByType('Other');
  if($('#kShipped')) $('#kShipped').textContent = appData.shipped.filter(x => x.carrier !== 'RETURNED TO STOCK' && x.carrier !== 'CONSOLIDATED').length;
};

window.openUniversalEditor = function(table, id) {
  const o = appData[table].find(x => x.id === id); if (!o) return;
  
  // STRIPPED WINDOW PREFIXES
  currentEditId = o.id; 
  editTargetRecord = { table: table, id: o.id, so: o.so, photo_urls: o.photo_urls || [] };
  
  const isRet = (table === 'shipped' && (o.carrier === 'RETURNED TO STOCK' || o.carrier === 'CONSOLIDATED'));
  
  if($('#e_so')) $('#e_so').value = o.so; if($('#e_cust')) $('#e_cust').value = o.customer;   if($('#e_loc')) $('#e_loc').value = o.location || ''; 
  if($('#e_weight')) $('#e_weight').value = o.weight || ''; if($('#e_comments')) $('#e_comments').value = o.comments || '';
  
  const counts = window.parseContainerString(o.type);
  if($('#e_skid')) $('#e_skid').value = counts.sk; if($('#e_box')) $('#e_box').value = counts.bx; if($('#e_crate')) $('#e_crate').value = counts.cr;
  if($('#e_pipe')) $('#e_pipe').value = counts.pi; if($('#e_other')) $('#e_other').value = counts.ot;
  
  const inputsToLock = ['e_so','e_cust','e_loc','e_weight','e_comments','e_status','e_staged_by','e_carrier','e_shipped_by','e_pm'];
  inputsToLock.forEach(i => { if($(`#${i}`)) $(`#${i}`).disabled = isRet; });
  document.querySelectorAll('#editModal .counter-btn').forEach(b => b.disabled = isRet);
  document.querySelectorAll('#editPhotoSection .photo-uploader').forEach(b => b.style.display = isRet ? 'none' : 'block');
  
  if($('#editPhotoSection')) $('#editPhotoSection').style.display = 'flex';
  if($('#editDelBtn')) $('#editDelBtn').style.display = 'block';
  
  if (table === 'staging') {
    if($('#editModalTitle')) $('#editModalTitle').textContent = 'Edit Staging Entry'; 
    if($('#editStagingFields')) $('#editStagingFields').style.display = 'block';
    if($('#editShippedFields')) $('#editShippedFields').style.display = 'none'; 
    if($('#editUndoBtn')) $('#editUndoBtn').style.display = 'none'; 
    if($('#editReturnBtn')) $('#editReturnBtn').style.display = 'block'; 
    if($('#editConsolidateBtn')) $('#editConsolidateBtn').style.display = 'block';
    if($('#editSplitBtn')) $('#editSplitBtn').style.display = 'block';
    if($('#editSaveBtn')) $('#editSaveBtn').style.display = 'block';
    if($('#e_status')) {
      const formatted = window.getFormattedStatus(o.status);
      if (!Array.from($('#e_status').options).some(opt => opt.value === formatted)) {
        $('#e_status').insertAdjacentHTML('beforeend', `<option value="${formatted}">${formatted}</option>`);
      }
      $('#e_status').value = formatted;
    }
    if($('#e_staged_by')) $('#e_staged_by').value = o.staged_by || '';
  } else {
    if($('#editModalTitle')) $('#editModalTitle').textContent = isRet ? 'View Locked Record' : 'Edit Shipped Entry Logs'; 
    if($('#editStagingFields')) $('#editStagingFields').style.display = 'none'; 
    if($('#editShippedFields')) $('#editShippedFields').style.display = 'block'; 
    if($('#editUndoBtn')) $('#editUndoBtn').style.display = 'block'; 
    if($('#editReturnBtn')) $('#editReturnBtn').style.display = 'none'; 
    if($('#editConsolidateBtn')) $('#editConsolidateBtn').style.display = 'none';
    if($('#editSplitBtn')) $('#editSplitBtn').style.display = 'none';
    if($('#editSaveBtn')) $('#editSaveBtn').style.display = isRet ? 'none' : 'block';
    if($('#e_carrier')) $('#e_carrier').value = o.carrier || ''; 
    if($('#e_shipped_by')) $('#e_shipped_by').value = o.shipped_by || ''; 
    if($('#e_pm')) $('#e_pm').value = o.pmd_email || '';
  }
  
  window.renderEditPhotoStrip();
  if($('#editModal')) $('#editModal').style.display = 'flex';
};

window.triggerReturnModal = function() {
  if($('#returnModal')) $('#returnModal').style.display = 'flex'; if($('#editModal')) $('#editModal').style.display = 'none';
  if($('#r_picked_by')) $('#r_picked_by').value = ''; if($('#r_returned_by')) $('#r_returned_by').value = ''; if($('#r_reason')) $('#r_reason').value = ''; 
  if($('#r_pm_chk')) $('#r_pm_chk').checked = false; window.togglePMEmail(false, 'r_pm_email', 'r_pm_email_btn'); if($('#r_pm_email')) $('#r_pm_email').value = ''; 
};

window.openCommentModal = function(table, id) {
  const o = appData[table].find(x => x.id === id); if(!o) return; 
  
  // STRIPPED WINDOW PREFIX
  currentCommentTarget = { table: table, id: id };
  
  if($('#quick_comments')) { $('#quick_comments').value = o.comments || ''; $('#quick_comments').disabled = !currentUser; }
  if($('#saveCommentBtn')) $('#saveCommentBtn').style.display = currentUser ? 'block' : 'none';
  if($('#commentModal')) $('#commentModal').style.display = 'flex';
};

window.togglePMEmail = function(isChecked, inputId, btnId) {
  if($('#'+inputId)) $('#'+inputId).disabled = !isChecked; if($('#'+btnId)) $('#'+btnId).disabled = !isChecked;
};

window.triggerShipModal = function(id) {
  const item = appData.staging.find(x => x.id === id); if (!item) return; 
  
  // STRIPPED WINDOW PREFIXES
  activeShipTargetItem = item; 
  if($('#photoPreviewStrip')) $('#photoPreviewStrip').innerHTML = ''; 
  selectedPhotoBlobs = [];
  
  if($('#m_so')) $('#m_so').value = item.so; if($('#m_cust')) $('#m_cust').value = item.customer; if($('#m_qty')) $('#m_qty').value = item.type;
  if($('#m_carrier')) $('#m_carrier').value = ''; if($('#m_loc')) $('#m_loc').value = item.location; if($('#m_weight')) $('#m_weight').value = item.weight || '—'; if($('#m_by')) $('#m_by').value = '';
  
  if($('#m_comments')) $('#m_comments').value = item.comments || ''; 
  
  if($('#m_pm_chk')) $('#m_pm_chk').checked = false; window.togglePMEmail(false, 'm_pm_email', 'm_pm_email_btn'); if($('#m_pm_email')) $('#m_pm_email').value = '';
  if($('#shipModal')) $('#shipModal').style.display = 'flex';
  window.renderPhotoStrip();
};

window.closeShipModal = function() { if($('#shipModal')) $('#shipModal').style.display = 'none'; window.loadCloudData(); };

window.openOrdersModal = function() {
  if(!$('#ordersModal')) return; const tbody = $('#tblOrders tbody'); if(!tbody) return; tbody.innerHTML = '';
  if($('#searchOrdersModal')) $('#searchOrdersModal').value = '';
  
  const groups = {};
  appData.staging.forEach(o => { const key = o.so || 'Unknown SO'; if(!groups[key]) groups[key] = []; groups[key].push(o); });
  
  Object.keys(groups).forEach(so => {
    groups[so].sort((a,b) => new Date(b.entry_date) - new Date(a.entry_date));
    const safeId = so.replace(/[^a-zA-Z0-9]/g, '_'); const allCustomers = groups[so].map(x => x.customer).join(' ');
    
    tbody.insertAdjacentHTML('beforeend', `
      <tr class="group-header-row" data-so="${so}" data-cust="${allCustomers}" data-safeid="${safeId}" style="cursor:pointer; background:#f8fafc;" onclick="window.toggleOrderGroup('${safeId}')">
        <td style="padding: 12px; border-bottom:1px solid #e2e8f0;"><span id="icon_so_${safeId}" style="display:inline-block; width:16px; font-weight:900; color:#64748b;">+</span> <a class="so-link" onclick="event.stopPropagation(); window.openOrderHistory('${so}')">${so}</a></td>
        <td colspan="3" style="text-align:right; font-size:12px; color:#64748b; padding: 12px; border-bottom:1px solid #e2e8f0;">${groups[so].length} Staging Entry(s)</td>
      </tr>
    `);
    
    groups[so].forEach(o => {
      tbody.insertAdjacentHTML('beforeend', `
        <tr class="sub_so_${safeId}" style="display:none; font-size:12px; background:#fff;">
          <td style="padding: 10px 12px 10px 24px; color:#475569; border-bottom:1px solid #f1f5f9;">↳ ${o.customer}</td>
          <td style="padding: 10px 12px; border-bottom:1px solid #f1f5f9; white-space: nowrap;">${o.type}</td>
          <td style="padding: 10px 12px; border-bottom:1px solid #f1f5f9; white-space: nowrap;"><b>${o.location}</b></td>
          <td style="padding: 10px 12px; border-bottom:1px solid #f1f5f9; color:#64748b; text-align:right; white-space:nowrap;">${new Date(o.entry_date).toLocaleString()}</td>
        </tr>
      `);
    });
  });
  $('#ordersModal').style.display = 'flex';
};

window.filterOrdersModal = function() {
  const q = $('#searchOrdersModal').value.toLowerCase();
  document.querySelectorAll('.group-header-row').forEach(tr => {
    const match = tr.getAttribute('data-so').toLowerCase().includes(q) || tr.getAttribute('data-cust').toLowerCase().includes(q);
    tr.style.display = match ? 'table-row' : 'none';
    const safeId = tr.getAttribute('data-safeid');
    if(!match) {
      document.querySelectorAll('.sub_so_' + safeId).forEach(r => r.style.display = 'none');
      const icon = document.getElementById('icon_so_' + safeId); if(icon) icon.textContent = '+';
    }
  });
};

window.toggleOrderGroup = function(safeId) {
   const rows = document.querySelectorAll('.sub_so_' + safeId);
   const icon = document.getElementById('icon_so_' + safeId);
   let isHidden = false; if(rows.length > 0) isHidden = rows[0].style.display === 'none';
   rows.forEach(r => r.style.display = isHidden ? 'table-row' : 'none');
   if(icon) icon.textContent = isHidden ? '-' : '+';
};

window.showNotification = function(message) {
  let container = $('#toast-container');
  if (!container) { container = document.createElement('div'); container.id = 'toast-container'; document.body.appendChild(container); }
  const toast = document.createElement('div'); toast.className = 'toast-msg'; toast.textContent = message;
  container.appendChild(toast);
  requestAnimationFrame(() => toast.classList.add('show'));
  setTimeout(() => { toast.classList.remove('show'); setTimeout(() => toast.remove(), 300); }, 3000);
};

// NEW: Audio Synthesizer Chime
window.playSuccessChime = function() {
  try {
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.type = 'sine';
    osc.frequency.setValueAtTime(1046.50, ctx.currentTime); // High C
    gain.gain.setValueAtTime(0.4, ctx.currentTime); // Increased volume
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.5);
    osc.start();
    osc.stop(ctx.currentTime + 0.5);
  } catch(e) { console.warn("Audio chime disabled or unsupported:", e); }
};

window.toggleMenu = function(e) {
  e.stopPropagation(); const content = e.currentTarget.nextElementSibling; content.classList.toggle('show-menu');
};

document.addEventListener('click', function(e) {
  if (!e.target.matches('.hamburger-btn')) { document.querySelectorAll('.dropdown-content.show-menu').forEach(menu => { menu.classList.remove('show-menu'); }); }
});

window.getFormattedStatus = function(dbStatus) {
  if (/^\d{4}-\d{2}-\d{2}$/.test(dbStatus)) {
    const todayStr = new Date().toLocaleDateString('en-CA'); 
    const tmrw = new Date(); tmrw.setDate(tmrw.getDate() + 1);
    const tmrwStr = tmrw.toLocaleDateString('en-CA');
    
    if (dbStatus <= todayStr) return "Ship Today";
    if (dbStatus === tmrwStr) return "Ship Tomorrow";
  }
  return dbStatus;
};

window.getDbStatus = function(uiStatus) {
   const todayStr = new Date().toLocaleDateString('en-CA');
   const tmrw = new Date(); tmrw.setDate(tmrw.getDate() + 1);
   const tmrwStr = tmrw.toLocaleDateString('en-CA');

   if (uiStatus === 'Ship Today') return todayStr;
   if (uiStatus === 'Ship Tomorrow') return tmrwStr;
   return uiStatus; 
};

window.activeStatusDropdownId = null;
document.addEventListener('change', function(e) {
  if (e.target.tagName === 'SELECT' && e.target.id.includes('status') && e.target.value === 'Ship On Future Date') {
    window.activeStatusDropdownId = e.target.id;
    const todayStr = new Date().toLocaleDateString('en-CA');
    if($('#fd_datePicker')) {
      $('#fd_datePicker').min = todayStr; $('#fd_datePicker').value = todayStr;
      $('#fd_datePicker').disabled = false; $('#fd_tbd').checked = false;
    }
    if($('#futureDateModal')) $('#futureDateModal').style.display = 'flex';
  }
});

window.cancelDateModal = function() {
  if($('#futureDateModal')) $('#futureDateModal').style.display = 'none';
  if(window.activeStatusDropdownId && $('#' + window.activeStatusDropdownId)) $('#' + window.activeStatusDropdownId).value = 'Partial';
};

window.confirmDateModal = function() {
  const isTbd = $('#fd_tbd').checked; const dateVal = $('#fd_datePicker').value;
  if(!isTbd && !dateVal) return alert("Please select a date or check TBD.");
  const finalVal = isTbd ? 'TBD' : dateVal;
  const sel = $('#' + window.activeStatusDropdownId);
  if (!Array.from(sel.options).some(opt => opt.value === finalVal)) {
    sel.insertAdjacentHTML('beforeend', `<option value="${finalVal}">${finalVal}</option>`);
  }
  sel.value = finalVal;
  if($('#futureDateModal')) $('#futureDateModal').style.display = 'none';
};
