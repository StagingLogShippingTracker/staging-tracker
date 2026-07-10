// --- media.js ---

window.PHOTO_UI = {
  camera: '📷 Live Photo',
  upload: '📁 File Upload',
  autoScan: '📄 Auto Scan',
  section: 'Photos',
  badge: 'Photo',
  maxCount: 10
};

window.PHOTO_NO_SCAN = new Set(['main', 'edit']);

window.PHOTO_STRIPS = {
  main: { selector: '#mainPhotoPreviewStrip' },
  dispatch: { selector: '#photoPreviewStrip' },
  notify: { selector: '#nr_photoPreviewStrip' },
  report: { selector: '#ra_photoPreviewStrip' },
  quickship: { selector: '#qs_photoPreviewStrip' },
  edit: { selector: '#editPhotoPreviewStrip', editMode: true }
};

function getPhotoBlobArray(context) {
  switch (context) {
    case 'main': return typeof mainPhotoBlobs !== 'undefined' ? mainPhotoBlobs : null;
    case 'dispatch': return typeof selectedPhotoBlobs !== 'undefined' ? selectedPhotoBlobs : null;
    case 'notify': return window.nrPhotoBlobs;
    case 'report': return window.reportPhotoBlobs;
    case 'quickship': return window.qsPhotoBlobs;
    default: return null;
  }
}

