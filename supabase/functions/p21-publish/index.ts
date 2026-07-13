import {
  corsHeaders,
  isValidPublishPayload,
  Json,
  normalizeSo,
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

  try {
    const body = await req.json().catch(() => ({}));
    const soRaw = String(body.so || body.soNumber || '').trim();
    const soKey = normalizeSo(soRaw);
    const payload = body.payload as unknown;

    if (!soKey) {
      return new Response(JSON.stringify({ ok: false, message: 'SO number is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    if (!isValidPublishPayload(payload)) {
      return new Response(JSON.stringify({
        ok: false,
        message: 'Invalid payload. Expected { found, header|summary, ... } from the P21 proxy.',
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const toStore: Json = {
      ...payload,
      so: soKey,
      source: 'client-publish',
    };

    const supabase = serviceClient();
    await writeCacheRow(supabase, soRaw, toStore, 'client-publish');

    return new Response(JSON.stringify({
      ok: true,
      so: soKey,
      found: Boolean(payload.found),
      published: true,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ ok: false, error: true, message }), {
      status: 502,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
