// --- operations.js ---

window.banishMemory = function(inputId) {
  if(!$('#'+inputId)) return;
  const val = $('#'+inputId).value.trim();
  if(!val) return;
  if(confirm(`Remove "${val}" from autocomplete memory?`)) {
    if(!hiddenMemory.includes(val)) {
      hiddenMemory.push(val);
      localStorage.setItem('swift_hidden_memory', JSON.stringify(hiddenMemory));
    }
    $('#'+inputId).value = '';
    window.loadCloudData();
  }
};

window.loadCloudData = async function() {
  try {
    const rosterPromise = typeof window.loadCloudRosters === 'function'
      ? window.loadCloudRosters()
      : Promise.resolve();
    const [st, sh] = await Promise.all([
      supabaseClient.from('staging').select('*').order('entry_date', { ascending: false }),
      supabaseClient.from('shipped').select('*').order('shipped_at', { ascending: false })
    ]);
    await rosterPromise;
    
    if (!st.error && st.data) appData.staging = st.data; 
    if (!sh.error && sh.data) appData.shipped = sh.data;
    
    const allData = [...appData.staging, ...appData.shipped];
    const filterMem = (arr) => [...new Set(arr.filter(Boolean))].filter(x => !hiddenMemory.includes(x));

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

    // Stripping inner text forces Chrome/Safari to respect the full input string
    safeUpdateDatalist('dl_customers', filterMem(allData.map(x=>x.customer)).map(c=>`<option value="${c}"></option>`).join(''));
    safeUpdateDatalist('dl_locations', filterMem(allData.map(x=>x.location)).map(l=>`<option value="${l}"></option>`).join(''));
    safeUpdateDatalist('dl_stagers', filterMem(
      typeof window.getPersonDropdownValues === 'function' ? window.getPersonDropdownValues() : []
    ).map(s => `<option value="${s}"></option>`).join(''));
    safeUpdateDatalist('dl_pastEmails', filterMem(appData.shipped.map(x=>x.pmd_email)).map(em=>`<option value="${em}@swiftsupply.ca"></option>`).join(''));
    safeUpdateDatalist('dl_sos', filterMem(allData.map(x=>x.so)).map(s=>`<option value="${s}"></option>`).join(''));
    
    window.renderTables(); 
    if(typeof window.initUniversalDropdowns === 'function') window.initUniversalDropdowns();
    if(typeof window.checkOverdueShipments === 'function') window.checkOverdueShipments();
  } catch(e) { console.error("Data load failed:", e); }
};

window.deleteCurrentRecord = async function() {
  if(confirm("Are you sure you want to PERMANENTLY delete this record?")) {
    await supabaseClient.from(editTargetRecord.table).delete().eq('id', currentEditId);
    window.logAction(editTargetRecord.table, `Deleted entry for SO: ${editTargetRecord.so}`);
    window.closeModal('editModal');
    if(typeof window.showNotification === 'function') window.showNotification('Record Deleted Permanently');
    window.loadCloudData();
    
    if(window.activeReportMode) { window.reportRecordAction('Fixed via Deletion'); }
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
    const e = appData.staging.find(x => x.id === currentEditId);
    const currentTimeStamp = new Date().toLocaleString();
    let pmName = finalPmEmail ? finalPmEmail.split('@')[0].split('.')[0] : null;
    if(pmName) pmName = pmName.charAt(0).toUpperCase() + pmName.slice(1);
    
    const { error: insertError } = await supabaseClient.from('shipped').insert([{
      so: editTargetRecord.so, customer: $('#e_cust').value.trim(), type: window.getDynamicType('e'), qty: window.getDynamicQty('e'),
      carrier: 'RETURNED TO STOCK', location: $('#e_loc').value.trim(),
      weight: $('#e_weight').value.trim(), comments: e.comments, shipped_by: returnedBy, pmd_email: pmName || pickedBy, photo_urls: editTargetRecord.photo_urls
    }]); 
    if(insertError) throw insertError;
    
    await supabaseClient.from('staging').delete().eq('id', currentEditId);
    window.logBinMovement('to-shipped', `SO ${editTargetRecord.so}: ${window.getDynamicType('e')} moved from Staging Log to Shipped Log (Returned to Stock) from ${$('#e_loc').value.trim()}`);
    window.logAction('staging', `Returned to Stock SO: ${editTargetRecord.so}`);
    window.logAction('shipped', `Added Return to Stock log for SO: ${editTargetRecord.so}`);
    if(typeof window.showNotification === 'function') window.showNotification('Returned to Stock Successfully');
    if (typeof window.rememberPersonBy === 'function') window.rememberPersonBy(pickedBy, returnedBy);

    if(pmChecked && finalPmEmail) {
      const cachedSubject = `RETURN TO STOCK: SO ${editTargetRecord.so} - ${$('#e_cust').value.trim()}`;
      const cachedBody = `Your order/pick has now been Returned to Stock. Return details:<br><br><b>Reason:</b> ${reason}<br><br>----------------------------------------------------------------------<br><b>SO#</b>                   | ${editTargetRecord.so}<br><b>Customer</b>              | ${$('#e_cust').value.trim()}<br><b>Container(s)</b>          | ${window.getDynamicType('e')}<br><b>Total Weight (In lbs)</b> | ${$('#e_weight').value.trim() || '—'}<br><b>Picked By</b>             | ${pickedBy}<br><b>Returned At</b>           | ${currentTimeStamp}<br><b>Returned By</b>           | ${returnedBy}<br>----------------------------------------------------------------------<br><br>${window.buildEmailNotificationFooter()}`;

      const attachmentUrls = editTargetRecord.photo_urls ? editTargetRecord.photo_urls.map(p => `https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/freight-photos/${p}`) : [];

      window.sendPmEmailWebhook({
          to: finalPmEmail,
          cc: "warehouse1@swiftsupply.ca",
          subject: cachedSubject,
          body: cachedBody,
          attachments: attachmentUrls,
          has_attachments: attachmentUrls.length > 0
        });
    }

    window.closeModal('returnModal');
    window.loadCloudData();
    if(window.activeReportMode) { window.reportRecordAction('Fixed via Return to Stock'); }

  } catch(err) { alert("Return to Stock error: " + err.message); }
};

