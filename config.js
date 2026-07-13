const SUPABASE_URL = 'https://gdrpdiwykmnybmkadlrv.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdkcnBkaXd5a21ueWJta2FkbHJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1MjMyMTIsImV4cCI6MjA5NjA5OTIxMn0.Z7ih_vQic1GtzCyZmTEV-RWJnmuaNZQDfOV2_Fvan5g';
const MAKE_EMAIL_WEBHOOK_URL = 'https://hook.us2.make.com/cxvgao3s4lwnrmntk762j25qct6bkkft';
const TRACKER_SITE_URL = 'https://staginglogshippingtracker.github.io/staging-tracker/';
const TRACKER_LOGO_URL = `${TRACKER_SITE_URL}staging-shipping-logo.png?v=4`;
window.REMOVED = window.REMOVED || 'http://127.0.0.1:8787';

window.APP_ASSET_VERSIONS = {
  config: '4.3',
  partials: '1.3',
  style: '10.9',
  ui: '7.4',
  app: '6.0',
  auth: '3.4',
  history: '3.5',
  split: '3.7',
  reports: '3.8',
  operations: '5.2',
  batch: '6.2',
  media: '5.4',
  autoscan: '3.0',
  employees: '3.3',
  contacts: '1.1'
};

window.buildEmailNotificationFooter = function() {
  return `For more details, visit: <a href="${TRACKER_SITE_URL}">Staging Log & Shipping Tracker</a><br><br><a href="${TRACKER_SITE_URL}"><img src="${TRACKER_LOGO_URL}" alt="SLST — Staging Log & Shipping Tracker" style="max-width:360px;width:100%;height:auto;border:0;display:block;" /></a><br><br>Thanks`;
};

const PM_SMS_ROSTER = {
  'Amanda Sievers': '7807204487@msg.telus.com',
  'Amber Shuya': '7809141677@msg.telus.com',
  'Ben Karpiak': '7802320414@txt.bell.ca',
  'Brandon Kaminski': '7809755556@msg.telus.com',
  'Brice Johnson': '7809350628@msg.telus.com',
  'Carmen Martin': '7802385255@pcs.rogers.com',
  'Chris Acorn': '7807253416@msg.telus.com',
  'Dustin Strachan': '7809759387@msg.telus.com',
  'Kim Mulder': '7809530959@msg.telus.com',
  'Meedo Attia': '5875013894@txt.freedommobile.ca',
  'Miranda McBrayne': '7809356267@fido.ca',
  'Renee Jean': '7808196520@msg.telus.com',
  'Sean Fitzpatrick': '7802660362@msg.telus.com',
  'Steele Hult': '3069037728@sms.sasktel.com'
};

window.resolvePmSmsEmail = function(inputVal) {
  if (!inputVal) return null;
  const val = inputVal.trim();
  if (PM_SMS_ROSTER[val]) return PM_SMS_ROSTER[val];
  const lower = val.toLowerCase();
  const match = Object.keys(PM_SMS_ROSTER).find(name => name.toLowerCase() === lower);
  return match ? PM_SMS_ROSTER[match] : null;
};
const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
const $ = sel => document.querySelector(sel);

window.sendPmEmailWebhook = function(payload) {
  return fetch(MAKE_EMAIL_WEBHOOK_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  }).catch(err => console.warn('Make.com webhook error:', err));
};

let appData = { staging: [], shipped: [] };
let activeShipTargetItem = null;
let currentEditId = null;
let editTargetRecord = { table: null, id: null, photo_urls: [] };
let selectedPhotoBlobs = [];
let mainPhotoBlobs = [];
let hiddenMemory = [];
let currentCommentTarget = { table: null, id: null };
let currentUser = null;

let isBatchMode = new URLSearchParams(window.location.search).get('batch') === 'true';
let batchSelectedIds = new Set();
let batchTarget = null;
let isSameSoMode = false;
let sameSoSelectedIds = new Set();
window.discrepancyList = [];

try { hiddenMemory = JSON.parse(localStorage.getItem('swift_hidden_memory')) || []; } catch(e) {}
try { window.discrepancyList = JSON.parse(localStorage.getItem('swift_discrepancies')) || []; } catch(e) {}
