window.bootstrapStandalonePWA = function() {
  const pwaData = {
    "short_name": "StagingTracker", "name": "Swift Staging Tracker Hub",
    "icons": [{"src": "https://cdn-icons-png.flaticon.com/512/3014/3014166.png", "type": "image/png", "sizes": "512x512"}],
    "start_url": ".", "background_color": "#f1f5f9", "theme_color": "#dd4d25", "display": "standalone", "orientation": "portrait"
  };
  if($('#pwa-manifest')) $('#pwa-manifest').setAttribute('href', 'data:application/manifest+json;charset=utf-8,' + encodeURIComponent(JSON.stringify(pwaData)));
};

// NEW FUNCTION: Builds the Employee Email Dropdown
window.initEmployeeEmailDropdown = function() {
  if (typeof rawContactsData === 'undefined') return;
  
  // Filter out contacts that don't have a valid email
  const validContacts = rawContactsData.filter(c => c.email && c.email.toLowerCase() !== 'n/a');
  
  // Create a hidden datalist in the background
  let dl = document.getElementById('dl_employeeEmails');
  if (!dl) {
    dl = document.createElement('datalist');
    dl.id = 'dl_employeeEmails';
    document.body.appendChild(dl);
  }
  
  // Populate it with emails (The user will see the Name & Branch, but it will output the Email)
  dl.innerHTML = validContacts.map(c => `<option value="${c.email}">${c.name} (${c.branch})</option>`).join('');
  
// Find all PM Email input fields across the app and attach this new list to them
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
  window.initOpenStreetMapEngine(); 
  window.initAuth();
  
  if (isBatchMode) document.body.classList.add('batch-mode');
  
  // Trigger the new dropdown setup on boot
  window.initEmployeeEmailDropdown(); 
  // --- GLOBAL DOM ENFORCEMENT (Automated Memory & Autocomplete Fix) ---
  
  // 1. Inject the missing dl_sos datalist into the page so you don't have to edit HTML files
  if (!document.getElementById('dl_sos')) {
    document.body.insertAdjacentHTML('beforeend', '<datalist id="dl_sos"></datalist>');
  }

  // 2. Disable native browser memory (autocomplete) on all inputs/textareas to fix the cutoff bug
  document.querySelectorAll('input:not([type="password"]):not([type="email"]), textarea').forEach(el => {
    el.setAttribute('autocomplete', 'off');
    el.setAttribute('spellcheck', 'false');
  });

  // 3. Auto-attach the SO memory datalist to ALL SO fields across the entire app
  document.querySelectorAll('input[id*="_so"], input[id="so"]').forEach(el => {
    if(!el.id.includes('search')) el.setAttribute('list', 'dl_sos');
  });
  
  window.loadCloudData(); 
  setInterval(window.loadCloudData, 5000);

  // --- V5.1 AUTOMATED DOM FIXES ---
  document.querySelectorAll('option').forEach(opt => {
      if (opt.textContent.trim() === 'Awaiting Instructions') opt.textContent = 'Awaiting Shipping Instructions';
  });

  const mWeight = document.getElementById('m_weight');
  if (mWeight) {
      mWeight.removeAttribute('readonly');
      mWeight.style.background = '';
      mWeight.setAttribute('oninput', 'window.formatWeight(this)');
  }

  const tblStaging = document.getElementById('tblStaging');
  if (tblStaging && !document.getElementById('sortToggle')) {
      // Intelligently target the wrap, or fallback to the table itself if on index.html
      const referenceNode = tblStaging.closest('.table-wrap') || tblStaging;
      referenceNode.insertAdjacentHTML('beforebegin', `
        <div style="display:flex; justify-content:flex-end; margin-top:4px; margin-bottom:12px; padding-right:4px;">
          <select id="sortToggle" class="btn" style="height:36px; background:#fff; border:1px solid #cbd5e1; color:#475569; font-size:13px; padding:0 12px; cursor:pointer;" onchange="window.renderTables()">
            <option value="urgency">Sort: Urgency (Default)</option>
            <option value="date_desc">Sort: Newest First</option>
            <option value="date_asc">Sort: Oldest First</option>
            <option value="customer">Sort: Customer A-Z</option>
          </select>
        </div>
      `);
  }
  }
  
  if($('#add')) $('#add').addEventListener('click', window.submitStagingEntry);
}

if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', initApp); } 
else { initApp(); }