window.saveEditedRecord = async function() {
  const dynamicQty = window.getDynamicQty('e');
  if (dynamicQty === 0) return alert("Error: You must have at least 1 container to save this record.");
  
  const locValue = $('#e_loc').value.trim();
  const soVal = $('#e_so').value.trim();

  if (editTargetRecord.table === 'staging') {
    const proceed = await window.checkSoConflict(soVal, currentEditId);
    if(!proceed) return;
  }
  
  const aisleRegex = /^[A-Z]-\d{2}-[A-F]-[12]$/i;
  if (editTargetRecord.table === 'staging' && aisleRegex.test(locValue)) {
    const isOccupied = appData.staging.some(x => x.id !== currentEditId && (x.location || '').toLowerCase() === locValue.toLowerCase());
    if (isOccupied) {
      if (!confirm(`Conflict Warning: Aisle location ${locValue.toUpperCase()} is already occupied. Do you want to proceed and place them together?`)) return;
    }
  }

  const dynamicType = window.getDynamicType('e');
  const basePayload = { so: soVal, customer: $('#e_cust').value.trim(), location: locValue, weight: $('#e_weight').value.trim(), comments: $('#e_comments').value.trim(), type: dynamicType, qty: dynamicQty };

  if (editTargetRecord.table === 'staging') {
    const newStatus = window.getDbStatus($('#e_status').value.trim());
    const { error } = await supabaseClient.from('staging').update({ ...basePayload, status: newStatus, staged_by: $('#e_staged_by').value.trim(), photo_urls: editTargetRecord.photo_urls }).eq('id', currentEditId);
    if(error) { alert("Database Error: " + error.message); return; }
    const oldLoc = (editTargetRecord.location || '').trim();
    if (oldLoc && oldLoc.toLowerCase() !== locValue.toLowerCase()) {
      window.logBinMovement('move', `SO ${soVal} moved from ${oldLoc} to ${locValue}`);
    }
    if (typeof window.rememberPersonBy === 'function') {
      window.rememberPersonBy($('#e_staged_by').value.trim());
    }
  } else {
    const newCarrier = $('#e_carrier').value.trim();
    const { error } = await supabaseClient.from('shipped').update({ ...basePayload, carrier: newCarrier, shipped_by: $('#e_shipped_by').value.trim(), pmd_email: $('#e_pm').value.trim() || null, photo_urls: editTargetRecord.photo_urls }).eq('id', currentEditId);
    if(error) { alert("Database Error: " + error.message); return; }
    if (typeof window.rememberPersonBy === 'function') {
      window.rememberPersonBy($('#e_shipped_by').value.trim());
    }
    if (typeof window.rememberCarrier === 'function') {
      window.rememberCarrier(newCarrier);
    }
  }
  
  window.logAction(editTargetRecord.table, `Edited SO ${basePayload.so}`);
  
  if($('#editModal')) window.closeModal('editModal'); 
  if(typeof window.showNotification === 'function') window.showNotification('Record Updated Successfully');
  window.loadCloudData();
  
  if(window.activeReportMode) { window.reportRecordAction('Fixed via Manual Edit'); }
};

window.executeShippedUndo = async function() {
  if(!confirm("Are you sure you want to undo this action and return it to Staging?")) return;
  try {
    const { data: currentRecord } = await supabaseClient.from('shipped').select('*').eq('id', editTargetRecord.id).single();
    
    const proceed = await window.checkSoConflict(currentRecord.so, null);
    if(!proceed) return;

    // Fixed: 'status' is now 'Partial' to conform to database check constraint
    const { error } = await supabaseClient.from('staging').insert([{ so: currentRecord.so, customer: currentRecord.customer, type: currentRecord.type, qty: currentRecord.qty, location: currentRecord.location, weight: currentRecord.weight, comments: currentRecord.comments, status: 'Partial', photo_urls: currentRecord.photo_urls }]);
    if (error) { alert("Undo Database Error: " + error.message); return; }
    
    await supabaseClient.from('shipped').delete().eq('id', editTargetRecord.id);
    window.logBinMovement('to-staging', `SO ${currentRecord.so}: ${currentRecord.type || 'containers'} moved from Shipped Log back to Staging Log${currentRecord.location ? ` (${currentRecord.location})` : ''}`);
    window.logAction('shipped', `Undo Shipment Action for SO: ${currentRecord.so}`);
    window.logAction('staging', `Restored to Staging via Undo for SO: ${currentRecord.so}`);
    if(typeof window.showNotification === 'function') window.showNotification('Shipment Action Undone');
    window.closeModal('editModal'); 
    window.loadCloudData();
  } catch(e) { alert("Undo error: " + e.message); }
};

window.submitFreightDispatch = async function() {
  const dispatcher = $('#m_by').value.trim(); 
  const pmRaw = $('#m_pm_email').value.trim(); const pmChecked = $('#m_pm_chk').checked;
  const carrierVal = $('#m_carrier').value.trim() || 'Unassigned Carrier';
  const shipComments = $('#m_comments') ? $('#m_comments').value.trim() : (activeShipTargetItem.comments || '');
  
  if(!dispatcher) return alert("Missing required dispatcher input.");
  
  let finalPmEmail = null;
  if (pmChecked) {
    finalPmEmail = window.resolveEmail(pmRaw);
    if (!finalPmEmail) return alert("Invalid PM Entry. Please select a valid PM from the list or type a valid email address.");
  }
  
  if($('#modalConfirmBtn')) $('#modalConfirmBtn').disabled = true;
  try {
    let photoUrls = (activeShipTargetItem && activeShipTargetItem.photo_urls) ? [...activeShipTargetItem.photo_urls] : [];
    
    for (let i = 0; i < selectedPhotoBlobs.length; i++) {
      const file = selectedPhotoBlobs[i]; 
      const cleanFileName = file.name.replace(/[^a-zA-Z0-9.]/g, '');
      const path = `${activeShipTargetItem.so}-${Date.now()}-${i}-${cleanFileName}`;
      await supabaseClient.storage.from('freight-photos').upload(path, file); photoUrls.push(path);
    }
    
    let pmName = finalPmEmail ? finalPmEmail.split('@')[0].split('.')[0] : null;
    if(pmName) pmName = pmName.charAt(0).toUpperCase() + pmName.slice(1);

    const { error: insertError } = await supabaseClient.from('shipped').insert([{
      so: activeShipTargetItem.so, customer: activeShipTargetItem.customer, type: activeShipTargetItem.type,
      qty: activeShipTargetItem.qty, carrier: carrierVal, location: activeShipTargetItem.location,
      weight: activeShipTargetItem.weight, comments: activeShipTargetItem.comments, shipped_by: dispatcher, pmd_email: pmName, photo_urls: photoUrls
    }]);
    
    if (insertError) {
      alert("Database Error: " + insertError.message);
      if($('#modalConfirmBtn')) $('#modalConfirmBtn').disabled = false;
      return;
    }

    await supabaseClient.from('staging').delete().eq('id', activeShipTargetItem.id);
    window.logBinMovement('to-shipped', `SO ${activeShipTargetItem.so}: ${activeShipTargetItem.type || 'containers'} moved from Staging Log to Shipped Log via ${carrierVal}${activeShipTargetItem.location ? ` (${activeShipTargetItem.location})` : ''}`);
    window.logAction('staging', `Ship Confirmed SO: ${activeShipTargetItem.so}`);
    window.logAction('shipped', `Added via Ship Confirm: SO: ${activeShipTargetItem.so}`);
    
    // -> ADD THIS ONE LINE HERE <-
    if(typeof window.playSuccessChime === 'function') window.playSuccessChime();
    
    if(typeof window.showNotification === 'function') window.showNotification('Freight Dispatched Successfully');
    if (typeof window.rememberPersonBy === 'function') window.rememberPersonBy(dispatcher);
    if (typeof window.rememberCarrier === 'function') window.rememberCarrier($('#m_carrier').value.trim());

    if(pmChecked && finalPmEmail) {
      const currentTimeStamp = new Date().toLocaleString();
      const cachedSubject = `SHIP NOTIFICATION: SO ${activeShipTargetItem.so} - ${activeShipTargetItem.customer}`;
      const cachedBody = `Your order has now been shipped! Order details:<br><br>----------------------------------------------------------------------<br><b>SO#</b>                   | ${activeShipTargetItem.so}<br><b>Customer</b>              | ${activeShipTargetItem.customer}<br><b>Container(s)</b>          | ${activeShipTargetItem.type}<br><b>Total Weight (In lbs)</b> | ${activeShipTargetItem.weight || '—'}<br><b>Carrier</b>               | ${carrierVal}<br><b>Shipped At</b>            | ${currentTimeStamp}<br><b>Shipped By</b>            | ${dispatcher}<br><b>Comments</b>              | ${shipComments || 'None'}<br>----------------------------------------------------------------------<br><br>${window.buildEmailNotificationFooter()}`;

      const attachmentUrls = photoUrls.map(p => `https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/freight-photos/${p}`);

      window.sendPmEmailWebhook({
          to: finalPmEmail,
          cc: "warehouse1@swiftsupply.ca",
          subject: cachedSubject,
          body: cachedBody,
          attachments: attachmentUrls,
          has_attachments: attachmentUrls.length > 0
        });
    }

    window.closeShipModal();
    if(window.activeReportMode) { window.reportRecordAction('Fixed via Shipped Out'); }

  } catch(e) { 
    alert("Data dispatch error."); 
  } finally { 
    if($('#modalConfirmBtn')) $('#modalConfirmBtn').disabled = false; 
  }
};

