window.toggleBatchMode = function() {
  isBatchMode = !isBatchMode; batchSelectedIds.clear();
  document.body.classList.toggle('batch-mode', isBatchMode); window.renderTables();
};

window.toggleBatchSelect = function(id, isChecked) {
  if (isChecked) batchSelectedIds.add(id); else batchSelectedIds.delete(id);
};

// Upgraded to dynamically target 'staging' OR 'shipped'
window.batchSelectAll = function(table = 'staging') {
  const q = $('#q') ? $('#q').value.toLowerCase() : '';
  const targetData = appData[table] || appData.staging;
  const fData = targetData.filter(o => (o.so||'').toLowerCase().includes(q) || (o.customer||'').toLowerCase().includes(q) || (o.location||'').toLowerCase().includes(q));
  fData.forEach(o => batchSelectedIds.add(o.id)); window.renderTables();
};

window.batchUnselectAll = function() { batchSelectedIds.clear(); window.renderTables(); };

window.batchDelete = async function(table = 'staging') {
  if (batchSelectedIds.size === 0) return alert("Select at least one entry to delete.");
  if (!confirm(`Are you sure you want to PERMANENTLY delete ${batchSelectedIds.size} selected entries?`)) return;
  try {
    for (let id of batchSelectedIds) {
      const target = appData[table].find(x => x.id === id);
      if (target) window.logAction(table, `Batch Deleted entry for SO: ${target.so}`);
      await supabaseClient.from(table).delete().eq('id', id);
    }
    if (typeof window.showNotification === 'function') window.showNotification('Batch Deletion Successful');
    window.batchUnselectAll();
    window.loadCloudData();
    if(window.activeReportMode) { window.reportRecordAction('Fixed via Deletion'); }
  } catch(e) { alert("Batch Delete Error: " + e.message); }
};

window.batchCancel = function() {
  isBatchMode = false; batchSelectedIds.clear(); document.body.classList.remove('batch-mode'); window.renderTables();
};

window.openSameSoModal = function() {
  if(!currentEditId) return; const target = appData.staging.find(x => x.id === currentEditId); if(!target) return;
  if($('#editModal')) $('#editModal').style.display = 'none';
  
  isSameSoMode = true; sameSoSelectedIds.clear();
  const matchingItems = appData.staging.filter(x => x.so === target.so); matchingItems.forEach(o => sameSoSelectedIds.add(o.id));
  
  const tBody = $('#tblSameSo tbody'); tBody.innerHTML = '';
  matchingItems.forEach(o => {
    tBody.insertAdjacentHTML('beforeend', `<tr style="color:#64748b; border-bottom:1px solid #f1f5f9;">
      <td style="text-align:center;"><input type="checkbox" style="width:18px;height:18px;" onchange="window.toggleSameSoSelect('${o.id}', this.checked)" checked></td>
      <td><b>${o.so}</b></td><td>${o.customer}</td><td>${new Date(o.entry_date).toLocaleString()}</td><td>${o.type}</td><td><b>${o.location}</b></td><td><small>${o.coords||'—'}</small></td>
      <td>${o.weight || '—'}</td><td>${o.status}</td><td>${o.staged_by||'—'}</td></tr>`);
  });
  $('#sameSoModal').style.display = 'flex';
};

window.toggleSameSoSelect = function(id, isChecked) { if(isChecked) sameSoSelectedIds.add(id); else sameSoSelectedIds.delete(id); };

window.sameSoSelectAll = function() {
  const target = appData.staging.find(x => x.id === currentEditId);
  appData.staging.filter(x => x.so === target.so).forEach(o => sameSoSelectedIds.add(o.id));
  window.openSameSoModal(); 
};

window.sameSoCancel = function() { isSameSoMode = false; sameSoSelectedIds.clear(); $('#sameSoModal').style.display = 'none'; };

