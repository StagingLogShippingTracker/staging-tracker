// --- autoscan.js — document scanner with torch, crop preview, and filters ---

const AUTO_SCAN_FILTERS = {
  none: { label: 'Original (color)', apply: (canvas) => canvas },
  bw: { label: 'Simple B&W', apply: autoScanFilterSimpleBw },
  bwStrong: { label: 'Strong B&W', apply: autoScanFilterStrongBw },
  document: { label: 'Document (adaptive)', apply: autoScanFilterDocument },
  contrast: { label: 'High contrast', apply: autoScanFilterHighContrast }
};

const autoScanState = {
  context: null,
  mode: 'scan',
  stream: null,
  videoTrack: null,
  timer: null,
  torchRetryTimer: null,
  stableTicks: 0,
  prevGray: null,
  prevBounds: null,
  prevCorners: null,
  corners: null,
  bounds: null,
  capturing: false,
  cameraStarting: false,
  torchOn: true,
  torchSupported: false,
  analysisCanvas: null,
  analysisCtx: null,
  review: null,
  cropDrag: null
};

window.ensureAutoScanModal = function() {
  if (document.getElementById('autoScanModal')) return;
  document.body.insertAdjacentHTML('beforeend', `
<div id="autoScanModal" class="modal-overlay" style="display:none;">
  <div class="auto-scan-shell">
    <button type="button" class="modal-close-x" id="autoScanClose" aria-label="Close">&times;</button>

    <div id="autoScanPermissionPanel" class="auto-scan-permission">
      <div class="auto-scan-permission-card">
        <div class="auto-scan-permission-icon" aria-hidden="true">📷</div>
        <h3>Camera &amp; Flash Access</h3>
        <p>Auto Scan uses your rear camera and turns on the flash automatically for clearer document photos.</p>
        <p class="auto-scan-permission-note">Tap the button below, then choose <strong>Allow</strong> when your device asks for camera permission.</p>
        <button type="button" id="autoScanPermissionBtn" class="btn auto-scan-permission-btn">Allow Camera &amp; Flash</button>
        <button type="button" id="autoScanPermissionCancel" class="btn btn-muted auto-scan-permission-cancel">Cancel</button>
      </div>
    </div>

    <div id="autoScanScanPanel" class="auto-scan-panel" style="display:none;">
      <div class="auto-scan-hint">Align paperwork inside the frame — flash turns on automatically</div>
      <button type="button" id="autoScanTorchBtn" class="auto-scan-torch-btn" title="Toggle flash">⚡ Flash On</button>
      <video id="autoScanVideo" autoplay playsinline muted></video>
      <canvas id="autoScanOverlay"></canvas>
      <div class="auto-scan-flash" id="autoScanFlash"></div>
      <button type="button" id="autoScanManualBtn" class="auto-scan-manual-btn">Capture now</button>
      <div class="auto-scan-status is-searching" id="autoScanStatus">Position document in frame</div>
    </div>

    <div id="autoScanReviewPanel" class="auto-scan-review" style="display:none;">
      <div class="auto-scan-review-header">
        <h3>Review scan</h3>
        <p class="auto-scan-review-sub">Adjust crop borders if needed, pick a filter, then confirm or retry.</p>
      </div>
      <div id="autoScanCropEditor" class="auto-scan-crop-editor" style="display:none;">
        <div class="auto-scan-crop-stage">
          <canvas id="autoScanCropSource"></canvas>
          <canvas id="autoScanCropOverlay"></canvas>
        </div>
        <p class="auto-scan-crop-hint">Drag the corner handles to match the document edges</p>
      </div>
      <div class="auto-scan-review-preview-wrap">
        <canvas id="autoScanReviewPreview"></canvas>
      </div>
      <div class="auto-scan-review-controls">
        <label class="auto-scan-filter-label" for="autoScanFilterSelect">Scan filter</label>
        <select id="autoScanFilterSelect" class="auto-scan-filter-select"></select>
        <div class="auto-scan-review-actions">
          <button type="button" id="autoScanAdjustCropBtn" class="btn btn-muted auto-scan-btn">Adjust crop</button>
          <button type="button" id="autoScanRetryBtn" class="btn auto-scan-btn" style="background:#64748b;">Retry</button>
          <button type="button" id="autoScanConfirmBtn" class="btn auto-scan-btn">Use this scan</button>
        </div>
      </div>
    </div>
  </div>
</div>`);

  document.getElementById('autoScanClose').addEventListener('click', () => window.closeAutoScan());
  document.getElementById('autoScanModal').addEventListener('click', (e) => {
    if (e.target.id === 'autoScanModal') window.closeAutoScan();
  });
  document.getElementById('autoScanPermissionBtn').addEventListener('click', () => window.autoScanStartCamera());
  document.getElementById('autoScanPermissionCancel').addEventListener('click', () => window.closeAutoScan());
  document.getElementById('autoScanTorchBtn').addEventListener('click', () => window.toggleAutoScanTorch());
  document.getElementById('autoScanManualBtn').addEventListener('click', () => window.autoScanManualCapture());
  document.getElementById('autoScanRetryBtn').addEventListener('click', () => window.autoScanRetry());
  document.getElementById('autoScanConfirmBtn').addEventListener('click', () => window.autoScanConfirm());
  document.getElementById('autoScanAdjustCropBtn').addEventListener('click', () => window.autoScanToggleCropEditor());
  document.getElementById('autoScanFilterSelect').addEventListener('change', () => window.autoScanUpdateReviewPreview());

  const cropOverlay = document.getElementById('autoScanCropOverlay');
  cropOverlay.addEventListener('pointerdown', autoScanCropPointerDown);
  cropOverlay.addEventListener('pointermove', autoScanCropPointerMove);
  cropOverlay.addEventListener('pointerup', autoScanCropPointerUp);
  cropOverlay.addEventListener('pointercancel', autoScanCropPointerUp);

  const sel = document.getElementById('autoScanFilterSelect');
  sel.innerHTML = Object.entries(AUTO_SCAN_FILTERS).map(([id, f]) =>
    `<option value="${id}">${f.label}</option>`
  ).join('');
  sel.value = 'document';
};

