window.bootstrapStandalonePWA = function() {
  const themeColor = '#e04015';
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
  `;
  document.body.appendChild(footer);
};

window.initPmSmsDropdown = function() {
  let dl = document.getElementById('dl_pmSmsNames');
  if (!dl) {
    dl = document.createElement('datalist');
    dl.id = 'dl_pmSmsNames';
    document.body.appendChild(dl);
  }
  dl.innerHTML = Object.keys(PM_SMS_ROSTER).sort().map(name => `<option value="${name}"></option>`).join('');
  const input = document.getElementById('pn_pm_email');
  if (input) {
    input.setAttribute('list', 'dl_pmSmsNames');
    input.placeholder = 'Select PM name...';
    input.disabled = false;
    input.removeAttribute('style');
  }
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
  window.initAuth();

  if (isBatchMode) document.body.classList.add('batch-mode');

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