window.openBatchConsolidateModal = function(fromSameSo = false) {
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
  
  $('#bc_so').value = firstItem.so || ''; $('#bc_cust').value = firstItem.customer || '';
  $('#bc_skid').value = totalSk; $('#bc_box').value = totalBx; $('#bc_crate').value = totalCr; $('#bc_pipe').value = totalPi; $('#bc_other').value = totalOt;
  $('#bc_weight').value = totalWeight > 0 ? totalWeight.toLocaleString('en-US') : '';
  $('#bc_loc').value = ''; $('#bc_coords').value = ''; $('#bc_comments').value = ''; $('#bc_status').value = 'Partial';
  $('#bc_staged_by').value = currentUser ? (currentUser.email.split('@')[0]) : '';
  $('#bc_photo_urls').value = JSON.stringify(photoUrls); $('#bc_source').value = fromSameSo ? 'sameso' : 'batch';
  
  if(fromSameSo) $('#sameSoModal').style.display = 'none'; $('#batchConsolidateModal').style.display = 'flex';
};

window.executeBatchConsolidate = async function() {
  const fromSameSo = $('#bc_source').value === 'sameso'; const selectedSet = fromSameSo ? sameSoSelectedIds : batchSelectedIds;
  if(selectedSet.size === 0) return;
  const dynamicType = window.getDynamicType('bc'); const dynamicQty = window.getDynamicQty('bc'); const photoUrls = JSON.parse($('#bc_photo_urls').value || '[]');

  $('#btnConfirmBc').disabled = true; $('#btnConfirmBc').textContent = 'Consolidating...';

  try {
    const { error: insErr } = await supabaseClient.from('staging').insert([{
      so: $('#bc_so').value.trim(), customer: $('#bc_cust').value.trim(), status: $('#bc_status').value, 
      location: $('#bc_loc').value.trim(), coords: $('#bc_coords').value.trim(), weight: $('#bc_weight').value.trim(), comments: $('#bc_comments').value.trim(), 
      staged_by: $('#bc_staged_by').value.trim() + ' (Consolidated)', type: dynamicType, qty: dynamicQty, photo_urls: photoUrls
    }]);
    if(insErr) throw insErr;
    
    for(let id of selectedSet) { await supabaseClient.from('staging').delete().eq('id', id); }
    window.logAction('staging', `Batch Consolidated ${selectedSet.size} entries into new SO: ${$('#bc_so').value.trim()}`);
    if(typeof window.showNotification === 'function') window.showNotification('Batch Consolidation Successful');
    
    $('#batchConsolidateModal').style.display = 'none';
    if(fromSameSo) window.sameSoCancel(); else window.batchCancel();
    window.loadCloudData();
    if(window.activeReportMode) { window.reportRecordAction('Fixed via Consolidation'); }
  } catch(e) { alert("Consolidation error: " + e.message); }
  
  $('#btnConfirmBc').disabled = false; $('#btnConfirmBc').textContent = 'Confirm Consolidation';
};

// NEW: Batch Undo for Shipped Logs
window.batchUndo = async function() {
  if (batchSelectedIds.size === 0) return alert("Select at least one shipped entry to undo.");
  if (!confirm(`Are you sure you want to undo ${batchSelectedIds.size} shipped entries back to Staging?`)) return;
  try {
    for (let id of batchSelectedIds) {
      const currentRecord = appData.shipped.find(x => x.id === id);
      if (!currentRecord) continue;
      
      const proceed = await window.checkSoConflict(currentRecord.so, null);
      if(!proceed) return; 
      
      const { error } = await supabaseClient.from('staging').insert([{ 
        so: currentRecord.so, customer: currentRecord.customer, type: currentRecord.type, qty: currentRecord.qty, location: currentRecord.location, coords: currentRecord.coords, weight: currentRecord.weight, comments: currentRecord.comments, status: 'Partial', photo_urls: currentRecord.photo_urls 
      }]);
      if(error) throw error;
      
      await supabaseClient.from('shipped').delete().eq('id', id);
      window.logAction('shipped', `Batch Undo Shipment Action for SO: ${currentRecord.so}`);
      window.logAction('staging', `Restored to Staging via Batch Undo for SO: ${currentRecord.so}`);
    }
    if(typeof window.showNotification === 'function') window.showNotification('Batch Undo Successful');
    window.batchUnselectAll();
    window.loadCloudData();
  } catch(e) { alert("Batch Undo Error: " + e.message); }
};
