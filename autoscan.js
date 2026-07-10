// --- autoscan.js — document scanner with torch + perspective crop ---

const autoScanState = {
  context: null,
  stream: null,
  videoTrack: null,
  timer: null,
  stableTicks: 0,
  prevGray: null,
  prevBounds: null,
  prevCorners: null,
  corners: null,
  capturing: false,
  torchOn: true,
  torchSupported: false,
  analysisCanvas: null,
  analysisCtx: null
};

window.ensureAutoScanModal = function() {
  if (document.getElementById('autoScanModal')) return;
  document.body.insertAdjacentHTML('beforeend', `
<div id="autoScanModal" class="modal-overlay" style="display:none;">
  <div class="auto-scan-shell">
    <button type="button" class="modal-close-x" id="autoScanClose" aria-label="Close">&times;</button>
    <div class="auto-scan-hint">Align paperwork inside the frame — flash is on for best scan</div>
    <button type="button" id="autoScanTorchBtn" class="auto-scan-torch-btn" title="Toggle flash">⚡ Flash On</button>
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
  document.getElementById('autoScanTorchBtn').addEventListener('click', () => window.toggleAutoScanTorch());
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
  if (w && h) { overlay.width = w; overlay.height = h; }
}

function autoScanDefaultGuide() {
  return { left: 0.1, top: 0.16, right: 0.9, bottom: 0.84 };
}

function autoScanBoundsValid(bounds) {
  if (!bounds) return false;
  const bw = bounds.right - bounds.left;
  const bh = bounds.bottom - bounds.top;
  if (bw < 0.18 || bh < 0.18 || bw > 0.97 || bh > 0.97) return false;
  const ratio = bw / bh;
  return ratio >= 0.22 && ratio <= 4.2;
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
  const blurred = autoScanBlurGray(gray, w, h);
  const thresh = autoScanOtsu(blurred);
  const marginX = Math.floor(w * 0.04);
  const marginY = Math.floor(h * 0.04);
  let minX = w, minY = h, maxX = 0, maxY = 0, count = 0;
  for (let y = marginY; y < h - marginY; y++) {
    for (let x = marginX; x < w - marginX; x++) {
      if (blurred[y * w + x] >= thresh) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        count++;
      }
    }
  }
  if (count < w * h * 0.06) return null;
  return {
    left: minX / w, top: minY / h, right: (maxX + 1) / w, bottom: (maxY + 1) / h
  };
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
  const hi = maxM * 0.22;
  const lo = maxM * 0.08;
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

function autoScanMergeBounds(a, b) {
  if (!a) return b;
  if (!b) return a;
  return {
    left: Math.max(a.left, b.left),
    top: Math.max(a.top, b.top),
    right: Math.min(a.right, b.right),
    bottom: Math.min(a.bottom, b.bottom)
  };
}

function autoScanBoundsToCorners(bounds) {
  return [
    { x: bounds.left, y: bounds.top },
    { x: bounds.right, y: bounds.top },
    { x: bounds.right, y: bounds.bottom },
    { x: bounds.left, y: bounds.bottom }
  ];
}

function autoScanRefineCornersFromEdges(edges, w, h, bounds) {
  const pts = [];
  const bx0 = Math.floor(bounds.left * w);
  const bx1 = Math.floor(bounds.right * w);
  const by0 = Math.floor(bounds.top * h);
  const by1 = Math.floor(bounds.bottom * h);
  for (let y = by0; y < by1; y++) {
    for (let x = bx0; x < bx1; x++) {
      if (edges[y * w + x] === 2) pts.push({ x, y });
    }
  }
  if (pts.length < 40) return autoScanBoundsToCorners(bounds);

  const pick = (fn) => {
    let best = pts[0];
    let score = fn(best);
    for (let i = 1; i < pts.length; i++) {
      const s = fn(pts[i]);
      if (s < score) { score = s; best = pts[i]; }
    }
    return { x: best.x / w, y: best.y / h };
  };

  return [
    pick(p => p.x + p.y),
    pick(p => -p.x + p.y),
    pick(p => -p.x - p.y),
    pick(p => p.x - p.y)
  ];
}

function autoScanDetectDocument(gray, w, h) {
  const paper = autoScanDetectPaperBounds(gray, w, h);
  const edges = autoScanCannyEdges(gray, w, h);
  let edgeBounds = null;

  const col = new Float32Array(w);
  const row = new Float32Array(h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (edges[y * w + x] === 2) { col[x]++; row[y]++; }
    }
  }
  const xs = Math.floor(w * 0.06), xe = Math.floor(w * 0.94);
  const ys = Math.floor(h * 0.06), ye = Math.floor(h * 0.94);
  const peak = (arr, start, end, forward) => {
    let best = -1, idx = forward ? start : end;
    for (let i = start; forward ? i <= end : i >= end; i += forward ? 1 : -1) {
      if (arr[i] > best) { best = arr[i]; idx = i; }
    }
    return idx;
  };
  if (col.some(v => v > 0)) {
    edgeBounds = {
      left: peak(col, xs, xe, true) / w,
      right: (peak(col, xs, xe, false) + 1) / w,
      top: peak(row, ys, ye, true) / h,
      bottom: (peak(row, ys, ye, false) + 1) / h
    };
  }

  let bounds = autoScanMergeBounds(paper, edgeBounds);
  if (!bounds || !autoScanBoundsValid(bounds)) {
    if (paper && autoScanBoundsValid(paper)) bounds = paper;
    else if (edgeBounds && autoScanBoundsValid(edgeBounds)) bounds = edgeBounds;
    else return null;
  }

  const corners = autoScanRefineCornersFromEdges(edges, w, h, bounds);
  const edgeScore = autoScanEdgeDensity(gray, w, h, bounds);
  if (edgeScore < 7) return null;
  return { bounds, corners, edgeScore };
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
  if (!overlay) return;
  const ctx = overlay.getContext('2d');
  const w = overlay.width;
  const h = overlay.height;
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = 'rgba(0,0,0,0.5)';
  ctx.fillRect(0, 0, w, h);

  const drawPath = (pts) => {
    ctx.beginPath();
    ctx.moveTo(pts[0].x * w, pts[0].y * h);
    for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x * w, pts[i].y * h);
    ctx.closePath();
  };

  const pts = corners || autoScanBoundsToCorners(bounds || autoScanDefaultGuide());
  drawPath(pts);
  ctx.save();
  ctx.clip();
  ctx.clearRect(0, 0, w, h);
  ctx.restore();

  const color = ready ? '#22c55e' : (corners ? '#facc15' : '#ffffff');
  ctx.strokeStyle = color;
  ctx.lineWidth = 3;
  drawPath(pts);
  ctx.stroke();

  const len = 22;
  pts.forEach((p) => {
    const px = p.x * w, py = p.y * h;
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
  const srcCtx = srcCanvas.getContext('2d');
  const src = srcCtx.getImageData(0, 0, sw, sh);
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

function autoScanEnhance(canvas) {
  const ctx = canvas.getContext('2d');
  const w = canvas.width;
  const h = canvas.height;
  const img = ctx.getImageData(0, 0, w, h);
  const gray = autoScanToGray(img);
  const blurred = autoScanBlurGray(gray, w, h);
  const threshold = autoScanOtsu(blurred);
  const d = img.data;
  for (let i = 0, p = 0; i < d.length; i += 4, p++) {
    const v = blurred[p] >= threshold ? 255 : 0;
    d[i] = d[i + 1] = d[i + 2] = v;
  }
  ctx.putImageData(img, 0, 0);
  return canvas;
}

function autoScanAnalyzeFrame() {
  const video = document.getElementById('autoScanVideo');
  if (!video || video.readyState < 2 || autoScanState.capturing) return null;

  if (!autoScanState.analysisCanvas) {
    autoScanState.analysisCanvas = document.createElement('canvas');
    autoScanState.analysisCtx = autoScanState.analysisCanvas.getContext('2d', { willReadFrequently: true });
  }
  const aw = 480;
  const ah = 360;
  autoScanState.analysisCanvas.width = aw;
  autoScanState.analysisCanvas.height = ah;
  autoScanState.analysisCtx.drawImage(video, 0, 0, aw, ah);
  const imageData = autoScanState.analysisCtx.getImageData(0, 0, aw, ah);
  const gray = autoScanToGray(imageData);
  const motion = autoScanMotionScore(gray, autoScanState.prevGray);
  autoScanState.prevGray = gray;

  const doc = autoScanDetectDocument(gray, aw, ah);
  const bounds = doc ? doc.bounds : autoScanDefaultGuide();
  const corners = doc ? doc.corners : null;
  const detected = !!doc;
  const still = motion < 6.5;
  const boundsStable = autoScanBoundsDelta(bounds, autoScanState.prevBounds) < 0.022;
  const cornersStable = !corners || autoScanCornersDelta(corners, autoScanState.prevCorners) < 0.06;
  autoScanState.prevBounds = bounds;
  autoScanState.prevCorners = corners;
  autoScanState.corners = corners;

  return { bounds, corners, detected, still, boundsStable, cornersStable, motion };
}

async function autoScanApplyTorch(track, on) {
  if (!track || track.readyState === 'ended') return false;
  const want = !!on;
  const attempts = [
    () => track.applyConstraints({ advanced: [{ torch: want }] }),
    () => track.applyConstraints({ torch: want }),
    () => track.applyConstraints({ advanced: [{ fillLightMode: want ? 'flash' : 'off' }] }),
    () => track.applyConstraints({ fillLightMode: want ? 'flash' : 'off' })
  ];
  for (const attempt of attempts) {
    try {
      await attempt();
      const settings = track.getSettings ? track.getSettings() : {};
      if (settings.torch === want) return true;
      if (want && settings.fillLightMode === 'flash') return true;
      if (!want && (settings.torch === false || settings.fillLightMode === 'off')) return true;
      return true;
    } catch (_) { /* try next format */ }
  }
  return false;
}

async function autoScanEnableTorchImmediate(track) {
  if (!track) return false;
  let ok = await autoScanApplyTorch(track, true);
  if (!ok) {
    for (const delay of [80, 200, 450]) {
      await new Promise(r => setTimeout(r, delay));
      ok = await autoScanApplyTorch(track, true);
      if (ok) break;
    }
  }
  autoScanState.torchSupported = ok;
  const btn = document.getElementById('autoScanTorchBtn');
  if (btn) {
    btn.style.display = ok ? '' : 'none';
    btn.textContent = '⚡ Flash On';
    btn.classList.remove('is-off');
  }
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
    { video: { ...base, advanced: [{ torch: true }] }, audio: false },
    { video: { ...base, torch: true }, audio: false },
    { video: { ...base, advanced: [{ fillLightMode: 'flash' }] }, audio: false },
    { video: { ...base, fillLightMode: { ideal: 'flash' } }, audio: false },
    { video: base, audio: false }
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

async function autoScanSetTorch(on) {
  autoScanState.torchOn = !!on;
  const btn = document.getElementById('autoScanTorchBtn');
  if (btn) {
    btn.textContent = on ? '⚡ Flash On' : '⚡ Flash Off';
    btn.classList.toggle('is-off', !on);
  }
  const track = autoScanState.videoTrack;
  if (!track) return false;
  if (on) return autoScanEnableTorchImmediate(track);
  return autoScanApplyTorch(track, false);
}

window.toggleAutoScanTorch = function() {
  autoScanSetTorch(!autoScanState.torchOn);
};

function autoScanScreenFlash() {
  const flash = document.getElementById('autoScanFlash');
  if (!flash) return;
  flash.classList.add('active');
  setTimeout(() => flash.classList.remove('active'), 200);
}

async function autoScanCapture(bounds, corners) {
  const video = document.getElementById('autoScanVideo');
  if (!video || !autoScanState.context || autoScanState.capturing) return;
  autoScanState.capturing = true;

  if (autoScanState.torchSupported) await autoScanSetTorch(true);
  autoScanScreenFlash();
  await new Promise(r => setTimeout(r, 120));

  const vw = video.videoWidth;
  const vh = video.videoHeight;
  const src = document.createElement('canvas');
  src.width = vw;
  src.height = vh;
  src.getContext('2d').drawImage(video, 0, 0);

  const c = corners || autoScanState.corners || autoScanBoundsToCorners(bounds || autoScanDefaultGuide());
  const outW = Math.max(400, Math.round(Math.hypot(c[1].x - c[0].x, c[1].y - c[0].y) * vw));
  const outH = Math.max(400, Math.round(Math.hypot(c[3].x - c[0].x, c[3].y - c[0].y) * vh));
  let result = autoScanWarpPerspective(src, c, outW, outH);
  result = autoScanEnhance(result);

  result.toBlob((blob) => {
    if (blob) {
      window.addPhotoFromBlob(blob, autoScanState.context);
      if (typeof window.showNotification === 'function') window.showNotification('Document scanned');
    }
    window.closeAutoScan();
  }, 'image/jpeg', 0.94);
}

function autoScanTick() {
  autoScanResizeOverlay();
  const result = autoScanAnalyzeFrame();
  if (!result) return;

  const { bounds, corners, detected, still, boundsStable, cornersStable } = result;
  const ready = detected && still && boundsStable && cornersStable;

  if (ready) {
    autoScanState.stableTicks++;
    autoScanSetStatus('Hold still — auto-scanning…', false);
    autoScanDrawOverlay(bounds, corners, autoScanState.stableTicks >= 5);
    if (autoScanState.stableTicks >= 8) {
      autoScanSetStatus('Captured!', true);
      autoScanCapture(bounds, corners);
    }
  } else {
    autoScanState.stableTicks = 0;
    if (!detected) autoScanSetStatus('Center document in frame', false);
    else if (!still) autoScanSetStatus('Hold camera steady', false);
    else autoScanSetStatus('Align all edges in frame', false);
    autoScanDrawOverlay(bounds, corners, false);
  }
}

window.openAutoScan = async function(context) {
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
  autoScanState.stableTicks = 0;
  autoScanState.prevGray = null;
  autoScanState.prevBounds = null;
  autoScanState.prevCorners = null;
  autoScanState.corners = null;
  autoScanState.capturing = false;
  autoScanState.torchOn = true;
  autoScanSetStatus('Turning on camera flash…', false);
  autoScanDrawOverlay(null, null, false);

  document.getElementById('autoScanModal').style.display = 'flex';

  try {
    const stream = await autoScanOpenCameraStream();
    autoScanState.stream = stream;
    autoScanState.videoTrack = stream.getVideoTracks()[0] || null;
    const video = document.getElementById('autoScanVideo');
    video.srcObject = stream;
    await video.play();
    const torchOk = await autoScanEnableTorchImmediate(autoScanState.videoTrack);
    autoScanSetStatus(
      torchOk ? 'Flash on — center document in frame' : 'Center document in frame (flash unavailable)',
      false
    );
    autoScanResizeOverlay();
    if (autoScanState.timer) clearInterval(autoScanState.timer);
    autoScanState.timer = setInterval(autoScanTick, 100);
    window.addEventListener('resize', autoScanResizeOverlay);
  } catch (e) {
    alert('Unable to access camera: ' + (e.message || 'permission denied'));
    window.closeAutoScan();
  }
};

window.closeAutoScan = async function() {
  if (autoScanState.timer) {
    clearInterval(autoScanState.timer);
    autoScanState.timer = null;
  }
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
  autoScanState.capturing = false;
  autoScanState.stableTicks = 0;
  autoScanState.prevGray = null;
  autoScanState.prevBounds = null;
  autoScanState.prevCorners = null;
  autoScanState.corners = null;
};
