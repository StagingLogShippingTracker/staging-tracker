import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * SLST ship-confirmation HTML email — concept-matched layout.
 * Images MUST be HTTPS PNGs (Outlook blocks SVG / data: URIs).
 * Forced light appearance: bgcolor + color-scheme + Outlook dark overrides.
 */

type ShipConfirmationData = {
  so: string;
  customer: string;
  carrier: string;
  shippedAt: string;
  shippedBy: string;
  containers: string;
  weight: string;
  comments: string;
  logoUrl?: string;
  ctaUrl?: string;
  emailContact?: string;
  websiteUrl?: string;
  year?: number;
  assetBaseUrl?: string;
};

/** Brand tokens aligned to concept mockup + app theme. */
const BRAND = "#D93223";
const BRAND_DARK = "#B92820";
const INK = "#2A2A2A";
const BODY = "#3A3A3A";
const MUTED = "#6B6B6B";
const BORDER = "#E6E2DC";
const PAGE_BG = "#F3F1EC";
const CARD_SHELL = "#F7F5F1";
const WHITE = "#FFFFFF";
const ICON_WASH = "#FDECEA";

/**
 * Public HTTPS asset host (Supabase Storage bucket `email-assets`).
 * Outlook blocks SVG and data: image URIs — HTTPS PNGs are required.
 */
export const DEFAULT_EMAIL_ASSET_BASE =
  "https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/email-assets";

/** Cache-bust so Outlook/CDN pick up the HD logo after redeploys. */
const ASSET_VERSION = "20260722b";

function emailAssetUrl(fileKey: string, baseUrl?: string): string {
  const base = (baseUrl ?? DEFAULT_EMAIL_ASSET_BASE).replace(/\/$/, "");
  const key = fileKey.replace(/\.png$/i, "");
  // Edge function uses ?f= ; Storage uses /file.png
  if (base.includes("/functions/v1/email-assets")) {
    return `${base}?f=${encodeURIComponent(key)}&v=${ASSET_VERSION}`;
  }
  return `${base}/${encodeURIComponent(key)}.png?v=${ASSET_VERSION}`;
}