window.insertStagingEntry = async function({
  fields,
  photoBlobs = [],
  logMessage,
  onSuccess,
  submitBtn
}) {
  const sk = parseInt(fields.skid) || 0;
  const bx = parseInt(fields.box) || 0;
  const cr = parseInt(fields.crate) || 0;
  const pi = parseInt(fields.pipe) || 0;
  const ot = parseInt(fields.other) || 0;
  const soVal = (fields.so || '').trim();
  const locValue = (fields.location || '').trim();

  if (!soVal || !(fields.customer || '').trim() || !locValue) {
    alert('Fields Missing.');
    return { ok: false };
  }

  const totalQty = sk + bx + cr + pi + ot;
  if (totalQty === 0) {
    alert('Error: You must add at least 1 container to confirm this entry.');
    return { ok: false };
  }

  const proceed = await window.checkSoConflict(soVal, null);
  if (!proceed) return { ok: false };

  const aisleRegex = /^[A-Z]-\d{2}-[A-F]-[12]$/i;
  if (aisleRegex.test(locValue)) {
    const isOccupied = appData.staging.some(x => (x.location || '').toLowerCase() === locValue.toLowerCase());
    if (isOccupied && !confirm(`Conflict Warning: Aisle location ${locValue.toUpperCase()} is already occupied. Do you want to proceed and place them together?`)) {
      return { ok: false };
    }
  }

  const typeParts = [];
  if (sk) typeParts.push(window.formatContainer(sk, 'Skid'));
  if (bx) typeParts.push(window.formatContainer(bx, 'Box'));
  if (cr) typeParts.push(window.formatContainer(cr, 'Crate'));
  if (pi) typeParts.push(window.formatContainer(pi, 'Pipe/Rod'));
  if (ot) typeParts.push(window.formatContainer(ot, 'Other'));

  if (submitBtn) {
    submitBtn.disabled = true;
    submitBtn.dataset.prevText = submitBtn.textContent;
    submitBtn.textContent = 'Saving...';
  }

  try {
    const photoUrls = [];
    for (let i = 0; i < photoBlobs.length; i++) {
      const file = photoBlobs[i];
      const cleanFileName = file.name.replace(/[^a-zA-Z0-9.]/g, '');
      const path = `${soVal}-staging-${Date.now()}-${i}-${cleanFileName}`;
      const { error: uploadError } = await supabaseClient.storage.from('freight-photos').upload(path, file);
      if (!uploadError) photoUrls.push(path);
    }

    const payload = {
      so: soVal,
      customer: (fields.customer || '').trim(),
      status: window.getDbStatus(fields.status || 'Partial'),
      location: locValue,
      weight: (fields.weight || '').trim(),
      comments: (fields.comments || '').trim(),
      staged_by: (fields.staged_by || '').trim(),
      type: typeParts.join(', '),
      qty: totalQty,
      photo_urls: photoUrls
    };

    const { data: insertedData, error } = await supabaseClient.from('staging').insert([payload]).select();
    if (error) {
      alert('Database Error: ' + error.message);
      return { ok: false, error };
    }

    window.logAction('staging', logMessage || `Added new entry for SO: ${soVal}`);
    if (typeof window.showNotification === 'function') window.showNotification('Staging Entry Added');
    if (typeof window.rememberPersonBy === 'function' && payload.staged_by) {
      window.rememberPersonBy(payload.staged_by);
    }

    if (onSuccess) onSuccess(insertedData && insertedData[0] ? insertedData[0] : null);
    window.loadCloudData();
    return { ok: true, record: insertedData && insertedData[0] ? insertedData[0] : null };
  } catch (e) {
    alert('System Error: ' + e.message);
    return { ok: false, error: e };
  } finally {
    if (submitBtn) {
      submitBtn.disabled = false;
      submitBtn.textContent = submitBtn.dataset.prevText || submitBtn.textContent;
    }
  }
};

window.submitStagingEntry = async function() {
  const result = await window.insertStagingEntry({
    fields: {
      so: $('#so') ? $('#so').value : '',
      customer: $('#customer') ? $('#customer').value : '',
      location: $('#loc') ? $('#loc').value : '',
      weight: $('#weight') ? $('#weight').value : '',
      comments: $('#comments') ? $('#comments').value : '',
      status: $('#status') ? $('#status').value : 'Partial',
      staged_by: $('#staged_by') ? $('#staged_by').value : '',
      skid: $('#c_skid') ? $('#c_skid').value : 0,
      box: $('#c_box') ? $('#c_box').value : 0,
      crate: $('#c_crate') ? $('#c_crate').value : 0,
      pipe: $('#c_pipe') ? $('#c_pipe').value : 0,
      other: $('#c_other') ? $('#c_other').value : 0
    },
    photoBlobs: mainPhotoBlobs,
    logMessage: `Added new entry for SO: ${($('#so') ? $('#so').value : '').trim()}`,
    submitBtn: $('#add'),
    onSuccess: () => {
      if ($('#so')) $('#so').value = '';
      if ($('#customer')) $('#customer').value = '';
      if ($('#loc')) $('#loc').value = '';
      if ($('#staged_by')) $('#staged_by').value = '';
      if ($('#weight')) $('#weight').value = '';
      if ($('#c_skid')) $('#c_skid').value = 0;
      if ($('#c_box')) $('#c_box').value = 0;
      if ($('#c_crate')) $('#c_crate').value = 0;
      if ($('#c_pipe')) $('#c_pipe').value = 0;
      if ($('#c_other')) $('#c_other').value = 0;
      if ($('#comments')) $('#comments').value = '';
      mainPhotoBlobs = [];
      if (typeof window.renderMainPhotoStrip === 'function') window.renderMainPhotoStrip();
    }
  });
  if (result && !result.ok && $('#add')) {
    $('#add').disabled = false;
    $('#add').textContent = 'Add';
  }
};

window.saveQuickComment = async function() {
  const newComment = $('#quick_comments').value.trim();
  const { error } = await supabaseClient.from(currentCommentTarget.table)
    .update({ comments: newComment }).eq('id', currentCommentTarget.id);
  if(error) return alert("Error saving comment: " + error.message);
  const o = appData[currentCommentTarget.table].find(x => x.id === currentCommentTarget.id);
  if(o) window.logAction(currentCommentTarget.table, `Added/Edited comment for SO: ${o.so}`);
  if(typeof window.showNotification === 'function') window.showNotification('Comment Saved');
  if($('#commentModal')) window.closeModal('commentModal');
  window.loadCloudData();
};

window.nrPhotoBlobs = [];

