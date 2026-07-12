window.toggleBatchMode = function() {
  window.enableBatchMode(document.getElementById('tblStaging') ? 'tblStaging' : 'tblShipped');
};

window.getBatchModalEl = function(tableId) {
  if (tableId === 'tblStagingExpanded') return document.getElementById('stagingExpandedModal');
  if (tableId === 'tblShippedExpanded') return document.getElementById('shippedExpandedModal');
  return null;
};

window.isBatchActiveFor = function(tableId) {
  return isBatchMode && batchTarget === tableId;
};

window.enableBatchMode = function(tableId) {
  if (!tableId) return;
  isBatchMode = true;
  batchTarget = tableId;
  batchSelectedIds.clear();
  document.body.classList.remove('batch-mode');
  document.getElementById('stagingExpandedModal')?.classList.remove('batch-mode');
  document.getElementById('shippedExpandedModal')?.classList.remove('batch-mode');
  const modal = window.getBatchModalEl(tableId);
  if (modal) modal.classList.add('batch-mode');
  else document.body.classList.add('batch-mode');
  window.renderTables();
};

window.enableExpandedStagingBatch = function() {
  window.enableBatchMode('tblStagingExpanded');
};

window.enableExpandedShippedBatch = function() {
  window.enableBatchMode('tblShippedExpanded');
};

window.toggleBatchSelect = function(id, isChecked) {
  if (isChecked) batchSelectedIds.add(id); else batchSelectedIds.delete(id);
};

window.batchSelectAll = function() {
  let q = '';
  if (batchTarget === 'tblStagingExpanded') {
    q = $('#searchStagingExpanded') ? $('#searchStagingExpanded').value : '';
  } else {
    q = $('#q') ? $('#q').value : '';
  }
  window.filterLogByQuickSearch(appData.staging, q).forEach(o => batchSelectedIds.add(o.id));
  window.renderTables();
};

window.batchUnselectAll = function() { batchSelectedIds.clear(); window.renderTables(); };

window.batchDelete = async function() {
  if (batchSelectedIds.size === 0) return alert("Select at least one entry to delete.");
  if (!confirm(`Are you sure you want to PERMANENTLY delete ${batchSelectedIds.size} selected entries?`)) return;
  try {
    for (let id of batchSelectedIds) {
      const target = appData.staging.find(x => x.id === id);
      if (target) window.logAction('staging', `Batch Deleted entry for SO: ${target.so}`);
      await supabaseClient.from('staging').delete().eq('id', id);
    }
    if (typeof window.showNotification === 'function') window.showNotification(`Successfully deleted ${batchSelectedIds.size} entries.`);
    window.batchCancel(); window.loadCloudData();
  } catch(e) { alert("Batch delete error: " + e.message); }
};

window.batchCancel = function() {
  isBatchMode = false;
  batchSelectedIds.clear();
  batchTarget = null;
  document.body.classList.remove('batch-mode');
  document.getElementById('stagingExpandedModal')?.classList.remove('batch-mode');
  document.getElementById('shippedExpandedModal')?.classList.remove('batch-mode');
  window.renderTables();
};

window.openSameSoModal = async function() {
  if(!currentEditId) return;
  const target = appData.staging.find(x => x.id === currentEditId);
  if(!target) return;
  if (!(await window.openModal('sameSoModal'))) return;
  window.closeModal('editModal');
  
  isSameSoMode = true; sameSoSelectedIds.clear();
  const matchingItems = appData.staging.filter(x => x.so === target.so);
  matchingItems.forEach(o => sameSoSelectedIds.add(o.id));
  
  const tBody = $('#tblSameSo tbody');
  if (!tBody) return;
  tBody.innerHTML = '';
  matchingItems.forEach(o => {
    tBody.insertAdjacentHTML('beforeend', window.buildSameSoRowHtml(o, sameSoSelectedIds.has(o.id)));
  });
};

window.toggleSameSoSelect = function(id, isChecked) { if(isChecked) sameSoSelectedIds.add(id); else sameSoSelectedIds.delete(id); };

