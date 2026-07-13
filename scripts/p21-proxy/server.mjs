#!/usr/bin/env node
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { fetchOrderInsights } from './p21-core.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  for (const line of fs.readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) process.env[key] = value;
  }
}

loadEnvFile(path.join(__dirname, '.env'));

const PORT = Number(process.env.P21_PROXY_PORT || 8787);
const config = {
  baseUrl: process.env.P21_BASE_URL || 'https://swiftsupply.epicordistribution.com',
  username: process.env.P21_USERNAME || '',
  password: process.env.P21_PASSWORD || ''
};

if (process.env.P21_TLS_REJECT_UNAUTHORIZED === '0') {
  process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
}

const tokenState = { accessToken: null, expiresAt: 0 };

function json(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type'
  });
  res.end(payload);
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    });
    return res.end();
  }

  const url = new URL(req.url || '/', `http://127.0.0.1:${PORT}`);

  if (req.method === 'GET' && url.pathname === '/health') {
    return json(res, 200, {
      ok: true,
      role: 'connector',
      p21BaseUrl: config.baseUrl,
      credentialsConfigured: Boolean(config.username && config.password)
    });
  }

  const orderMatch = url.pathname.match(/^\/api\/order\/(.+)$/);
  if (req.method === 'GET' && orderMatch) {
    try {
      const insights = await fetchOrderInsights(config, decodeURIComponent(orderMatch[1]), tokenState);
      return json(res, insights.found ? 200 : 404, insights);
    } catch (e) {
      const code = e.code || 'ERROR';
      const status = code === 'BAD_REQUEST' ? 400 : code === 'AUTH' ? 401 : code === 'CONFIG' ? 503 : 502;
      return json(res, status, { found: false, error: code, message: e.message });
    }
  }

  return json(res, 404, { error: 'NOT_FOUND' });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`P21 connector listening on http://0.0.0.0:${PORT}`);
  console.log(`Target: ${config.baseUrl}`);
  console.log('Run on a host with VPN/network access to Prophet21.');
});