window.openNotifyReturnModal = async function() {
  if (!(await window.openModal('notifyReturnModal', { requireShared: false }))) return;
  if ($('#nr_so')) $('#nr_so').value='';
  if ($('#nr_cust')) $('#nr_cust').value='';
  if ($('#nr_skid')) $('#nr_skid').value=0;
  if ($('#nr_box')) $('#nr_box').value=0;
  if ($('#nr_crate')) $('#nr_crate').value=0;
  if ($('#nr_pipe')) $('#nr_pipe').value=0;
  if ($('#nr_other')) $('#nr_other').value=0;
  if ($('#nr_loc')) $('#nr_loc').value='';
  if ($('#nr_weight')) $('#nr_weight').value='';
  if ($('#nr_comments')) $('#nr_comments').value='';
  if ($('#nr_received_by')) $('#nr_received_by').value = currentUser ? currentUser.email.split('@')[0] : '';
  window.nrPhotoBlobs = [];
  if (typeof window.renderNRPhotoStrip === 'function') window.renderNRPhotoStrip();
};

window.submitNotifyReturn = async function() {
  const soVal = $('#nr_so').value.trim();
  const custVal = $('#nr_cust').value.trim();
  const locVal = $('#nr_loc').value.trim();
  const receivedByVal = $('#nr_received_by').value.trim();
  
  const pmInputEl = $('#nr_pm_email') || $('#nr_cc_pm');
  const pmRaw = pmInputEl ? pmInputEl.value.trim() : ''; 
  
  if(!soVal || !custVal || !locVal || !receivedByVal) return alert("Please fill out all required fields (*).");
  if(!pmRaw) return alert("Please specify a PM to notify of this return.");
  
  const finalPmEmail = window.resolveEmail(pmRaw);
  if (!finalPmEmail) return alert("Invalid PM Entry. Please select a valid PM from the list or type a full email address (e.g., name@domain.com).");

  $('#nr_submitBtn').disabled = true; $('#nr_submitBtn').textContent = 'Sending Notification...';
  
  try {
    const dynamicType = window.getDynamicType('nr');
    const weightVal = $('#nr_weight').value.trim();
    const commentsVal = $('#nr_comments').value.trim();
    
    let photoLinksHTML = "";
    let attachmentUrls = []; 
    
    for (let i = 0; i < window.nrPhotoBlobs.length; i++) {
      const file = window.nrPhotoBlobs[i]; 
      const cleanFileName = file.name.replace(/[^a-zA-Z0-9.]/g, '');
      const path = `${soVal}-return-${Date.now()}-${i}-${cleanFileName}`;
      const { error: uploadError } = await supabaseClient.storage.from('freight-photos').upload(path, file);
      if(!uploadError) {
        const publicUrl = `https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/freight-photos/${path}`;
        photoLinksHTML += `<a href="${publicUrl}">View Attached Photo ${i+1}</a><br>`;
        attachmentUrls.push(publicUrl);
      }
    }

    const currentTimeStamp = new Date().toLocaleString();
    const emailSubject = `RETURN NOTIFICATION: SO ${soVal} - ${custVal}`;
    let emailBody = `A new return has been received. Details below:<br><br>
    ----------------------------------------------------------------------<br>
    <b>SO#</b>                   | ${soVal}<br>
    <b>Customer</b>              | ${custVal}<br>
    <b>Container(s)</b>          | ${dynamicType || 'None'}<br>
    <b>Location</b>              | ${locVal}<br>
    <b>Total Weight (In lbs)</b> | ${weightVal || '—'}<br>
    <b>Received By</b>           | ${receivedByVal}<br>
    <b>Received At</b>           | ${currentTimeStamp}<br>
    <b>Comments</b>              | ${commentsVal || 'None'}<br>
    ----------------------------------------------------------------------<br><br>`;
    
    if (photoLinksHTML !== "") emailBody += `<b>Photos:</b><br>${photoLinksHTML}<br><br>`;
    emailBody += window.buildEmailNotificationFooter();

    window.sendPmEmailWebhook({
        to: finalPmEmail,
        cc: "warehouse1@swiftsupply.ca",
        subject: emailSubject,
        body: emailBody,
        attachments: attachmentUrls,
        has_attachments: attachmentUrls.length > 0
      });

    window.logAction('staging', `Sent Automated Return Notification for SO: ${soVal}`);
    if(typeof window.showNotification === 'function') window.showNotification('Return Notification Sent Successfully');
    if (typeof window.rememberPersonBy === 'function') window.rememberPersonBy(receivedByVal);
    window.closeModal('notifyReturnModal');

  } catch(e) { alert("System Error: " + e.message); }
  
  $('#nr_submitBtn').disabled = false; $('#nr_submitBtn').textContent = 'Submit Return Notification';
};

window.pnPhotoBlobs = [];

window.openPoNotifyModal = async function() {
  if (!(await window.openModal('poNotifyModal', { requireShared: false }))) return;
  if ($('#pn_po')) $('#pn_po').value = '';
  if ($('#pn_cust')) $('#pn_cust').value = '';
  if ($('#pn_skid')) $('#pn_skid').value = 0;
  if ($('#pn_box')) $('#pn_box').value = 0;
  if ($('#pn_crate')) $('#pn_crate').value = 0;
  if ($('#pn_pipe')) $('#pn_pipe').value = 0;
  if ($('#pn_other')) $('#pn_other').value = 0;
  if ($('#pn_loc')) $('#pn_loc').value = '';
  if ($('#pn_weight')) $('#pn_weight').value = '';
  if ($('#pn_comments')) $('#pn_comments').value = '';
  if ($('#pn_received_by')) $('#pn_received_by').value = currentUser ? currentUser.email.split('@')[0] : '';
  if ($('#pn_pm_email')) $('#pn_pm_email').value = '';
  window.pnPhotoBlobs = [];
  if (typeof window.renderPNPhotoStrip === 'function') window.renderPNPhotoStrip();
};

