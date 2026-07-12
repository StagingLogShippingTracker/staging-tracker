window.contactBatchSelected = new Set();
window.contactBatchMode = false;

window.filterContactsBySearch = function(entries, term) {
  const q = (term || '').toLowerCase();
  return entries.map((c, idx) => ({ c, idx })).filter(({ c }) =>
    (c.name || '').toLowerCase().includes(q)
    || (c.branch || '').toLowerCase().includes(q)
    || (c.designation || '').toLowerCase().includes(q)
  );
};

window.contactLabeledCell = function(label, content, className = '', style = '') {
  const cls = className ? ` class="${className}"` : '';
  const sty = style ? ` style="${style}"` : '';
  return `<td data-label="${label}"${cls}${sty}>${content}</td>`;
};

window.renderContactsTable = function() {
  const tbody = document.querySelector('#tblContacts tbody');
  if (!tbody || typeof rawContactsData === 'undefined') return;

  const term = document.getElementById('contactSearch') ? document.getElementById('contactSearch').value : '';
  let html = '';

  rawContactsData.forEach((c, idx) => {
    const match = (c.name || '').toLowerCase().includes(term.toLowerCase())
      || (c.branch || '').toLowerCase().includes(term.toLowerCase())
      || (c.designation || '').toLowerCase().includes(term.toLowerCase());
    if (!match) return;

    const checked = window.contactBatchSelected.has(idx) ? 'checked' : '';
    html += `
      <tr>
        ${window.contactLabeledCell('Select', `<input type="checkbox" class="batch-checkbox" ${checked} onchange="window.toggleContactCheck(${idx}, this.checked)" />`, 'show-in-batch', 'text-align:center;')}
        ${window.contactLabeledCell('Name', `<span class="contact-name-cell">${c.name}</span>`)}
        ${window.contactLabeledCell('Designation', c.designation, '', 'color:var(--text-muted);')}
        ${window.contactLabeledCell('Branch', `<span class="branch-badge">${c.branch}</span>`)}
        ${window.contactLabeledCell('Email', c.email ? `<a href="mailto:${c.email}" class="contact-email-link">${c.email}</a>` : '—')}
        ${window.contactLabeledCell('Ext.', c.ext)}
        ${window.contactLabeledCell('Direct', c.direct)}
        ${window.contactLabeledCell('Mobile', c.mobile)}
      </tr>
    `;
  });

  if (html === '') {
    html = '<tr><td colspan="8" style="text-align:center; padding:20px; color:var(--text-muted);">No contacts found matching your search.</td></tr>';
  }
  tbody.innerHTML = html;
};

window.contactBatchCancel = function() {
  window.contactBatchMode = false;
  window.contactBatchSelected.clear();
  document.body.classList.remove('batch-mode');
  if (location.search.includes('batch=true')) {
    history.replaceState({}, '', 'contacts.html');
  }
  window.renderContactsTable();
};

window.initContactBatchFromUrl = function() {
  if (new URLSearchParams(location.search).get('batch') === 'true') {
    window.contactBatchMode = true;
    document.body.classList.add('batch-mode');
  }
};

window.toggleContactCheck = function(idx, isChecked) {
  if (isChecked) window.contactBatchSelected.add(idx);
  else window.contactBatchSelected.delete(idx);
};

window.contactBatchSelectAll = function() {
  const term = document.getElementById('contactSearch') ? document.getElementById('contactSearch').value : '';
  window.filterContactsBySearch(rawContactsData, term).forEach(({ idx }) => {
    window.contactBatchSelected.add(idx);
  });
  window.renderContactsTable();
};

window.contactBatchUnselectAll = function() {
  window.contactBatchSelected.clear();
  window.renderContactsTable();
};

window.contactBatchDelete = function() {
  if (window.contactBatchSelected.size === 0) return alert('Select at least one contact to delete.');
  if (!confirm(`Are you sure you want to remove ${window.contactBatchSelected.size} selected contacts?`)) return;

  Array.from(window.contactBatchSelected).sort((a, b) => b - a).forEach(idx => {
    rawContactsData.splice(idx, 1);
  });

  window.contactBatchSelected.clear();
  window.renderContactsTable();
  if (typeof window.showNotification === 'function') window.showNotification('Contacts Deleted');
};

window.contactBatchExport = function() {
  if (window.contactBatchSelected.size === 0) return alert('Select at least one contact to export.');

  const indices = Array.from(window.contactBatchSelected).sort((a, b) => a - b);
  let csvContent = 'Name,Designation,Branch,Email,Ext,Direct,Mobile\n';

  indices.forEach(idx => {
    const c = rawContactsData[idx];
    csvContent += `"${c.name}","${c.designation}","${c.branch}","${c.email}","${c.ext}","${c.direct}","${c.mobile}"\n`;
  });

  const blob = new Blob([csvContent], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'Swift_Contacts_Export.csv';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);

  if (typeof window.showNotification === 'function') window.showNotification('Contacts Exported');
  window.contactBatchCancel();
};

window.initContactsPage = function() {
  window.initContactBatchFromUrl();
  window.renderContactsTable();
};
