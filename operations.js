// --- operations.js ---
window.hiddenMemory = JSON.parse(localStorage.getItem('swift_hidden_memory')) || [];

window.banishMemory = function(inputId) {
  if(!$('#'+inputId)) return;
  const val = $('#'+inputId).value.trim();
  if(!val) return;
  if(confirm(`Remove "${val}" from autocomplete memory?`)) {
    if(!window.hiddenMemory.includes(val)) {
      window.hiddenMemory.push(val);
      localStorage.setItem('swift_hidden_memory', JSON.stringify(window.hiddenMemory));
    }
    $('#'+inputId).value = '';
    window.loadCloudData();
  }
};

window.loadCloudData = async function() {
  try {
    const [st, sh] = await Promise.all([
      supabaseClient.from('staging').select('*').order('entry_date', { ascending: false }),
      supabaseClient.from('shipped').select('*').order('shipped_at', { ascending: false })
    ]);
    
    if (!st.error && st.data) window.appData.staging = st.data; 
    if (!sh.error && sh.data) window.appData.shipped = sh.data;
    
    const allData = [...window.appData.staging, ...window.appData.shipped];
    const filterMem = (arr) => [...new Set(arr.filter(Boolean))].filter(x => !window.hiddenMemory.includes(x));

    const activeEl = document.activeElement;
    const activeListId = (activeEl && activeEl.tagName === 'INPUT') ? activeEl.getAttribute('list') : null;

    const safeUpdateDatalist = (id, newHtml) => {
      const el = $('#' + id);
      if (el && el.innerHTML !== newHtml) {
        if (activeListId !== id) { 
          el.innerHTML = newHtml; 
        }
      }
    };

    safeUpdateDatalist('dl_customers', filterMem(allData.map(x=>x.customer)).map(c=>`<option value="${c}">`).join(''));
    safeUpdateDatalist('dl_locations', filterMem(allData.map(x=>x.location)).map(l=>`<option value="${l}">`).join(''));
    safeUpdateDatalist('dl_stagers', filterMem(allData.map(x=>(x.staged_by || x.shipped_by))).map(s=>`<option value="${s}">`).join(''));
    safeUpdateDatalist('dl_pastEmails', filterMem(window.appData.shipped.map(x=>x.pmd_email)).map(em=>`<option value="${em}@swiftsupply.ca">`).join(''));
    
    window.renderTables(); 
    if(typeof window.syncMapPins === 'function') window.syncMapPins();
  } catch(e) { console.error("Data load failed:", e); }
};

window.deleteCurrentRecord = async function() {
  if(confirm("Are you sure you want to PERMANENTLY delete this record?")) {
    try {
      await supabaseClient.from(window.editTargetRecord.table).delete().eq('id', window.currentEditId);
      window.logAction(window.editTargetRecord.table, `Deleted entry for SO: ${window.editTargetRecord.so}`);
      if($('#editModal')) $('#editModal').style.display = 'none';
      if(typeof window.showNotification === 'function') window.showNotification('Record Deleted Permanently');
      window.loadCloudData();
      if(window.activeReportMode) { window.reportRecordAction('Fixed via Deletion'); }
    } catch (e) {
      alert("Delete failed: " + e.message);
    }
  }
};