window.submitPoNotification = async function() {
  const poVal = $('#pn_po').value.trim();
  const custVal = $('#pn_cust').value.trim();
  const locVal = $('#pn_loc').value.trim();
  const receivedByVal = $('#pn_received_by').value.trim();
  const pmNameVal = $('#pn_pm_email') ? $('#pn_pm_email').value.trim() : '';

  if (!poVal || !custVal || !locVal || !receivedByVal) return alert('Please fill out all required fields (*).');
  if (pmNameVal && !window.resolvePmSmsEmail(pmNameVal)) {
    return alert('Please select a valid PM name from the list.');
  }

  $('#pn_submitBtn').disabled = true; $('#pn_submitBtn').textContent = 'Sending Notification...';

  try {
    const dynamicType = window.getDynamicType('pn');
    const weightVal = $('#pn_weight').value.trim();
    const commentsVal = $('#pn_comments').value.trim();

    let photoLinksHTML = '';
    let attachmentUrls = [];

    for (let i = 0; i < window.pnPhotoBlobs.length; i++) {
      const file = window.pnPhotoBlobs[i];
      const cleanFileName = file.name.replace(/[^a-zA-Z0-9.]/g, '');
      const path = `${poVal}-po-${Date.now()}-${i}-${cleanFileName}`;
      const { error: uploadError } = await supabaseClient.storage.from('freight-photos').upload(path, file);
      if (!uploadError) {
        const publicUrl = `https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/freight-photos/${path}`;
        photoLinksHTML += `<a href="${publicUrl}">View Attached Photo ${i + 1}</a><br>`;
        attachmentUrls.push(publicUrl);
      }
    }

    const currentTimeStamp = new Date().toLocaleString();
    const emailSubject = `PO NOTIFICATION: PO ${poVal} - ${custVal}`;
    let emailBody = `A new PO has been received. Details below:<br><br>
    ----------------------------------------------------------------------<br>
    <b>PO#</b>                    | ${poVal}<br>
    <b>Customer</b>              | ${custVal}<br>
    <b>Container(s)</b>          | ${dynamicType || 'None'}<br>
    <b>Location</b>              | ${locVal}<br>
    <b>Total Weight (In lbs)</b> | ${weightVal || '—'}<br>
    <b>Received By</b>           | ${receivedByVal}<br>
    <b>Received At</b>           | ${currentTimeStamp}<br>
    <b>Comments</b>              | ${commentsVal || 'None'}<br>
    ----------------------------------------------------------------------<br><br>`;

    if (photoLinksHTML !== '') emailBody += `<b>Photos:</b><br>${photoLinksHTML}<br><br>`;
    emailBody += window.buildEmailNotificationFooter();

    window.sendPmEmailWebhook({
        to: 'warehouse1@swiftsupply.ca',
        cc: 'warehouse1@swiftsupply.ca',
        subject: emailSubject,
        body: emailBody,
        attachments: attachmentUrls,
        has_attachments: attachmentUrls.length > 0
      });

    if (pmNameVal) {
      const pmSmsEmail = window.resolvePmSmsEmail(pmNameVal);
      const smsLines = [
        `• PO: ${poVal}`,
        `• Customer: ${custVal}`,
        `• Containers: ${dynamicType || 'None'}`,
        `• Location: ${locVal}`,
        `• Weight: ${weightVal || '—'} lbs`,
        `• Received By: ${receivedByVal}`,
        `• Received At: ${currentTimeStamp}`
      ];
      if (commentsVal) smsLines.push(`• Comments: ${commentsVal}`);
      const smsBody = smsLines.join('\n');
      window.sendPmEmailWebhook({
        to: pmSmsEmail,
        cc: 'warehouse1@swiftsupply.ca',
        subject: `PO ${poVal} - ${custVal}`,
        body: smsBody,
        attachments: [],
        has_attachments: false
      });
    }

    window.logAction('staging', `Sent Automated PO Notification for PO: ${poVal}${pmNameVal ? ' (PM SMS: ' + pmNameVal + ')' : ''}`);
    if (typeof window.showNotification === 'function') window.showNotification('PO Notification Sent Successfully');
    if (typeof window.rememberPersonBy === 'function') window.rememberPersonBy(receivedByVal);
    window.closeModal('poNotifyModal');
  } catch (e) { alert('System Error: ' + e.message); }

  $('#pn_submitBtn').disabled = false; $('#pn_submitBtn').textContent = 'Submit PO Notification';
};

window.resolveEmail = function(inputVal) {
  if (!inputVal) return null;
  let val = inputVal.trim();
  if (val.includes('@') && val.includes('.')) return val; 
  if (typeof rawContactsData !== 'undefined') {
    const match = rawContactsData.find(c => c.name.toLowerCase() === val.toLowerCase() || c.name.toLowerCase().includes(val.toLowerCase()));
    if (match && match.email && match.email !== 'N/A') return match.email;
  }
  return null; 
};

window.triggerUniversalConsolidate = async function(targetSo) {
  let so = typeof targetSo === 'string' ? targetSo : null;
  
  // Intelligent Context Detection: 
  // If no SO was provided via button click, pull from memory ONLY if the Edit Modal is actively open.
  if (!so && $('#editModal') && window.getComputedStyle($('#editModal')).display !== 'none') {
    if (typeof editTargetRecord !== 'undefined' && editTargetRecord && editTargetRecord.so) {
      so = editTargetRecord.so;
    }
  }

  // Hide overlapping modals to prevent z-index boxing conflicts
  window.closeModal('editModal');
  window.closeModal('orderHistoryModal');
  window.closeModal('reportNoModal');
  
  // If we STILL don't have an SO, prompt the user for one (Quick Consolidate route)
  if (!so) {
    so = prompt("Enter exact SO# to consolidate:");
    if (!so) return;
  }
  
  so = so.trim();
  const matches = appData.staging.filter(x => x.so.toLowerCase() === so.toLowerCase());
  
  if (matches.length === 0) return alert("No active staging entries found for SO: " + so);
  if (matches.length === 1) return alert("There is only 1 active entry for SO: " + so + ". Nothing to consolidate.");

  // CRITICAL FIX: Direct variable assignment (NO 'window.' prefix)
  // This ensures batch.js actually receives the target and builds the table.
  currentEditId = matches[0].id;
  editTargetRecord = matches[0];
  editTargetRecord.table = 'staging'; 
  
  if(typeof window.openSameSoModal === 'function') {
    await window.openSameSoModal();
  }
};

window.openUniversalAddModal = async function(so) {
  window.closeModal('orderHistoryModal');
  const lockFields = !!(so && so.trim());
  const existingCustomer = lockFields ? window.lookupCustomerBySo(so) : null;
  
  if($('#ra_so')) {
    $('#ra_so').value = so || '';
    $('#ra_so').disabled = lockFields;
    $('#ra_so').style.background = lockFields ? '#f1f5f9' : '';
  }
  if($('#ra_cust')) {
    $('#ra_cust').value = existingCustomer || '';
    $('#ra_cust').disabled = lockFields;
    $('#ra_cust').style.background = lockFields ? '#f1f5f9' : '';
  }
  if($('#ra_status')) { $('#ra_status').disabled = false; $('#ra_status').style.background = ''; }
  
  if($('#ra_skid')) $('#ra_skid').value=0; if($('#ra_box')) $('#ra_box').value=0; if($('#ra_crate')) $('#ra_crate').value=0; if($('#ra_pipe')) $('#ra_pipe').value=0; if($('#ra_other')) $('#ra_other').value=0; 
  if($('#ra_loc')) $('#ra_loc').value=''; if($('#ra_weight')) $('#ra_weight').value=''; if($('#ra_comments')) $('#ra_comments').value=''; 
  if($('#ra_staged_by')) { $('#ra_staged_by').value = currentUser ? currentUser.email.split('@')[0] : ''; $('#ra_staged_by').disabled = false; $('#ra_staged_by').style.background = ''; }
  
  await window.openModal('reportAddModal', { requireShared: false, zIndex: 3600 });
};
window.qsPhotoBlobs = [];

window.openQuickShipModal = async function() {
  if (!(await window.openModal('quickShipModal'))) return;
  const qsSo = $('#qs_so');
  if (!qsSo) return;
  qsSo.value = '';
  if ($('#qs_cust')) $('#qs_cust').value = '';
  if ($('#qs_skid')) $('#qs_skid').value = 0;
  if ($('#qs_box')) $('#qs_box').value = 0;
  if ($('#qs_crate')) $('#qs_crate').value = 0;
  if ($('#qs_pipe')) $('#qs_pipe').value = 0;
  if ($('#qs_other')) $('#qs_other').value = 0;
  if ($('#qs_carrier')) $('#qs_carrier').value = '';
  if ($('#qs_loc')) $('#qs_loc').value = '';
  if ($('#qs_weight')) $('#qs_weight').value = '';
  if ($('#qs_comments')) $('#qs_comments').value = '';
  if ($('#qs_by')) $('#qs_by').value = currentUser ? currentUser.email.split('@')[0] : '';
  if ($('#qs_pm_chk')) $('#qs_pm_chk').checked = false;
  window.togglePMEmail(false, 'qs_pm_email', 'qs_pm_email_btn');
  if ($('#qs_pm_email')) $('#qs_pm_email').value = '';
  window.qsPhotoBlobs = [];
  window.clearPhotoBlobs('quickship');
};

