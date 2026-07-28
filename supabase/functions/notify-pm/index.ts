import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  isShipConfirmationType,
  renderShipConfirmationEmail,
  shipDataFromPayload,
} from "./email-templates/ship-confirmation.ts";
import { renderNotificationEmail } from "./email-templates/notification-email.ts";

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

function normalizeAttachments(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((p) => publicPhotoUrl(String(p)))
    .filter((url) => url.length > 0);
}

function withAttachmentFields(
  body: Record<string, unknown>,
  attachmentUrls: string[],
): Record<string, unknown> {
  const first = attachmentUrls[0] ?? "";
  return {
    ...body,
    attachments: attachmentUrls,
    attachment_urls: attachmentUrls,
    photo_urls: attachmentUrls,
    public_photo_url: first,
    publicPhotoUrl: first,
    has_attachments: attachmentUrls.length > 0,
    attachment_count: attachmentUrls.length,
  };
}

/**
 * Replace client HTML snippets with branded templates for all PM email types.
 * Make continues to send `body` as the email HTML.
 */
function enrichEmailBody(
  body: Record<string, unknown>,
  attachmentUrls: string[],
): Record<string, unknown> {
  const notificationType = String(body.notification_type ?? "");
  let html: string | null = null;
  let logoUrl = String(body.logo_url ?? body.logoUrl ?? "");

  if (isShipConfirmationType(notificationType)) {
    const shipData = shipDataFromPayload(body);
    html = renderShipConfirmationEmail(shipData, attachmentUrls);
    logoUrl = shipData.logoUrl ?? logoUrl;
  } else {
    html = renderNotificationEmail(notificationType, body, attachmentUrls);
  }

  if (!html) return withAttachmentFields(body, attachmentUrls);

  return withAttachmentFields({
    ...body,
    logo_url: logoUrl,
    body: html,
    html,
    html_body: html,
  }, attachmentUrls);
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
    if (!to || !to.includes("@")) {
      return new Response(
        JSON.stringify({ error: "Missing or invalid to email" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const notificationType = String(body.notification_type ?? "").trim();
    const missing: string[] = [];
    if (
      notificationType === "ship_confirm" ||
      notificationType === "quick_ship"
    ) {
      if (!String(body.so ?? "").trim()) missing.push("so");
      if (!String(body.customer ?? "").trim()) missing.push("customer");
      if (!String(body.carrier ?? "").trim()) missing.push("carrier");
    } else if (notificationType === "return_to_stock") {
      if (!String(body.so ?? "").trim()) missing.push("so");
      if (!String(body.reason ?? "").trim()) missing.push("reason");
    } else if (notificationType === "po_notification") {
      if (!String(body.po ?? "").trim()) missing.push("po");
      if (!String(body.vendor ?? body.customer ?? "").trim()) {
        missing.push("vendor");
      }
    } else if (notificationType === "return_notification") {
      if (!String(body.so ?? "").trim()) missing.push("so");
      if (!String(body.customer ?? "").trim()) missing.push("customer");
    }
    if (missing.length > 0) {
      return new Response(
        JSON.stringify({
          error: `Missing required fields: ${missing.join(", ")}`,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const attachments = normalizeAttachments(body.attachments);
    const enriched = enrichEmailBody({ ...body, to, attachments }, attachments);

    const payload = {
      ...enriched,
      to,
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