function autoScanShowPermissionPanel() {
  autoScanState.mode = 'permission';
  const perm = document.getElementById('autoScanPermissionPanel');
  const scan = document.getElementById('autoScanScanPanel');
  const review = document.getElementById('autoScanReviewPanel');
  if (perm) perm.style.display = 'flex';
  if (scan) scan.style.display = 'none';
  if (review) review.style.display = 'none';
}

function autoScanShowScanPanel() {
  autoScanState.mode = 'scan';
  const perm = document.getElementById('autoScanPermissionPanel');
  const scan = document.getElementById('autoScanScanPanel');
  const review = document.getElementById('autoScanReviewPanel');
  if (perm) perm.style.display = 'none';
  if (scan) scan.style.display = 'block';
  if (review) review.style.display = 'none';
  const torchBtn = document.getElementById('autoScanTorchBtn');
  if (torchBtn) torchBtn.style.display = '';
}

function autoScanShowReviewPanel() {
  autoScanState.mode = 'review';
  const perm = document.getElementById('autoScanPermissionPanel');
  if (perm) perm.style.display = 'none';
  document.getElementById('autoScanScanPanel').style.display = 'none';
  document.getElementById('autoScanReviewPanel').style.display = 'flex';
  document.getElementById('autoScanTorchBtn').style.display = 'none';
  document.getElementById('autoScanCropEditor').style.display = 'none';
  document.getElementById('autoScanAdjustCropBtn').textContent = 'Adjust crop';
}

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
  if (w && h) { overlay.width = w; overlay.height = h; }
}

function autoScanDefaultGuide() {
  return { left: 0.14, top: 0.1, right: 0.86, bottom: 0.9 };
}

function autoScanBoundsArea(bounds) {
  if (!bounds) return 0;
  return Math.max(0, bounds.right - bounds.left) * Math.max(0, bounds.bottom - bounds.top);
}

function autoScanVideoDisplayRect(video) {
  const cw = video.clientWidth || 1;
  const ch = video.clientHeight || 1;
  const vw = video.videoWidth || 1;
  const vh = video.videoHeight || 1;
  const scale = Math.min(cw / vw, ch / vh);
  const dw = vw * scale;
  const dh = vh * scale;
  return { ox: (cw - dw) / 2, oy: (ch - dh) / 2, dw, dh, cw, ch };
}

function autoScanMapPointToOverlay(pt, rect) {
  return { x: rect.ox + pt.x * rect.dw, y: rect.oy + pt.y * rect.dh };
}

function autoScanBoundsValid(bounds) {
  if (!bounds) return false;
  const bw = bounds.right - bounds.left;
  const bh = bounds.bottom - bounds.top;
  if (bw < 0.18 || bh < 0.22 || bw > 0.95 || bh > 0.95) return false;
  const area = bw * bh;
  if (area < 0.06 || area > 0.68) return false;
  const ratio = bw / bh;
  return ratio >= 0.35 && ratio <= 1.35;
}

function autoScanBoundsDelta(a, b) {
  if (!a || !b) return 1;
  return Math.abs(a.left - b.left) + Math.abs(a.top - b.top) + Math.abs(a.right - b.right) + Math.abs(a.bottom - b.bottom);
}

function autoScanCornersDelta(a, b) {
  if (!a || !b || a.length !== 4 || b.length !== 4) return 1;
  let d = 0;
  for (let i = 0; i < 4; i++) d += Math.abs(a[i].x - b[i].x) + Math.abs(a[i].y - b[i].y);
  return d;
}

function autoScanCloneCorners(corners) {
  return corners.map(p => ({ x: p.x, y: p.y }));
}

function autoScanToGray(imageData) {
  const out = new Float32Array(imageData.width * imageData.height);
  const d = imageData.data;
  for (let i = 0, p = 0; i < d.length; i += 4, p++) {
    out[p] = d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114;
  }
  return out;
}

function autoScanBlurGray(gray, w, h) {
  const out = new Float32Array(gray.length);
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      let s = 0;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) s += gray[(y + dy) * w + (x + dx)];
      }
      out[y * w + x] = s / 9;
    }
  }
  return out;
}

function autoScanOtsu(gray) {
  const hist = new Uint32Array(256);
  for (let i = 0; i < gray.length; i++) hist[Math.min(255, Math.max(0, Math.round(gray[i])))]++;
  const total = gray.length;
  let sum = 0;
  for (let i = 0; i < 256; i++) sum += i * hist[i];
  let sumB = 0, wB = 0, maxVar = 0, threshold = 128;
  for (let t = 0; t < 256; t++) {
    wB += hist[t];
    if (!wB) continue;
    const wF = total - wB;
    if (!wF) break;
    sumB += t * hist[t];
    const mB = sumB / wB;
    const mF = (sum - sumB) / wF;
    const v = wB * wF * (mB - mF) * (mB - mF);
    if (v > maxVar) { maxVar = v; threshold = t; }
  }
  return threshold;
}

function autoScanDetectPaperBounds(gray, w, h) {
  const border = Math.max(3, Math.floor(Math.min(w, h) * 0.05));
  let borderSum = 0, borderN = 0;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (x < border || x >= w - border || y < border || y >= h - border) {
        borderSum += gray[y * w + x];
        borderN++;
      }
    }
  }
  const bg = borderN ? borderSum / borderN : 90;

  const collect = (thresh) => {
    const mx = Math.floor(w * 0.04);
    const my = Math.floor(h * 0.04);
    let minX = w, minY = h, maxX = 0, maxY = 0, count = 0;
    for (let y = my; y < h - my; y++) {
      for (let x = mx; x < w - mx; x++) {
        if (gray[y * w + x] >= thresh) {
          minX = Math.min(minX, x);
          maxX = Math.max(maxX, x);
          minY = Math.min(minY, y);
          maxY = Math.max(maxY, y);
          count++;
        }
      }
    }
    if (count < w * h * 0.03) return null;
    const padX = Math.floor(w * 0.01);
    const padY = Math.floor(h * 0.01);
    return {
      left: Math.max(0, (minX - padX) / w),
      top: Math.max(0, (minY - padY) / h),
      right: Math.min(1, (maxX + 1 + padX) / w),
      bottom: Math.min(1, (maxY + 1 + padY) / h)
    };
  };

  let thresh = Math.min(215, bg + 26);
  let bounds = collect(thresh);
  if (bounds && autoScanBoundsArea(bounds) > 0.65) bounds = collect(thresh + 18);
  if (bounds && autoScanBoundsArea(bounds) > 0.65) bounds = collect(thresh + 32);
  return bounds;
}

