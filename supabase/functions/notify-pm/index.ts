import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  isShipConfirmationType,
  renderShipConfirmationEmail,
  shipDataFromPayload,
} from "./email-templates/ship-confirmation.ts";
import { renderNotificationEmail } from "./email-templates/notification-email.ts";

/** Bumped on each intentional notify-pm deploy (theme / logging fixes). */
const NOTIFY_PM_VERSION = 89;

const WAREHOUSE_FEEDBACK_EMAIL = "warehouse2@swiftsupply.ca";
const WAREHOUSE_FEEDBACK_PM_NAME = "Warehouse 2";
/** Default CC when clients omit it — Make's Outlook module rejects empty CC. */
const WAREHOUSE_DEFAULT_CC = "warehouse1@swiftsupply.ca";

/** Every in-app email type the Flutter clients can send. */
const ALL_NOTIFICATION_TYPES = [
  "ship_notification",
  "return_to_stock_notification",
  "po_notification",
  "bulk_po_notification",
  "return_notification",
  "feedback_notification",
] as const;

function isFeedbackType(notificationType: string): boolean {
  return (
    notificationType === "feedback" ||
    notificationType === "feedback_notification"
  );
}

/**
 * Normalize client aliases → Make/log types.
 * Make itself is type-agnostic (sends to/subject/body); we still normalize so
 * templates, logs, and any future filters stay consistent.
 */
function normalizeMakeNotificationType(raw: string): {
  makeType: string;
  clientType: string;
} {
  const clientType = raw.trim();
  const lower = clientType.toLowerCase();
  switch (lower) {
    case "ship_confirm":
    case "quick_ship":
    case "ship_notification":
      return { makeType: "ship_notification", clientType: clientType || lower };
    case "return_to_stock":
    case "return_to_stock_notification":
      return {
        makeType: "return_to_stock_notification",
        clientType: clientType || lower,
      };
    case "po_notification":
      return { makeType: "po_notification", clientType: clientType || lower };
    case "bulk_po_notification":
      return {
        makeType: "bulk_po_notification",
        clientType: clientType || lower,
      };
    case "return_notification":
      return {
        makeType: "return_notification",
        clientType: clientType || lower,
      };
    case "feedback":
    case "feedback_notification":
      return {
        makeType: "feedback_notification",
        clientType: clientType || lower,
      };
    default:
      return { makeType: clientType, clientType };
  }
}

/** Ensure every common Make email recipient mapping field is populated. */
function applyRecipientAliases(
  body: Record<string, unknown>,
  to: string,
): void {
  body.to = to;
  body.to_email = to;
  body.email = to;
  body.pm_email = to;
  body.recipient = to;
}

/**
 * Final JSON posted to Make — must satisfy the webhook interface for every
 * notification type (ship, quick ship, return-to-stock, PO, bulk PO, return,
 * feedback). Outlook rejects empty `to` / empty CC arrays.
 */