function esc(value: string | undefined | null): string {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function displayOrNone(value: string | undefined | null): string {
  const v = String(value ?? "").trim();
  return v.length ? esc(v) : "None";
}

function detailCard(opts: {
  iconUrl: string;
  title: string;
  rows: Array<{ label: string; value: string }>;
}): string {
  const rowsHtml = opts.rows
    .map(
      (r) => `
        <tr>
          <td style="padding:0 0 10px 0;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.35;color:${INK};">
            <div style="font-weight:700;color:${INK};mso-line-height-rule:exactly;">${esc(r.label)}</div>
            <div style="font-weight:400;color:${BODY};padding-top:2px;mso-line-height-rule:exactly;">${r.value}</div>
          </td>
        </tr>`,
    )
    .join("");

  return `
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="${WHITE}" class="og-white"
      style="background-color:${WHITE} !important;border:1px solid ${BORDER};border-radius:14px;box-shadow:0 4px 14px rgba(42,42,42,0.06);">
      <tr>
        <td bgcolor="${WHITE}" class="og-white" style="padding:20px 18px 12px 18px;background-color:${WHITE} !important;">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
            <tr>
              <td width="44" valign="top" style="padding-right:12px;">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="40" height="40" bgcolor="${ICON_WASH}" class="og-icon"
                  style="width:40px;height:40px;background-color:${ICON_WASH} !important;border-radius:10px;">
                  <tr>
                    <td align="center" valign="middle" bgcolor="${ICON_WASH}" class="og-icon"
                      style="width:40px;height:40px;text-align:center;vertical-align:middle;background-color:${ICON_WASH} !important;">
                      <img src="${esc(opts.iconUrl)}" width="24" height="24" alt=""
                        style="display:block;margin:0 auto;border:0;outline:none;-ms-interpolation-mode:bicubic;" />
                    </td>
                  </tr>
                </table>
              </td>
              <td valign="middle">
                <div style="font-family:Arial,Helvetica,sans-serif;font-size:12px;font-weight:700;letter-spacing:0.12em;color:${BRAND};text-transform:uppercase;mso-line-height-rule:exactly;">
                  ${esc(opts.title)}
                </div>
              </td>
            </tr>
          </table>
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin-top:14px;">
            ${rowsHtml}
          </table>
        </td>
      </tr>
    </table>`;
}

/**
 * HD logo: serve ~900px PNG, display at 300px (3x) for crisp Outlook / HiDPI.
 * Tagline is baked into the logo artwork — do not duplicate as HTML text.
 */
function logoBlock(logoUrl: string): string {
  return `<img src="${esc(logoUrl)}" width="300" alt="SLST — Staging Log &amp; Shipping Tracker"
    style="display:block;margin:0 auto;border:0;outline:none;width:300px;max-width:86%;height:auto;-ms-interpolation-mode:bicubic;" />`;
}

function renderShipConfirmationEmail(data: ShipConfirmationData): string {
  const assetBase = data.assetBaseUrl ?? DEFAULT_EMAIL_ASSET_BASE;
  const logoUrl = (data.logoUrl && data.logoUrl.trim()) ||
    emailAssetUrl("slst-logo-email", assetBase);

  const so = esc(data.so);
  const customer = displayOrNone(data.customer);
  const carrier = displayOrNone(data.carrier);
  const shippedAt = displayOrNone(data.shippedAt);
  const shippedBy = displayOrNone(data.shippedBy);
  const containers = displayOrNone(data.containers);
  const weight = displayOrNone(data.weight);
  const comments = displayOrNone(data.comments);
  const year = data.year ?? new Date().getFullYear();
  const emailContact = (data.emailContact ?? "warehouse1@swiftsupply.ca").trim();
  const websiteUrl = (data.websiteUrl ?? "https://www.swiftsupply.ca").trim();
  const ctaUrl = (data.ctaUrl ?? websiteUrl).trim();
  const mailto = `mailto:${emailContact}`;

  const clipboard = emailAssetUrl("icon-clipboard", assetBase);
  const truck = emailAssetUrl("icon-truck", assetBase);
  const cargo = emailAssetUrl("icon-cargo", assetBase);
  const chat = emailAssetUrl("icon-chat", assetBase);
  const search = emailAssetUrl("icon-search", assetBase);
  const mail = emailAssetUrl("icon-mail", assetBase);
  const globe = emailAssetUrl("icon-globe", assetBase);
  const watermark = emailAssetUrl("watermark-gears", assetBase);

  const orderCard = detailCard({
    iconUrl: clipboard,
    title: "ORDER SUMMARY",
    rows: [
      { label: "SO#", value: so || "None" },
      { label: "Customer", value: customer },
    ],
  });
  const shippingCard = detailCard({
    iconUrl: truck,
    title: "SHIPPING INFORMATION",
    rows: [
      { label: "Carrier", value: carrier },
      { label: "Shipped At", value: shippedAt },
      { label: "Shipped By", value: shippedBy },
    ],
  });
  const cargoCard = detailCard({
    iconUrl: cargo,
    title: "CARGO DETAILS",
    rows: [
      { label: "Container(s)", value: containers },
      { label: "Total Weight (In lbs)", value: weight },
    ],
  });
  const notesCard = detailCard({
    iconUrl: chat,
    title: "ADDITIONAL NOTES",
    rows: [{ label: "Comments", value: comments }],
  });

  return `<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <meta name="color-scheme" content="light only" />
  <meta name="supported-color-schemes" content="light" />
  <title>Your order has now been shipped!</title>
  <!--[if mso]>
  <noscript>
    <xml>
      <o:OfficeDocumentSettings>
        <o:PixelsPerInch>96</o:PixelsPerInch>
        <o:AllowPNG/>
      </o:OfficeDocumentSettings>
    </xml>
  </noscript>
  <style>
    table { border-collapse: collapse; }
    td, th, div, p, a, span, strong, h1 { font-family: Arial, Helvetica, sans-serif !important; }
  </style>
  <![endif]-->
  <style type="text/css">
    :root { color-scheme: light only; supported-color-schemes: light; }
    body, table, td, a { -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
    table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
    img { -ms-interpolation-mode: bicubic; border: 0; outline: none; text-decoration: none; }
    body { margin: 0 !important; padding: 0 !important; width: 100% !important; background-color: ${PAGE_BG} !important; }
    a { color: ${BRAND}; }

    /* Keep light palette even when the client tries to invert for dark mode */
    @media (prefers-color-scheme: dark) {
      .og-page, .og-shell, .og-white, .og-icon, .og-footer {
        background-color: ${PAGE_BG} !important;
        color: ${INK} !important;
      }
      .og-shell { background-color: ${CARD_SHELL} !important; }
      .og-white { background-color: ${WHITE} !important; }
      .og-icon { background-color: ${ICON_WASH} !important; }
      .og-text, .og-text div, .og-text p, .og-text span, .og-text strong, .og-text h1 {
        color: ${INK} !important;
      }
      .og-brand { color: ${BRAND} !important; }
      .og-muted { color: ${MUTED} !important; }
      .og-cta { background-color: ${BRAND} !important; color: ${WHITE} !important; }
    }

    /* Outlook.com / Outlook dark-mode attribute hooks */
    [data-ogsc] .og-page, [data-ogsb] .og-page { background-color: ${PAGE_BG} !important; }
    [data-ogsc] .og-shell, [data-ogsb] .og-shell { background-color: ${CARD_SHELL} !important; }
    [data-ogsc] .og-white, [data-ogsb] .og-white { background-color: ${WHITE} !important; }
    [data-ogsc] .og-icon, [data-ogsb] .og-icon { background-color: ${ICON_WASH} !important; }
    [data-ogsc] .og-text, [data-ogsc] .og-text *, [data-ogsb] .og-text, [data-ogsb] .og-text * { color: ${INK} !important; }
    [data-ogsc] .og-brand, [data-ogsb] .og-brand { color: ${BRAND} !important; }
    [data-ogsc] .og-muted, [data-ogsb] .og-muted { color: ${MUTED} !important; }
    [data-ogsc] .og-cta, [data-ogsb] .og-cta { background-color: ${BRAND} !important; color: ${WHITE} !important; }

    @media only screen and (max-width: 620px) {
      .email-card { width: 100% !important; }
      .stack-col { display: block !important; width: 100% !important; max-width: 100% !important; box-sizing: border-box !important; padding-left: 0 !important; padding-right: 0 !important; }
      .stack-col-pad { padding: 8px 0 !important; }
      .footer-right { text-align: left !important; padding-top: 16px !important; }
      .logo-img { width: 260px !important; max-width: 90% !important; height: auto !important; }
    }
  </style>
</head>
<body class="og-page" bgcolor="${PAGE_BG}" style="margin:0;padding:0;background-color:${PAGE_BG};">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:${PAGE_BG};">
    SO# ${so} for ${customer} has shipped via ${carrier}.
  </div>

  <table role="presentation" class="og-page" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="${PAGE_BG}"
    background="${esc(watermark)}"
    style="background-color:${PAGE_BG};background-image:url('${esc(watermark)}');background-repeat:repeat;background-position:top center;">
    <tr>
      <td align="center" bgcolor="${PAGE_BG}" class="og-page" style="padding:36px 16px 28px 16px;background-color:${PAGE_BG};">
        <!--[if mso]>
        <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0"><tr><td>
        <![endif]-->

        <table role="presentation" class="email-card og-shell" width="600" cellpadding="0" cellspacing="0" border="0" bgcolor="${CARD_SHELL}"
          style="width:100%;max-width:600px;background-color:${CARD_SHELL};border-radius:18px;border:1px solid ${BORDER};box-shadow:0 18px 48px rgba(42,42,42,0.10);overflow:hidden;">

          <!-- Logo / brand lockup -->
          <tr>
            <td align="center" bgcolor="${CARD_SHELL}" class="og-shell"
              background="${esc(watermark)}"
              style="padding:42px 36px 10px 36px;background-color:${CARD_SHELL};background-image:url('${esc(watermark)}');background-repeat:repeat;background-size:240px 240px;">
              <!--[if gte mso 9]>
              <v:rect xmlns:v="urn:schemas-microsoft-com:vml" fill="true" stroke="false" style="width:600px;">
              <v:fill type="tile" src="${esc(watermark)}" color="${CARD_SHELL}" />
              <v:textbox style="mso-fit-shape-to-text:true" inset="0,0,0,0">
              <![endif]-->
              ${logoBlock(logoUrl).replace("<img ", '<img class="logo-img" ')}
              <!--[if gte mso 9]>
              </v:textbox></v:rect>
              <![endif]-->
            </td>
          </tr>

          <!-- Headline -->
          <tr>
            <td align="center" bgcolor="${CARD_SHELL}" class="og-shell og-text" style="padding:26px 36px 6px 36px;background-color:${CARD_SHELL};">
              <h1 style="margin:0;font-family:Arial,Helvetica,sans-serif;font-size:28px;line-height:1.28;font-weight:700;color:${INK};">
                Your order has now been shipped!
              </h1>
            </td>
          </tr>
          <tr>
            <td align="center" bgcolor="${CARD_SHELL}" class="og-shell og-text" style="padding:8px 36px 26px 36px;background-color:${CARD_SHELL};">
              <p style="margin:0;font-family:Arial,Helvetica,sans-serif;font-size:16px;line-height:1.4;color:${BODY};">
                Order details:
              </p>
            </td>
          </tr>

          <!-- 2×2 detail cards — concept spacing -->
          <tr>
            <td bgcolor="${CARD_SHELL}" class="og-shell" style="padding:0 22px 10px 22px;background-color:${CARD_SHELL};">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td class="stack-col stack-col-pad" width="50%" valign="top" style="width:50%;padding:8px;">
                    ${orderCard}
                  </td>
                  <td class="stack-col stack-col-pad" width="50%" valign="top" style="width:50%;padding:8px;">
                    ${shippingCard}
                  </td>
                </tr>
                <tr>
                  <td class="stack-col stack-col-pad" width="50%" valign="top" style="width:50%;padding:8px;">
                    ${cargoCard}
                  </td>
                  <td class="stack-col stack-col-pad" width="50%" valign="top" style="width:50%;padding:8px;">
                    ${notesCard}
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- CTA -->
          <tr>
            <td align="center" bgcolor="${CARD_SHELL}" class="og-shell" style="padding:26px 36px 34px 36px;background-color:${CARD_SHELL};">
              <!--[if mso]>
              <v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word"
                href="${esc(ctaUrl)}" style="height:52px;v-text-anchor:middle;width:340px;" arcsize="50%" stroke="f" fillcolor="${BRAND}">
                <w:anchorlock/>
                <center style="color:#ffffff;font-family:Arial,Helvetica,sans-serif;font-size:13px;font-weight:700;letter-spacing:0.06em;">
                  VIEW FULL TRACKING DETAILS
                </center>
              </v:roundrect>
              <![endif]-->
              <!--[if !mso]><!-- -->
              <a class="og-cta" href="${esc(ctaUrl)}"
                style="display:inline-block;background-color:${BRAND};background-image:linear-gradient(90deg, ${BRAND} 0%, ${BRAND_DARK} 100%);color:${WHITE} !important;font-family:Arial,Helvetica,sans-serif;font-size:13px;font-weight:700;letter-spacing:0.08em;text-decoration:none;padding:16px 34px;border-radius:999px;box-shadow:0 10px 24px rgba(217,50,35,0.35);mso-hide:all;">
                <img src="${esc(search)}" width="16" height="16" alt=""
                  style="display:inline-block;vertical-align:middle;margin-right:10px;border:0;" />
                <span style="vertical-align:middle;color:${WHITE} !important;">VIEW FULL TRACKING DETAILS</span>
              </a>
              <!--<![endif]-->
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td bgcolor="${CARD_SHELL}" class="og-shell" style="padding:0 36px;background-color:${CARD_SHELL};">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td bgcolor="${CARD_SHELL}" class="og-shell" style="border-top:1px solid ${BORDER};font-size:0;line-height:0;background-color:${CARD_SHELL};">&nbsp;</td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td bgcolor="${CARD_SHELL}" class="og-shell og-footer" style="padding:22px 36px 32px 36px;background-color:${CARD_SHELL};">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td class="stack-col og-text" valign="top"
                    style="font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.55;color:${INK};">
                    <strong style="font-weight:700;color:${INK};">Thank you for using SLST!</strong><br />
                    <span style="color:${BODY};">SLST - Staging Log &amp; Shipping Tracker</span><br />
                    <span class="og-muted" style="font-size:12px;color:${MUTED};">Copyright © ${year} SLST. All rights reserved.</span>
                  </td>
                  <td class="stack-col footer-right" valign="top" align="right"
                    style="font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.9;white-space:nowrap;">
                    <a class="og-brand" href="${esc(mailto)}" style="color:${BRAND};text-decoration:underline;">
                      <img src="${esc(mail)}" width="14" height="14" alt=""
                        style="display:inline-block;vertical-align:middle;margin-right:5px;border:0;" />
                      <span style="vertical-align:middle;color:${BRAND};">Email</span>
                    </a>
                    &nbsp;&nbsp;&nbsp;
                    <a class="og-brand" href="${esc(websiteUrl)}" style="color:${BRAND};text-decoration:underline;">
                      <img src="${esc(globe)}" width="14" height="14" alt=""
                        style="display:inline-block;vertical-align:middle;margin-right:5px;border:0;" />
                      <span style="vertical-align:middle;color:${BRAND};">Website</span>
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>

        <!--[if mso]>
        </td></tr></table>
        <![endif]-->

        <div class="og-muted" style="font-family:Arial,Helvetica,sans-serif;font-size:11px;color:${MUTED};padding-top:18px;">
          Sent via SLST · Swift Supply
        </div>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function renderShipConfirmationPlain(data: ShipConfirmationData): string {
  return [
    "Your order has now been shipped!",
    "",
    "Order details:",
    `SO#: ${data.so || "None"}`,
    `Customer: ${data.customer || "None"}`,
    `Carrier: ${data.carrier || "None"}`,
    `Shipped At: ${data.shippedAt || "None"}`,
    `Shipped By: ${data.shippedBy || "None"}`,
    `Container(s): ${data.containers || "None"}`,
    `Total Weight (lbs): ${data.weight || "None"}`,
    `Comments: ${data.comments || "None"}`,
  ].join("\n");
}