window.submitQuickShip = async function() {
  const soVal = $('#qs_so').value.trim(); const custVal = $('#qs_cust').value.trim();
  const carrierVal = $('#qs_carrier').value.trim() || 'Unassigned Carrier';
  const dispatcher = $('#qs_by').value.trim();
  const pmRaw = $('#qs_pm_email').value.trim(); const pmChecked = $('#qs_pm_chk').checked;

  if(!soVal || !custVal || !dispatcher) return alert("Missing required inputs.");
  const dynamicQty = window.getDynamicQty('qs');
  if(dynamicQty === 0) return alert("Must have at least 1 container.");

  let finalPmEmail = null;
  if (pmChecked) {
    finalPmEmail = window.resolveEmail(pmRaw);
    if (!finalPmEmail) return alert("Invalid PM Entry.");
  }

  $('#qsConfirmBtn').disabled = true; $('#qsConfirmBtn').textContent = 'Shipping...';

  try {
    let photoUrls = [];
    for (let i = 0; i < window.qsPhotoBlobs.length; i++) {
      const file = window.qsPhotoBlobs[i]; 
      const cleanFileName = file.name.replace(/[^a-zA-Z0-9.]/g, '');
      const path = `${soVal}-quickship-${Date.now()}-${i}-${cleanFileName}`;
      await supabaseClient.storage.from('freight-photos').upload(path, file); 
      photoUrls.push(path);
    }

    let pmName = finalPmEmail ? finalPmEmail.split('@')[0].split('.')[0] : null;
    if(pmName) pmName = pmName.charAt(0).toUpperCase() + pmName.slice(1);

    const dynamicType = window.getDynamicType('qs');
    const { error: insertError } = await supabaseClient.from('shipped').insert([{
      so: soVal, customer: custVal, type: dynamicType, qty: dynamicQty, carrier: carrierVal, location: $('#qs_loc').value.trim(),
      weight: $('#qs_weight').value.trim(), comments: $('#qs_comments').value.trim(), shipped_by: dispatcher, pmd_email: pmName, photo_urls: photoUrls
    }]);

    if (insertError) throw insertError;

    window.logBinMovement('to-shipped', `SO ${soVal}: ${dynamicType} moved to Shipped Log via Quick Ship (${carrierVal})`);
    window.logAction('shipped', `Added via Quick Ship: SO: ${soVal}`);
    if(typeof window.playSuccessChime === 'function') window.playSuccessChime();
    if(typeof window.showNotification === 'function') window.showNotification('Quick Ship Successful');
    if (typeof window.rememberPersonBy === 'function') window.rememberPersonBy(dispatcher);
    if (typeof window.rememberCarrier === 'function') window.rememberCarrier($('#qs_carrier').value.trim());

    if(pmChecked && finalPmEmail) {
      const currentTimeStamp = new Date().toLocaleString();
      const cachedSubject = `SHIP NOTIFICATION: SO ${soVal} - ${custVal}`;
      const cachedBody = `Your order has now been shipped! Order details:<br><br>----------------------------------------------------------------------<br><b>SO#</b>                   | ${soVal}<br><b>Customer</b>              | ${custVal}<br><b>Container(s)</b>          | ${dynamicType}<br><b>Total Weight (In lbs)</b> | ${$('#qs_weight').value.trim() || '—'}<br><b>Carrier</b>               | ${carrierVal}<br><b>Shipped At</b>            | ${currentTimeStamp}<br><b>Shipped By</b>            | ${dispatcher}<br><b>Comments</b>              | ${$('#qs_comments').value.trim() || 'None'}<br>----------------------------------------------------------------------<br><br>${window.buildEmailNotificationFooter()}`;

      const attachmentUrls = photoUrls.map(p => `https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/freight-photos/${p}`);

      window.sendPmEmailWebhook({ to: finalPmEmail, cc: "warehouse1@swiftsupply.ca", subject: cachedSubject, body: cachedBody, attachments: attachmentUrls, has_attachments: attachmentUrls.length > 0 });
    }

    window.closeModal('quickShipModal');
    window.loadCloudData();
  } catch(e) { alert("Quick Ship Error: " + e.message); } finally {
    $('#qsConfirmBtn').disabled = false; $('#qsConfirmBtn').textContent = 'Quick Ship Dispatch';
  }
};

window.checkSoConflict = async function(so, excludeId) {
  if (!so) return true;
  const conflicts = appData.staging.filter(x => x.so.toLowerCase() === so.toLowerCase() && x.id !== excludeId);
  if (conflicts.length > 0) {
    return new Promise(async resolve => {
      if ($('#conflict_so_title')) $('#conflict_so_title').textContent = so;
      let html = `<div class="history-section">`;
      html += `<h4 class="section-staging">Current Active Staging</h4>`;
      html += typeof window.formatActiveStagingList === 'function'
        ? window.formatActiveStagingList(conflicts)
        : '';
      html += `</div>`;
      if ($('#conflict_content')) $('#conflict_content').innerHTML = html;
      if (!(await window.openModal('soConflictModal', { zIndex: 4000 }))) { resolve(true); return; }

      const cancelBtn = $('#conflictCancelBtn');
      const proceedBtn = $('#conflictProceedBtn');
      if (cancelBtn) cancelBtn.onclick = () => { window.closeModal('soConflictModal'); resolve(false); };
      if (proceedBtn) proceedBtn.onclick = () => { window.closeModal('soConflictModal'); resolve(true); };
    });
  }
  return true;
};

window.PERSON_BY_FIELD_IDS = [
  'staged_by', 'e_staged_by', 'e_shipped_by', 'ra_staged_by', 'qs_by', 'm_by',
  'r_picked_by', 'r_returned_by', 'bc_staged_by', 'sp_staged_by', 'nr_received_by', 'pn_received_by'
];

const BY_ROSTER_KEY = 'swift_by_roster';
const CARRIER_ROSTER_KEY = 'swift_carrier_roster';
const ROSTER_TYPES = { person: 'person_by', carrier: 'carrier' };
window.cloudRosterCache = { person_by: null, carrier: null, loaded: false };

window.loadCloudRosters = async function() {
  try {
    const { data, error } = await supabaseClient
      .from('dropdown_roster')
      .select('roster_type, value')
      .order('value', { ascending: true });
    if (error) {
      if (error.code === '42P01') return;
      console.warn('Cloud roster load failed:', error.message);
      return;
    }
    const person = [];
    const carrier = [];
    (data || []).forEach(row => {
      const val = (row.value || '').trim();
      if (!val) return;
      if (row.roster_type === ROSTER_TYPES.person) person.push(val);
      if (row.roster_type === ROSTER_TYPES.carrier) carrier.push(val);
    });
    person.sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' }));
    carrier.sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' }));
    window.cloudRosterCache.person_by = person;
    window.cloudRosterCache.carrier = carrier;
    window.cloudRosterCache.loaded = true;
    localStorage.setItem(BY_ROSTER_KEY, JSON.stringify(person));
    localStorage.setItem(CARRIER_ROSTER_KEY, JSON.stringify(carrier));
  } catch (e) {
    console.warn('Cloud roster load error:', e);
  }
};

