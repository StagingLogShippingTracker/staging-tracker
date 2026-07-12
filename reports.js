// --- reports.js ---
window.activeReportMode = false;
window.currentReportFilter = 'all'; 
window.reportQueue = [];
window.reportIndex = 0;
window.reportResults = [];
window.reportPhotoBlobs = [];

window.startStagingReport = async function(mode) {
  const saved = localStorage.getItem('swift_report_state');
  if(saved) {
    try {
      const state = JSON.parse(saved);
      if(state.queue && state.queue.length > 0 && state.index < state.queue.length) {
        window.pendingReportMode = mode;
        if($('#reportResumeModal')) await window.openModal('reportResumeModal', { requireShared: false });
        return;
      }
    } catch(e) {}
  }
  window.initStagingReport(mode);
};

function locSortKey(loc) {
  const l = (loc || '').toUpperCase();
  
  if (l.includes('PARTIAL BOX SHELF')) return [2, l];
  if (l.includes('BOX SHELF') && !l.includes('SHIPPING')) return [1, l];
  
  const aisleMatch = l.match(/^([A-Z])-(\d{2})-([A-Z])-(1|2|1\+2)$/);
  if (aisleMatch) {
    let suffix = aisleMatch[4] === '1' ? 1 : (aisleMatch[4] === '2' ? 2 : 3);
    return [3, aisleMatch[1], parseInt(aisleMatch[2], 10), aisleMatch[3], suffix];
  }
  
  if (l.includes('SOUTH WALL')) return [4, l];
  if (l.match(/^W-\d+/) || l.includes('SHIPPING')) return [5, l];
  if (l.includes('CORP DROP')) return [6, l];
  return [7, l];
}

window.resumeStagingReport = function() {
  const state = JSON.parse(localStorage.getItem('swift_report_state'));
  window.reportQueue = state.queue;
  window.reportIndex = state.index;
  window.reportResults = state.results || [];
  window.currentReportFilter = state.filter || 'all';
  window.activeReportMode = true;
  if($('#reportResumeModal')) window.closeModal('reportResumeModal');
  window.renderNextReportItem();
};

window.initStagingReport = function(mode = 'all') {
  if(!mode && window.pendingReportMode) mode = window.pendingReportMode;
  window.currentReportFilter = mode; 
  const aisleRegex = /^([A-Z])-\d{2}-([A-Z])-(1|2|1\+2)$/i;
  
  let sourceData = appData.staging;
  if (mode === 'aisle') sourceData = sourceData.filter(x => aisleRegex.test(x.location||''));
  else if (mode === 'non_aisle') sourceData = sourceData.filter(x => !aisleRegex.test(x.location||''));
  else if (mode === 'discrepancies') sourceData = sourceData.filter(x => window.discrepancyList.includes(x.id));

  let sorted = [...sourceData].sort((a, b) => {
    const keyA = locSortKey(a.location), keyB = locSortKey(b.location);
    if (keyA[0] !== keyB[0]) return keyA[0] - keyB[0];
    if (keyA[0] === 1) return (a.location||'').localeCompare(b.location||''); 
    if (keyA[1] !== keyB[1]) return keyA[1].localeCompare(keyB[1]);
    if (keyA[2] !== keyB[2]) return keyA[2] - keyB[2];
    if (keyA[3] !== keyB[3]) return keyA[3].localeCompare(keyB[3]);
    return keyA[4] - keyB[4];
  });
  
  window.reportQueue = sorted.map(x => x.id);
  window.reportIndex = 0;
  window.reportResults = [];
  window.activeReportMode = true;
  window.saveReportState();
  if($('#reportResumeModal')) window.closeModal('reportResumeModal');
  window.renderNextReportItem();
};

window.saveReportState = function() {
  localStorage.setItem('swift_report_state', JSON.stringify({queue: window.reportQueue, index: window.reportIndex, results: window.reportResults, filter: window.currentReportFilter}));
};

window.pauseReport = function() {
  if (!window.activeReportMode) return;
  window.saveReportState();
};

window.closeReportMainModal = function() {
  window.closeModal('reportMainModal');
  if (typeof window.pauseReport === 'function') window.pauseReport();
};

