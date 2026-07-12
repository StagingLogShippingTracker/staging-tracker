window._openModalIds = window._openModalIds || new Set();

window.injectTemplatePartial = function(tplId, hostId, checkId) {
  if (document.getElementById(checkId)) return true;
  const tpl = document.getElementById(tplId);
  const host = document.getElementById(hostId);
  if (!tpl || !host || host.dataset.loaded === '1') {
    return !!document.getElementById(checkId);
  }
  host.innerHTML = tpl.textContent;
  host.dataset.loaded = '1';
  return !!document.getElementById(checkId);
};

window.fetchPartialHtml = async function(path) {
  const v = (window.APP_ASSET_VERSIONS && window.APP_ASSET_VERSIONS.partials) || '1.3';
  const url = `${path}?v=${v}`;
  try {
    const res = await fetch(url);
    if (res.ok) return await res.text();
  } catch (e) { /* fall through */ }
  try {
    const xhr = new XMLHttpRequest();
    xhr.open('GET', url, false);
    xhr.send(null);
    if (xhr.status === 200) return xhr.responseText;
  } catch (e) { /* fall through */ }
  return null;
};

window.injectSharedPartialsFromTemplates = function() {
  window.injectTemplatePartial('tpl-shared-modals', 'shared-modals-host', 'editModal');
  window.injectTemplatePartial('tpl-shared-datalists', 'shared-datalists-host', 'dl_customers');
  window.injectTemplatePartial('tpl-stat-detail-modal', 'stat-detail-modal-host', 'statDetailModal');
  window.injectTemplatePartial('tpl-notification-modals', 'notification-modals-host', 'notifyReturnModal');
};

window.updateModalScrollLock = function() {
  let anyOpen = false;
  document.querySelectorAll('.modal-overlay').forEach(el => {
    const shown = window.getComputedStyle(el).display === 'flex';
    if (shown) {
      anyOpen = true;
      el.classList.add('is-open');
    } else {
      el.classList.remove('is-open');
      el.style.display = 'none';
      if (el.id) window._openModalIds.delete(el.id);
    }
  });
  document.body.classList.toggle('modal-open', anyOpen);
};

window.syncModalScrollLockSoon = function() {
  requestAnimationFrame(() => window.updateModalScrollLock());
};

window.bindModalScrollLockSync = function() {
  if (document.body.dataset.modalScrollSync) return;
  document.body.dataset.modalScrollSync = '1';
  document.addEventListener('click', (e) => {
    if (e.target.closest('.modal-overlay, .modal-close-x')) {
      window.syncModalScrollLockSoon();
    }
  }, true);
};

window.getOpenModals = function() {
  return Array.from(document.querySelectorAll('.modal-overlay[id]'))
    .filter(el => el.classList.contains('is-open') || window.getComputedStyle(el).display === 'flex');
};

window.getModalBaseZ = function() {
  const raw = window.getComputedStyle(document.documentElement).getPropertyValue('--z-modal').trim();
  const n = parseInt(raw, 10);
  return Number.isFinite(n) ? n : 1000;
};

window.getModalZStep = function() {
  const base = window.getModalBaseZ();
  const raw = window.getComputedStyle(document.documentElement).getPropertyValue('--z-modal-nested').trim();
  const nested = parseInt(raw, 10);
  return Number.isFinite(nested) && nested > base ? nested - base : 100;
};

window.getTopOpenModal = function() {
  const open = window.getOpenModals();
  if (!open.length) return null;
  return open.sort((a, b) => {
    const za = parseInt(window.getComputedStyle(a).zIndex, 10) || 0;
    const zb = parseInt(window.getComputedStyle(b).zIndex, 10) || 0;
    return zb - za;
  })[0];
};

window.openModal = async function(id, options) {
  const opts = options || {};
  if (opts.requireShared !== false && !document.getElementById(id)) {
    if (typeof window.ensureSharedModals === 'function') {
      await window.ensureSharedModals();
    }
  }
  const el = document.getElementById(id);
  if (!el) {
    console.warn('Modal not found:', id);
    return false;
  }
  el.classList.add('is-open');
  el.style.display = 'flex';
  if (opts.zIndex != null) {
    el.style.zIndex = String(opts.zIndex);
  } else {
    let maxZ = window.getModalBaseZ() - window.getModalZStep();
    window.getOpenModals().forEach(m => {
      if (m.id === id) return;
      const z = parseInt(window.getComputedStyle(m).zIndex, 10);
      if (Number.isFinite(z) && z > maxZ) maxZ = z;
    });
    el.style.zIndex = String(maxZ + window.getModalZStep());
  }
  el.setAttribute('role', 'dialog');
  el.setAttribute('aria-modal', 'true');
  const heading = el.querySelector('h3, h2');
  if (heading && !heading.id) {
    heading.id = id + '__title';
  }
  if (heading) el.setAttribute('aria-labelledby', heading.id);
  window._openModalIds.add(id);
  window.updateModalScrollLock();
  return true;
};

window.closeModal = function(id) {
  const el = document.getElementById(id);
  if (el) {
    el.classList.remove('is-open');
    el.style.display = 'none';
    el.style.zIndex = '';
  }
  window._openModalIds.delete(id);
  window.updateModalScrollLock();
};

window.getModalCloseHandler = function(modalId) {
  const special = {
    stagingExpandedModal: 'window.closeStagingExpandedModal()',
    shippedExpandedModal: 'window.closeShippedExpandedModal()',
    shipModal: 'window.closeShipModal()',
    reportMainModal: 'window.closeReportMainModal()'
  };
  return special[modalId] || `window.closeModal('${modalId}')`;
};

