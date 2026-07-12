import {
  assertSyncKey,
  collectTrackerSos,
  corsHeaders,
  fetchLiveInsights,
  Json,
  loadP21Config,
  normalizeSo,
  serviceClient,
  writeCacheRow,
} from './p21-core.ts';

async function upsertPayload(soRaw: string, payload: Json, source: string) {
  const supabase = serviceClient();
  await writeCacheRow(supabase, soRaw, payload, source);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const supabase = serviceClient();
    await assertSyncKey(req);

    const body = await req.json().catch(() => ({}));
    const mode = String(body.mode || 'single');

    if (mode === 'bulk') {
      const sos: string[] = Array.isArray(body.sos) ? body.sos.map(String) : await collectTrackerSos(supabase);
      const payloads: Json[] = Array.isArray(body.payloads) ? body.payloads : [];
      let synced = 0;

      if (payloads.length) {
        for (const item of payloads) {
          const soRaw = String(item.so || item.soNumber || '').trim();
          const payload = (item.payload || item) as Json;
          if (!soRaw || !payload) continue;
          await upsertPayload(soRaw, payload, String(item.source || 'swift-sync'));
          synced++;
        }
        return new Response(JSON.stringify({ ok: true, mode: 'bulk', synced }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      const cfg = loadP21Config();
      const results: Json[] = [];
      for (const so of sos) {
        try {
          const live = await fetchLiveInsights(so, cfg);
          await upsertPayload(so, live, String(live.source || 'swift-sync'));
          synced++;
          results.push({ so, ok: true, found: live.found });
        } catch (e) {
          results.push({ so, ok: false, error: e instanceof Error ? e.message : String(e) });
        }
      }
      return new Response(JSON.stringify({ ok: true, mode: 'bulk', synced, total: sos.length, results }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const soRaw = String(body.so || body.soNumber || '').trim();
    if (!soRaw) {
      return new Response(JSON.stringify({ ok: false, message: 'SO number is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const payload = body.payload as Json | undefined;
    if (payload && typeof payload === 'object') {
      await upsertPayload(soRaw, payload, String(body.source || 'swift-sync'));
      return new Response(JSON.stringify({ ok: true, so: normalizeSo(soRaw), ingested: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const cfg = loadP21Config();
    const live = await fetchLiveInsights(soRaw, cfg);
    await upsertPayload(soRaw, live, String(live.source || 'swift-sync'));
    return new Response(JSON.stringify({ ok: true, so: normalizeSo(soRaw), found: live.found }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    const status = (e as Error & { status?: number }).status || 502;
    const message = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ ok: false, error: true, message }), {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