function autoScanMeanBrightness(gray, w, h, bounds) {
  const x0 = Math.floor(bounds.left * w);
  const x1 = Math.floor(bounds.right * w);
  const y0 = Math.floor(bounds.top * h);
  const y1 = Math.floor(bounds.bottom * h);
  let sum = 0, n = 0;
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      sum += gray[y * w + x];
      n++;
    }
  }
  return n ? sum / n : 0;
}

function autoScanCannyEdges(gray, w, h) {
  const blurred = autoScanBlurGray(gray, w, h);
  const mag = new Float32Array(w * h);
  let maxM = 0;
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      const i = y * w + x;
      const gx = -blurred[i - w - 1] - 2 * blurred[i - 1] - blurred[i + w - 1] + blurred[i - w + 1] + 2 * blurred[i + 1] + blurred[i + w + 1];
      const gy = -blurred[i - w - 1] - 2 * blurred[i - w] - blurred[i - w + 1] + blurred[i + w - 1] + 2 * blurred[i + w] + blurred[i + w + 1];
      const m = Math.hypot(gx, gy);
      mag[i] = m;
      if (m > maxM) maxM = m;
    }
  }
  const hi = maxM * 0.18;
  const lo = maxM * 0.06;
  const edges = new Uint8Array(w * h);
  for (let i = 0; i < mag.length; i++) {
    if (mag[i] >= hi) edges[i] = 2;
    else if (mag[i] >= lo) edges[i] = 1;
  }
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      const i = y * w + x;
      if (edges[i] !== 1) continue;
      let strong = false;
      for (let dy = -1; dy <= 1 && !strong; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (edges[(y + dy) * w + (x + dx)] === 2) { strong = true; break; }
        }
      }
      edges[i] = strong ? 2 : 0;
    }
  }
  return edges;
}

function autoScanDetectDocument(gray, w, h) {
  const bounds = autoScanDetectPaperBounds(gray, w, h);
  if (!bounds || !autoScanBoundsValid(bounds)) return null;

  const corners = autoScanBoundsToCorners(bounds);
  const edgeScore = autoScanEdgeDensity(gray, w, h, bounds);
  const innerBright = autoScanMeanBrightness(gray, w, h, bounds);
  if (innerBright < 115 && edgeScore < 6) return null;
  return { bounds, corners, edgeScore };
}

function autoScanBoundsToCorners(bounds) {
  return [
    { x: bounds.left, y: bounds.top },
    { x: bounds.right, y: bounds.top },
    { x: bounds.right, y: bounds.bottom },
    { x: bounds.left, y: bounds.bottom }
  ];
}

function autoScanCornersToBounds(corners) {
  let left = 1, top = 1, right = 0, bottom = 0;
  corners.forEach(p => {
    left = Math.min(left, p.x);
    top = Math.min(top, p.y);
    right = Math.max(right, p.x);
    bottom = Math.max(bottom, p.y);
  });
  return { left, top, right, bottom };
}

function autoScanCornersValid(corners) {
  if (!corners || corners.length !== 4) return false;
  for (const p of corners) {
    if (p.x < 0.01 || p.x > 0.99 || p.y < 0.01 || p.y > 0.99) return false;
  }
  const b = autoScanCornersToBounds(corners);
  return autoScanBoundsArea(b) >= 0.05;
}

function autoScanEdgeDensity(gray, w, h, bounds) {
  const x0 = Math.floor(bounds.left * w);
  const x1 = Math.floor(bounds.right * w);
  const y0 = Math.floor(bounds.top * h);
  const y1 = Math.floor(bounds.bottom * h);
  let sum = 0, n = 0;
  for (let y = Math.max(1, y0); y < Math.min(h - 1, y1); y++) {
    for (let x = Math.max(1, x0); x < Math.min(w - 1, x1); x++) {
      const i = y * w + x;
      const gx = gray[i + 1] - gray[i - 1];
      const gy = gray[i + w] - gray[i - w];
      sum += Math.hypot(gx, gy);
      n++;
    }
  }
  return n ? sum / n : 0;
}

function autoScanMotionScore(gray, prevGray) {
  if (!prevGray || prevGray.length !== gray.length) return 999;
  let sum = 0;
  for (let i = 0; i < gray.length; i++) sum += Math.abs(gray[i] - prevGray[i]);
  return sum / gray.length;
}