function photoRemoveHandler(context, idx) {
  switch (context) {
    case 'main': return `mainPhotoBlobs.splice(${idx},1); window.renderContextPhotoStrip('main')`;
    case 'dispatch': return `selectedPhotoBlobs.splice(${idx},1); window.renderContextPhotoStrip('dispatch')`;
    case 'notify': return `window.nrPhotoBlobs.splice(${idx},1); window.renderContextPhotoStrip('notify')`;
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
  window.ensureAutoScanModal();
  document.querySelectorAll('.photo-options-grid').forEach(grid => {
    if (isStagingPhotoGrid(grid)) return;
    const context = inferPhotoContextFromGrid(grid);
    if (!context || window.PHOTO_NO_SCAN.has(context)) return;
    if (grid.querySelector('.photo-uploader--scan')) return;
    grid.classList.add('photo-options-grid--scan');
    const btn = document.createElement('div');
    btn.className = 'photo-uploader photo-uploader--scan';
    btn.textContent = window.PHOTO_UI.autoScan;
    btn.addEventListener('click', () => window.openAutoScan(context));
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

// --- AUTO SCAN (document camera) ---
const autoScanState = {
  context: null,
  stream: null,
  timer: null,
  stableTicks: 0,
  prevGray: null,
  prevBounds: null,
  capturing: false,
  analysisCanvas: null,
  analysisCtx: null
};

window.ensureAutoScanModal = function() {
  if (document.getElementById('autoScanModal')) return;
  document.body.insertAdjacentHTML('beforeend', `
<div id="autoScanModal" class="modal-overlay" style="display:none;">
  <div class="auto-scan-shell">
    <button type="button" class="modal-close-x" id="autoScanClose" aria-label="Close">&times;</button>
    <div class="auto-scan-hint">Fit paperwork inside the frame</div>
    <video id="autoScanVideo" autoplay playsinline muted></video>
    <canvas id="autoScanOverlay"></canvas>
    <div class="auto-scan-flash" id="autoScanFlash"></div>
    <div class="auto-scan-status is-searching" id="autoScanStatus">Position document in frame</div>
  </div>
</div>`);
  document.getElementById('autoScanClose').addEventListener('click', () => window.closeAutoScan());
  document.getElementById('autoScanModal').addEventListener('click', (e) => {
    if (e.target.id === 'autoScanModal') window.closeAutoScan();
  });
};

function autoScanSetStatus(text, ready) {
  const el = document.getElementById('autoScanStatus');
  if (!el) return;
  el.textContent = text;
  el.classList.toggle('is-ready', !!ready);
  el.classList.toggle('is-searching', !ready);
}

function autoScanResizeOverlay() {
  const video = document.getElementById('autoScanVideo');
  const overlay = document.getElementById('autoScanOverlay');
  if (!video || !overlay) return;
  const w = video.clientWidth;
  const h = video.clientHeight;
  if (w && h) {
    overlay.width = w;
    overlay.height = h;
  }
}

function autoScanDefaultGuide() {
  const padX = 0.08;
  const padY = 0.14;
  return { left: padX, top: padY, right: 1 - padX, bottom: 1 - padY };
}

function autoScanBoundsValid(bounds) {
  if (!bounds) return false;
  const w = bounds.right - bounds.left;
  const h = bounds.bottom - bounds.top;
  if (w < 0.22 || h < 0.22) return false;
  if (w > 0.96 || h > 0.96) return false;
  const ratio = w / h;
  return ratio >= 0.28 && ratio <= 3.6;
}

function autoScanBoundsDelta(a, b) {
  if (!a || !b) return 1;
  return Math.abs(a.left - b.left) + Math.abs(a.top - b.top) + Math.abs(a.right - b.right) + Math.abs(a.bottom - b.bottom);
}

function autoScanToGray(imageData) {
  const out = new Float32Array(imageData.width * imageData.height);
  const d = imageData.data;
  for (let i = 0, p = 0; i < d.length; i += 4, p++) {
    out[p] = d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114;
  }
  return out;
}

function autoScanMotionScore(gray, w, h, prevGray) {
  if (!prevGray || prevGray.length !== gray.length) return 999;
  let sum = 0;
  for (let i = 0; i < gray.length; i++) sum += Math.abs(gray[i] - prevGray[i]);
  return sum / gray.length;
}

function autoScanDetectBounds(gray, w, h) {
  const edges = new Float32Array(w * h);
  let maxEdge = 0;
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      const i = y * w + x;
      const gx = gray[i + 1] - gray[i - 1];
      const gy = gray[i + w] - gray[i - w];
      const mag = Math.sqrt(gx * gx + gy * gy);
      edges[i] = mag;
      if (mag > maxEdge) maxEdge = mag;
    }
  }
  if (maxEdge < 8) return null;
  const threshold = maxEdge * 0.42;
  const col = new Float32Array(w);
  const row = new Float32Array(h);
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      const e = edges[y * w + x];
      if (e >= threshold) {
        col[x] += e;
        row[y] += e;
      }
    }
  }
  const xStart = Math.floor(w * 0.08);
  const xEnd = Math.floor(w * 0.92);
  const yStart = Math.floor(h * 0.08);
  const yEnd = Math.floor(h * 0.92);
  const pickEdge = (arr, start, end, fromStart) => {
    let best = -1;
    let idx = fromStart ? start : end;
    const step = fromStart ? 1 : -1;
    for (let i = start; fromStart ? i <= end : i >= end; i += step) {
      if (arr[i] > best) { best = arr[i]; idx = i; }
    }
    return idx / arr.length;
  };
  const left = pickEdge(col, xStart, xEnd, true);
  const right = pickEdge(col, xStart, xEnd, false);
  const top = pickEdge(row, yStart, yEnd, true);
  const bottom = pickEdge(row, yStart, yEnd, false);
  const bounds = { left, top, right, bottom };
  return autoScanBoundsValid(bounds) ? bounds : null;
}

function autoScanEdgeScore(gray, w, h, bounds) {
  const bx0 = Math.floor(bounds.left * w);
  const bx1 = Math.floor(bounds.right * w);
  const by0 = Math.floor(bounds.top * h);
  const by1 = Math.floor(bounds.bottom * h);
  let sum = 0;
  let count = 0;
  for (let y = by0; y < by1; y++) {
    for (let x = bx0; x < bx1; x++) {
      const i = y * w + x;
      if (x > 0 && x < w - 1 && y > 0 && y < h - 1) {
        const gx = gray[i + 1] - gray[i - 1];
        const gy = gray[i + w] - gray[i - w];
        sum += Math.sqrt(gx * gx + gy * gy);
        count++;
      }
    }
  }
  return count ? sum / count : 0;
}

