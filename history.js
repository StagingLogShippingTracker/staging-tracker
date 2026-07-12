// --- history.js ---

window.BIN_MOVEMENT_PREFIX = 'Bin Movement:';

window.logAction = async function(table, actionDesc) {
  const userEmail = currentUser ? currentUser.email.split('@')[0] : 'Guest';
  try {
    await supabaseClient.from('changelog').insert([{
      table_name: table, action: actionDesc, user_email: userEmail
    }]);
  } catch(e) { console.error("Changelog log failed:", e); }
};

window.logBinMovement = async function(type, description) {
  const labels = {
    split: 'Split',
    consolidate: 'Consolidated',
    move: 'Relocated',
    'to-shipped': 'To Shipped Log',
    'to-staging': 'To Staging Log'
  };
  const label = labels[type] || 'Moved';
  await window.logAction('staging', `${window.BIN_MOVEMENT_PREFIX} ${label} — ${description}`);
};

window.isBinMovementAction = function(action) {
  if (!action) return false;
  if (action.startsWith(window.BIN_MOVEMENT_PREFIX)) return true;
  const normalized = action.toLowerCase();
  if (/split order so/i.test(action)) return true;
  if (/batch consolidated/i.test(action)) return true;
  if (/report fix: changed location for so/i.test(action)) return true;
  if (/bin move:/i.test(action)) return true;
  if (/^ship confirmed so/i.test(action)) return true;
  if (/^added via quick ship:/i.test(action)) return true;
  if (/^returned to stock so/i.test(action)) return true;
  if (/^restored to staging/i.test(action)) return true;
  if (normalized.includes('to shipped log') || normalized.includes('to staging log')) return true;
  return false;
};

window.matchesSoInBinMovement = function(action, so) {
  if (!action || !so) return false;
  const esc = so.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`\\b${esc}\\b`, 'i').test(action);
};

window.getBinMovementType = function(action) {
  const normalized = (action || '').toLowerCase();
  if (normalized.includes('split')) return 'split';
  if (normalized.includes('consolidat')) return 'consolidate';
  if (normalized.includes('to staging log') || normalized.includes('restored to staging')) return 'to-staging';
  if (normalized.includes('to shipped log') || normalized.includes('ship confirm') || normalized.includes('quick ship') || normalized.includes('returned to stock')) return 'to-shipped';
  return 'move';
};

window.getBinMovementTypeLabel = function(type) {
  if (type === 'split') return 'Split';
  if (type === 'consolidate') return 'Consolidated';
  if (type === 'to-shipped') return 'To Shipped';
  if (type === 'to-staging') return 'To Staging';
  return 'Relocated';
};

window.formatBinMovementSummary = function(action) {
  if (!action) return '';
  if (action.startsWith(window.BIN_MOVEMENT_PREFIX)) {
    return action.replace(new RegExp(`^${window.BIN_MOVEMENT_PREFIX}\\s*`), '').replace(/^(Split|Consolidated|Relocated|To Shipped Log|To Staging Log)\s*—\s*/i, '');
  }
  if (/^Split Order SO/i.test(action)) {
    const countMatch = action.match(/into (\d+) separate/i);
    return countMatch ? `Split into ${countMatch[1]} separate staging entries` : action;
  }
  if (/^Batch Consolidated/i.test(action)) {
    return action.replace(/^Batch Consolidated\s*/i, 'Consolidated ');
  }
  const locMatch = action.match(/Changed Location for SO .+? to (.+)$/i);
  if (locMatch) return `Relocated to ${locMatch[1]}`;
  if (/^Ship Confirmed SO/i.test(action)) return 'Moved from Staging Log to Shipped Log (Ship Confirm)';
  if (/^Added via Quick Ship:/i.test(action)) return 'Moved to Shipped Log (Quick Ship)';
  if (/^Returned to Stock SO/i.test(action)) return 'Moved from Staging Log to Shipped Log (Returned to Stock)';
  if (/^Restored to Staging/i.test(action)) return 'Moved from Shipped Log back to Staging Log';
  return action;
};