function buildMakeWebhookPayload(
  enriched: Record<string, unknown>,
  opts: {
    to: string;
    cc: string;
    notificationType: string;
    pmName: string | null;
    sentBy: string;
    attachmentUrls: string[];
  },
): Record<string, unknown> {
  const subject = String(enriched.subject ?? "").trim() ||
    `Swift Staging notification (${opts.notificationType || "email"})`;
  const bodyHtml = String(
    enriched.body ?? enriched.html ?? enriched.html_body ?? "",
  ).trim() ||
    `<p>Swift Staging &amp; Shipping Log notification</p><p>Type: ${opts.notificationType}</p>`;
  const httpsOnly = opts.attachmentUrls.filter((u) =>
    /^https?:\/\//i.test(u)
  );
  return {
    ...enriched,
    to: opts.to,
    cc: opts.cc,
    subject,
    body: bodyHtml,
    html: bodyHtml,
    html_body: bodyHtml,
    attachments: httpsOnly,
    attachment_urls: httpsOnly,
    photo_urls: httpsOnly,
    public_photo_url: httpsOnly[0] ?? "",
    publicPhotoUrl: httpsOnly[0] ?? "",
    // Boolean (not string) — Make router uses length(attachments) + this flag.
    has_attachments: httpsOnly.length > 0,
    attachment_count: httpsOnly.length,
    notification_type: opts.notificationType,
    pm_name: opts.pmName ?? enriched.pm_name,
    sent_by: opts.sentBy,
    notify_pm_version: NOTIFY_PM_VERSION,
    supported_notification_types: [...ALL_NOTIFICATION_TYPES],
  };
}

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
  "sms_to",
  "sms_plain",
  "is_sms",
  "plain_text",
  "text",
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
  return explicit || null;
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
    let to = String(body.to ?? "").trim();
    const incomingType = String(body.notification_type ?? "").trim();
    const { makeType, clientType } = normalizeMakeNotificationType(incomingType);
    let notificationType = makeType;
    body.client_notification_type = clientType;
    body.notification_type = notificationType;

    if (isFeedbackType(incomingType) || isFeedbackType(notificationType)) {
      // Make's PM-email scenario matches `*_notification` types and looks up
      // the roster name "Warehouse 2" (not a shortened "Warehouse").
      notificationType = "feedback_notification";
      to = WAREHOUSE_FEEDBACK_EMAIL;
      applyRecipientAliases(body, to);
      body.notification_type = notificationType;
      body.pm_name = WAREHOUSE_FEEDBACK_PM_NAME;
      // Legacy Make mappings expect `customer` on every PM email payload.
      if (!String(body.customer ?? "").trim()) {
        body.customer = "App feedback";
      }
    } else if (to.includes("@")) {
      applyRecipientAliases(body, to);
    }

    const sentBy = userData.user.email ?? userData.user.id;
    const pmName = isFeedbackType(notificationType)
      ? WAREHOUSE_FEEDBACK_PM_NAME
      : resolvePmName(body);
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
      error_detail: "notify-pm aborted before delivery",
    };

    if (!to || !to.includes("@")) {
      const logId = await appendNotificationLog({
        ...logBase,
        status: "rejected",
        channel: "email",
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
    if (isShipConfirmationType(notificationType) ||
      notificationType === "ship_confirm" ||
      notificationType === "quick_ship") {
      if (!String(body.so ?? "").trim()) missing.push("so");
      if (!String(body.customer ?? "").trim()) missing.push("customer");
      if (!String(body.carrier ?? "").trim()) missing.push("carrier");
    } else if (
      notificationType === "return_to_stock" ||
      notificationType === "return_to_stock_notification"
    ) {
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
    } else if (isFeedbackType(notificationType)) {
      if (!String(body.details ?? body.message ?? "").trim()) {
        missing.push("details");
      }
    }
    if (missing.length > 0) {
      const detail = `Missing required fields: ${missing.join(", ")}`;
      const logId = await appendNotificationLog({
        ...logBase,
        status: "rejected",
        channel: "email",
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
    const cc = String(body.cc ?? "").trim() || WAREHOUSE_DEFAULT_CC;
    body.cc = cc;
    logBase.payload = sanitizePayloadForLog({
      ...body,
      to,
      cc,
      pm_name: pmName,
      sent_by: sentBy,
      attachment_count: attachments.length,
      notify_pm_version: NOTIFY_PM_VERSION,
    });
    pendingLog = {
      ...logBase,
      status: "failed",
      channel: "email",
      error_detail: "notify-pm aborted before delivery",
    };

    const enriched = enrichEmailBody({ ...body, to, cc, attachments }, attachments);
    const payload = buildMakeWebhookPayload(enriched, {
      to,
      cc,
      notificationType,
      pmName,
      sentBy,
      attachmentUrls: attachments,
    });

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

    const logId = await appendNotificationLog({
      ...logBase,
      status: "sent",
      channel: "email",
      error_detail: null,
    });
    pendingLog = null;

    return new Response(
      JSON.stringify({
        ok: true,
        channel: "email",
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
