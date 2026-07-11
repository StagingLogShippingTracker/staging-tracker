// --- media.js ---

window.PHOTO_UI = {
  camera: '📷 Live Photo',
  upload: '📁 File Upload',
  autoScan: '📄 Scan Document',
  section: 'Photos',
  badge: 'Photo',
  maxCount: 10
};

window.PHOTO_NO_SCAN = new Set(['main', 'edit']);

window.PHOTO_STRIPS = {
  main: { selector: '#mainPhotoPreviewStrip' },
  dispatch: { selector: '#photoPreviewStrip' },
  notify: { selector: '#nr_photoPreviewStrip' },
  ponotify: { selector: '#pn_photoPreviewStrip' },
  report: { selector: '#ra_photoPreviewStrip' },
  quickship: { selector: '#qs_photoPreviewStrip' },
  edit: { selector: '#editPhotoPreviewStrip', editMode: true }
};

function getPhotoBlobArray(context) {
  switch (context) {
    case 'main': return typeof mainPhotoBlobs !== 'undefined' ? mainPhotoBlobs : null;
    case 'dispatch': return typeof selectedPhotoBlobs !== 'undefined' ? selectedPhotoBlobs : null;
    case 'notify': return window.nrPhotoBlobs;
    case 'ponotify': return window.pnPhotoBlobs;
    case 'report': return window.reportPhotoBlobs;
    case 'quickship': return window.qsPhotoBlobs;
    default: return null;
  }
}
window.getPhotoBlobArray = getPhotoBlobArray;

function photoRemoveHandler(context, idx) {
  switch (context) {
    case 'main': return `mainPhotoBlobs.splice(${idx},1); window.renderContextPhotoStrip('main')`;
    case 'dispatch': return `selectedPhotoBlobs.splice(${idx},1); window.renderContextPhotoStrip('dispatch')`;
    case 'notify': return `window.nrPhotoBlobs.splice(${idx},1); window.renderContextPhotoStrip('notify')`;
    case 'ponotify': return `window.pnPhotoBlobs.splice(${idx},1); window.renderContextPhotoStrip('ponotify')`;
    case 'report': return `window.reportPhotoBlobs.splice(${idx},1); window.renderContextPhotoStrip('report')`;
    case 'quickship': return `window.qsPhotoBlobs.splice(${idx},1); window.renderContextPhotoStrip('quickship')`;
    default: return '';
  }
}

function appendPhotoBadge(container, label, removeOnclick, saved) {
  const cls = saved ? 'photo-badge photo-badge-saved' : 'photo-badge';
  container.insertAdjacentHTML('beforeend',
    `<span class="${cls}">📎 ${label} <span onclick="${removeOnclick}">&times;</span></span>`);
}

window.renderContextPhotoStrip = function(context) {
  const config = window.PHOTO_STRIPS[context];
  if (!config) return;
  const container = document.querySelector(config.selector);
  if (!container) return;
  container.innerHTML = '';
  const badge = window.PHOTO_UI.badge;
  let num = 0;

  if (config.editMode) {
    if (!editTargetRecord || !editTargetRecord.photo_urls || editTargetRecord.photo_urls.length === 0) return;
    editTargetRecord.photo_urls.forEach((url, idx) => {
      appendPhotoBadge(container, `${badge} ${idx + 1}`, `window.deleteEditPhoto(${idx})`, true);
    });
    return;
  }

  if (context === 'dispatch' && activeShipTargetItem && activeShipTargetItem.photo_urls) {
    activeShipTargetItem.photo_urls.forEach((url, idx) => {
      appendPhotoBadge(container, `${badge} ${idx + 1}`,
        `activeShipTargetItem.photo_urls.splice(${idx},1); window.renderContextPhotoStrip('dispatch')`, true);
    });
    num = activeShipTargetItem.photo_urls.length;
  }

  const blobs = getPhotoBlobArray(context);
  if (!blobs) return;
  blobs.forEach((f, idx) => {
    appendPhotoBadge(container, `${badge} ${num + idx + 1}`, photoRemoveHandler(context, idx), false);
  });
};

window.clearPhotoBlobs = function(context) {
  const blobs = getPhotoBlobArray(context);
  if (blobs) blobs.length = 0;
  window.renderContextPhotoStrip(context);
};

window.renderMainPhotoStrip = function() { window.renderContextPhotoStrip('main'); };
window.renderPhotoStrip = function() { window.renderContextPhotoStrip('dispatch'); };
window.renderNRPhotoStrip = function() { window.renderContextPhotoStrip('notify'); };
window.renderPNPhotoStrip = function() { window.renderContextPhotoStrip('ponotify'); };
window.renderReportPhotoStrip = function() { window.renderContextPhotoStrip('report'); };
window.renderQsPhotoStrip = function() { window.renderContextPhotoStrip('quickship'); };
window.renderEditPhotoStrip = function() { window.renderContextPhotoStrip('edit'); };