window.submitReturnToStock = async function() {
  const pickedBy = $('#r_picked_by').value.trim(); const returnedBy = $('#r_returned_by').value.trim();
  const reason = $('#r_reason').value.trim();
  const pmRaw = $('#r_pm_email').value.trim(); const pmChecked = $('#r_pm_chk').checked;

  if(!pickedBy || !returnedBy || !reason) return alert("Missing required inputs.");
  
  let finalPmEmail = null;
  if (pmChecked) {
    finalPmEmail = window.resolveEmail(pmRaw);
    if (!finalPmEmail) return alert("Invalid PM Entry. Please select a valid PM from the list or type a valid email address.");
  }
  
  try {
    const e = window.appData.staging.find(x => x.id === window.currentEditId);
    const currentTimeStamp = new Date().toLocaleString();
    let pmName = finalPmEmail ? finalPmEmail.split('@')[0].split('.')[0] : null;
    if(pmName) pmName = pmName.charAt(0).toUpperCase() + pmName.slice(1);
    
    const { error: insertError } = await supabaseClient.from('shipped').insert([{
      so: window.editTargetRecord.so, customer: $('#e_cust').value.trim(), type: window.getDynamicType('e'), qty: window.getDynamicQty('e'),
      carrier: 'RETURNED TO STOCK', location: $('#e_loc').value.trim(), coords: $('#e_coords').value.trim(),
      weight: $('#e_weight').value.trim(), comments: e ? e.comments : '', shipped_by: returnedBy, pmd_email: pmName || pickedBy, photo_urls: window.editTargetRecord.photo_urls
    }]); 
    if(insertError) throw insertError;
    
    await supabaseClient.from('staging').delete().eq('id', window.currentEditId);
    window.logAction('staging', `Returned to Stock SO: ${window.editTargetRecord.so}`);
    window.logAction('shipped', `Added Return to Stock log for SO: ${window.editTargetRecord.so}`);
    if(typeof window.showNotification === 'function') window.showNotification('Returned to Stock Successfully');

    if(pmChecked && finalPmEmail) {
      const cachedSubject = `RETURN TO STOCK: ${window.editTargetRecord.so} for ${$('#e_cust').value.trim()}`;
      const cachedBody = `Your order/pick has now been Returned to Stock. Return details:<br><br><b>Reason:</b> ${reason}<br><br>----------------------------------------------------------------------<br><b>SO#</b>                   | ${window.editTargetRecord.so}<br><b>Customer</b>              | ${$('#e_cust').value.trim()}<br><b>Container(s)</b>          | ${window.getDynamicType('e')}<br><b>Total Weight (In lbs)</b> | ${$('#e_weight').value.trim() || '—'}<br><b>Picked by</b>             | ${pickedBy}<br><b>Returned At</b>           | ${currentTimeStamp}<br><b>Returned By</b>           | ${returnedBy}<br>----------------------------------------------------------------------<br><br>For more shipment details, visit: <a href="https://swiftoperations.github.io/staging-tracker/">Swift Staging Tracker</a><br><br>Thanks`;

      const attachmentUrls = window.editTargetRecord.photo_urls ? window.editTargetRecord.photo_urls.map(p => `https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/freight-photos/${p}`) : [];

      fetch('https://hook.us2.make.com/iykii8i5j1vssv6d8qkqest78iphjw7i', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          to: finalPmEmail, 
          cc: "warehouse1@swiftsupply.ca", 
          subject: cachedSubject, 
          body: cachedBody,
          attachments: attachmentUrls,
          has_attachments: attachmentUrls.length > 0
        })
      }).catch(err => console.warn(err));
    }

    if($('#returnModal')) $('#returnModal').style.display='none';
    window.loadCloudData();
    if(window.activeReportMode) { window.reportRecordAction('Fixed via Return to Stock'); }

  } catch(err) { alert("Return to Stock error: " + err.message); }
};

window.saveEditedRecord = async function() {
  const dynamicQty = window.getDynamicQty('e');
  if (dynamicQty === 0) return alert("Error: You must have at least 1 container to save this record.");
  const locValue = $('#e_loc').value.trim(); const soVal = $('#e_so').value.trim();

  if (window.editTargetRecord.table === 'staging') {
    const proceed = await window.checkSoConflict(soVal, window.currentEditId);
    if(!proceed) return;
  }
  
  const dynamicType = window.getDynamicType('e');
  const basePayload = { so: soVal, customer: $('#e_cust').value.trim(), location: locValue, coords: $('#e_coords').value.trim(), weight: $('#e_weight').value.trim(), comments: $('#e_comments').value.trim(), type: dynamicType, qty: dynamicQty };

  if (window.editTargetRecord.table === 'staging') {
    const newStatus = window.getDbStatus($('#e_status
