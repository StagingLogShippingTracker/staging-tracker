import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  isShipConfirmationType,
  renderShipConfirmationEmail,
  shipDataFromPayload,
} from "./email-templates/ship-confirmation.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/** Server-side only — never ship this map in desktop/APK clients. */
const PM_SMS_ROSTER: Record<string, string> = {
  "Amanda Sievers": "7807204487@msg.telus.com",
  "Amber Shuya": "7809141677@msg.telus.com",
  "Ben Karpiak": "7802320414@txt.bell.ca",
  "Brandon Kaminski": "7809755556@msg.telus.com",
  "Brice Johnson": "7809350628@msg.telus.com",
  "Carmen Martin": "7802385255@pcs.rogers.com",
  "Chris Acorn": "7807253416@msg.telus.com",
  "Dustin Strachan": "7809759387@msg.telus.com",
  "Kim Mulder": "7809530959@msg.telus.com",
  "Meedo Attia": "5875013894@txt.freedommobile.ca",
  "Miranda McBrayne": "7809356267@fido.ca",
  "Renee Jean": "7808196520@msg.telus.com",
  "Sean Fitzpatrick": "7802660362@msg.telus.com",
  "Steele Hult": "3069037728@sms.sasktel.com",
};

function resolveSmsGateway(input: string | undefined | null): string | null {
  if (!input) return null;
  const val = input.trim();
  if (!val) return null;
  if (val.includes("@")) return val;
  if (PM_SMS_ROSTER[val]) return PM_SMS_ROSTER[val];
  const lower = val.toLowerCase();
  const match = Object.keys(PM_SMS_ROSTER).find((n) => n.toLowerCase() === lower);
  return match ? PM_SMS_ROSTER[match] : null;
}

function publicPhotoUrl(path: string): string {
  const base = Deno.env.get("SUPABASE_URL") ?? "";
  const clean = path.startsWith("/") ? path.slice(1) : path;
  if (clean.startsWith("http")) return clean;
  return `${base}/storage/v1/object/public/freight-photos/${clean}`;
}

async function resolveWebhookUrl(): Promise<string | null> {
  const fromEnv = Deno.env.get("MAKE_EMAIL_WEBHOOK_URL");
  if (fromEnv && fromEnv.trim()) return fromEnv.trim();

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !serviceKey) return null;

  const admin = createClient(url, serviceKey);
  const { data, error } = await admin.rpc("get_app_secret", {
    p_key: "MAKE_EMAIL_WEBHOOK_URL",
  });
  if (error || !data || data === "REPLACE_ME") return null;
  return String(data);
}

/**
 * For ship_confirm / quick_ship, replace the client HTML snippet with the
 * branded template. Make continues to send `body` as the email HTML.
 * SMS path is untouched (separate webhook POST with plain text).
 */
function enrichEmailBody(body: Record<string, unknown>): Record<string, unknown> {
  const notificationType = String(body.notification_type ?? "");
  if (!isShipConfirmationType(notificationType)) return body;

  // shipDataFromPayload always fills logoUrl with the hosted transparent PNG
  // when the client omits logo_url (Outlook cannot render SVG/data: icons).
  const shipData = shipDataFromPayload(body);
  const html = renderShipConfirmationEmail(shipData);
  return {
    ...body,
    logo_url: shipData.logoUrl,
    body: html,
    html,
    html_body: html,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const webhook = await resolveWebhookUrl();
    if (!webhook) {
      return new Response(
        JSON.stringify({
          error:
            "MAKE_EMAIL_WEBHOOK_URL is not configured (edge secret or private.app_secrets)",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const to = String(body.to ?? "").trim();
    if (!to) {
      return new Response(JSON.stringify({ error: "Missing to" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const attachments = Array.isArray(body.attachments)
      ? body.attachments.map((p: string) => publicPhotoUrl(String(p)))
      : [];

    const enriched = enrichEmailBody({ ...body, to, attachments });

    const payload = {
      ...enriched,
      to,
      attachments,
      has_attachments: attachments.length > 0,
      sent_by: userData.user.email ?? userData.user.id,
    };

    const makeRes = await fetch(webhook, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!makeRes.ok) {
      const text = await makeRes.text();
      return new Response(
        JSON.stringify({ error: "Make webhook failed", detail: text }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const smsTarget = resolveSmsGateway(body.sms_to ?? body.pm_name ?? null);
    if (smsTarget && body.sms_plain) {
      await fetch(webhook, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          to: smsTarget,
          subject: "",
          body: String(body.sms_plain),
          text: String(body.sms_plain),
          is_sms: true,
          plain_text: true,
          notification_type: body.notification_type ?? "pm_sms",
          attachments: [],
          has_attachments: false,
          sent_by: userData.user.email ?? userData.user.id,
        }),
      });
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
