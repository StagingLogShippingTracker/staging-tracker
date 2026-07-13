import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

export type Json = Record<string, unknown>;

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function normalizeSo(raw: string) {
  return String(raw || '').trim().replace(/^SO[#:\s-]*/i, '');
}

export function serviceClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
}

/** Basic shape check — accepts proxy / insights payloads. */
export function isValidPublishPayload(payload: unknown): payload is Json {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) return false;
  const p = payload as Json;
  if (typeof p.found !== 'boolean') return false;
  if (p.found) {
    const hasHeader = p.header && typeof p.header === 'object';
    const hasSummary = p.summary && typeof p.summary === 'object';
    if (!hasHeader && !hasSummary) return false;
  }
  return true;
}

export async function writeCacheRow(
  supabase: SupabaseClient,
  soRaw: string,
  payload: Json,
  source = 'client-publish',
) {
  const soKey = normalizeSo(soRaw);
  const expires = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  const { error } = await supabase.from('p21_order_cache').upsert({
    so_key: soKey,
    so_raw: soRaw,
    found: Boolean(payload.found),
    payload,
    matched_by: (payload.matchedBy as string) || null,
    source: (payload.source as string) || source,
    fetched_at: new Date().toISOString(),
    expires_at: expires,
  });
  if (error) throw error;
}
