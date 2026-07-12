window.SWIFT_THEME_KEY = 'swift_theme';

window.applySavedTheme = function() {
  try {
    const saved = localStorage.getItem(window.SWIFT_THEME_KEY);
    if (saved === 'dark') document.documentElement.setAttribute('data-theme', 'dark');
    else document.documentElement.removeAttribute('data-theme');
  } catch (e) { /* private browsing */ }
};
window.applySavedTheme();

window.toggleDarkMode = function() {
  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  if (isDark) {
    document.documentElement.removeAttribute('data-theme');
    localStorage.setItem(window.SWIFT_THEME_KEY, 'light');
  } else {
    document.documentElement.setAttribute('data-theme', 'dark');
    localStorage.setItem(window.SWIFT_THEME_KEY, 'dark');
  }
  window.syncThemeToggleLabels();
  if (typeof window.renderStagingStatusLegend === 'function') window.renderStagingStatusLegend();
  if (typeof window.renderTables === 'function') window.renderTables();
  if (typeof window.renderContactsTable === 'function') window.renderContactsTable();
};

window.syncThemeToggleLabels = function() {
  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  document.querySelectorAll('.dropdown-theme-toggle').forEach(btn => {
    btn.textContent = isDark ? 'Light' : 'Dark';
    btn.setAttribute('aria-pressed', isDark ? 'true' : 'false');
    btn.setAttribute('aria-label', isDark ? 'Switch to light mode' : 'Switch to dark mode');
  });
};

window.initThemeMenu = function() {
  document.querySelectorAll('.dropdown-content').forEach(menu => {
    if (menu.dataset.themeReady) return;
    menu.dataset.themeReady = '1';

    const links = document.createElement('div');
    links.className = 'dropdown-content__links';
    while (menu.firstChild) links.appendChild(menu.firstChild);
    menu.appendChild(links);

    const themeCol = document.createElement('div');
    themeCol.className = 'dropdown-theme-col';
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'dropdown-theme-toggle';
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      window.toggleDarkMode();
    });
    themeCol.appendChild(btn);
    menu.appendChild(themeCol);
  });
  window.syncThemeToggleLabels();
};

window.isMobilePortraitCardView = function() {
  return window.matchMedia('(max-width: 767px) and (orientation: portrait)').matches;
};

window.isMobileCardView = function() {
  return window.matchMedia('(max-width: 767px)').matches;
};

window.MOBILE_CARD_INITIAL = 5;
window.MOBILE_CARD_STEP = 5;
window.mobileCardVisible = { tblStaging: 5, tblShipped: 5 };

window.resetMobileCardVisible = function() {
  window.mobileCardVisible = {
    tblStaging: window.MOBILE_CARD_INITIAL,
    tblShipped: window.MOBILE_CARD_INITIAL
  };
};

window.showMoreMobileCards = function(tableId) {
  if (!window.mobileCardVisible) window.resetMobileCardVisible();
  window.mobileCardVisible[tableId] = (window.mobileCardVisible[tableId] || window.MOBILE_CARD_INITIAL) + window.MOBILE_CARD_STEP;
  if (typeof window.renderTables === 'function') window.renderTables();
};

window.getTableRenderLimit = function(tableId, isDashboardPreview) {
  if (window.isMobileCardView()) {
    if (!window.mobileCardVisible) window.resetMobileCardVisible();
    return window.mobileCardVisible[tableId] || window.MOBILE_CARD_INITIAL;
  }
  if (isDashboardPreview) return 20;
  return 999999;
};

window.updateMobileCardMoreButtons = function(tableId, shownCount, totalCount, isDashboardPreview) {
  const isStaging = tableId === 'tblStaging';
  const btn = document.getElementById(isStaging ? 'stagingShowMore' : 'shippedShowMore');
  const notice = document.getElementById(isStaging ? 'stageLimitNotice' : 'shippedLimitNotice');

  if (window.isMobileCardView()) {
    if (notice) notice.style.display = 'none';
    if (btn) btn.style.display = shownCount < totalCount ? 'block' : 'none';
    return;
  }

  if (btn) btn.style.display = 'none';
  if (notice && isDashboardPreview) {
    notice.style.display = totalCount > 20 ? 'block' : 'none';
  } else if (notice) {
    notice.style.display = 'none';
  }
};

window.syncMobileCardBatchMode = function() {
  const hide = window.isMobilePortraitCardView();
  document.body.classList.toggle('batch-unavailable', hide);
  if (!hide) return;
  if (typeof isBatchMode !== 'undefined' && isBatchMode && typeof window.batchCancel === 'function') {
    window.batchCancel();
  }
  if (window.location.search.includes('batch=true')) {
    const url = new URL(window.location.href);
    url.searchParams.delete('batch');
    window.history.replaceState({}, '', url.pathname + (url.search || ''));
  }
};

window.bootstrapStandalonePWA = function() {
  const themeColor = '#D93223';
  let themeMeta = document.querySelector('meta[name="theme-color"]');
  if (!themeMeta) {
    themeMeta = document.createElement('meta');
    themeMeta.setAttribute('name', 'theme-color');
    document.head.appendChild(themeMeta);
  }
  themeMeta.setAttribute('content', themeColor);
};

