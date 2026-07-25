import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// --- email-shared.ts ---
/**
 * Shared SLST branded email layout — light-first (matches user light HTML).
 * Dark preference: SLST logo swap + darker info-card fill only (no full dark theme).
 * Logos capped at width=150 / max-width:160px.
 */

export const DEFAULT_EMAIL_ASSET_BASE =
  "https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/email-assets";

const ASSET_VERSION = "20260725l";
const FONT =
  "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";

// Light tokens (reference) — default inline styles; never change these for dark
const L_PAGE = "#f4f4f5";
const L_SHELL = "#fbf9f5";
const L_SHELL_BORDER = "#e5e2dc";
const L_CARD = "#f1ece4";
const L_HEADLINE = "#1a1a1a";
const L_SUBTITLE = "#555555";
const L_CARD_TITLE = "#222222";
const L_LABEL = "#666666";
const L_VALUE = "#111111";
const L_PLUS = "#555555";
const L_FOOTER = "#666666";
const L_DISCLAIMER = "#666666";
const L_DIVIDER = "#e0dad0";
const ORANGE = "#e65100";
const BLUE = "#0288d1";
const CTA_TOP = "#d32f2f";
const CTA_BOT = "#b71c1c";
/** Dark-mode shell (lighter than cards) + card fill (media query / Outlook hooks). */
const D_SHELL = "#2e3033";
const D_CARD = "#151515";
const D_CARD_TITLE = "#f0f0f0";
const D_LABEL = "#a8a8a8";
const D_VALUE = "#f2f2f2";
const D_DISCLAIMER = "#999999";

const ICON_EMOJI: Record<string, string> = {
  "icon-clipboard": "📋",
  "icon-truck": "🚚",
  "icon-cargo": "📦",
  "icon-chat": "💬",
};

export function emailAssetUrl(fileKey: string, baseUrl?: string): string {
  const base = (baseUrl ?? DEFAULT_EMAIL_ASSET_BASE).replace(/\/$/, "");
  const key = fileKey.replace(/\.png$/i, "");
  if (base.includes("/functions/v1/email-assets")) {
    return `${base}?f=${encodeURIComponent(key)}&v=${ASSET_VERSION}`;
  }
  return `${base}/${encodeURIComponent(key)}.png?v=${ASSET_VERSION}`;
}