window.normalizeModalCloseButtons = function() {
  if (typeof window.closeModal !== 'function') return;
  const legacyRe = /#([\w-]+).*display\s*=\s*['"]none['"]/;
  document.querySelectorAll('.modal-overlay[id]').forEach(modal => {
    const id = modal.id;
    const closeExpr = window.getModalCloseHandler(id);
    modal.querySelectorAll('.modal-close-x, button[onclick]').forEach(btn => {
      const onclick = btn.getAttribute('onclick') || '';
      if (!onclick) return;
      if (/closeModal|closeStagingExpandedModal|closeShippedExpandedModal|closeShipModal|closeReportMainModal/.test(onclick)) return;
      const m = onclick.match(legacyRe);
      if (m && m[1] === id) btn.setAttribute('onclick', closeExpr);
    });
  });
};

window.initModalDomSetup = function() {
  const mWeight = document.getElementById('m_weight');
  if (mWeight) {
    mWeight.removeAttribute('readonly');
    mWeight.style.background = '';
    mWeight.setAttribute('oninput', 'window.formatWeight(this)');
  }

  document.querySelectorAll('input:not([type="password"]):not([type="email"]), textarea').forEach(el => {
    el.setAttribute('autocomplete', 'off');
    el.setAttribute('spellcheck', 'false');
  });

  document.querySelectorAll('input[id*="_so"], input[id="so"]').forEach(el => {
    if (!el.id.includes('search')) el.setAttribute('list', 'dl_sos');
  });

  document.querySelectorAll('option').forEach(opt => {
    if (opt.textContent.trim() === 'Awaiting Instructions') {
      opt.textContent = 'Awaiting Shipping Instructions';
    }
  });

  document.querySelectorAll('.modal-close-x').forEach(btn => {
    if (!btn.getAttribute('aria-label')) btn.setAttribute('aria-label', 'Close');
  });

  if (typeof window.initEmployeeEmailDropdown === 'function') window.initEmployeeEmailDropdown();
  if (typeof window.initPmSmsDropdown === 'function') window.initPmSmsDropdown();
  if (typeof window.initPhotoFields === 'function') window.initPhotoFields();
  if (typeof window.initUniversalDropdowns === 'function') window.initUniversalDropdowns();
  if (typeof window.initSoCustomerAutofill === 'function') window.initSoCustomerAutofill();
  if (typeof window.initSearchClearButtons === 'function') window.initSearchClearButtons();
  if (typeof window.initStagingSortSelects === 'function') window.initStagingSortSelects();
  if (typeof window.hydrateFreightBlocks === 'function') window.hydrateFreightBlocks();
  window.bindModalScrollLockSync();
  window.normalizeModalCloseButtons();
};

window.loadSharedPartials = async function() {
  window.injectSharedPartialsFromTemplates();

  if (!document.getElementById('editModal')) {
    const modalsHost = document.getElementById('shared-modals-host');
    const html = await window.fetchPartialHtml('partials/shared-modals.html');
    if (html && modalsHost && !modalsHost.dataset.loaded) {
      modalsHost.innerHTML = html;
      modalsHost.dataset.loaded = '1';
    }
  }

  if (!document.getElementById('dl_customers')) {
    const datalistsHost = document.getElementById('shared-datalists-host');
    const html = await window.fetchPartialHtml('partials/datalists.html');
    if (html && datalistsHost && !datalistsHost.dataset.loaded) {
      datalistsHost.innerHTML = html;
      datalistsHost.dataset.loaded = '1';
    }
  }

  if (!document.getElementById('statDetailModal')) {
    const statHost = document.getElementById('stat-detail-modal-host');
    const html = await window.fetchPartialHtml('partials/stat-detail-modal.html');
    if (html && statHost && !statHost.dataset.loaded) {
      statHost.innerHTML = html;
      statHost.dataset.loaded = '1';
    }
  }

  if (!document.getElementById('notifyReturnModal')) {
    const notifyHost = document.getElementById('notification-modals-host');
    const html = await window.fetchPartialHtml('partials/notification-modals.html');
    if (html && notifyHost && !notifyHost.dataset.loaded) {
      notifyHost.innerHTML = html;
      notifyHost.dataset.loaded = '1';
    }
  }

  window.initModalDomSetup();
};

window.ensureSharedModals = async function() {
  const sentinels = ['editModal', 'shipModal', 'loginModal'];
  if (sentinels.some(id => document.getElementById(id))) return true;
  if (typeof window.loadSharedPartials === 'function') {
    await window.loadSharedPartials();
  }
  return sentinels.some(id => document.getElementById(id));
};

document.addEventListener('keydown', function(e) {
  if (e.key !== 'Escape') return;
  const top = typeof window.getTopOpenModal === 'function' ? window.getTopOpenModal() : null;
  if (!top) return;
  if (top.id === 'stagingExpandedModal' && typeof window.closeStagingExpandedModal === 'function') {
    window.closeStagingExpandedModal();
  } else if (top.id === 'shippedExpandedModal' && typeof window.closeShippedExpandedModal === 'function') {
    window.closeShippedExpandedModal();
  } else if (top.id && typeof window.closeModal === 'function') {
    window.closeModal(top.id);
  } else {
    top.style.display = 'none';
    top.classList.remove('is-open');
  }
  window.updateModalScrollLock();
});

window.injectSharedPartialsFromTemplates();
window.bindModalScrollLockSync();