window.saveRosterValueToCloud = async function(rosterType, value) {
  const name = (value || '').trim();
  if (!name || !currentUser) return;
  try {
    const { error } = await supabaseClient.from('dropdown_roster').upsert(
      { roster_type: rosterType, value: name },
      { onConflict: 'roster_type,value' }
    );
    if (error) console.warn('Cloud roster save failed:', error.message);
  } catch (e) {
    console.warn('Cloud roster save error:', e);
  }
};

const BY_ROSTER_VERSION_KEY = 'swift_by_roster_version';
const BY_ROSTER_RESET_VERSION = '2';

window.initPersonByRoster = function() {
  const storedVersion = localStorage.getItem(BY_ROSTER_VERSION_KEY);
  if (storedVersion !== BY_ROSTER_RESET_VERSION) {
    localStorage.removeItem('swift_custom_bys');
    localStorage.setItem(BY_ROSTER_VERSION_KEY, BY_ROSTER_RESET_VERSION);
  }
};

window.getPersonByRoster = function() {
  window.initPersonByRoster();
  if (window.cloudRosterCache.person_by) return [...window.cloudRosterCache.person_by];
  try {
    const list = JSON.parse(localStorage.getItem(BY_ROSTER_KEY) || '[]');
    return Array.isArray(list) ? list : [];
  } catch (e) {
    return [];
  }
};

window.rememberPersonBy = function(...args) {
  let opts = {};
  const last = args[args.length - 1];
  if (last && typeof last === 'object' && !Array.isArray(last) && ('skipRefresh' in last || 'selectId' in last)) {
    opts = args.pop();
  }
  window.initPersonByRoster();
  const hidden = typeof hiddenMemory !== 'undefined' ? hiddenMemory : [];
  const roster = window.getPersonByRoster();
  let changed = false;
  args.forEach(raw => {
    const name = (raw || '').trim();
    if (!name || hidden.includes(name)) return;
    if (!roster.some(r => r.toLowerCase() === name.toLowerCase())) {
      roster.push(name);
      changed = true;
    }
  });
  if (changed) {
    roster.sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' }));
    localStorage.setItem(BY_ROSTER_KEY, JSON.stringify(roster));
    window.cloudRosterCache.person_by = [...roster];
    args.forEach(raw => {
      const name = (raw || '').trim();
      if (name) window.saveRosterValueToCloud(ROSTER_TYPES.person, name);
    });
    const dl = document.getElementById('dl_stagers');
    if (dl && typeof filterMem === 'function') {
      dl.innerHTML = filterMem(roster).map(s => `<option value="${s}"></option>`).join('');
    }
    if (opts.selectId) {
      window.refreshPersonSelect(opts.selectId, opts.selectedValue || args[args.length - 1]);
    } else if (changed && !opts.skipRefresh && typeof window.initUniversalDropdowns === 'function') {
      window.initUniversalDropdowns();
    }
  } else if (opts.selectId) {
    window.refreshPersonSelect(opts.selectId, opts.selectedValue || args[args.length - 1]);
  }
  return changed;
};

window.getPersonDropdownValues = function() {
  const hidden = typeof hiddenMemory !== 'undefined' ? hiddenMemory : [];
  return window.getPersonByRoster()
    .filter(v => v && !hidden.includes(v))
    .sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' }));
};

const CARRIER_ROSTER_VERSION_KEY = 'swift_carrier_roster_version';
const CARRIER_ROSTER_RESET_VERSION = '1';

window.initCarrierRoster = function() {
  const storedVersion = localStorage.getItem(CARRIER_ROSTER_VERSION_KEY);
  if (storedVersion !== CARRIER_ROSTER_RESET_VERSION) {
    localStorage.removeItem('swift_custom_carriers');
    localStorage.setItem(CARRIER_ROSTER_VERSION_KEY, CARRIER_ROSTER_RESET_VERSION);
  }
};

window.getCarrierRoster = function() {
  window.initCarrierRoster();
  if (window.cloudRosterCache.carrier) return [...window.cloudRosterCache.carrier];
  try {
    const list = JSON.parse(localStorage.getItem(CARRIER_ROSTER_KEY) || '[]');
    return Array.isArray(list) ? list : [];
  } catch (e) {
    return [];
  }
};

const CARRIER_SKIP_VALUES = new Set(['RETURNED TO STOCK', 'CONSOLIDATED', 'Unassigned Carrier']);

window.isRememberableCarrier = function(raw) {
  const name = (raw || '').trim();
  if (!name || CARRIER_SKIP_VALUES.has(name)) return false;
  const hidden = typeof hiddenMemory !== 'undefined' ? hiddenMemory : [];
  return !hidden.includes(name);
};

window.rememberCarrier = function(...args) {
  let opts = {};
  const last = args[args.length - 1];
  if (last && typeof last === 'object' && !Array.isArray(last) && ('skipRefresh' in last || 'selectId' in last)) {
    opts = args.pop();
  }
  window.initCarrierRoster();
  const roster = window.getCarrierRoster();
  let changed = false;
  args.forEach(raw => {
    const name = (raw || '').trim();
    if (!window.isRememberableCarrier(name)) return;
    if (!roster.some(r => r.toLowerCase() === name.toLowerCase())) {
      roster.push(name);
      changed = true;
    }
  });
  if (changed) {
    roster.sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' }));
    localStorage.setItem(CARRIER_ROSTER_KEY, JSON.stringify(roster));
    window.cloudRosterCache.carrier = [...roster];
    args.forEach(raw => {
      const name = (raw || '').trim();
      if (window.isRememberableCarrier(name)) window.saveRosterValueToCloud(ROSTER_TYPES.carrier, name);
    });
    if (opts.selectId) {
      window.refreshCarrierSelect(opts.selectId, opts.selectedValue || args[args.length - 1]);
    } else if (changed && !opts.skipRefresh && typeof window.initUniversalDropdowns === 'function') {
      window.initUniversalDropdowns();
    }
  } else if (opts.selectId) {
    window.refreshCarrierSelect(opts.selectId, opts.selectedValue || args[args.length - 1]);
  }
  return changed;
};

window.getCarrierDropdownValues = function() {
  return window.getCarrierRoster()
    .filter(v => window.isRememberableCarrier(v))
    .sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' }));
};