window.extractBinMovements = function(logs, so) {
  const matched = (logs || [])
    .filter(log => window.isBinMovementAction(log.action) && window.matchesSoInBinMovement(log.action, so));

  const deduped = matched.filter((log, _i, arr) => {
    if (log.action.startsWith(window.BIN_MOVEMENT_PREFIX)) return true;
    if (/^added via ship confirm|^undo shipment action|^added return to stock log|^batch undo shipment action/i.test(log.action)) return false;
    const hasNearbyCanonical = arr.some(other =>
      other !== log
      && other.action.startsWith(window.BIN_MOVEMENT_PREFIX)
      && Math.abs(new Date(other.created_at) - new Date(log.created_at)) < 3000
    );
    return !hasNearbyCanonical;
  });

  return deduped
    .map(log => ({
      type: window.getBinMovementType(log.action),
      summary: window.formatBinMovementSummary(log.action),
      created_at: log.created_at,
      user: log.user_email,
      raw: log.action
    }))
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
};

window.formatBinMovementsList = function(movements) {
  if (!movements || movements.length === 0) {
    return '<p style="font-size:12px; color:#6b7280; margin:0 0 12px 0;">No bin movements recorded for this order.</p>';
  }
  let html = '<ul class="history-bin-list" style="margin:0 0 12px 0; padding-left:20px; font-size:13px; color:#334155;">';
  movements.forEach(entry => {
    const typeLabel = window.getBinMovementTypeLabel(entry.type);
    html += `<li style="margin-bottom:8px;">
      <span class="bin-movement-type bin-movement-type--${entry.type}">${typeLabel}</span>
      <span>${entry.summary}</span>
      <br><span style="font-size:11px; color:#64748b;">(By ${entry.user || 'Unknown'} on ${new Date(entry.created_at).toLocaleString()})</span>
    </li>`;
  });
  return html + '</ul>';
};

window.openChangelogModal = async function(table) {
  if(!(await window.openModal('changelogModal'))) return;
  if($('#changelogTitle')) $('#changelogTitle').textContent = table === 'staging' ? 'Staging Entries Changelog' : 'Shipped Log Changelog';
  const tbody = $('#tblChangelog tbody');
  
  tbody.innerHTML = '<tr><td colspan="2" style="text-align:center; padding:12px;">Loading changes...</td></tr>';
  
  try {
    const { data, error } = await supabaseClient.from('changelog')
      .select('*').eq('table_name', table).order('created_at', { ascending: false }).limit(75);
      
    if(error) throw error;
    tbody.innerHTML = '';
    
    if(!data || data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="2" style="text-align:center; color:#6b7280; padding:12px;">No changes logged yet.</td></tr>';
      return;
    }
    
    data.forEach(log => {
      tbody.insertAdjacentHTML('beforeend', `
        <tr style="border-bottom: 1px solid #f0f1f3;">
          <td style="color:#6b7280; font-size:12px; white-space:nowrap; padding:8px;">${new Date(log.created_at).toLocaleString()}</td>
          <td style="font-size:13px; padding:8px;"><span style="font-weight:bold; color:#0284c7;">[${log.user_email}]</span> ${log.action}</td>
        </tr>
      `);
    });
  } catch(e) {
    tbody.innerHTML = `<tr><td colspan="2" style="text-align:center; color:red; padding:12px;">Error: ${e.message}</td></tr>`;
  }
};

window.formatActiveStagingList = function(entries) {
  if (!entries || entries.length === 0) return '<p style="font-size:12px; color:#6b7280;">No active staging entries found.</p>';
  let html = '<ul style="margin:0; padding-left:20px; font-size:13px; color:#334155;">';
  entries.forEach(e => {
    html += `<li style="margin-bottom:6px;"><b>${e.type}</b> @ <b>${e.location}</b> <br><span style="font-size:11px; color:#64748b;">(Staged by ${e.staged_by || 'Unknown'} on ${new Date(e.entry_date).toLocaleString()})</span></li>`;
  });
  return html + '</ul>';
};