function autoScanDrawOverlay(bounds, ready) {
  const overlay = document.getElementById('autoScanOverlay');
  if (!overlay) return;
  const ctx = overlay.getContext('2d');
  const w = overlay.width;
  const h = overlay.height;
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = 'rgba(0,0,0,0.45)';
  ctx.fillRect(0, 0, w, h);

  const b = bounds || autoScanDefaultGuide();
  const x = b.left * w;
  const y = b.top * h;
  const rw = (b.right - b.left) * w;
  const rh = (b.bottom - b.top) * h;
  ctx.clearRect(x, y, rw, rh);

  const color = ready ? '#22c55e' : (bounds ? '#facc15' : '#ffffff');
  const len = Math.min(28, rw * 0.12, rh * 0.12);
  ctx.strokeStyle = color;
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(x, y + len); ctx.lineTo(x, y); ctx.lineTo(x + len, y);
  ctx.moveTo(x + rw - len, y); ctx.lineTo(x + rw, y); ctx.lineTo(x + rw, y + len);
  ctx.moveTo(x, y + rh - len); ctx.lineTo(x, y + rh); ctx.lineTo(x + len, y + rh);
  ctx.moveTo(x + rw - len, y + rh); ctx.lineTo(x + rw, y + rh); ctx.lineTo(x + rw, y + rh - len);
  ctx.stroke();

  if (bounds) {
    ctx.strokeStyle = ready ? 'rgba(34,197,94,0.9)' : 'rgba(250,204,21,0.85)';
    ctx.lineWidth = 2;
    ctx.strokeRect(x, y, rw, rh);
  }
}

function autoScanAnalyzeFrame() {
  const video = document.getElementById('autoScanVideo');
  if (!video || video.readyState < 2 || autoScanState.capturing) return null;

  if (!autoScanState.analysisCanvas) {
    autoScanState.analysisCanvas = document.createElement('canvas');
    autoScanState.analysisCtx = autoScanState.analysisCanvas.getContext('2d', { willReadFrequently: true });
  }
  const aw = 200;
  const ah = 150;
  autoScanState.analysisCanvas.width = aw;
  autoScanState.analysisCanvas.height = ah;
  autoScanState.analysisCtx.drawImage(video, 0, 0, aw, ah);
  const imageData = autoScanState.analysisCtx.getImageData(0, 0, aw, ah);
  const gray = autoScanToGray(imageData);
  const motion = autoScanMotionScore(gray, aw, ah, autoScanState.prevGray);
  autoScanState.prevGray = gray;

  let bounds = autoScanDetectBounds(gray, aw, ah);
  const hasDetectedDoc = !!bounds;
  if (!bounds) bounds = autoScanDefaultGuide();
  const edgeScore = autoScanEdgeScore(gray, aw, ah, bounds);
  const detected = hasDetectedDoc && edgeScore > 11;
  const still = motion < 9.5;
  const boundsStable = autoScanBoundsDelta(bounds, autoScanState.prevBounds) < 0.035;
  autoScanState.prevBounds = bounds;

  return { bounds, detected, still, boundsStable, edgeScore, motion };
}