window.buildSelectOptionsHtml = function(values, otherNewExtra = '') {
  let html = '<option value="">-- Select --</option>';
  values.forEach(val => {
    const safe = val.replace(/"/g, '&quot;');
    html += `<option value="${safe}">${val}</option>`;
  });
  html += `<option value="OTHER_NEW"${otherNewExtra}>+ Add Other / New</option>`;
  return html;
};

window.applySelectOptions = function(el, values, selectedValue, forceUpdate, otherNewExtra = '') {
  if (!el || el.tagName !== 'SELECT') return;
  if (!forceUpdate && document.activeElement === el) return;
  const currentVal = selectedValue !== undefined ? selectedValue : el.value;
  el.innerHTML = window.buildSelectOptionsHtml(values, otherNewExtra);
  if (values.includes(currentVal) || currentVal === 'OTHER_NEW') {
    el.value = currentVal;
  } else if (currentVal) {
    const opt = document.createElement('option');
    opt.value = currentVal;
    opt.textContent = currentVal;
    el.insertBefore(opt, el.lastElementChild);
    el.value = currentVal;
  } else {
    el.value = '';
  }
};

window.refreshPersonSelect = function(id, selectedValue) {
  const el = document.getElementById(id);
  if (!el) return;
  window.applySelectOptions(el, window.getPersonDropdownValues(), selectedValue, true);
};

window.refreshCarrierSelect = function(id, selectedValue) {
  const el = document.getElementById(id);
  if (!el) return;
  window.applySelectOptions(el, window.getCarrierDropdownValues(), selectedValue, true, ' style="font-weight:bold; color:var(--brand);"');
};

window.normalizeSoKey = function(so) {
  return (so || '').trim().toLowerCase();
};

window.lookupCustomerBySo = function(so) {
  const key = window.normalizeSoKey(so);
  if (!key || typeof appData === 'undefined') return null;
  let customer = null;
  let bestTime = 0;
  const consider = (record, dateField) => {
    if (!record || window.normalizeSoKey(record.so) !== key || !record.customer) return;
    const t = new Date(record[dateField] || 0).getTime() || 0;
    if (t >= bestTime) {
      bestTime = t;
      customer = record.customer;
    }
  };
  (appData.staging || []).forEach(r => consider(r, 'entry_date'));
  (appData.shipped || []).forEach(r => consider(r, 'shipped_at'));
  return customer;
};

window.autofillCustomerFromSo = function(soInputId, customerInputId) {
  const soEl = document.getElementById(soInputId);
  const custEl = document.getElementById(customerInputId);
  if (!soEl || !custEl || custEl.disabled) return;
  const soVal = soEl.value.trim();
  if (!soVal) return;
  if (custEl.value.trim() && custEl.dataset.manualCustomer === '1') return;
  const customer = window.lookupCustomerBySo(soVal);
  if (customer) {
    custEl.value = customer;
    custEl.dataset.autoFilled = '1';
    delete custEl.dataset.manualCustomer;
  }
};

window.initSoCustomerAutofill = function() {
  const pairs = [
    { so: 'so', cust: 'customer' },
    { so: 'ra_so', cust: 'ra_cust' },
    { so: 'qs_so', cust: 'qs_cust' }
  ];
  pairs.forEach(({ so, cust }) => {
    const soEl = document.getElementById(so);
    const custEl = document.getElementById(cust);
    if (!soEl || soEl.dataset.soAutofillBound) return;
    soEl.dataset.soAutofillBound = '1';
    const run = () => window.autofillCustomerFromSo(so, cust);
    soEl.addEventListener('input', run);
    soEl.addEventListener('change', run);
    soEl.addEventListener('blur', run);
    if (custEl && !custEl.dataset.customerManualBound) {
      custEl.dataset.customerManualBound = '1';
      custEl.addEventListener('input', () => {
        if (custEl.value.trim()) custEl.dataset.manualCustomer = '1';
        else delete custEl.dataset.manualCustomer;
      });
    }
  });
};

window.ensureByFieldWrapper = function(el) {
  if (!el || el.closest('.by-field-row')) return el;
  const parent = el.parentElement;
  if (!parent) return el;
  const btn = el.nextElementSibling;
  if (btn && btn.tagName === 'BUTTON') btn.style.display = 'none';
  if (!el.closest('.by-field-row')) {
    if (parent.classList.contains('by-field-row')) return el;
    const wrap = document.createElement('div');
    wrap.className = 'by-field-row';
    wrap.style.cssText = 'display:flex; width:100%;';
    parent.insertBefore(wrap, el);
    wrap.appendChild(el);
  }
  el.style.width = '100%';
  el.style.borderTopRightRadius = '8px';
  el.style.borderBottomRightRadius = '8px';
  el.style.borderRight = '1px solid #cbd5e1';
  return el;
};

window.initUniversalDropdowns = function() {
  const carrierFields = ['qs_carrier', 'm_carrier', 'e_carrier'];

  const discovered = [...new Set([
    ...(window.PERSON_BY_FIELD_IDS || []),
    ...Array.from(document.querySelectorAll('input[id$="_by"], select[id$="_by"], input#staged_by, select#staged_by')).map(e => e.id)
  ])];

  const personOptions = window.getPersonDropdownValues();

  function syncPersonSelect(id) {
    let el = document.getElementById(id);
    if (!el) return;

    window.ensureByFieldWrapper(el);
    el = document.getElementById(id);

    if (el.tagName === 'INPUT') {
      const select = document.createElement('select');
      select.id = id;
      select.className = 'by-person-select';
      if (el.required) select.required = true;
      select.style.cssText = 'width:100%;';
      el.parentNode.replaceChild(select, el);
      el = select;
      el.addEventListener('change', function onPersonSelectChange() {
        if (el.value === 'OTHER_NEW') {
          const newVal = prompt('Enter name:');
          if (newVal && newVal.trim()) {
            const cleanVal = newVal.trim();
            window.rememberPersonBy(cleanVal, { selectId: id, selectedValue: cleanVal });
          } else {
            el.value = '';
          }
        }
      });
    } else if (!el.classList.contains('by-person-select')) {
      el.classList.add('by-person-select');
    }

    const currentVal = el.value;
    window.applySelectOptions(el, personOptions, currentVal, false);
  }

  function syncCarrierSelect(id) {
    let el = document.getElementById(id);
    if (!el) return;

    if (el.tagName === 'INPUT') {
      const select = document.createElement('select');
      select.id = id;
      select.className = el.className;
      if (el.style.cssText) select.style.cssText = el.style.cssText;
      el.parentNode.replaceChild(select, el);
      el = select;
      const btn = el.nextElementSibling;
      if (btn && btn.tagName === 'BUTTON') {
        btn.style.display = 'none';
        el.style.borderRight = '1px solid #cbd5e1';
        el.style.borderTopRightRadius = '8px';
        el.style.borderBottomRightRadius = '8px';
      }
      el.addEventListener('change', function onCarrierSelectChange() {
        if (el.value === 'OTHER_NEW') {
          const newVal = prompt('Enter new Carrier:');
          if (newVal && newVal.trim()) {
            const cleanVal = newVal.trim();
            window.rememberCarrier(cleanVal, { selectId: id, selectedValue: cleanVal });
          } else { el.value = ''; }
        }
      });
    }

    window.applySelectOptions(el, window.getCarrierDropdownValues(), el.value, false, ' style="font-weight:bold; color:var(--brand);"');
  }

  discovered.forEach(syncPersonSelect);
  carrierFields.forEach(syncCarrierSelect);
};

window.openReportAddModal = function() {
  let targetSo = '';
  let auditItem = null;
  if (window.activeReportMode && window.reportQueue?.length > 0 && typeof window.reportIndex === 'number') {
    auditItem = appData.staging.find(x => x.id === window.reportQueue[window.reportIndex]);
    if (auditItem?.so) targetSo = auditItem.so;
  }
  window.reportPhotoBlobs = [];
  if (typeof window.renderReportPhotoStrip === 'function') window.renderReportPhotoStrip();
  if ($('#reportMainModal')) $('#reportMainModal').style.display = 'none';
  if (typeof window.openUniversalAddModal === 'function') window.openUniversalAddModal(targetSo);
  if (auditItem?.location && $('#ra_loc')) $('#ra_loc').value = auditItem.location;
};

window.closeReportAddModal = function() {
  window.closeModal('reportAddModal');
  if (window.activeReportMode) window.openModal('reportMainModal', { requireShared: false });
};