function autoScanDrawOverlay(bounds, corners, ready) {
  const overlay = document.getElementById('autoScanOverlay');
  const video = document.getElementById('autoScanVideo');
  if (!overlay || !video) return;
  const ctx = overlay.getContext('2d');
  const w = overlay.width;
  const h = overlay.height;
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = 'rgba(0,0,0,0.55)';
  ctx.fillRect(0, 0, w, h);

  const rect = autoScanVideoDisplayRect(video);
  const normPts = corners || autoScanBoundsToCorners(bounds || autoScanDefaultGuide());
  const pts = normPts.map(p => autoScanMapPointToOverlay(p, rect));

  const drawPath = (points) => {
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    for (let i = 1; i < points.length; i++) ctx.lineTo(points[i].x, points[i].y);
    ctx.closePath();
  };

  drawPath(pts);
  ctx.save();
  ctx.clip();
  ctx.clearRect(0, 0, w, h);
  ctx.restore();

  const color = ready ? '#22c55e' : (bounds && corners ? '#facc15' : '#ffffff');
  ctx.strokeStyle = color;
  ctx.lineWidth = 3;
  drawPath(pts);
  ctx.stroke();

  const len = 22;
  ctx.fillStyle = color;
  pts.forEach((p) => {
    const px = p.x, py = p.y;
    ctx.beginPath();
    ctx.arc(px, py, 7, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(px - len, py); ctx.lineTo(px + len, py);
    ctx.moveTo(px, py - len); ctx.lineTo(px, py + len);
    ctx.stroke();
  });
}

function autoScanSampleBilinear(data, w, h, sx, sy) {
  const x = Math.max(0, Math.min(w - 1.001, sx));
  const y = Math.max(0, Math.min(h - 1.001, sy));
  const x0 = Math.floor(x), y0 = Math.floor(y);
  const x1 = Math.min(w - 1, x0 + 1);
  const y1 = Math.min(h - 1, y0 + 1);
  const tx = x - x0, ty = y - y0;
  const o = (xx, yy) => (yy * w + xx) * 4;
  const out = [0, 0, 0];
  for (let c = 0; c < 3; c++) {
    const v00 = data[o(x0, y0) + c], v10 = data[o(x1, y0) + c];
    const v01 = data[o(x0, y1) + c], v11 = data[o(x1, y1) + c];
    out[c] = (1 - tx) * (1 - ty) * v00 + tx * (1 - ty) * v10 + (1 - tx) * ty * v01 + tx * ty * v11;
  }
  return out;
}

function autoScanWarpPerspective(srcCanvas, corners, outW, outH) {
  const sw = srcCanvas.width;
  const sh = srcCanvas.height;
  const src = srcCanvas.getContext('2d').getImageData(0, 0, sw, sh);
  const out = document.createElement('canvas');
  out.width = outW;
  out.height = outH;
  const octx = out.getContext('2d');
  const img = octx.createImageData(outW, outH);
  const tl = corners[0], tr = corners[1], br = corners[2], bl = corners[3];
  for (let y = 0; y < outH; y++) {
    const v = outH <= 1 ? 0 : y / (outH - 1);
    for (let x = 0; x < outW; x++) {
      const u = outW <= 1 ? 0 : x / (outW - 1);
      const sx = (tl.x * (1 - u) * (1 - v) + tr.x * u * (1 - v) + br.x * u * v + bl.x * (1 - u) * v) * sw;
      const sy = (tl.y * (1 - u) * (1 - v) + tr.y * u * (1 - v) + br.y * u * v + bl.y * (1 - u) * v) * sh;
      const rgb = autoScanSampleBilinear(src.data, sw, sh, sx, sy);
      const i = (y * outW + x) * 4;
      img.data[i] = rgb[0];
      img.data[i + 1] = rgb[1];
      img.data[i + 2] = rgb[2];
      img.data[i + 3] = 255;
    }
  }
  octx.putImageData(img, 0, 0);
  return out;
}

function autoScanOutputSize(corners, srcW, srcH) {
  const outW = Math.max(320, Math.round(Math.hypot(corners[1].x - corners[0].x, corners[1].y - corners[0].y) * srcW));
  const outH = Math.max(320, Math.round(Math.hypot(corners[3].x - corners[0].x, corners[3].y - corners[0].y) * srcH));
  return { outW: Math.min(outW, 2400), outH: Math.min(outH, 2400) };
}

function autoScanFilterSimpleBw(canvas) {
  const out = document.createElement('canvas');
  out.width = canvas.width;
  out.height = canvas.height;
  const ctx = out.getContext('2d');
  ctx.drawImage(canvas, 0, 0);
  const img = ctx.getImageData(0, 0, out.width, out.height);
  const gray = autoScanBlurGray(autoScanToGray(img), out.width, out.height);
  const threshold = autoScanOtsu(gray);
  const d = img.data;
  for (let i = 0, p = 0; i < d.length; i += 4, p++) {
    const v = gray[p] >= threshold ? 255 : 0;
    d[i] = d[i + 1] = d[i + 2] = v;
  }
  ctx.putImageData(img, 0, 0);
  return out;
}

function autoScanFilterStrongBw(canvas) {
  const out = autoScanFilterSimpleBw(canvas);
  const ctx = out.getContext('2d');
  const img = ctx.getImageData(0, 0, out.width, out.height);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const v = d[i] > 200 ? 255 : 0;
    d[i] = d[i + 1] = d[i + 2] = v;
  }
  ctx.putImageData(img, 0, 0);
  return out;
}

function autoScanFilterDocument(canvas) {
  const out = document.createElement('canvas');
  out.width = canvas.width;
  out.height = canvas.height;
  const ctx = out.getContext('2d');
  ctx.drawImage(canvas, 0, 0);
  const img = ctx.getImageData(0, 0, out.width, out.height);
  const gray = autoScanBlurGray(autoScanToGray(img), out.width, out.height);
  const threshold = autoScanOtsu(gray);
  const d = img.data;
  for (let i = 0, p = 0; i < d.length; i += 4, p++) {
    const local = gray[p];
    const v = local >= threshold - 12 ? 255 : (local >= threshold - 35 ? 200 : 0);
    d[i] = d[i + 1] = d[i + 2] = v;
  }
  ctx.putImageData(img, 0, 0);
  return out;
}

function autoScanFilterHighContrast(canvas) {
  const out = document.createElement('canvas');
  out.width = canvas.width;
  out.height = canvas.height;
  const ctx = out.getContext('2d');
  ctx.drawImage(canvas, 0, 0);
  const img = ctx.getImageData(0, 0, out.width, out.height);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const g = d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114;
    const v = Math.max(0, Math.min(255, (g - 128) * 1.8 + 128));
    d[i] = d[i + 1] = d[i + 2] = v;
  }
  ctx.putImageData(img, 0, 0);
  return out;
}

function autoScanRectCrop(srcCanvas, bounds) {
  const b = bounds || autoScanDefaultGuide();
  const sw = srcCanvas.width;
  const sh = srcCanvas.height;
  const x0 = Math.max(0, Math.floor(b.left * sw));
  const y0 = Math.max(0, Math.floor(b.top * sh));
  const cw = Math.max(1, Math.floor((b.right - b.left) * sw));
  const ch = Math.max(1, Math.floor((b.bottom - b.top) * sh));
  const out = document.createElement('canvas');
  out.width = cw;
  out.height = ch;
  out.getContext('2d').drawImage(srcCanvas, x0, y0, cw, ch, 0, 0, cw, ch);
  return out;
}

function autoScanSanitizeCorners(corners, bounds) {
  const base = autoScanBoundsToCorners(bounds || autoScanDefaultGuide());
  if (!corners || corners.length !== 4) return base;
  const c = autoScanCloneCorners(corners).map(p => ({
    x: Math.max(0.02, Math.min(0.98, p.x)),
    y: Math.max(0.02, Math.min(0.98, p.y))
  }));
  if (!autoScanCornersValid(c)) return base;
  const warpedArea = autoScanBoundsArea(autoScanCornersToBounds(c));
  if (warpedArea < 0.05) return base;
  return c;
}