window.initSiteFooter = function() {
  if (document.querySelector('.site-footer')) return;
  const footer = document.createElement('footer');
  footer.className = 'site-footer';
  footer.setAttribute('aria-label', 'Site credit and legal notice');
  footer.innerHTML = `
    <p class="site-footer__credit">Designed, developed, and maintained by Brice Johnson.</p>
    <p class="site-footer__legal">Open-source components are used under their respective licenses. All other software, design, and content are the property of Brice Johnson. All rights reserved. Unauthorized use, reproduction, or distribution is prohibited.</p>
    <div class="site-footer__etched-mark" aria-hidden="true">
      <img src="brand/staging-shipping-tire-logo.png?v=5" alt="" class="site-footer__etched-logo" width="40" height="40" draggable="false" />
    </div>
  `;
  const wrap = document.querySelector('.wrap');
  if (wrap && wrap.parentNode === document.body) wrap.insertAdjacentElement('afterend', footer);
  else document.body.appendChild(footer);
};

window.initPmSmsDropdown = function() {
  const sel = document.getElementById('pn_pm_email');
  if (!sel || sel.tagName !== 'SELECT') return;
  const saved = sel.value;
  sel.innerHTML = '<option value="">— Select PM —</option>' +
    Object.keys(PM_SMS_ROSTER).sort().map(name =>
      `<option value="${name}">${name}</option>`
    ).join('');
  if (saved && PM_SMS_ROSTER[saved]) sel.value = saved;
  const staleList = document.getElementById('dl_pmSmsNames');
  if (staleList) staleList.remove();
};

window.initEmployeeEmailDropdown = function() {
  if (typeof rawContactsData === 'undefined') return;
  const validContacts = rawContactsData.filter(c => c.email && c.email.toLowerCase() !== 'n/a');
  let dl = document.getElementById('dl_employeeEmails');
  if (!dl) {
    dl = document.createElement('datalist');
    dl.id = 'dl_employeeEmails';
    document.body.appendChild(dl);
  }
  dl.innerHTML = validContacts.map(c => `<option value="${c.email}">${c.name} (${c.branch})</option>`).join('');
  const targetIds = ['m_pm_email', 'r_pm_email', 'e_pm', 'nr_pm_email', 'qs_pm_email'];
  targetIds.forEach(id => {
    const input = document.getElementById(id);
    if (input) {
      input.setAttribute('list', 'dl_employeeEmails');
      if (!input.placeholder) input.placeholder = "Type name or email...";
    }
  });
};

function initApp() {
  window.bootstrapStandalonePWA();
  window.initThemeMenu();
  window.syncMobileCardBatchMode();
  window.addEventListener('resize', window.syncMobileCardBatchMode);
  window.addEventListener('orientationchange', () => setTimeout(window.syncMobileCardBatchMode, 100));
  window.addEventListener('resize', () => {
    if (typeof window.renderTables === 'function') window.renderTables();
  });
  window.addEventListener('orientationchange', () => {
    setTimeout(() => {
      if (typeof window.renderTables === 'function') window.renderTables();
    }, 100);
  });
  window.initAuth();

  if (isBatchMode && !window.isMobilePortraitCardView()) document.body.classList.add('batch-mode');
  else if (isBatchMode && typeof window.batchCancel === 'function') window.batchCancel();

  window.initEmployeeEmailDropdown();
  window.initPmSmsDropdown();
  window.renderStagingStatusLegend();
  if (typeof window.initPersonByRoster === 'function') window.initPersonByRoster();
  if (typeof window.initCarrierRoster === 'function') window.initCarrierRoster();
  if (typeof window.initPhotoFields === 'function') window.initPhotoFields();
  if (typeof window.initUniversalDropdowns === 'function') window.initUniversalDropdowns();
  if (typeof window.initSoCustomerAutofill === 'function') window.initSoCustomerAutofill();
  if (typeof window.initSearchClearButtons === 'function') window.initSearchClearButtons();
  window.initSiteFooter();

  if (!document.getElementById('dl_sos')) {
    document.body.insertAdjacentHTML('beforeend', '<datalist id="dl_sos"></datalist>');
  }

  document.querySelectorAll('input:not([type="password"]):not([type="email"]), textarea').forEach(el => {
    el.setAttribute('autocomplete', 'off');
    el.setAttribute('spellcheck', 'false');
  });

  document.querySelectorAll('input[id*="_so"], input[id="so"]').forEach(el => {
    if(!el.id.includes('search')) el.setAttribute('list', 'dl_sos');
  });

  window.loadCloudData();
  setInterval(window.loadCloudData, 5000);

  document.querySelectorAll('option').forEach(opt => {
    if (opt.textContent.trim() === 'Awaiting Instructions') opt.textContent = 'Awaiting Shipping Instructions';
  });

  const mWeight = document.getElementById('m_weight');
  if (mWeight) {
    mWeight.removeAttribute('readonly');
    mWeight.style.background = '';
    mWeight.setAttribute('oninput', 'window.formatWeight(this)');
  }

  if($('#add')) $('#add').addEventListener('click', window.submitStagingEntry);
}

if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', initApp); }
else { initApp(); }
