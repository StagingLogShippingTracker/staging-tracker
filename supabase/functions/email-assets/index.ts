import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { ICONS } from "./icons-data.ts";
import { LOGO_A } from "./logo-a.ts";
import { LOGO_B } from "./logo-b.ts";

/**
 * Public PNG host for ship-confirmation HTML emails.
 * Outlook blocks SVG / data: image URIs — these HTTPS PNGs are required.
 *
 *   /functions/v1/email-assets?f=slst-logo-email
 *   /functions/v1/email-assets?f=icon-clipboard
 */

const assets: Record<string, string> = {
  ...ICONS,
  "slst-logo-email": LOGO_A + LOGO_B,
};
const ALLOWED = new Set(Object.keys(assets));

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Cache-Control": "public, max-age=86400, immutable",
};

function decodeBase64(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function resolveName(req: Request): string | null {
  const url = new URL(req.url);
  const q = (url.searchParams.get("f") ?? url.searchParams.get("file") ?? "")
    .trim();
  if (q) {
    const key = q.replace(/\.png$/i, "");
    return ALLOWED.has(key) ? key : null;
  }
  const parts = url.pathname.split("/").filter(Boolean);
  const last = parts[parts.length - 1] ?? "";
  if (last && last !== "email-assets") {
    const key = last.replace(/\.png$/i, "");
    return ALLOWED.has(key) ? key : null;
  }
  return null;
}

Deno.serve((req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response("Method not allowed", {
      status: 405,
      headers: corsHeaders,
    });
  }

  const name = resolveName(req);
  if (!name) {
    return new Response(
      JSON.stringify({ error: "Unknown asset", available: [...ALLOWED] }),
      {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const bytes = decodeBase64(assets[name]);
  return new Response(req.method === "HEAD" ? null : bytes, {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "image/png",
      "Content-Length": String(bytes.length),
    },
  });
});