function autoScanSafeCrop(srcCanvas, corners, bounds) {
  const b = bounds || autoScanCornersToBounds(corners || autoScanBoundsToCorners(autoScanDefaultGuide()));
  const c = autoScanSanitizeCorners(corners, b);
  const { outW, outH } = autoScanOutputSize(c, srcCanvas.width, srcCanvas.height);
  const minDim = Math.min(srcCanvas.width, srcCanvas.height) * 0.18;
  if (outW >= minDim && outH >= minDim * 0.45 && autoScanCornersValid(c)) {
    const warped = autoScanWarpPerspective(srcCanvas, c, outW, outH);
    if (warped.width >= minDim && warped.height >= minDim * 0.35) return warped;
  }
  return autoScanRectCrop(srcCanvas, b);
}

function autoScanBuildFilteredWarp(srcCanvas, corners, filterId, bounds) {
  const warped = autoScanSafeCrop(srcCanvas, corners, bounds);
  const filter = AUTO_SCAN_FILTERS[filterId] || AUTO_SCAN_FILTERS.document;
  return filter.apply(warped);
}

function autoScanAnalyzeFrame() {
  const video = document.getElementById('autoScanVideo');
  if (!video || video.readyState < 2 || autoScanState.capturing || autoScanState.mode !== 'scan') return null;

  if (!autoScanState.analysisCanvas) {
    autoScanState.analysisCanvas = document.createElement('canvas');
    autoScanState.analysisCtx = autoScanState.analysisCanvas.getContext('2d', { willReadFrequently: true });
  }
  const vw = video.videoWidth || 640;
  const vh = video.videoHeight || 480;
  const aw = 560;
  const ah = Math.max(320, Math.round(560 * vh / vw));
  autoScanState.analysisCanvas.width = aw;
  autoScanState.analysisCanvas.height = ah;
  autoScanState.analysisCtx.drawImage(video, 0, 0, aw, ah);
  const imageData = autoScanState.analysisCtx.getImageData(0, 0, aw, ah);
  const gray = autoScanToGray(imageData);
  const motion = autoScanMotionScore(gray, autoScanState.prevGray);
  autoScanState.prevGray = gray;

  const doc = autoScanDetectDocument(gray, aw, ah);
  const detected = !!doc;
  const bounds = detected ? doc.bounds : null;
  const corners = detected ? doc.corners : null;
  const still = motion < 7;
  const boundsStable = detected && autoScanBoundsDelta(bounds, autoScanState.prevBounds) < 0.024;
  const cornersStable = detected && (!corners || autoScanCornersDelta(corners, autoScanState.prevCorners) < 0.05);
  autoScanState.prevBounds = detected ? bounds : null;
  autoScanState.prevCorners = detected ? corners : null;
  if (detected) {
    autoScanState.bounds = bounds;
    autoScanState.corners = corners;
  }

  return { bounds, corners, detected, still, boundsStable, cornersStable, motion };
}

function autoScanTrackTorchCaps(track) {
  const caps = track.getCapabilities?.() || {};
  return {
    torch: Object.prototype.hasOwnProperty.call(caps, 'torch'),
    fillFlash: Array.isArray(caps.fillLightMode)
      ? caps.fillLightMode.includes('flash')
      : caps.fillLightMode === 'flash'
  };
}

function autoScanTryTorchSync(track) {
  if (!track || track.readyState === 'ended') return;
  const caps = autoScanTrackTorchCaps(track);
  const syncAttempts = [];
  if (caps.torch) {
    syncAttempts.push({ advanced: [{ torch: true }] });
    syncAttempts.push({ torch: true });
  }
  if (caps.fillFlash) {
    syncAttempts.push({ advanced: [{ fillLightMode: 'flash' }] });
    syncAttempts.push({ fillLightMode: 'flash' });
  }
  if (!syncAttempts.length) {
    syncAttempts.push({ advanced: [{ torch: true }] }, { torch: true });
  }
  syncAttempts.forEach(c => {
    try { track.applyConstraints(c); } catch (_) {}
  });
}

async function autoScanTryImageCaptureTorch(track) {
  if (typeof ImageCapture === 'undefined' || !track) return false;
  try {
    const ic = new ImageCapture(track);
    const caps = await ic.getPhotoCapabilities();
    const modes = caps.fillLightMode || [];
    if (Array.isArray(modes) && modes.includes('flash')) {
      await track.applyConstraints({ advanced: [{ fillLightMode: 'flash' }] });
      return true;
    }
  } catch (_) {}
  return false;
}

async function autoScanApplyTorch(track, on) {
  if (!track || track.readyState === 'ended') return false;
  const want = !!on;
  const caps = autoScanTrackTorchCaps(track);
  if (want && !caps.torch && !caps.fillFlash) {
    autoScanTryTorchSync(track);
    return false;
  }

  const attempts = [];
  if (caps.torch) {
    attempts.push(() => track.applyConstraints({ advanced: [{ torch: want }] }));
    attempts.push(() => track.applyConstraints({ torch: want }));
  }
  if (caps.fillFlash) {
    attempts.push(() => track.applyConstraints({ advanced: [{ fillLightMode: want ? 'flash' : 'off' }] }));
    attempts.push(() => track.applyConstraints({ fillLightMode: want ? 'flash' : 'off' }));
  }
  if (!attempts.length && want) {
    attempts.push(() => track.applyConstraints({ advanced: [{ torch: true }] }));
    attempts.push(() => track.applyConstraints({ torch: true }));
  }

  for (const attempt of attempts) {
    try {
      await attempt();
      const settings = track.getSettings?.() || {};
      if (want) {
        if (settings.torch === true || settings.fillLightMode === 'flash') return true;
        if (caps.torch || caps.fillFlash) return true;
      } else if (settings.torch === false || settings.fillLightMode === 'off') {
        return true;
      }
    } catch (_) { /* try next */ }
  }
  if (want) return autoScanTryImageCaptureTorch(track);
  return false;
}

