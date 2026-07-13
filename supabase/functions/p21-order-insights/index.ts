import {
  corsHeaders,
  canFetchLiveP21,
  fetchLiveInsights,
  loadP21Config,
  normalizeSo,
  readCacheRow,
  serviceClient,
  writeCacheRow,
} from './p21-core.ts';

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

  const body = await req.json().catch(() => ({}));
  const soRaw = String(body.so || body.soNumber || '').trim();
  const refresh = Boolean(body.refresh);
  const soKey = normalizeSo(soRaw);

  try {
    if (!soKey) {
      return new Response(JSON.stringify({ found: false, message: 'SO number is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = serviceClient();
    const cfg = loadP21Config();
    const liveAllowed = canFetchLiveP21(cfg);

    if (!refresh) {
      const cached = await readCacheRow(supabase, soKey, true);
      if (cached?.payload && !cached.stale) {
        return new Response(JSON.stringify({
          ...(cached.payload as Record<string, unknown>),
          cached: true,
          fetchedAt: cached.fetched_at,
        }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }
    }

    if (liveAllowed) {
      const live = await fetchLiveInsights(soRaw, cfg);
      await writeCacheRow(supabase, soRaw, live);
      return new Response(JSON.stringify({ ...live, cached: false, fetchedAt: new Date().toISOString() }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const cached = await readCacheRow(supabase, soKey, true);
    if (cached?.payload) {
      return new Response(JSON.stringify({
        ...(cached.payload as Record<string, unknown>),
        cached: true,
        stale: cached.stale,
        fetchedAt: cached.fetched_at,
        message: cached.stale
          ? 'Prophet21 cache is stale; Swift network sync will refresh it.'
          : undefined,
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    return new Response(JSON.stringify({
      found: false,
      cached: false,
      message: 'Prophet21 data not synced yet. Run sync-to-supabase.ps1 on the Swift network.',
    }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    if (soKey) {
      try {
        const supabase = serviceClient();
        const cached = await readCacheRow(supabase, soKey, true);
        if (cached?.payload) {
          return new Response(JSON.stringify({
            ...(cached.payload as Record<string, unknown>),
            cached: true,
            stale: true,
            fetchedAt: cached.fetched_at,
            warning: message,
          }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
      } catch (_) { /* ignore */ }
    }
    return new Response(JSON.stringify({ found: false, error: true, message }), {
      status: 502,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