export function esc(value: string | undefined | null): string {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

export function displayOrNone(value: string | undefined | null): string {
  const v = String(value ?? "").trim();
  return v.length ? esc(v) : "None";
}

function fieldRows(
  rows: Array<{ label: string; value: string }>,
): string {
  return rows
    .map((r, i) => {
      const isLast = i === rows.length - 1;
      const valuePad = isLast ? "" : " padding-bottom: 8px;";
      return `
                      <tr>
                        <td class="og-label" style="font-size: 13px; color: ${L_LABEL}; padding-bottom: 2px; word-break: normal; overflow-wrap: break-word;">${esc(r.label)}</td>
                      </tr>
                      <tr>
                        <td class="og-value" style="font-size: 15px; font-weight: bold; color: ${L_VALUE}; word-break: normal; overflow-wrap: break-word;${valuePad}">${r.value}</td>
                      </tr>`;
    })
    .join("");
}

/** Info card: ~49% width (pairs with 4px gap), cream, 4px top accent. */
export function infoCard(opts: {
  accent: "orange" | "blue";
  title: string;
  icon?: string;
  iconKey?: string;
  fields: Array<{ label: string; value: string }>;
}): string {
  const accent = opts.accent === "blue" ? BLUE : ORANGE;
  const emoji =
    opts.icon ??
    (opts.iconKey ? ICON_EMOJI[opts.iconKey] : undefined) ??
    (opts.accent === "blue" ? "💬" : "📋");
  const titleCls =
    opts.accent === "blue" ? "og-title-blue" : "og-title-orange";
  return `
                  <td class="col-stack og-card" valign="top" width="49%" style="width: 49%; background-color: ${L_CARD}; border-radius: 10px; border-top: 4px solid ${accent}; padding: 14px 12px; word-break: normal; overflow-wrap: break-word;">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td class="${titleCls}" style="font-size: 13px; font-weight: 700; color: ${L_CARD_TITLE}; text-transform: uppercase; letter-spacing: 0.4px; padding-bottom: 10px; word-break: normal; overflow-wrap: break-word;">
                          <span style="color: ${accent}; margin-right: 4px;">${emoji}</span> ${esc(opts.title)}
                        </td>
                      </tr>
                      ${fieldRows(opts.fields)}
                    </table>
                  </td>`;
}

function cardsGridHtml(
  cards: Array<{
    iconKey?: string;
    icon?: string;
    title: string;
    accent?: "orange" | "blue";
    rows: Array<{ label: string; value: string }>;
  }>,
): string {
  const rendered = cards.map((card, i) => {
    const accent = card.accent ?? (i % 2 === 0 ? "orange" : "blue");
    return infoCard({
      accent,
      title: card.title,
      icon: card.icon,
      iconKey: card.iconKey,
      fields: card.rows,
    });
  });

  const rowHtml: string[] = [];
  for (let i = 0; i < rendered.length; i += 2) {
    const left = rendered[i];
    const right = rendered[i + 1];
    const isLastRow = i + 2 >= rendered.length;
    const bottomPad = isLastRow ? "28px" : "15px";
    // Tiny fixed gap — avoid a wide spacer <td> that Outlook expands into a grey gutter.
    const gap =
      `<td class="col-gap" width="4" style="width: 4px; max-width: 4px; font-size: 1px; line-height: 1px; padding: 0;">&nbsp;</td>`;
    const rightCell = right ??
      `<td class="col-stack" valign="top" width="49%" style="width: 49%; padding: 0;">&nbsp;</td>`;
    rowHtml.push(`
          <tr>
            <td style="padding-bottom: ${bottomPad};">
              <table role="presentation" class="cards-row" border="0" cellpadding="0" cellspacing="0" width="100%" style="width: 100%; table-layout: fixed;">
                <tr>
                  ${left}
                  ${gap}
                  ${rightCell}
                </tr>
              </table>
            </td>
          </tr>`);
  }
  return rowHtml.join("");
}

function attachmentsSection(attachmentUrls: string[]): string {
  if (!attachmentUrls.length) return "";
  const gallery = attachmentUrls.slice(0, 8).map((url, i) => `
                <tr>
                  <td style="padding: 8px 0;">
                    <a href="${esc(url)}" style="text-decoration: none;">
                      <img src="${esc(url)}" width="520" alt="Attachment ${i + 1}"
                        style="display: block; width: 100%; max-width: 520px; height: auto; border-radius: 10px; border: 1px solid ${L_SHELL_BORDER};" />
                    </a>
                  </td>
                </tr>`).join("");
  return `
          <tr>
            <td style="padding-bottom: 20px;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" class="og-card"
                style="background-color: ${L_CARD}; border-radius: 10px; border-top: 4px solid ${ORANGE}; padding: 16px;">
                <tr>
                  <td class="og-title-orange" style="font-size: 13px; font-weight: 700; color: ${L_CARD_TITLE}; text-transform: uppercase; letter-spacing: 0.5px; padding-bottom: 10px;">
                    <span style="color: ${ORANGE}; margin-right: 4px;">📎</span> ATTACHMENTS
                  </td>
                </tr>
                <tr>
                  <td class="og-label" style="font-size: 13px; color: ${L_LABEL}; padding-bottom: 2px;">Files</td>
                </tr>
                <tr>
                  <td class="og-value" style="font-size: 15px; font-weight: bold; color: ${L_VALUE};">
                    ${attachmentUrls.length} attached image${attachmentUrls.length === 1 ? "" : "s"}
                  </td>
                </tr>
              </table>
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="margin-top: 12px;">
                ${gallery}
              </table>
            </td>
          </tr>`;
}

function themeCss(): string {
  return `
    :root { color-scheme: light dark; supported-color-schemes: light dark; }
    .logo-light, .logo-swift {
      display: block !important;
      width: 150px !important;
      max-width: 160px !important;
      height: auto !important;
    }
    .logo-dark {
      display: none !important;
      width: 150px !important;
      max-width: 160px !important;
      height: auto !important;
    }
    @media (prefers-color-scheme: dark) {
      .logo-light { display: none !important; }
      .logo-dark {
        display: block !important;
        width: 150px !important;
        max-width: 160px !important;
        height: auto !important;
      }
      .email-container, .og-shell { background-color: ${D_SHELL} !important; }
      .og-card { background-color: ${D_CARD} !important; }
      .og-title-orange, .og-title-blue { color: ${D_CARD_TITLE} !important; }
      .og-label { color: ${D_LABEL} !important; }
      .og-value { color: ${D_VALUE} !important; }
      .og-disclaimer { color: ${D_DISCLAIMER} !important; }
    }
    /* Outlook.com dark-mode attribute hooks */
    [data-ogsb] .logo-light, [data-ogsc] .logo-light { display: none !important; }
    [data-ogsb] .logo-dark, [data-ogsc] .logo-dark {
      display: block !important;
      width: 150px !important;
      max-width: 160px !important;
      height: auto !important;
    }
    [data-ogsb] .email-container, [data-ogsb] .og-shell,
    [data-ogsc] .email-container, [data-ogsc] .og-shell { background-color: ${D_SHELL} !important; }
    [data-ogsb] .og-card, [data-ogsc] .og-card { background-color: ${D_CARD} !important; }
    [data-ogsb] .og-title-orange, [data-ogsb] .og-title-blue,
    [data-ogsc] .og-title-orange, [data-ogsc] .og-title-blue { color: ${D_CARD_TITLE} !important; }
    [data-ogsb] .og-label, [data-ogsc] .og-label { color: ${D_LABEL} !important; }
    [data-ogsb] .og-value, [data-ogsc] .og-value { color: ${D_VALUE} !important; }
    [data-ogsb] .og-disclaimer, [data-ogsc] .og-disclaimer { color: ${D_DISCLAIMER} !important; }
  `;
}

export type BrandedEmailOptions = {
  title: string;
  preview: string;
  subtitle?: string;
  cards: Array<{
    iconKey?: string;
    icon?: string;
    title: string;
    accent?: "orange" | "blue";
    rows: Array<{ label: string; value: string }>;
  }>;
  /** Pre-built cards grid HTML (optional override). */
  cardsGridHtml?: string;
  attachmentUrls?: string[];
  assetBaseUrl?: string;
  logoUrl?: string;
  ctaUrl?: string;
  ctaLabel?: string;
  emailContact?: string;
  websiteUrl?: string;
  year?: number;
};

export function renderBrandedEmail(opts: BrandedEmailOptions): string {
  const assetBase = opts.assetBaseUrl ?? DEFAULT_EMAIL_ASSET_BASE;
  const slstLight = emailAssetUrl("slst-logo-email", assetBase);
  const slstDark = emailAssetUrl("slst-logo-email-dark", assetBase);
  const swiftLogoUrl = emailAssetUrl("swift-supply-logo-email", assetBase);
  const title = esc(opts.title);
  const subtitle = esc(opts.subtitle ?? "Order details:");
  const preview = esc(opts.preview);
  const attachmentUrls = opts.attachmentUrls ?? [];
  const ctaUrl = (opts.ctaUrl ?? "").trim();
  const ctaLabel = esc(opts.ctaLabel ?? "VIEW FULL TRACKING DETAILS");
  const grid = opts.cardsGridHtml ?? cardsGridHtml(opts.cards);

  const logoStyle =
    'display: block; max-width: 160px; height: auto; border: 0; outline: none; -ms-interpolation-mode: bicubic;';
  const logoDarkStyle =
    'display: none; max-width: 160px; height: auto; border: 0; outline: none; -ms-interpolation-mode: bicubic;';

  const ctaBlock = ctaUrl
    ? `
          <tr>
            <td align="center" style="padding-bottom: 30px;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" class="og-cta" style="border-radius: 25px; background: linear-gradient(180deg, ${CTA_TOP} 0%, ${CTA_BOT} 100%); background-color: ${CTA_TOP}; padding: 14px 28px; box-shadow: 0 3px 6px rgba(183, 28, 28, 0.3);">
                    <a href="${esc(ctaUrl)}" target="_blank" style="font-size: 14px; font-weight: bold; color: #ffffff; text-decoration: none; display: inline-block; letter-spacing: 0.5px;">
                      🔍 ${ctaLabel}
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>`
    : "";

  return `<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="color-scheme" content="light dark">
  <meta name="supported-color-schemes" content="light dark">
  <meta name="x-apple-disable-message-reformatting">
  <title>${title}</title>
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
    .logo-light { display: block !important; }
    .logo-dark { display: none !important; }
  </style>
  <![endif]-->
  <style>
    body, table, td, a { text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
    table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
    img { -ms-interpolation-mode: bicubic; border: 0; height: auto; line-height: 100%; outline: none; text-decoration: none; }
    body { height: 100% !important; margin: 0 !important; padding: 0 !important; width: 100% !important; background-color: ${L_PAGE}; font-family: ${FONT}; color-scheme: light dark; }
    ${themeCss()}
    /* Narrow (phone): keep 2-col touching; only stack on very narrow viewports */
    @media screen and (max-width: 600px) {
      .email-container { width: 100% !important; max-width: 100% !important; padding: 12px !important; }
      .cards-row { width: 100% !important; table-layout: fixed !important; }
      .col-stack {
        display: table-cell !important;
        width: 49% !important;
        max-width: 49% !important;
        box-sizing: border-box !important;
      }
      .col-gap {
        display: table-cell !important;
        width: 2px !important;
        max-width: 2px !important;
        height: auto !important;
        font-size: 1px !important;
        line-height: 1px !important;
        padding: 0 !important;
      }
      .og-card { padding: 10px 8px !important; }
      .og-title-orange, .og-title-blue { font-size: 12px !important; letter-spacing: 0.2px !important; }
      .og-label { font-size: 12px !important; }
      .og-value { font-size: 14px !important; word-break: normal !important; overflow-wrap: break-word !important; }
    }
    @media screen and (max-width: 380px) {
      .col-stack { display: block !important; width: 100% !important; max-width: 100% !important; }
      .col-gap {
        display: block !important;
        width: 100% !important;
        max-width: 100% !important;
        height: 8px !important;
      }
      .og-card { padding: 12px 10px !important; }
    }
  </style>
</head>
<body class="og-page" style="margin: 0; padding: 30px 0; background-color: ${L_PAGE}; font-family: ${FONT};">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:${L_PAGE};">
    ${preview}
  </div>

  <table role="presentation" class="og-page" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: ${L_PAGE};">
    <tr>
      <td align="center">

        <table role="presentation" class="email-container og-shell" border="0" cellpadding="0" cellspacing="0" width="600" bgcolor="${L_SHELL}" style="background-color: ${L_SHELL}; border-radius: 16px; border: 1px solid ${L_SHELL_BORDER}; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.05);">

          <!-- HEADER LOGOS -->
          <tr>
            <td align="center" style="padding-bottom: 24px;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" valign="middle">
                    <img class="logo-swift" src="${esc(swiftLogoUrl)}" alt="Swift Supply" width="150"
                      style="${logoStyle}">
                  </td>
                  <td align="center" valign="middle" class="og-plus" style="padding: 0 15px; font-size: 24px; font-weight: bold; color: ${L_PLUS};">
                    +
                  </td>
                  <td align="center" valign="middle">
                    <img class="logo-light" src="${esc(slstLight)}" alt="SLST Shipping Tracker" width="150"
                      style="${logoStyle}">
                    <img class="logo-dark" src="${esc(slstDark)}" alt="SLST Shipping Tracker" width="150"
                      style="${logoDarkStyle}">
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- MAIN HEADLINE -->
          <tr>
            <td align="center" style="padding-bottom: 20px;">
              <h1 class="og-headline" style="margin: 0 0 6px 0; font-size: 24px; font-weight: 800; color: ${L_HEADLINE}; letter-spacing: -0.3px; font-family: ${FONT};">
                ${title}
              </h1>
              <p class="og-subtitle" style="margin: 0; font-size: 15px; color: ${L_SUBTITLE}; font-weight: 500; font-family: ${FONT};">
                ${subtitle}
              </p>
            </td>
          </tr>

          ${grid}
          ${attachmentsSection(attachmentUrls)}
          ${ctaBlock}

          <!-- DIVIDER -->
          <tr>
            <td class="og-divider" style="border-top: 1px solid ${L_DIVIDER}; padding-bottom: 20px;"></td>
          </tr>

          <!-- FOOTER -->
          <tr>
            <td align="left" class="og-footer" style="font-size: 12px; color: ${L_FOOTER}; line-height: 1.5; font-family: ${FONT};">
              <strong class="og-thanks" style="color: ${L_FOOTER};">Swift notification via</strong><br>
              SLST — Staging Log &amp; Shipping Tracker
              <div class="og-disclaimer" style="margin-top: 14px; font-size: 10px; line-height: 1.45; color: ${L_DISCLAIMER};">
                SLST is an internal operations tool for Swift Nisku warehouse staff. It helps us record what is staged, what is ready to ship, and what has left the building—and to notify sales when orders depart. It is not a carrier tracking system, proof-of-delivery tool, or comprehensive order-tracking platform. Expectations beyond this operational purpose fall outside the scope of the application.
              </div>
              <div class="og-disclaimer" style="margin-top: 8px; font-size: 10px; line-height: 1.45; color: ${L_DISCLAIMER};">
                SLST is a pilot project designed and developed by Brice Johnson and is not an official Swift corporate product. It remains under active testing and development; occasional issues or incomplete behaviour may occur as the system is refined.
              </div>
            </td>
          </tr>

        </table>

      </td>
    </tr>
  </table>

</body>
</html>`;
}

// Back-compat exports
export { ASSET_VERSION, ORANGE, BLUE, L_CARD };
export const darkModeCss = themeCss;
export const PAGE_BG = L_PAGE;
export const CARD_SHELL = L_SHELL;
export const INK = L_HEADLINE;
export const BODY = L_SUBTITLE;
export const MUTED = L_FOOTER;
export const BORDER = L_SHELL_BORDER;
export const WHITE = "#ffffff";
export function surfaceBg(color: string): string {
  return `background-color:${color};`;
}
export function detailCard(opts: {
  iconUrl: string;
  title: string;
  accent: "orange" | "blue";
  rows: Array<{ label: string; value: string }>;
}): string {
  return infoCard({
    accent: opts.accent,
    title: opts.title,
    fields: opts.rows,
  });
}
export function headerLogosBlock(
  _swift: string,
  _light: string,
  _dark: string,
): string {
  return "";
}


// --- ship-confirmation.ts ---
/**
 * SLST ship-confirmation HTML email — concept-matched layout.
 */
export type ShipConfirmationData = {
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

export { DEFAULT_EMAIL_ASSET_BASE, emailAssetUrl };

export function renderShipConfirmationEmail(
  data: ShipConfirmationData,
  attachmentUrls: string[] = [],
): string {
  const assetBase = data.assetBaseUrl ?? DEFAULT_EMAIL_ASSET_BASE;
  const so = esc(data.so);
  const customer = displayOrNone(data.customer);
  const carrier = displayOrNone(data.carrier);
  const shippedAt = displayOrNone(data.shippedAt);
  const shippedBy = displayOrNone(data.shippedBy);
  const containers = displayOrNone(data.containers);
  const weight = displayOrNone(data.weight);
  const comments = displayOrNone(data.comments);
  return renderBrandedEmail({
    assetBaseUrl: assetBase,
    logoUrl: data.logoUrl,
    title: "Your order has now been shipped!",
    preview: `SO# ${so} for ${customer} has shipped via ${carrier}.`,
    subtitle: "Order details:",
    attachmentUrls,
    ctaUrl: data.ctaUrl,
    emailContact: data.emailContact,
    websiteUrl: data.websiteUrl,
    year: data.year,
    cards: [
      {
        iconKey: "icon-clipboard",
        title: "ORDER SUMMARY",
        accent: "orange",
        rows: [
          { label: "SO#", value: so || "None" },
          { label: "Customer", value: customer },
        ],
      },
      {
        iconKey: "icon-truck",
        title: "SHIPPING INFORMATION",
        accent: "blue",
        rows: [
          { label: "Carrier", value: carrier },
          { label: "Shipped At", value: shippedAt },
          { label: "Shipped By", value: shippedBy },
        ],
      },
      {
        iconKey: "icon-cargo",
        title: "CARGO DETAILS",
        accent: "orange",
        rows: [
          { label: "Container(s)", value: containers },
          { label: "Total Weight (In lbs)", value: weight },
        ],
      },
      {
        iconKey: "icon-chat",
        title: "ADDITIONAL NOTES",
        accent: "blue",
        rows: [{ label: "Comments", value: comments }],
      },
    ],
  });
}

export function renderShipConfirmationPlain(data: ShipConfirmationData): string {
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

export function isShipConfirmationType(
  notificationType: string | undefined | null,
): boolean {
  const t = String(notificationType ?? "").trim().toLowerCase();
  return t === "ship_confirm" || t === "quick_ship";
}

export function shipDataFromPayload(
  body: Record<string, unknown>,
): ShipConfirmationData {
  const pick = (...keys: string[]): string => {
    for (const k of keys) {
      const v = body[k];
      if (v != null && String(v).trim()) return String(v).trim();
    }
    return "";
  };
  const assetBase = pick("asset_base_url", "assetBaseUrl") ||
    DEFAULT_EMAIL_ASSET_BASE;
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
    // Optional payload logo override; branded layout always uses light SLST logo.
    logoUrl: logoFromPayload || undefined,
    ctaUrl: pick("cta_url", "ctaUrl", "tracking_url", "trackingUrl") ||
      undefined,
    emailContact: pick("email_contact", "emailContact") || undefined,
    websiteUrl: pick("website_url", "websiteUrl") || undefined,
    assetBaseUrl: assetBase,
  };
}


// --- notification-email.ts ---
/**
 * Branded HTML for non-ship PM notifications (return, PO, etc.).
 */

function pick(body: Record<string, unknown>, ...keys: string[]): string {
  for (const k of keys) {
    const v = body[k];
    if (v != null && String(v).trim()) return String(v).trim();
  }
  return "";
}

function baseFromBody(
  body: Record<string, unknown>,
  attachmentUrls: string[],
) {
  const assetBase = pick(body, "asset_base_url", "assetBaseUrl") ||
    DEFAULT_EMAIL_ASSET_BASE;
  return {
    assetBaseUrl: assetBase,
    attachmentUrls,
  };
}

export function renderReturnNotificationEmail(
  body: Record<string, unknown>,
  attachmentUrls: string[] = [],
): string {
  const so = displayOrNone(pick(body, "so", "so_number"));
  const customer = displayOrNone(pick(body, "customer"));
  const details = displayOrNone(pick(body, "details", "comments", "notes"));
  return renderBrandedEmail({
    ...baseFromBody(body, attachmentUrls),
    title: "Return notification",
    preview: `Return notification for SO ${so}`,
    subtitle: "Return details:",
    cards: [
      {
        iconKey: "icon-clipboard",
        title: "RETURN DETAILS",
        accent: "orange",
        rows: [
          { label: "SO#", value: so },
          { label: "Customer", value: customer },
        ],
      },
      {
        iconKey: "icon-chat",
        title: "NOTES",
        accent: "blue",
        rows: [{ label: "Details", value: details }],
      },
    ],
  });
}

export function renderReturnToStockEmail(
  body: Record<string, unknown>,
  attachmentUrls: string[] = [],
): string {
  const so = displayOrNone(pick(body, "so", "so_number"));
  const customer = displayOrNone(pick(body, "customer"));
  const reason = displayOrNone(pick(body, "reason"));
  const pickedBy = displayOrNone(pick(body, "picked_by", "pickedBy"));
  const returnedBy = displayOrNone(pick(body, "returned_by", "returnedBy"));
  return renderBrandedEmail({
    ...baseFromBody(body, attachmentUrls),
    title: "Returned to stock",
    preview: `SO ${so} returned to stock`,
    subtitle: "Stock return details:",
    cards: [
      {
        iconKey: "icon-truck",
        title: "RETURN TO STOCK",
        accent: "orange",
        rows: [
          { label: "SO#", value: so },
          { label: "Customer", value: customer },
          { label: "Picked By", value: pickedBy },
          { label: "Returned By", value: returnedBy },
        ],
      },
      {
        iconKey: "icon-chat",
        title: "REASON",
        accent: "blue",
        rows: [{ label: "Reason", value: reason }],
      },
    ],
  });
}

export function renderPoNotificationEmail(
  body: Record<string, unknown>,
  attachmentUrls: string[] = [],
): string {
  const po = displayOrNone(pick(body, "po", "po_number"));
  const vendor = displayOrNone(pick(body, "vendor", "customer"));
  const so = displayOrNone(pick(body, "so", "so_number", "linked_so", "linkedSo"));
  const details = displayOrNone(pick(body, "details", "comments", "notes"));
  const rows: Array<{ label: string; value: string }> = [
    { label: "PO#", value: po },
    { label: "Vendor", value: vendor },
  ];
  if (so !== "None") rows.push({ label: "Linked SO#", value: so });
  return renderBrandedEmail({
    ...baseFromBody(body, attachmentUrls),
    title: "PO notification",
    preview: `PO notification: ${po}`,
    subtitle: "Order details:",
    cards: [
      {
        iconKey: "icon-clipboard",
        title: "PO NOTIFICATION",
        accent: "orange",
        rows,
      },
      {
        iconKey: "icon-chat",
        title: "DETAILS",
        accent: "blue",
        rows: [{ label: "Notes", value: details }],
      },
    ],
  });
}

export function renderBulkPoNotificationEmail(
  body: Record<string, unknown>,
  attachmentUrls: string[] = [],
): string {
  const raw = body.pos;
  const list = Array.isArray(raw) ? raw : [];
  const cards = list.slice(0, 12).map((item, i) => {
    const row = (item && typeof item === "object")
      ? item as Record<string, unknown>
      : {};
    const po = displayOrNone(pick(row, "po", "po_number"));
    const vendor = displayOrNone(pick(row, "vendor", "customer"));
    const containers = displayOrNone(pick(row, "containers", "type"));
    const details = displayOrNone(pick(row, "details", "comments", "notes"));
    return {
      iconKey: i % 2 === 0 ? "icon-clipboard" : "icon-cargo",
      title: `PO ${po}`,
      accent: (i % 2 === 0 ? "orange" : "blue") as "orange" | "blue",
      rows: [
        { label: "PO#", value: po },
        { label: "Vendor", value: vendor },
        { label: "Container(s)", value: containers },
        { label: "Notes", value: details },
      ],
    };
  });
  if (!cards.length) {
    cards.push({
      iconKey: "icon-clipboard",
      title: "BULK PO",
      accent: "orange",
      rows: [{ label: "POs", value: "None" }],
    });
  }
  return renderBrandedEmail({
    ...baseFromBody(body, attachmentUrls),
    title: "Bulk PO notification",
    preview: `Bulk PO notification (${list.length} POs)`,
    subtitle: "Order details:",
    cards,
  });
}

export function renderNotificationEmail(
  notificationType: string,
  body: Record<string, unknown>,
  attachmentUrls: string[] = [],
): string | null {
  const t = notificationType.trim().toLowerCase();
  switch (t) {
    case "return_notification":
      return renderReturnNotificationEmail(body, attachmentUrls);
    case "return_to_stock":
      return renderReturnToStockEmail(body, attachmentUrls);
    case "po_notification":
      return renderPoNotificationEmail(body, attachmentUrls);
    case "bulk_po_notification":
      return renderBulkPoNotificationEmail(body, attachmentUrls);
    default:
      return null;
  }
}


// --- index.ts ---
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
    if (!to) {
      return new Response(JSON.stringify({ error: "Missing to" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
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