window.openOrderHistory = async function(so) {
  if(!(await window.openModal('orderHistoryModal'))) return;
  if ($('#history_so_title')) $('#history_so_title').textContent = so;
  if ($('#history_content')) $('#history_content').innerHTML = '<div style="text-align:center; padding:20px; color:#6b7280;">Loading history...</div>';

  const p21Promise = typeof window.fetchP21OrderInsights === 'function'
    ? window.fetchP21OrderInsights(so)
    : Promise.resolve({ ok: false, offline: true, message: 'P21 module not loaded.' });

  try {
    const activeEntries = appData.staging.filter(x => x.so === so);
    const shippedEntries = appData.shipped.filter(x => x.so === so);
    let html = `<div class="history-section">`;

    html += `<h4 class="section-p21">Prophet21 Order Insights</h4>`;
    html += `<div id="history_p21_content"><div style="text-align:center; padding:12px; color:#6b7280;">Loading Prophet21...</div></div>`;

    html += `<h4 class="section-staging">Current Active Staging</h4>`;
    html += window.formatActiveStagingList(activeEntries);

    html += `<h4 class="section-shipped">Past Shipments</h4>`;
    if(shippedEntries.length === 0) html += `<p style="font-size:12px; color:#6b7280;">No past shipments found.</p>`;
    else {
      html += `<ul style="margin:0 0 12px 0; padding-left:20px; font-size:13px; color:#334155;">`;
      shippedEntries.forEach(e => {
        const action = e.carrier === 'RETURNED TO STOCK' ? 'Returned to Stock' : (e.carrier === 'CONSOLIDATED' ? 'Consolidated' : `Shipped via ${e.carrier}`);
        html += `<li style="margin-bottom:6px;"><b>${e.type}</b> - ${action} from <b>${e.location}</b> <br><span style="font-size:11px; color:#64748b;">(By ${e.shipped_by || 'Unknown'} on ${new Date(e.shipped_at).toLocaleString()})</span></li>`;
      });
      html += `</ul>`;
    }

    const { data, error } = await supabaseClient.from('changelog').select('*').ilike('action', `%${so}%`).order('created_at', { ascending: false });
    if(error) throw error;

    const binMovements = window.extractBinMovements(data, so);
    html += `<h4 class="section-bin-movements">Bin Movements</h4>`;
    html += window.formatBinMovementsList(binMovements);

    html += `<h4 class="section-changelog">Changelog History</h4>`;
    const changelogEntries = (data || []).filter(log => !window.isBinMovementAction(log.action) || !window.matchesSoInBinMovement(log.action, so));
    if(changelogEntries.length === 0) {
      html += `<p style="font-size:12px; color:#6b7280;">No log history.</p>`;
    } else {
      html += `<ul style="margin:0; padding-left:20px; font-size:12px; color:#4b5563; max-height:200px; overflow-y:auto;">`;
      changelogEntries.forEach(log => { html += `<li style="margin-bottom:8px;"><b>${new Date(log.created_at).toLocaleString()}</b> <span style="color:#0ea5e9; font-weight:bold;">[${log.user_email}]</span><br/>${log.action}</li>`; });
      html += `</ul>`;
    }

    html += `</div>`;
    $('#history_content').innerHTML = html;

    const p21Result = await p21Promise;
    const p21El = document.getElementById('history_p21_content');
    if (p21El && typeof window.formatP21OrderInsightsSection === 'function') {
      p21El.innerHTML = window.formatP21OrderInsightsSection(p21Result);
    }
  } catch (e) { $('#history_content').innerHTML = `<span style="color:red;">Error: ${e.message}</span>`; }
};
