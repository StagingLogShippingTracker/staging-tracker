// --- media.js ---

// --- UNIFIED PHOTO UPLOAD ENGINE ---
window.handlePhotoUpload = function(inputEl, context = 'main') {
  if (!inputEl.files || inputEl.files.length === 0) return;

  if (context === 'edit' && (!editTargetRecord.photo_urls || editTargetRecord.photo_urls === null)) {
     editTargetRecord.photo_urls = [];
  }

  Array.from(inputEl.files).forEach(f => {
    if (context === 'edit') {
      const cleanFileName = f.name.replace(/[^a-zA-Z0-9.]/g, ''); 
      const path = `edit-${Date.now()}-${cleanFileName}`;
      
      const saveBtn = document.querySelector('#editSaveBtn');
      if(saveBtn) { saveBtn.disabled = true; saveBtn.textContent = 'Uploading...'; }

      supabaseClient.storage.from('freight-photos').upload(path, f).then(({error}) => {
        if(saveBtn) { saveBtn.disabled = false; saveBtn.textContent = 'Save'; }
        if(!error) { 
          editTargetRecord.photo_urls.push(path); 
          window.renderEditPhotoStrip(); 
        } else {
          alert("Photo upload failed: " + error.message);
        }
      });
    } else if (context === 'dispatch') {
      if (typeof selectedPhotoBlobs !== 'undefined' && selectedPhotoBlobs.length < 10) selectedPhotoBlobs.push(f);
    } else if (context === 'notify') {
      if (typeof window.nrPhotoBlobs !== 'undefined' && window.nrPhotoBlobs.length < 10) window.nrPhotoBlobs.push(f);
    } else if (context === 'report') {
      if (typeof window.reportPhotoBlobs !== 'undefined' && window.reportPhotoBlobs.length < 10) window.reportPhotoBlobs.push(f);
    } else {
      if (typeof mainPhotoBlobs !== 'undefined' && mainPhotoBlobs.length < 10) mainPhotoBlobs.push(f);
    }
  });

  if (context === 'main') window.renderMainPhotoStrip();
  else if (context === 'dispatch') window.renderPhotoStrip('#photoPreviewStrip', selectedPhotoBlobs);
  else if (context === 'notify' && typeof window.renderNRPhotoStrip === 'function') window.renderNRPhotoStrip();
  else if (context === 'report' && typeof window.renderReportPhotoStrip === 'function') window.renderReportPhotoStrip();
};

window.deleteEditPhoto = async function(index) {
  if (!confirm("Remove this photo permanently?")) return;
  const path = editTargetRecord.photo_urls[index];
  try {
    await supabaseClient.storage.from('freight-photos').remove([path]);
    editTargetRecord.photo_urls.splice(index, 1);
    
    const payload = { photo_urls: editTargetRecord.photo_urls };
    const { error } = await supabaseClient.from(editTargetRecord.table).update(payload).eq('id', editTargetRecord.id);
    
    if (error) throw error;
    
    window.renderEditPhotoStrip();
    window.loadCloudData();
    if (typeof window.showNotification === 'function') window.showNotification('Photo Removed');
  } catch(e) {
    alert("Error removing photo: " + e.message);
  }
};

window.renderPhotoStrip = function(selector, blobsArray) {
  const container = document.querySelector(selector); if(!container) return; container.innerHTML = '';
  if (selector === '#photoPreviewStrip' && activeShipTargetItem && activeShipTargetItem.photo_urls) {
    activeShipTargetItem.photo_urls.forEach((url, idx) => {
      container.insertAdjacentHTML('beforeend', `<span class="photo-badge">📎 Staged-${idx+1} <span onclick="activeShipTargetItem.photo_urls.splice(${idx},1); window.renderPhotoStrip('${selector}', selectedPhotoBlobs)">&times;</span></span>`);
    });
  }
  blobsArray.forEach((f, idx) => {
    container.insertAdjacentHTML('beforeend', `<span class="photo-badge">📎 Upload-${idx+1} <span onclick="selectedPhotoBlobs.splice(${idx},1); window.renderPhotoStrip('${selector}', selectedPhotoBlobs)">&times;</span></span>`);
  });
};

window.renderMainPhotoStrip = function() {
  const container = document.querySelector('#mainPhotoPreviewStrip'); if(!container) return; container.innerHTML = '';
  if (typeof mainPhotoBlobs === 'undefined') return;
  mainPhotoBlobs.forEach((f, idx) => {
    container.insertAdjacentHTML('beforeend', `<span class="photo-badge">📎 Img-${idx+1} <span onclick="mainPhotoBlobs.splice(${idx},1); window.renderMainPhotoStrip()">&times;</span></span>`);
  });
};

window.renderEditPhotoStrip = function() {
  const container = document.querySelector('#editPhotoPreviewStrip'); if(!container) return; container.innerHTML = '';
  if (!editTargetRecord.photo_urls || editTargetRecord.photo_urls.length === 0) return;
  editTargetRecord.photo_urls.forEach((url, idx) => {
    container.insertAdjacentHTML('beforeend', `<span class="photo-badge" style="background:#e0f2fe; color:#0369a1;">🖼️ Saved-${idx+1} <span onclick="window.deleteEditPhoto(${idx})" style="color:#dc2626; margin-left:4px;">&times;</span></span>`);
  });
};

window.openPhotoViewer = function(id, indexToOpen = 0) {
  const o = appData.staging.find(x => x.id === id) || appData.shipped.find(x => x.id === id);
  if(!o || !o.photo_urls || o.photo_urls.length === 0) return;
  const gal = document.querySelector('#modalPhotoGallery');
  gal.innerHTML = o.photo_urls.map(p => `<a href="${SUPABASE_URL}/storage/v1/object/public/freight-photos/${p}" target="_blank" style="display:block; text-decoration:none;"><img src="${SUPABASE_URL}/storage/v1/object/public/freight-photos/${p}" style="width:100%; height:140px; object-fit:cover; border-radius:10px; border:1px solid #cbd5e1; box-shadow:0 2px 4px rgba(0,0,0,0.1);"><div style="text-align:center; font-size:11px; margin-top:6px; font-weight:700; color:#4b5563;">TAP TO ENLARGE</div></a>`).join('');
  document.querySelector('#viewModal').style.display = 'flex';
};