window.initPhotoFields = function() {
  document.querySelectorAll('.photo-options-grid .photo-uploader:not(.photo-uploader--scan)').forEach((btn) => {
    const grid = btn.closest('.photo-options-grid');
    const uploaders = grid ? grid.querySelectorAll('.photo-uploader:not(.photo-uploader--scan)') : [];
    const idx = Array.from(uploaders).indexOf(btn);
    if (idx === 0) btn.textContent = window.PHOTO_UI.camera;
    else if (idx === 1) btn.textContent = window.PHOTO_UI.upload;
  });
  document.querySelectorAll('#editPhotoSection > label').forEach(l => {
    l.textContent = window.PHOTO_UI.section;
    l.classList.add('photo-section-label');
  });
  window.injectAutoScanButtons();
};

function inferPhotoContextFromGrid(grid) {
  const input = grid.querySelector('input[type="file"][onchange*="handlePhotoUpload"]');
  if (!input) return null;
  const match = input.getAttribute('onchange').match(/handlePhotoUpload\(this,\s*'([^']+)'\)/);
  return match ? match[1] : null;
}

function isStagingPhotoGrid(grid) {
  return !!(grid.closest('#entryFormCard') || grid.closest('#editPhotoSection'));
}

window.injectAutoScanButtons = function() {
  if (typeof window.ensureAutoScanModal === 'function') window.ensureAutoScanModal();
  document.querySelectorAll('.photo-options-grid').forEach(grid => {
    if (isStagingPhotoGrid(grid)) return;
    const context = inferPhotoContextFromGrid(grid);
    if (!context || window.PHOTO_NO_SCAN.has(context)) return;

    grid.querySelectorAll('.photo-uploader--scan').forEach(el => el.remove());

    grid.classList.add('photo-options-grid--scan');
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'photo-uploader photo-uploader--scan';
    btn.textContent = window.PHOTO_UI.autoScan;
    btn.dataset.autoscanVersion = '2';
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      window.openAutoScan(context);
    });
    grid.appendChild(btn);
  });
};

window.addPhotoFromBlob = function(blob, context, filename) {
  const name = filename || `scan-${Date.now()}.jpg`;
  const file = new File([blob], name, { type: blob.type || 'image/jpeg' });
  const blobs = getPhotoBlobArray(context);
  if (!blobs) return false;
  if (blobs.length >= window.PHOTO_UI.maxCount) {
    alert(`Maximum of ${window.PHOTO_UI.maxCount} photos reached.`);
    return false;
  }
  blobs.push(file);
  window.renderContextPhotoStrip(context);
  return true;
};

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
      if (saveBtn) { saveBtn.disabled = true; saveBtn.textContent = 'Uploading...'; }

      supabaseClient.storage.from('freight-photos').upload(path, f).then(({ error }) => {
        if (saveBtn) { saveBtn.disabled = false; saveBtn.textContent = 'Save'; }
        if (!error) {
          editTargetRecord.photo_urls.push(path);
          window.renderEditPhotoStrip();
        } else {
          alert('Photo upload failed: ' + error.message);
        }
      });
    } else {
      const blobs = getPhotoBlobArray(context);
      if (blobs && blobs.length < window.PHOTO_UI.maxCount) blobs.push(f);
    }
  });

  inputEl.value = '';
  if (context !== 'edit') window.renderContextPhotoStrip(context);
};

window.handleQsPhotoUpload = function(inputEl) {
  window.handlePhotoUpload(inputEl, 'quickship');
};

window.deleteEditPhoto = async function(index) {
  if (!confirm('Remove this photo permanently?')) return;
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
  } catch (e) {
    alert('Error removing photo: ' + e.message);
  }
};

window.openPhotoViewer = function(id, indexToOpen = 0) {
  const o = appData.staging.find(x => x.id === id) || appData.shipped.find(x => x.id === id);
  if (!o || !o.photo_urls || o.photo_urls.length === 0) return;
  const gal = document.querySelector('#modalPhotoGallery');
  gal.innerHTML = o.photo_urls.map(p => `<a href="${SUPABASE_URL}/storage/v1/object/public/freight-photos/${p}" target="_blank" style="display:block; text-decoration:none;"><img src="${SUPABASE_URL}/storage/v1/object/public/freight-photos/${p}" style="width:100%; height:140px; object-fit:cover; border-radius:10px; border:1px solid #cbd5e1; box-shadow:0 2px 4px rgba(0,0,0,0.1);"><div style="text-align:center; font-size:11px; margin-top:6px; font-weight:700; color:#4b5563;">TAP TO ENLARGE</div></a>`).join('');
  document.querySelector('#viewModal').style.display = 'flex';
};
