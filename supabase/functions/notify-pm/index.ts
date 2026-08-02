import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  isShipConfirmationType,
  renderShipConfirmationEmail,
  shipDataFromPayload,
} from "./email-templates/ship-confirmation.ts";
import { renderNotificationEmail } from "./email-templates/notification-email.ts";

/** Bumped on each intentional notify-pm deploy (theme / logging fixes). */
const NOTIFY_PM_VERSION = 80;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function serviceAdmin() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !serviceKey) return null;
  return createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

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

  const admin = serviceAdmin();
  if (!admin) return null;
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

const LOG_OMIT_KEYS = new Set([
  "body",
  "html",
  "html_body",
  "attachments",
  "attachment_urls",
  "photo_urls",
]);

/** Compact JSON for notification_log — drop large HTML / photo arrays. */
function sanitizePayloadForLog(
  body: Record<string, unknown>,
): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(body)) {
    if (LOG_OMIT_KEYS.has(k)) continue;
    if (typeof v === "string" && v.length > 4000) {
      out[k] = `${v.slice(0, 4000)}…`;
      continue;
    }
    out[k] = v;
  }
  return out;
}

function resolvePmName(body: Record<string, unknown>): string | null {
  const explicit = String(body.pm_name ?? "").trim();
  if (explicit) return explicit;
  const smsKey = String(body.sms_to ?? "").trim();
  if (smsKey && PM_SMS_ROSTER[smsKey]) return smsKey;
  const lower = smsKey.toLowerCase();
  const rosterMatch = Object.keys(PM_SMS_ROSTER).find(
    (n) => n.toLowerCase() === lower,
  );
  if (rosterMatch) return rosterMatch;
  return null;
}

function extractPoSummary(body: Record<string, unknown>): string | null {
  const single = String(body.po ?? "").trim();
  if (single) return single;
  const pos = body.pos;
  if (!Array.isArray(pos) || pos.length === 0) return null;
  return pos
    .map((p) => {
      if (p && typeof p === "object" && "po" in p) {
        return String((p as { po?: unknown }).po ?? "").trim();
      }
      return String(p ?? "").trim();
    })
    .filter((s) => s.length > 0)
    .join(", ");
}