window.sameSoSelectAll = function() {
  const target = appData.staging.find(x => x.id === currentEditId);
  appData.staging.filter(x => x.so === target.so).forEach(o => sameSoSelectedIds.add(o.id));
  window.openSameSoModal(); 
};

window.sameSoCancel = function() { isSameSoMode = false; sameSoSelectedIds.clear(); window.closeModal('sameSoModal'); };

window.openBatchConsolidateModal = async function(fromSameSo = false) {
  const selectedSet = fromSameSo ? sameSoSelectedIds : batchSelectedIds;
  if(selectedSet.size === 0) return alert("Select at least one order to consolidate.");
  
  let firstItem = null; let conflict = false; let totalSk = 0, totalBx = 0, totalCr = 0, totalPi = 0, totalOt = 0; let totalWeight = 0; let photoUrls = [];
  selectedSet.forEach(id => {
    const item = appData.staging.find(x => x.id === id); if(!item) return;
    if(!firstItem) firstItem = item; else if(item.so !== firstItem.so || item.customer !== firstItem.customer) conflict = true;
    const counts = window.parseContainerString(item.type);
    totalSk += counts.sk; totalBx += counts.bx; totalCr += counts.cr; totalPi += counts.pi; totalOt += counts.ot;
    totalWeight += parseFloat((item.weight || '0').toString().replace(/[^0-9.]/g, '')) || 0;
    if(item.photo_urls) photoUrls.push(...item.photo_urls);
  });
  
  if(conflict && !confirm("Warning: Selected orders have differing SO or Customer names. Continue?")) return;
  
  if (!(await window.openModal('batchConsolidateModal'))) return;
  if ($('#bc_so')) $('#bc_so').value = firstItem.so || '';
  if ($('#bc_cust')) $('#bc_cust').value = firstItem.customer || '';
  if ($('#bc_skid')) $('#bc_skid').value = totalSk; $('#bc_box').value = totalBx; $('#bc_crate').value = totalCr; $('#bc_pipe').value = totalPi; $('#bc_other').value = totalOt;
  $('#bc_weight').value = totalWeight > 0 ? totalWeight.toLocaleString('en-US') : '';
  $('#bc_loc').value = ''; $('#bc_comments').value = ''; $('#bc_status').value = 'Partial';
  $('#bc_staged_by').value = currentUser ? (currentUser.email.split('@')[0]) : '';
  $('#bc_photo_urls').value = JSON.stringify(photoUrls); $('#bc_source').value = fromSameSo ? 'sameso' : 'batch';
  
  if(fromSameSo) window.closeModal('sameSoModal');
};

window.executeBatchConsolidate = async function() {
  const fromSameSo = $('#bc_source').value === 'sameso'; const selectedSet = fromSameSo ? sameSoSelectedIds : batchSelectedIds;
  if(selectedSet.size === 0) return;
  const dynamicType = window.getDynamicType('bc'); const dynamicQty = window.getDynamicQty('bc'); const photoUrls = JSON.parse($('#bc_photo_urls').value || '[]');

  $('#btnConfirmBc').disabled = true; $('#btnConfirmBc').textContent = 'Consolidating...';

  try {
    const { error: insErr } = await supabaseClient.from('staging').insert([{
      so: $('#bc_so').value.trim(), customer: $('#bc_cust').value.trim(), status: window.getDbStatus($('#bc_status').value),
      location: $('#bc_loc').value.trim(), weight: $('#bc_weight').value.trim(), comments: $('#bc_comments').value.trim(), 
      staged_by: $('#bc_staged_by').value.trim() + ' (Consolidated)', type: dynamicType, qty: dynamicQty, photo_urls: photoUrls
    }]);
    if(insErr) throw insErr;
    
    for(let id of selectedSet) { await supabaseClient.from('staging').delete().eq('id', id); }
    const sourceLocs = [...new Set(Array.from(selectedSet).map(id => appData.staging.find(x => x.id === id)?.location).filter(Boolean))].join(', ') || 'Unknown';
    const targetLoc = $('#bc_loc').value.trim() || 'Unknown';
    window.logBinMovement('consolidate', `SO ${$('#bc_so').value.trim()}: merged ${selectedSet.size} entries from ${sourceLocs} to ${targetLoc}`);
    if(typeof window.showNotification === 'function') window.showNotification('Batch Consolidation Successful');
    if (typeof window.rememberPersonBy === 'function') window.rememberPersonBy($('#bc_staged_by').value.trim());
    
    window.closeModal('batchConsolidateModal');
    if(fromSameSo) window.sameSoCancel(); else window.batchCancel();
    window.loadCloudData();
    if(window.activeReportMode) { window.reportRecordAction('Fixed via Consolidation'); }
  } catch(e) { alert("Consolidation error: " + e.message); }
  
  $('#btnConfirmBc').disabled = false; $('#btnConfirmBc').textContent = 'Confirm Consolidation';
};