function autoScanUpdateTorchButton() {
  const btn = document.getElementById('autoScanTorchBtn');
  if (!btn) return;
  btn.style.display = '';
  if (autoScanState.torchSupported) {
    btn.textContent = autoScanState.torchOn ? '⚡ Flash On' : '⚡ Flash Off';
    btn.title = 'Toggle flash';
  } else {
    btn.textContent = autoScanState.torchOn ? '⚡ Flash (screen boost)' : '⚡ Flash Off';
    btn.title = 'Hardware flash unavailable — tap to retry or use screen boost on capture';
  }
  btn.classList.toggle('is-off', !autoScanState.torchOn);
}

async function autoScanEnableTorchImmediate(track) {
  if (!track) return false;
  autoScanTryTorchSync(track);
  let ok = await autoScanApplyTorch(track, true);
  if (!ok) {
    for (const delay of [40, 100, 200, 400]) {
      await new Promise(r => setTimeout(r, delay));
      autoScanTryTorchSync(track);
      ok = await autoScanApplyTorch(track, true);
      if (ok) break;
    }
  }
  autoScanState.torchSupported = ok;
  autoScanUpdateTorchButton();
  return ok;
}

async function autoScanOpenCameraStream() {
  const base = {
    facingMode: { ideal: 'environment' },
    width: { ideal: 1920 },
    height: { ideal: 1080 },
    focusMode: { ideal: 'continuous' }
  };
  const attempts = [
    { video: base, audio: false },
    { video: { facingMode: { ideal: 'environment' }, width: { ideal: 1280 }, height: { ideal: 720 } }, audio: false },
    { video: { facingMode: 'environment' }, audio: false }
  ];
  let lastErr = null;
  for (const constraints of attempts) {
    try {
      return await navigator.mediaDevices.getUserMedia(constraints);
    } catch (e) {
      lastErr = e;
    }
  }
  throw lastErr || new Error('Camera unavailable');
}

function autoScanStartTorchLoop(track) {
  if (!track || autoScanState.torchRetryTimer) return;
  let attempts = 0;
  autoScanState.torchRetryTimer = setInterval(async () => {
    if (!autoScanState.torchOn || autoScanState.mode !== 'scan' || !autoScanState.videoTrack) {
      clearInterval(autoScanState.torchRetryTimer);
      autoScanState.torchRetryTimer = null;
      return;
    }
    if (autoScanState.torchSupported) {
      await autoScanApplyTorch(autoScanState.videoTrack, true);
      clearInterval(autoScanState.torchRetryTimer);
      autoScanState.torchRetryTimer = null;
      return;
    }
    if (++attempts > 20) {
      clearInterval(autoScanState.torchRetryTimer);
      autoScanState.torchRetryTimer = null;
      return;
    }
    await autoScanEnableTorchImmediate(autoScanState.videoTrack);
  }, 250);
}

async function autoScanSetTorch(on) {
  autoScanState.torchOn = !!on;
  const track = autoScanState.videoTrack;
  if (!track) {
    autoScanUpdateTorchButton();
    return false;
  }
  if (on) {
    autoScanTryTorchSync(track);
    const ok = await autoScanEnableTorchImmediate(track);
    autoScanState.torchSupported = ok;
    autoScanUpdateTorchButton();
    return ok;
  }
  await autoScanApplyTorch(track, false);
  autoScanUpdateTorchButton();
  return true;
}

window.toggleAutoScanTorch = function() {
  if (autoScanState.torchOn) {
    autoScanSetTorch(false);
    return;
  }
  autoScanState.torchOn = true;
  autoScanTryTorchSync(autoScanState.videoTrack);
  autoScanEnableTorchImmediate(autoScanState.videoTrack);
};

function autoScanScreenFlash() {
  const flash = document.getElementById('autoScanFlash');
  if (!flash) return;
  flash.classList.add('active');
  setTimeout(() => flash.classList.remove('active'), 220);
}

function autoScanStopScanLoop() {
  if (autoScanState.timer) {
    clearInterval(autoScanState.timer);
    autoScanState.timer = null;
  }
  if (autoScanState.torchRetryTimer) {
    clearInterval(autoScanState.torchRetryTimer);
    autoScanState.torchRetryTimer = null;
  }
}

function autoScanPauseCameraPreview() {
  autoScanStopScanLoop();
  const video = document.getElementById('autoScanVideo');
  if (video) video.pause();
}

async function autoScanCaptureFrame(bounds, corners) {
  const video = document.getElementById('autoScanVideo');
  if (!video || !autoScanState.context || autoScanState.capturing) return;
  autoScanState.capturing = true;
  autoScanStopScanLoop();

  if (autoScanState.torchOn) {
    if (autoScanState.torchSupported) await autoScanSetTorch(true);
    else autoScanScreenFlash();
  }
  await new Promise(r => setTimeout(r, autoScanState.torchSupported ? 140 : 80));

  const vw = video.videoWidth;
  const vh = video.videoHeight;
  const src = document.createElement('canvas');
  src.width = vw;
  src.height = vh;
  src.getContext('2d').drawImage(video, 0, 0);

  const c = autoScanCloneCorners(corners || autoScanState.corners || autoScanBoundsToCorners(bounds || autoScanDefaultGuide()));
  autoScanPauseCameraPreview();

  autoScanState.review = {
    srcCanvas: src,
    corners: c,
    bounds: bounds || autoScanState.bounds || autoScanDefaultGuide(),
    filterId: document.getElementById('autoScanFilterSelect')?.value || 'document',
    cropEditing: false
  };
  autoScanState.capturing = false;
  autoScanShowReviewPanel();
  window.autoScanUpdateReviewPreview();
}