function autoScanCapture(bounds) {
  const video = document.getElementById('autoScanVideo');
  if (!video || !autoScanState.context) return;
  autoScanState.capturing = true;
  const flash = document.getElementById('autoScanFlash');
  if (flash) {
    flash.classList.add('active');
    setTimeout(() => flash.classList.remove('active'), 180);
  }

  const b = bounds || autoScanDefaultGuide();
  const vw = video.videoWidth;
  const vh = video.videoHeight;
  const pad = 0.02;
  const left = Math.max(0, (b.left - pad) * vw);
  const top = Math.max(0, (b.top - pad) * vh);
  const right = Math.min(vw, (b.right + pad) * vw);
  const bottom = Math.min(vh, (b.bottom + pad) * vh);
  const width = Math.max(1, right - left);
  const height = Math.max(1, bottom - top);

  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  ctx.filter = 'contrast(1.12) brightness(1.04)';
  ctx.drawImage(video, left, top, width, height, 0, 0, width, height);

  canvas.toBlob((blob) => {
    if (blob) {
      window.addPhotoFromBlob(blob, autoScanState.context);
      if (typeof window.showNotification === 'function') window.showNotification('Document scanned');
    }
    window.closeAutoScan();
  }, 'image/jpeg', 0.92);
}

function autoScanTick() {
  autoScanResizeOverlay();
  const result = autoScanAnalyzeFrame();
  if (!result) return;

  const { bounds, detected, still, boundsStable } = result;
  const ready = detected && still && boundsStable;

  if (ready) {
    autoScanState.stableTicks++;
    autoScanSetStatus('Hold still — scanning…', false);
    autoScanDrawOverlay(bounds, autoScanState.stableTicks >= 4);
    if (autoScanState.stableTicks >= 6) {
      autoScanSetStatus('Captured!', true);
      autoScanCapture(bounds);
      return;
    }
  } else {
    autoScanState.stableTicks = 0;
    if (!detected) autoScanSetStatus('Position document in frame', false);
    else if (!still) autoScanSetStatus('Hold camera steady', false);
    else autoScanSetStatus('Align document edges', false);
    autoScanDrawOverlay(bounds, false);
  }
}

window.openAutoScan = async function(context) {
  if (window.PHOTO_NO_SCAN.has(context)) return;
  const blobs = getPhotoBlobArray(context);
  if (blobs && blobs.length >= window.PHOTO_UI.maxCount) {
    alert(`Maximum of ${window.PHOTO_UI.maxCount} photos reached.`);
    return;
  }
  if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
    alert('Camera access is not available on this device.');
    return;
  }

  window.ensureAutoScanModal();
  autoScanState.context = context;
  autoScanState.stableTicks = 0;
  autoScanState.prevGray = null;
  autoScanState.prevBounds = null;
  autoScanState.capturing = false;
  autoScanSetStatus('Position document in frame', false);
  autoScanDrawOverlay(null, false);

  const modal = document.getElementById('autoScanModal');
  modal.style.display = 'flex';

  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: 'environment' }, width: { ideal: 1920 }, height: { ideal: 1080 } },
      audio: false
    });
    autoScanState.stream = stream;
    const video = document.getElementById('autoScanVideo');
    video.srcObject = stream;
    await video.play();
    autoScanResizeOverlay();
    if (autoScanState.timer) clearInterval(autoScanState.timer);
    autoScanState.timer = setInterval(autoScanTick, 150);
    window.addEventListener('resize', autoScanResizeOverlay);
  } catch (e) {
    alert('Unable to access camera: ' + (e.message || 'permission denied'));
    window.closeAutoScan();
  }
};

window.closeAutoScan = function() {
  if (autoScanState.timer) {
    clearInterval(autoScanState.timer);
    autoScanState.timer = null;
  }
  window.removeEventListener('resize', autoScanResizeOverlay);
  if (autoScanState.stream) {
    autoScanState.stream.getTracks().forEach(t => t.stop());
    autoScanState.stream = null;
  }
  const video = document.getElementById('autoScanVideo');
  if (video) video.srcObject = null;
  const modal = document.getElementById('autoScanModal');
  if (modal) modal.style.display = 'none';
  autoScanState.context = null;
  autoScanState.capturing = false;
  autoScanState.stableTicks = 0;
  autoScanState.prevGray = null;
  autoScanState.prevBounds = null;
};
