// --- search-order.js ---
// Standalone Prophet21 lookup page: load Sales Order (SO) or Purchase Order (PO)
// details directly from P21, without pairing them to a staged/shipped order.
// Reuses the same P21 client + renderer as the Order History "Prophet21 Insights".

window.runOrderSearch = async function(kind) {
  const isPo = kind === 'po';
  const input = document.getElementById(isPo ? 'search_po_input' : 'search_so_input');
  const section = document.getElementById(isPo ? 'search_po_result' : 'search_so_result');
  const content = document.getElementById(isPo ? 'search_po_content' : 'search_so_content');
  if (!section || !content) return;

  const val = (input && input.value ? input.value : '').trim();
  section.style.display = 'block';

  if (!val) {
    content.innerHTML = `<p class="p21-status" style="font-size:12px; color:#6b7280; margin:0;">Enter a ${isPo ? 'PO' : 'SO'} number to search.</p>`;
    return;
  }

  content.innerHTML = '<div style="text-align:center; padding:12px; color:#6b7280;">Loading Prophet21…</div>';

  if (typeof window.fetchP21OrderInsights !== 'function' || typeof window.formatP21OrderInsightsSection !== 'function') {
    content.innerHTML = '<p style="color:#dc2626; font-size:12px; margin:0;">Prophet21 module not loaded.</p>';
    return;
  }

  try {
    const result = await window.fetchP21OrderInsights(val, { refresh: true });
    content.innerHTML = window.formatP21OrderInsightsSection(result);
  } catch (e) {
    content.innerHTML = `<p style="color:#dc2626; font-size:12px; margin:0;">Lookup failed: ${(e && e.message) ? e.message : e}</p>`;
  }
};

window.initSearchOrderPage = function() {
  ['search_so_input', 'search_po_input'].forEach(id => {
    const el = document.getElementById(id);
    if (!el || el.dataset.enterBound) return;
    el.dataset.enterBound = '1';
    el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        window.runOrderSearch(id === 'search_po_input' ? 'po' : 'so');
      }
    });
  });
};

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', window.initSearchOrderPage);
else window.initSearchOrderPage();
