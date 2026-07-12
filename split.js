// --- split.js ---

window.splitEngine = { targetId: null, total: 0, current: 0, dataArray: [], sourceItem: null };

window.openSplitPrompt = async function() {
  if (!(await window.openModal('splitPromptModal'))) return;
  window.splitEngine.targetId = window.activeReportMode ? window.reportQueue[window.reportIndex] : currentEditId;
  const countInput = $('#split_count_input');
  if (countInput) countInput.value = 2;
  window.closeModal('editModal');
};

window.submitSplitCount = async function() {
  const count = parseInt($('#split_count_input') ? $('#split_count_input').value : '', 10);
  if(isNaN(count) || count < 2) return alert("Must select at least 2 splits.");
  
  window.splitEngine.total = count;
  window.splitEngine.current = 1;
  window.splitEngine.dataArray = [];
  window.splitEngine.sourceItem = appData.staging.find(x => x.id === window.splitEngine.targetId);
  if (!window.splitEngine.sourceItem) return alert("Source entry not found.");
  
  window.closeModal('splitPromptModal');
  await window.renderSplitConfig();
};

window.renderSplitConfig = async function() {
  if (!(await window.openModal('configureSplitModal'))) return;
  const item = window.splitEngine.sourceItem;
  if (!item) return;
  if ($('#splitConfigTitle')) $('#splitConfigTitle').textContent = `Configure Split (${window.splitEngine.current} of ${window.splitEngine.total})`;
  if ($('#sp_so')) $('#sp_so').value = item.so;
  if ($('#sp_cust')) $('#sp_cust').value = item.customer;
  
  if ($('#sp_skid')) $('#sp_skid').value = 0; if ($('#sp_box')) $('#sp_box').value = 0; if ($('#sp_crate')) $('#sp_crate').value = 0;
  if ($('#sp_pipe')) $('#sp_pipe').value = 0; if ($('#sp_other')) $('#sp_other').value = 0;
  if ($('#sp_loc')) $('#sp_loc').value = ''; if ($('#sp_weight')) $('#sp_weight').value = ''; if ($('#sp_comments')) $('#sp_comments').value = '';
  if ($('#sp_status')) $('#sp_status').value = 'Partial';
  if ($('#sp_staged_by')) $('#sp_staged_by').value = currentUser ? currentUser.email.split('@')[0] : '';
};

window.saveConfigureSplit = async function() {
  const dynamicQty = window.getDynamicQty('sp');
  if (dynamicQty === 0) return alert("Error: You must add at least 1 container to confirm this split.");
  if (!$('#sp_loc').value.trim()) return alert("Error: You must assign a Location for this split.");
  
  const payload = {
    so: $('#sp_so').value.trim(), customer: $('#sp_cust').value.trim(), location: $('#sp_loc').value.trim(),
    weight: $('#sp_weight').value.trim(), status: window.getDbStatus($('#sp_status').value.trim()),
    comments: $('#sp_comments').value.trim(), staged_by: $('#sp_staged_by').value.trim() + ' (Split)',
    type: window.getDynamicType('sp'), qty: dynamicQty, photo_urls: window.splitEngine.sourceItem.photo_urls || []
  };
  
  window.splitEngine.dataArray.push(payload);
  window.splitEngine.current++;
  
  if (window.splitEngine.current > window.splitEngine.total) {
    window.closeModal('configureSplitModal');
    try {
      const { error: insErr } = await supabaseClient.from('staging').insert(window.splitEngine.dataArray);
      if(insErr) throw insErr;
      await supabaseClient.from('staging').delete().eq('id', window.splitEngine.targetId);
      
      window.logAction('staging', `Split Order SO ${payload.so} into ${window.splitEngine.total} separate entries.`);
      if(typeof window.showNotification === 'function') window.showNotification(`Order Split Successfully`);
      if (typeof window.rememberPersonBy === 'function') window.rememberPersonBy($('#sp_staged_by').value.trim());
      window.loadCloudData();
      
      if(window.activeReportMode) { window.reportRecordAction('Fixed via Split'); }
    } catch(e) { alert("Split Error: " + e.message); }
  } else {
    window.closeModal('configureSplitModal');
    setTimeout(window.renderSplitConfig, 200);
  }
};