async function appendNotificationLog(row: {
  notification_type: string;
  status: string;
  channel: string;
  pm_name: string | null;
  pm_email: string | null;
  pm_phone_gateway: string | null;
  so: string | null;
  po: string | null;
  customer: string | null;
  vendor: string | null;
  carrier: string | null;
  subject: string | null;
  sent_by: string | null;
  error_detail: string | null;
  payload: Record<string, unknown>;
}): Promise<string | null> {
  const admin = serviceAdmin();
  if (!admin) {
    console.error("notification_log skipped: missing service credentials");
    return null;
  }
  const record = {
    notification_type: row.notification_type || "unknown",
    status: row.status || "failed",
    channel: row.channel || "email",
    pm_name: row.pm_name,
    pm_email: row.pm_email,
    pm_phone_gateway: row.pm_phone_gateway,
    so: row.so,
    po: row.po,
    customer: row.customer,
    vendor: row.vendor,
    carrier: row.carrier,
    subject: row.subject,
    sent_by: row.sent_by,
    error_detail: row.error_detail,
    payload: row.payload ?? {},
  };
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      const { data, error } = await admin
        .from("notification_log")
        .insert(record)
        .select("id")
        .single();
      if (error) {
        console.error(
          `notification_log insert failed (attempt ${attempt}):`,
          error.message,
          error.code,
          error.details,
        );
        if (attempt < 2) continue;
        return null;
      }
      return data?.id ?? null;
    } catch (e) {
      console.error(`notification_log insert error (attempt ${attempt}):`, e);
      if (attempt < 2) continue;
      return null;
    }
  }
  return null;
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

  let pendingLog: Parameters<typeof appendNotificationLog>[0] | null = null;

  try {
    const webhook = await resolveWebhookUrl();
    if (!webhook) {
      return new Response(
        JSON.stringify({
          error:
            "MAKE_EMAIL_WEBHOOK_URL is not configured (edge secret or private.app_secrets)",
          notify_pm_version: NOTIFY_PM_VERSION,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({
          error: "Missing Authorization",
          notify_pm_version: NOTIFY_PM_VERSION,
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized",
          notify_pm_version: NOTIFY_PM_VERSION,
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const body = await req.json();
    const to = String(body.to ?? "").trim();
    const notificationType = String(body.notification_type ?? "").trim();
    const sentBy = userData.user.email ?? userData.user.id;
    const pmName = resolvePmName(body);
    const vendor = String(body.vendor ?? "").trim() || null;
    const customer = String(body.customer ?? "").trim() || vendor;

    const logBase = {
      notification_type: notificationType || "unknown",
      pm_name: pmName,
      pm_email: to || null,
      so: String(body.so ?? "").trim() || null,
      po: extractPoSummary(body),
      customer,
      vendor,
      carrier: String(body.carrier ?? "").trim() || null,
      subject: String(body.subject ?? "").trim() || null,
      sent_by: sentBy,
      payload: sanitizePayloadForLog({
        ...body,
        to,
        pm_name: pmName,
        sent_by: sentBy,
        notify_pm_version: NOTIFY_PM_VERSION,
      }),
    };
    pendingLog = {
      ...logBase,
      status: "failed",
      channel: "email",
      pm_phone_gateway: null,
      error_detail: "notify-pm aborted before delivery",
    };

    if (!to || !to.includes("@")) {
      const logId = await appendNotificationLog({
        ...logBase,
        status: "rejected",
        channel: "email",
        pm_phone_gateway: null,
        error_detail: "Missing or invalid to email",
      });
      pendingLog = null;
      return new Response(
        JSON.stringify({
          error: "Missing or invalid to email",
          notify_pm_version: NOTIFY_PM_VERSION,
          log_id: logId,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

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
      const detail = `Missing required fields: ${missing.join(", ")}`;
      const logId = await appendNotificationLog({
        ...logBase,
        status: "rejected",
        channel: "email",
        pm_phone_gateway: null,
        error_detail: detail,
      });
      pendingLog = null;
      return new Response(
        JSON.stringify({
          error: detail,
          notify_pm_version: NOTIFY_PM_VERSION,
          log_id: logId,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const attachments = normalizeAttachments(body.attachments);
    logBase.payload = sanitizePayloadForLog({
      ...body,
      to,
      pm_name: pmName,
      sent_by: sentBy,
      attachment_count: attachments.length,
      notify_pm_version: NOTIFY_PM_VERSION,
    });
    pendingLog = {
      ...logBase,
      status: "failed",
      channel: "email",
      pm_phone_gateway: null,
      error_detail: "notify-pm aborted before delivery",
    };

    const enriched = enrichEmailBody({ ...body, to, attachments }, attachments);
    const payload = {
      ...enriched,
      to,
      pm_name: pmName ?? enriched.pm_name,
      sent_by: sentBy,
      notify_pm_version: NOTIFY_PM_VERSION,
    };

    let makeRes: Response;
    try {
      makeRes = await fetch(webhook, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
    } catch (fetchErr) {
      const detail = `Make webhook fetch error: ${String(fetchErr)}`.slice(
        0,
        2000,
      );
      const logId = await appendNotificationLog({
        ...logBase,
        status: "failed",
        channel: "email",
        pm_phone_gateway: null,
        error_detail: detail,
      });
      pendingLog = null;
      return new Response(
        JSON.stringify({
          error: "Make webhook failed",
          detail,
          notify_pm_version: NOTIFY_PM_VERSION,
          log_id: logId,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!makeRes.ok) {
      const text = await makeRes.text();
      const logId = await appendNotificationLog({
        ...logBase,
        status: "failed",
        channel: "email",
        pm_phone_gateway: null,
        error_detail: text.slice(0, 2000) || "Make webhook failed",
      });
      pendingLog = null;
      return new Response(
        JSON.stringify({
          error: "Make webhook failed",
          detail: text,
          notify_pm_version: NOTIFY_PM_VERSION,
          log_id: logId,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const smsTarget = resolveSmsGateway(
      String(body.sms_to ?? body.pm_name ?? pmName ?? ""),
    );
    let smsSent = false;
    let smsError: string | null = null;
    if (smsTarget && body.sms_plain) {
      try {
        const smsRes = await fetch(webhook, {
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
            sent_by: sentBy,
          }),
        });
        if (smsRes.ok) {
          smsSent = true;
        } else {
          smsError = (await smsRes.text()).slice(0, 1000);
        }
      } catch (smsErr) {
        smsError = `SMS fetch error: ${String(smsErr)}`.slice(0, 1000);
      }
    }

    const channel = smsSent ? "email+sms" : "email";
    const logId = await appendNotificationLog({
      ...logBase,
      status: smsError ? "partial" : "sent",
      channel,
      pm_phone_gateway: smsTarget,
      error_detail: smsError,
    });
    pendingLog = null;

    return new Response(
      JSON.stringify({
        ok: true,
        channel,
        sms_sent: smsSent,
        notify_pm_version: NOTIFY_PM_VERSION,
        log_id: logId,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (e) {
    if (pendingLog) {
      await appendNotificationLog({
        ...pendingLog,
        status: "failed",
        error_detail: String(e).slice(0, 2000),
      });
    } else {
      await appendNotificationLog({
        notification_type: "unknown",
        status: "failed",
        channel: "email",
        pm_name: null,
        pm_email: null,
        pm_phone_gateway: null,
        so: null,
        po: null,
        customer: null,
        vendor: null,
        carrier: null,
        subject: null,
        sent_by: null,
        error_detail: String(e).slice(0, 2000),
        payload: { notify_pm_version: NOTIFY_PM_VERSION },
      });
    }
    return new Response(
      JSON.stringify({
        error: String(e),
        notify_pm_version: NOTIFY_PM_VERSION,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