function autoScanDrawCropEditor() {
  const review = autoScanState.review;
  if (!review) return;
  const srcCanvas = document.getElementById('autoScanCropSource');
  const overlay = document.getElementById('autoScanCropOverlay');
  if (!srcCanvas || !overlay) return;

  const maxW = Math.min(window.innerWidth - 32, 640);
  const scale = maxW / review.srcCanvas.width;
  const dw = Math.round(review.srcCanvas.width * scale);
  const dh = Math.round(review.srcCanvas.height * scale);
  srcCanvas.width = dw;
  srcCanvas.height = dh;
  overlay.width = dw;
  overlay.height = dh;
  srcCanvas.getContext('2d').drawImage(review.srcCanvas, 0, 0, dw, dh);

  const ctx = overlay.getContext('2d');
  ctx.clearRect(0, 0, dw, dh);
  ctx.fillStyle = 'rgba(0,0,0,0.45)';
  ctx.fillRect(0, 0, dw, dh);

  const pts = review.corners.map(p => ({ x: p.x * dw, y: p.y * dh }));
  ctx.beginPath();
  ctx.moveTo(pts[0].x, pts[0].y);
  for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y);
  ctx.closePath();
  ctx.save();
  ctx.clip();
  ctx.clearRect(0, 0, dw, dh);
  ctx.restore();

  ctx.strokeStyle = '#facc15';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(pts[0].x, pts[0].y);
  for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y);
  ctx.closePath();
  ctx.stroke();

  pts.forEach((p, idx) => {
    ctx.fillStyle = '#facc15';
    ctx.strokeStyle = '#1f2937';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(p.x, p.y, 16, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(p.x, p.y, 6, 0, Math.PI * 2);
    ctx.fillStyle = '#1f2937';
    ctx.fill();
    review._handlePx = review._handlePx || [];
    review._handlePx[idx] = { x: p.x, y: p.y };
  });
}

const AUTO_SCAN_CROP_HIT_RADIUS = 44;

function autoScanCropPointerCoords(overlay, clientX, clientY) {
  const rect = overlay.getBoundingClientRect();
  const scaleX = overlay.width / rect.width;
  const scaleY = overlay.height / rect.height;
  return {
    x: Math.max(0, Math.min(overlay.width, (clientX - rect.left) * scaleX)),
    y: Math.max(0, Math.min(overlay.height, (clientY - rect.top) * scaleY))
  };
}

window.autoScanUpdateReviewPreview = function() {
  const review = autoScanState.review;
  if (!review) return;
  review.filterId = document.getElementById('autoScanFilterSelect')?.value || 'document';
  const preview = document.getElementById('autoScanReviewPreview');
  if (!preview) return;

  const result = autoScanBuildFilteredWarp(review.srcCanvas, review.corners, review.filterId, review.bounds);
  const maxW = Math.min(window.innerWidth - 32, 720);
  const scale = Math.min(1, maxW / result.width);
  preview.width = Math.round(result.width * scale);
  preview.height = Math.round(result.height * scale);
  preview.getContext('2d').drawImage(result, 0, 0, preview.width, preview.height);

  if (review.cropEditing) autoScanDrawCropEditor();
};

window.autoScanToggleCropEditor = function() {
  const review = autoScanState.review;
  if (!review) return;
  review.cropEditing = !review.cropEditing;
  const editor = document.getElementById('autoScanCropEditor');
  const btn = document.getElementById('autoScanAdjustCropBtn');
  if (review.cropEditing) {
    editor.style.display = 'block';
    btn.textContent = 'Done adjusting';
    autoScanDrawCropEditor();
  } else {
    editor.style.display = 'none';
    btn.textContent = 'Adjust crop';
  }
};

function autoScanCropPointerDown(e) {
  const review = autoScanState.review;
  if (!review?.cropEditing) return;
  const overlay = document.getElementById('autoScanCropOverlay');
  const { x, y } = autoScanCropPointerCoords(overlay, e.clientX, e.clientY);
  let hit = -1;
  (review._handlePx || []).forEach((h, i) => {
    if (Math.hypot(h.x - x, h.y - y) < AUTO_SCAN_CROP_HIT_RADIUS) hit = i;
  });
  if (hit < 0) return;
  autoScanState.cropDrag = { idx: hit, overlay };
  overlay.setPointerCapture(e.pointerId);
  overlay.style.cursor = 'grabbing';
  e.preventDefault();
}

function autoScanCropPointerMove(e) {
  const drag = autoScanState.cropDrag;
  const review = autoScanState.review;
  if (!drag || !review) return;
  const overlay = drag.overlay;
  const { x, y } = autoScanCropPointerCoords(overlay, e.clientX, e.clientY);
  review.corners[drag.idx] = { x: x / overlay.width, y: y / overlay.height };
  autoScanDrawCropEditor();
  window.autoScanUpdateReviewPreview();
  e.preventDefault();
}

function autoScanCropPointerUp(e) {
  if (!autoScanState.cropDrag) return;
  autoScanState.cropDrag.overlay.style.cursor = 'grab';
  autoScanState.cropDrag.overlay?.releasePointerCapture?.(e.pointerId);
  autoScanState.cropDrag = null;
}

window.autoScanRetry = async function() {
  const context = autoScanState.context;
  autoScanState.review = null;
  autoScanState.capturing = false;
  autoScanState.stableTicks = 0;
  autoScanState.prevGray = null;
  autoScanState.prevBounds = null;
  autoScanState.prevCorners = null;
  autoScanState.corners = null;
  autoScanState.bounds = null;
  autoScanShowScanPanel();
  autoScanSetStatus(autoScanState.torchOn ? 'Flash on — center document in frame' : 'Center document in frame', false);
  autoScanDrawOverlay(null, null, false);

  const video = document.getElementById('autoScanVideo');
  if (video && autoScanState.stream) {
    try {
      await video.play();
      if (autoScanState.torchOn) {
        await autoScanEnableTorchImmediate(autoScanState.videoTrack);
        autoScanStartTorchLoop(autoScanState.videoTrack);
      }
      autoScanResizeOverlay();
      autoScanState.timer = setInterval(autoScanTick, 100);
    } catch (_) {
      window.closeAutoScan();
    }
  } else {
    window.closeAutoScan();
    if (context) window.openAutoScan(context);
  }
};

window.autoScanConfirm = function() {
  const review = autoScanState.review;
  const context = autoScanState.context;
  if (!review || !context) return;

  const result = autoScanBuildFilteredWarp(review.srcCanvas, review.corners, review.filterId, review.bounds);
  result.toBlob((blob) => {
    if (blob) {
      window.addPhotoFromBlob(blob, context);
      if (typeof window.showNotification === 'function') window.showNotification('Document scan saved');
    }
    window.closeAutoScan();
  }, 'image/jpeg', 0.92);
};