function isShipConfirmationType(notificationType: string | undefined | null): boolean {
  const t = String(notificationType ?? "").trim().toLowerCase();
  return t === "ship_confirm" || t === "quick_ship";
}

function shipDataFromPayload(body: Record<string, unknown>): ShipConfirmationData {
  const pick = (...keys: string[]): string => {
    for (const k of keys) {
      const v = body[k];
      if (v != null && String(v).trim()) return String(v).trim();
    }
    return "";
  };

  const assetBase = pick("asset_base_url", "assetBaseUrl") || DEFAULT_EMAIL_ASSET_BASE;
  const logoFromPayload = pick("logo_url", "logoUrl");

  return {
    so: pick("so", "so_number"),
    customer: pick("customer"),
    carrier: pick("carrier"),
    shippedAt: pick("shipped_at", "shippedAt"),
    shippedBy: pick("shipped_by", "shippedBy"),
    containers: pick("containers", "type", "container"),
    weight: pick("weight"),
    comments: pick("comments"),
    logoUrl: logoFromPayload || emailAssetUrl("slst-logo-email", assetBase),
    ctaUrl: pick("cta_url", "ctaUrl", "tracking_url", "trackingUrl") || undefined,
    emailContact: pick("email_contact", "emailContact") || undefined,
    websiteUrl: pick("website_url", "websiteUrl") || undefined,
    assetBaseUrl: assetBase,
  };
}

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