window.batchSelectAllShipped = function() {
  let q = '';
  if (batchTarget === 'tblShippedExpanded') {
    q = $('#searchShippedExpanded') ? $('#searchShippedExpanded').value : '';
  } else {
    q = $('#q') ? $('#q').value : '';
  }
  window.filterLogByQuickSearch(appData.shipped, q).forEach(o => batchSelectedIds.add(o.id));
  window.renderTables();
};

window.batchDeleteShipped = async function() {
  if (batchSelectedIds.size === 0) return alert("Select at least one shipped entry to delete.");
  if (!confirm(`Are you sure you want to PERMANENTLY delete ${batchSelectedIds.size} shipped entries?`)) return;
  try {
    for (let id of batchSelectedIds) {
      const target = appData.shipped.find(x => x.id === id);
      if (target) window.logAction('shipped', `Batch Deleted shipped entry for SO: ${target.so}`);
      await supabaseClient.from('shipped').delete().eq('id', id);
    }
    if (typeof window.showNotification === 'function') window.showNotification(`Successfully deleted ${batchSelectedIds.size} shipped entries.`);
    window.batchCancel(); window.loadCloudData();
  } catch(e) { alert("Batch delete error: " + e.message); }
};

window.batchUndoShipped = async function() {
  if (batchSelectedIds.size === 0) return alert("Select at least one shipped entry to undo.");
  if (!confirm(`Are you sure you want to undo ${batchSelectedIds.size} shipped entries back to Staging?`)) return;
  try {
    for (let id of batchSelectedIds) {
      const currentRecord = appData.shipped.find(x => x.id === id);
      if (!currentRecord) continue;
      
      const exists = appData.staging.some(x => x.so === currentRecord.so);
      if (exists) {
        alert(`SO Conflict: ${currentRecord.so} already exists in Staging. Skipping.`);
        continue;
      }
      
      const { error } = await supabaseClient.from('staging').insert([{ 
        so: currentRecord.so, customer: currentRecord.customer, type: currentRecord.type, qty: currentRecord.qty, location: currentRecord.location, weight: currentRecord.weight, comments: currentRecord.comments, status: 'Partial', photo_urls: currentRecord.photo_urls 
      }]);
      if(error) throw error;
      
      await supabaseClient.from('shipped').delete().eq('id', id);
      window.logBinMovement('to-staging', `SO ${currentRecord.so}: ${currentRecord.type || 'containers'} moved from Shipped Log back to Staging Log via Batch Undo${currentRecord.location ? ` (${currentRecord.location})` : ''}`);
      window.logAction('shipped', `Batch Undo Shipment Action for SO: ${currentRecord.so}`);
      window.logAction('staging', `Restored to Staging via Batch Undo for SO: ${currentRecord.so}`);
    }
    if(typeof window.showNotification === 'function') window.showNotification('Batch Undo Successful');
    window.batchCancel(); window.loadCloudData();
  } catch(e) { alert("Batch Undo Error: " + e.message); }
};