function autoScanTick() {
  autoScanResizeOverlay();
  const result = autoScanAnalyzeFrame();
  if (!result) return;

  const { bounds, corners, detected, still, boundsStable, cornersStable } = result;
  const ready = detected && still && boundsStable && cornersStable;

  if (ready) {
    autoScanState.stableTicks++;
    autoScanSetStatus('Hold still — locking onto document…', false);
    autoScanDrawOverlay(bounds, corners, autoScanState.stableTicks >= 5);
    if (autoScanState.stableTicks >= 9) {
      autoScanSetStatus('Captured — review your scan', true);
      autoScanCaptureFrame(bounds, corners);
    }
  } else {
    autoScanState.stableTicks = 0;
    if (!detected) autoScanSetStatus('Point camera at white paper on dark surface', false);
    else if (!still) autoScanSetStatus('Hold camera steady', false);
    else autoScanSetStatus('Align all document edges in frame', false);
    autoScanDrawOverlay(detected ? bounds : null, detected ? corners : null, false);
  }
}

window.autoScanManualCapture = function() {
  if (autoScanState.capturing || autoScanState.mode !== 'scan') return;
  const bounds = autoScanState.bounds || autoScanDefaultGuide();
  const corners = autoScanState.corners || autoScanBoundsToCorners(bounds);
  autoScanSetStatus('Capturing…', false);
  autoScanCaptureFrame(bounds, corners);
};

window.openAutoScan = function(context) {
  if (window.PHOTO_NO_SCAN && window.PHOTO_NO_SCAN.has(context)) return;
  const blobs = window.getPhotoBlobArray ? window.getPhotoBlobArray(context) : null;
  if (blobs && blobs.length >= (window.PHOTO_UI?.maxCount || 10)) {
    alert(`Maximum of ${window.PHOTO_UI.maxCount} photos reached.`);
    return;
  }
  if (!navigator.mediaDevices?.getUserMedia) {
    alert('Camera access is not available on this device.');
    return;
  }

  window.ensureAutoScanModal();
  autoScanState.context = context;
  autoScanState.review = null;
  autoScanState.stableTicks = 0;
  autoScanState.prevGray = null;
  autoScanState.prevBounds = null;
  autoScanState.prevCorners = null;
  autoScanState.corners = null;
  autoScanState.bounds = null;
  autoScanState.capturing = false;
  autoScanState.torchOn = true;
  autoScanState.torchSupported = false;
  autoScanState.cameraStarting = false;

  autoScanShowPermissionPanel();
  document.getElementById('autoScanModal').style.display = 'flex';

  const permBtn = document.getElementById('autoScanPermissionBtn');
  const hasUsed = localStorage.getItem('autoscan_camera_ack') === '1';
  if (permBtn) {
    permBtn.textContent = hasUsed ? 'Start Camera & Flash' : 'Allow Camera & Flash';
  }
};

window.autoScanStartCamera = async function() {
  if (autoScanState.cameraStarting || autoScanState.mode === 'scan') return;
  if (!autoScanState.context) return;

  autoScanState.cameraStarting = true;
  const permBtn = document.getElementById('autoScanPermissionBtn');
  if (permBtn) {
    permBtn.disabled = true;
    permBtn.textContent = 'Opening camera…';
  }

  autoScanShowScanPanel();
  autoScanSetStatus('Requesting camera access…', false);
  autoScanDrawOverlay(null, null, false);

  try {
    const stream = await autoScanOpenCameraStream();
    autoScanState.stream = stream;
    autoScanState.videoTrack = stream.getVideoTracks()[0] || null;

    autoScanTryTorchSync(autoScanState.videoTrack);

    const video = document.getElementById('autoScanVideo');
    video.srcObject = stream;
    video.onloadeddata = () => autoScanSetStatus('Camera ready — turning on flash…', false);

    await video.play();

    autoScanTryTorchSync(autoScanState.videoTrack);
    await autoScanEnableTorchImmediate(autoScanState.videoTrack);
    autoScanStartTorchLoop(autoScanState.videoTrack);

    localStorage.setItem('autoscan_camera_ack', '1');
    autoScanSetStatus(
      autoScanState.torchSupported
        ? 'Flash on — align document edges in frame'
        : 'Tap ⚡ Flash to retry, or use screen boost on capture',
      false
    );

    autoScanResizeOverlay();
    autoScanStopScanLoop();
    autoScanState.timer = setInterval(autoScanTick, 100);
    window.addEventListener('resize', autoScanResizeOverlay);
  } catch (e) {
    autoScanShowPermissionPanel();
    if (permBtn) {
      permBtn.disabled = false;
      permBtn.textContent = 'Allow Camera & Flash';
    }
    const denied = e && (e.name === 'NotAllowedError' || e.name === 'PermissionDeniedError');
    alert(denied
      ? 'Camera permission was denied. Please allow camera access in your browser or device settings, then try again.'
      : 'Unable to access camera: ' + (e.message || 'unknown error'));
  } finally {
    autoScanState.cameraStarting = false;
    if (permBtn && autoScanState.mode === 'permission') {
      permBtn.disabled = false;
      permBtn.textContent = localStorage.getItem('autoscan_camera_ack') === '1'
        ? 'Start Camera & Flash'
        : 'Allow Camera & Flash';
    }
  }
};

window.closeAutoScan = async function() {
  autoScanStopScanLoop();
  window.removeEventListener('resize', autoScanResizeOverlay);
  if (autoScanState.videoTrack) {
    try { await autoScanApplyTorch(autoScanState.videoTrack, false); } catch (_) {}
    autoScanState.videoTrack = null;
  }
  if (autoScanState.stream) {
    autoScanState.stream.getTracks().forEach(t => t.stop());
    autoScanState.stream = null;
  }
  const video = document.getElementById('autoScanVideo');
  if (video) video.srcObject = null;
  const modal = document.getElementById('autoScanModal');
  if (modal) modal.style.display = 'none';
  autoScanState.context = null;
  autoScanState.review = null;
  autoScanState.capturing = false;
  autoScanState.stableTicks = 0;
  autoScanState.prevGray = null;
  autoScanState.prevBounds = null;
  autoScanState.prevCorners = null;
  autoScanState.corners = null;
  autoScanState.bounds = null;
  autoScanState.mode = 'scan';
  autoScanState.cameraStarting = false;
  const perm = document.getElementById('autoScanPermissionPanel');
  if (perm) perm.style.display = 'none';
  const permBtn = document.getElementById('autoScanPermissionBtn');
  if (permBtn) {
    permBtn.disabled = false;
    permBtn.textContent = 'Allow Camera & Flash';
  }
};