window.downloadCSV = function(data, filename) {
  const headers = ['SO', 'Customer', 'Location', 'Entry Date', 'Result'];
  let csv = headers.join(',') + '\n';
  data.forEach(r => { csv += `"${r.so||''}","${r.customer||''}","${r.location||''}","${r.date||''}","${r.result||''}"\n`; });
  const blob = new Blob([csv], { type: 'text/csv' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  a.click();
};

window.renderNextReportItem = async function() {
  if(!window.activeReportMode) return;
  document.querySelectorAll('.modal-overlay').forEach(m => {
    const open = m.classList.contains('is-open') || window.getComputedStyle(m).display === 'flex';
    if (!open) return;
    if (m.id && typeof window.closeModal === 'function') window.closeModal(m.id);
    else { m.style.display = 'none'; m.classList.remove('is-open'); }
  });
  if (typeof window.updateModalScrollLock === 'function') window.updateModalScrollLock();
  
  if (window.reportIndex >= window.reportQueue.length) {
    alert("Staging Verification Report Complete!");
    window.activeReportMode = false;
    localStorage.removeItem('swift_report_state');
    if(window.reportResults && window.reportResults.length > 0) {
      window.downloadCSV(window.reportResults, 'Verification_Results.csv');
      const discrepancies = window.reportResults.filter(r => r.result !== 'Verified');
      if(discrepancies.length > 0) window.downloadCSV(discrepancies, 'Verification_Discrepancies.csv');
    }
    return;
  }

  const itemId = window.reportQueue[window.reportIndex];
  const item = appData.staging.find(x => x.id === itemId);
  
  if (!item) {
    window.reportIndex++; window.saveReportState(); return window.renderNextReportItem();
  }

  if($('#rep_loc')) $('#rep_loc').textContent = item.location || 'No Location';
  if($('#rep_so')) $('#rep_so').textContent = item.so;
  if($('#rep_cust')) $('#rep_cust').textContent = item.customer;
  if($('#rep_date')) $('#rep_date').textContent = new Date(item.entry_date).toLocaleString();
  if($('#rep_qty')) $('#rep_qty').textContent = item.type;
  if($('#rep_status')) $('#rep_status').textContent = item.status;
  if($('#rep_by')) $('#rep_by').textContent = item.staged_by || '—';
  
  if($('#rep_comment_box')) {
    if(item.comments && item.comments.trim() !== '') {
      $('#rep_comment_box').style.display = 'block';
      $('#rep_comments_text').value = item.comments;
    } else { $('#rep_comment_box').style.display = 'none'; }
  }
  
  if($('#rep_progress')) $('#rep_progress').textContent = `${window.reportIndex + 1} of ${window.reportQueue.length}`;
  await window.openModal('reportMainModal', { requireShared: false });
};

window.reportRecordAction = function(resultStr) {
  const item = appData.staging.find(x => x.id === window.reportQueue[window.reportIndex]);
  if(item) {
    window.reportResults.push({ so: item.so, customer: item.customer, location: item.location, date: new Date(item.entry_date).toLocaleString(), result: resultStr });
    window.discrepancyList = window.discrepancyList.filter(id => id !== item.id);
    if(resultStr !== 'Verified') window.discrepancyList.push(item.id);
    localStorage.setItem('swift_discrepancies', JSON.stringify(window.discrepancyList));
  }
  window.reportIndex++;
  window.saveReportState();
  setTimeout(window.renderNextReportItem, 600);
};

window.reportHandleYes = function() {
  window.reportRecordAction('Verified');
};

window.reportHandleNo = async function() {
  window.closeModal('reportMainModal');
  await window.openModal('reportNoModal', { requireShared: false });
};

window.reportHandleBack = function() {
  if (window.reportIndex > 0) {
    window.reportResults.pop();
    window.reportIndex--;
    window.saveReportState();
    window.renderNextReportItem();
  } else {
    alert("You are at the beginning of the report.");
  }
};

window.reportAction = async function(action) {
  const itemId = window.reportQueue[window.reportIndex];
  window.closeModal('reportNoModal');
  
  if(action === 'settle') {
    window.reportRecordAction('Discrepancy - Unresolved');
  } 
  else if (action === 'change') {
    if($('#report_new_loc')) $('#report_new_loc').value = '';
    await window.openModal('reportChangeLocModal', { requireShared: false });
  } 
  else if (action === 'split') {
    window.openSplitPrompt();
  }
  else if (action === 'ship') {
    window.triggerShipModal(itemId);
  }
  else if (action === 'edit') {
    await window.openUniversalEditor('staging', itemId);
    window.closeModal('reportNoModal');
    window.closeModal('reportMainModal');
  }
  else {
    await window.openUniversalEditor('staging', itemId);
    window.closeModal('editModal');

    if (action === 'delete') await window.deleteCurrentRecord();
    else if (action === 'return') await window.triggerReturnModal();
    else if (action === 'consolidate') await window.triggerUniversalConsolidate(appData.staging.find(x => x.id === itemId).so);
  }
};

window.reportSubmitNewLocation = async function() {
  const newLoc = $('#report_new_loc').value.trim();
  if(!newLoc) return alert("Enter a valid location.");
  
  const targetId = window.reportQueue[window.reportIndex];
  const target = appData.staging.find(x => x.id === targetId);
  
  window.closeModal('reportChangeLocModal');
  try {
    const { error } = await supabaseClient.from('staging').update({ location: newLoc }).eq('id', targetId);
    if(error) throw error;
    
    window.logAction('staging', `Report Fix: Changed Location for SO ${target.so} to ${newLoc}`);
    if(typeof window.showNotification === 'function') window.showNotification('Location Updated');
    
    window.loadCloudData();
    window.reportRecordAction(`Fixed via Location Change (${newLoc})`);
  } catch(e) { alert("Error updating location: " + e.message); window.renderNextReportItem(); }
};


window.submitReportAddEntry = async function() {
  const result = await window.insertStagingEntry({
    fields: {
      so: $('#ra_so') ? $('#ra_so').value : '',
      customer: $('#ra_cust') ? $('#ra_cust').value : '',
      location: $('#ra_loc') ? $('#ra_loc').value : '',
      weight: $('#ra_weight') ? $('#ra_weight').value : '',
      comments: $('#ra_comments') ? $('#ra_comments').value : '',
      status: $('#ra_status') ? $('#ra_status').value : 'Partial',
      staged_by: $('#ra_staged_by') ? $('#ra_staged_by').value : '',
      skid: $('#ra_skid') ? $('#ra_skid').value : 0,
      box: $('#ra_box') ? $('#ra_box').value : 0,
      crate: $('#ra_crate') ? $('#ra_crate').value : 0,
      pipe: $('#ra_pipe') ? $('#ra_pipe').value : 0,
      other: $('#ra_other') ? $('#ra_other').value : 0
    },
    photoBlobs: window.reportPhotoBlobs || [],
    logMessage: `Added new entry via Report module for SO: ${($('#ra_so') ? $('#ra_so').value : '').trim()}`,
    submitBtn: $('#ra_submitBtn'),
    onSuccess: (record) => {
      if (record) {
        appData.staging.push(record);
        window.injectIntoReportQueue(record);
      }
      if ($('#reportAddModal')) $('#reportAddModal').style.display = 'none';
      if (window.activeReportMode && typeof window.renderNextReportItem === 'function') {
        window.renderNextReportItem();
      }
    }
  });
  if (result && !result.ok && $('#ra_submitBtn')) {
    $('#ra_submitBtn').disabled = false;
    $('#ra_submitBtn').textContent = 'Add Entry';
  }
};

window.injectIntoReportQueue = function(item) {
  if (!window.activeReportMode) return;
  
  const aisleRegex = /^([A-Z])-\d{2}-([A-Z])-(1|2|1\+2)$/i;
  const isAisle = aisleRegex.test(item.location||'');
  
  if (window.currentReportFilter === 'aisle' && !isAisle) return;
  if (window.currentReportFilter === 'non_aisle' && isAisle) return;
  if (window.currentReportFilter === 'discrepancies') return; 
  
  const currentQueueItems = window.reportQueue.map(id => appData.staging.find(x => x.id === id)).filter(Boolean);
  currentQueueItems.push(item);
  
  currentQueueItems.sort((a, b) => {
    const keyA = locSortKey(a.location), keyB = locSortKey(b.location);
    if (keyA[0] !== keyB[0]) return keyA[0] - keyB[0];
    if (keyA[0] === 1) return (a.location||'').localeCompare(b.location||''); 
    if (keyA[1] !== keyB[1]) return keyA[1].localeCompare(keyB[1]);
    if (keyA[2] !== keyB[2]) return keyA[2] - keyB[2];
    if (keyA[3] !== keyB[3]) return keyA[3].localeCompare(keyB[3]);
    return keyA[4] - keyB[4];
  });
  
  const newQueue = currentQueueItems.map(x => x.id);
  const newIndexOfItem = newQueue.indexOf(item.id);
  
  if (newIndexOfItem <= window.reportIndex) {
    window.reportIndex++; 
  }
  
  window.reportQueue = newQueue;
  window.saveReportState();
  if($('#rep_progress')) $('#rep_progress').textContent = `${window.reportIndex + 1} of ${window.reportQueue.length}`;
};
