const SUPABASE_URL = 'https://gdrpdiwykmnybmkadlrv.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdkcnBkaXd5a21ueWJta2FkbHJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1MjMyMTIsImV4cCI6MjA5NjA5OTIxMn0.Z7ih_vQic1GtzCyZmTEV-RWJnmuaNZQDfOV2_Fvan5g';
const MAKE_EMAIL_WEBHOOK_URL = 'https://hook.us2.make.com/cxvgao3s4lwnrmntk762j25qct6bkkft';

const PM_SMS_ROSTER = {
  'Amanda Sievers': '7807204487@msg.telus.com',
  'Amber Shuya': '7809141677@msg.telus.com',
  'Ben Karpiak': '7802320414@txt.bell.ca',
  'Brandon Kaminski': '7809755556@msg.telus.com',
  'Carmen Martin': '7802385255@pcs.rogers.com',
  'Chris Acorn': '7807253416@msg.telus.com',
  'Dustin Strachan': '7809759387@msg.telus.com',
  'Kim Mulder': '7809530959@msg.telus.com',
  'Miranda McBrayne': '7809356267@fido.ca',
  'Renee Jean': '7808196520@msg.telus.com',
  'Sean Fitzpatrick': '7802660362@msg.telus.com'
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
let isSameSoMode = false;
let sameSoSelectedIds = new Set();
window.discrepancyList = [];

try { hiddenMemory = JSON.parse(localStorage.getItem('swift_hidden_memory')) || []; } catch(e) {}
try { window.discrepancyList = JSON.parse(localStorage.getItem('swift_discrepancies')) || []; } catch(e) {}
