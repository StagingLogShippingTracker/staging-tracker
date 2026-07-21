/**
 * SLST ship-confirmation HTML email.
 * Brand colours from lib/core/theme.dart (SlstColors).
 * Table-based + inline CSS for Outlook / Gmail / Apple Mail.
 *
 * Dynamic fields: so, customer, carrier, shippedAt, shippedBy,
 * containers, weight, comments, logoUrl, ctaUrl, emailContact, websiteUrl, year.
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
};

const BRAND = "#D93223";
const BRAND_DARK = "#B92820";
const INK = "#1E293B";
const SUBTLE = "#94A3B8";
const BORDER = "#E2E8F0";
const SURFACE_SUBTLE = "#F3F5F8";
const CARD_BG = "#FAFBFC";
const WHITE = "#FFFFFF";

/** Subtle gear + chevron watermark (data URI — clients that support bg-image). */
const GEAR_WATERMARK =
  "url(\"data:image/svg+xml," +
  encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" width="180" height="180" viewBox="0 0 180 180">` +
      `<g fill="none" stroke="#CBD5E1" stroke-width="1.2" opacity="0.45">` +
      `<circle cx="40" cy="40" r="14"/><circle cx="40" cy="40" r="6"/>` +
      `<path d="M40 22v4M40 54v4M22 40h4M54 40h4M27 27l3 3M50 50l3 3M53 27l-3 3M27 53l3-3"/>` +
      `<circle cx="140" cy="55" r="18"/><circle cx="140" cy="55" r="7"/>` +
      `<path d="M140 32v5M140 73v5M117 55h5M158 55h5"/>` +
      `<path d="M30 120l10-6 10 6v10l-10 6-10-6z"/><path d="M40 114v22"/>` +
      `<path d="M110 130l12-8 12 8-4 14h-16z"/>` +
      `<path d="M70 160l8-5 8 5-3 9H73z"/>` +
      `</g></svg>`,
  ) +
  '")';

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

/** Tiny brand-red SVG icons as data URIs (email-safe img). */
function iconDataUri(kind: "clipboard" | "truck" | "cargo" | "chat" | "search" | "mail" | "globe"): string {
  const svgs: Record<string, string> = {
    clipboard:
      `<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 28 28" fill="none">` +
      `<rect x="7" y="5" width="14" height="18" rx="2" stroke="${BRAND}" stroke-width="1.8"/>` +
      `<rect x="10" y="3" width="8" height="4" rx="1" fill="${BRAND}"/>` +
      `<path d="M10 12h8M10 16h8M10 20h5" stroke="${BRAND}" stroke-width="1.6" stroke-linecap="round"/>` +
      `</svg>`,
    truck:
      `<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 28 28" fill="none">` +
      `<path d="M3 16V9a2 2 0 0 1 2-2h10v11H5a2 2 0 0 1-2-2z" stroke="${BRAND}" stroke-width="1.8"/>` +
      `<path d="M15 11h5l3 4v4h-8V11z" stroke="${BRAND}" stroke-width="1.8" stroke-linejoin="round"/>` +
      `<circle cx="8" cy="20" r="2.2" stroke="${BRAND}" stroke-width="1.6"/>` +
      `<circle cx="20" cy="20" r="2.2" stroke="${BRAND}" stroke-width="1.6"/>` +
      `</svg>`,
    cargo:
      `<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 28 28" fill="none">` +
      `<path d="M5 12l9-5 9 5v9l-9 5-9-5v-9z" stroke="${BRAND}" stroke-width="1.8" stroke-linejoin="round"/>` +
      `<path d="M5 12l9 5 9-5M14 17v9" stroke="${BRAND}" stroke-width="1.6"/>` +
      `</svg>`,
    chat:
      `<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 28 28" fill="none">` +
      `<path d="M6 7h16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H12l-5 4v-4H6a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2z" stroke="${BRAND}" stroke-width="1.8" stroke-linejoin="round"/>` +
      `<path d="M9 12h10M9 16h6" stroke="${BRAND}" stroke-width="1.6" stroke-linecap="round"/>` +
      `</svg>`,
    search:
      `<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18" fill="none">` +
      `<circle cx="8" cy="8" r="5.5" stroke="#fff" stroke-width="1.8"/>` +
      `<path d="M12.5 12.5L16 16" stroke="#fff" stroke-width="1.8" stroke-linecap="round"/>` +
      `</svg>`,
    mail:
      `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">` +
      `<rect x="1.5" y="3" width="13" height="10" rx="1.5" stroke="${BRAND_DARK}" stroke-width="1.4"/>` +
      `<path d="M2 4l6 5 6-5" stroke="${BRAND_DARK}" stroke-width="1.4" stroke-linejoin="round"/>` +
      `</svg>`,
    globe:
      `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">` +
      `<circle cx="8" cy="8" r="6" stroke="${BRAND_DARK}" stroke-width="1.4"/>` +
      `<path d="M2 8h12M8 2c2 2.2 2 9.8 0 12M8 2c-2 2.2-2 9.8 0 12" stroke="${BRAND_DARK}" stroke-width="1.2"/>` +
      `</svg>`,
  };
  return `data:image/svg+xml,${encodeURIComponent(svgs[kind])}`;
}

function detailCard(opts: {
  iconKind: "clipboard" | "truck" | "cargo" | "chat";
  title: string;
  rows: Array<{ label: string; value: string }>;
}): string {
  const rowsHtml = opts.rows
    .map(
      (r) =>
        `<tr>
          <td style="padding:3px 0;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.5;color:${INK};">
            <strong style="font-weight:700;">${esc(r.label)}</strong>&nbsp;${r.value}
          </td>
        </tr>`,
    )
    .join("");

  return `
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:${WHITE};border:1px solid ${BORDER};border-radius:12px;box-shadow:0 2px 10px rgba(15,23,42,0.05);">
      <tr>
        <td style="padding:18px 16px;">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
            <tr>
              <td width="40" valign="top" style="padding-right:12px;">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="36" height="36" style="width:36px;height:36px;background-color:#FFF5F4;border-radius:8px;">
                  <tr>
                    <td align="center" valign="middle" style="width:36px;height:36px;text-align:center;vertical-align:middle;">
                      <img src="${iconDataUri(opts.iconKind)}" width="22" height="22" alt="" style="display:block;margin:0 auto;border:0;outline:none;" />
                    </td>
                  </tr>
                </table>
              </td>
              <td valign="top">
                <div style="font-family:Arial,Helvetica,sans-serif;font-size:11px;font-weight:700;letter-spacing:0.1em;color:${BRAND};padding-bottom:8px;text-transform:uppercase;">${esc(opts.title)}</div>
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
                  ${rowsHtml}
                </table>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>`;
}

function logoBlock(logoUrl?: string): string {
  if (logoUrl && logoUrl.trim()) {
    return `<img src="${esc(logoUrl.trim())}" width="220" alt="SLST — Staging Log &amp; Shipping Tracker" style="display:block;margin:0 auto;border:0;max-width:220px;height:auto;" />`;
  }
  // Email-safe wordmark: industrial SLST with brand underline on first S.
  return `
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:0 auto;">
      <tr>
        <td align="center" style="font-family:Arial Black,Arial,Helvetica,sans-serif;font-size:42px;line-height:1;letter-spacing:0.06em;color:${INK};font-weight:900;">
          <span style="border-bottom:4px solid ${BRAND};padding-bottom:2px;">S</span>LST
        </td>
      </tr>
    </table>`;
}

/**
 * Renders a full HTML document suitable for Make → Email (HTML body).
 */
export function renderShipConfirmationEmail(data: ShipConfirmationData): string {
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

  const orderCard = detailCard({
    iconKind: "clipboard",
    title: "ORDER SUMMARY",
    rows: [
      { label: "SO#", value: so || "None" },
      { label: "Customer", value: customer },
    ],
  });

  const shippingCard = detailCard({
    iconKind: "truck",
    title: "SHIPPING INFORMATION",
    rows: [
      { label: "Carrier", value: carrier },
      { label: "Shipped At", value: shippedAt },
      { label: "Shipped By", value: shippedBy },
    ],
  });

  const cargoCard = detailCard({
    iconKind: "cargo",
    title: "CARGO DETAILS",
    rows: [
      { label: "Container(s)", value: containers },
      { label: "Total Weight (In lbs)", value: weight },
    ],
  });

  const notesCard = detailCard({
    iconKind: "chat",
    title: "ADDITIONAL NOTES",
    rows: [{ label: "Comments", value: comments }],
  });

  const searchIcon = iconDataUri("search");
  const mailIcon = iconDataUri("mail");
  const globeIcon = iconDataUri("globe");

  return `<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <title>Your order has now been shipped!</title>
  <!--[if mso]>
  <noscript>
    <xml>
      <o:OfficeDocumentSettings>
        <o:PixelsPerInch>96</o:PixelsPerInch>
      </o:OfficeDocumentSettings>
    </xml>
  </noscript>
  <style>
    table { border-collapse: collapse; }
    td { font-family: Arial, Helvetica, sans-serif; }
  </style>
  <![endif]-->
  <style type="text/css">
    body, table, td, a { -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
    table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
    img { -ms-interpolation-mode: bicubic; border: 0; outline: none; text-decoration: none; }
    body { margin: 0 !important; padding: 0 !important; width: 100% !important; }
    a { color: ${BRAND_DARK}; }
    @media only screen and (max-width: 620px) {
      .email-card { width: 100% !important; }
      .stack-col { display: block !important; width: 100% !important; max-width: 100% !important; box-sizing: border-box !important; }
      .footer-right { text-align: left !important; padding-top: 14px !important; }
    }
  </style>
</head>
<body style="margin:0;padding:0;background-color:${SURFACE_SUBTLE};">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:${SURFACE_SUBTLE};">
    SO# ${so} for ${customer} has shipped via ${carrier}.
  </div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:${SURFACE_SUBTLE};">
    <tr>
      <td align="center" style="padding:28px 12px;">
        <!--[if mso]>
        <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0"><tr><td>
        <![endif]-->
        <table role="presentation" class="email-card" width="600" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:600px;background-color:${CARD_BG};border-radius:16px;border:1px solid ${BORDER};box-shadow:0 12px 40px rgba(15,23,42,0.08);overflow:hidden;">
          <!-- Header / brand + watermark -->
          <tr>
            <td align="center" style="padding:36px 28px 8px 28px;background-color:${CARD_BG};background-image:${GEAR_WATERMARK};background-repeat:repeat;background-size:180px 180px;">
              ${logoBlock(data.logoUrl)}
              <div style="font-family:Arial,Helvetica,sans-serif;font-size:11px;font-weight:700;letter-spacing:0.16em;color:${INK};padding-top:12px;text-transform:uppercase;">
                STAGING LOG &amp; SHIPPING TRACKER
              </div>
            </td>
          </tr>

          <!-- Headline -->
          <tr>
            <td align="center" style="padding:22px 28px 6px 28px;background-color:${CARD_BG};background-image:${GEAR_WATERMARK};background-repeat:repeat;background-size:180px 180px;">
              <h1 style="margin:0;font-family:Arial,Helvetica,sans-serif;font-size:26px;line-height:1.3;font-weight:700;color:${INK};">
                Your order has now been shipped!
              </h1>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:0 28px 20px 28px;background-color:${CARD_BG};background-image:${GEAR_WATERMARK};background-repeat:repeat;background-size:180px 180px;">
              <p style="margin:0;font-family:Arial,Helvetica,sans-serif;font-size:15px;color:${INK};">
                Order details:
              </p>
            </td>
          </tr>

          <!-- 2x2 detail cards -->
          <tr>
            <td style="padding:0 18px 8px 18px;background-color:${CARD_BG};background-image:${GEAR_WATERMARK};background-repeat:repeat;background-size:180px 180px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td class="stack-col" width="50%" valign="top" style="width:50%;padding:6px;">
                    ${orderCard}
                  </td>
                  <td class="stack-col" width="50%" valign="top" style="width:50%;padding:6px;">
                    ${shippingCard}
                  </td>
                </tr>
                <tr>
                  <td class="stack-col" width="50%" valign="top" style="width:50%;padding:6px;">
                    ${cargoCard}
                  </td>
                  <td class="stack-col" width="50%" valign="top" style="width:50%;padding:6px;">
                    ${notesCard}
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- CTA -->
          <tr>
            <td align="center" style="padding:20px 28px 28px 28px;background-color:${CARD_BG};background-image:${GEAR_WATERMARK};background-repeat:repeat;background-size:180px 180px;">
              <!--[if mso]>
              <v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word" href="${esc(ctaUrl)}" style="height:48px;v-text-anchor:middle;width:320px;" arcsize="50%" stroke="f" fillcolor="${BRAND}">
                <w:anchorlock/>
                <center style="color:#ffffff;font-family:Arial,Helvetica,sans-serif;font-size:13px;font-weight:700;">VIEW FULL TRACKING DETAILS</center>
              </v:roundrect>
              <![endif]-->
              <!--[if !mso]><!-- -->
              <a href="${esc(ctaUrl)}" style="display:inline-block;background:linear-gradient(90deg, ${BRAND} 0%, ${BRAND_DARK} 100%);background-color:${BRAND};color:${WHITE};font-family:Arial,Helvetica,sans-serif;font-size:13px;font-weight:700;letter-spacing:0.07em;text-decoration:none;padding:15px 30px;border-radius:999px;box-shadow:0 6px 18px rgba(217,50,35,0.35);mso-hide:all;">
                <img src="${searchIcon}" width="16" height="16" alt="" style="display:inline-block;vertical-align:middle;margin-right:8px;border:0;" />
                <span style="vertical-align:middle;">VIEW FULL TRACKING DETAILS</span>
              </a>
              <!--<![endif]-->
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:0 28px;background-color:${CARD_BG};">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="border-top:1px solid ${BORDER};font-size:0;line-height:0;">&nbsp;</td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:20px 28px 28px 28px;background-color:${CARD_BG};">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td class="stack-col" valign="top" style="font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.55;color:${INK};">
                    <strong style="font-weight:700;">Thank you for using SLST!</strong><br />
                    SLST - Staging Log &amp; Shipping Tracker<br />
                    <span style="font-size:12px;color:${SUBTLE};">Copyright © ${year} SLST. All rights reserved.</span>
                  </td>
                  <td class="stack-col footer-right" valign="top" align="right" style="font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.9;white-space:nowrap;">
                    <a href="${esc(mailto)}" style="color:${BRAND_DARK};text-decoration:underline;">
                      <img src="${mailIcon}" width="14" height="14" alt="" style="display:inline-block;vertical-align:middle;margin-right:4px;border:0;" />
                      <span style="vertical-align:middle;">Email</span>
                    </a>
                    &nbsp;&nbsp;&nbsp;
                    <a href="${esc(websiteUrl)}" style="color:${BRAND_DARK};text-decoration:underline;">
                      <img src="${globeIcon}" width="14" height="14" alt="" style="display:inline-block;vertical-align:middle;margin-right:4px;border:0;" />
                      <span style="vertical-align:middle;">Website</span>
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
        <div style="font-family:Arial,Helvetica,sans-serif;font-size:11px;color:${SUBTLE};padding-top:16px;">
          Sent via SLST · Swift Supply
        </div>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

/** Lightweight plain-text fallback for SMS / non-HTML paths. */
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

/** True when this notification should use the ship-confirmation HTML shell. */
export function isShipConfirmationType(notificationType: string | undefined | null): boolean {
  const t = String(notificationType ?? "").trim().toLowerCase();
  return t === "ship_confirm" || t === "quick_ship";
}

/** Map a notify-pm / Make webhook JSON body into template data. */
export function shipDataFromPayload(body: Record<string, unknown>): ShipConfirmationData {
  const pick = (...keys: string[]): string => {
    for (const k of keys) {
      const v = body[k];
      if (v != null && String(v).trim()) return String(v).trim();
    }
    return "";
  };

  return {
    so: pick("so", "so_number"),
    customer: pick("customer"),
    carrier: pick("carrier"),
    shippedAt: pick("shipped_at", "shippedAt"),
    shippedBy: pick("shipped_by", "shippedBy"),
    containers: pick("containers", "type", "container"),
    weight: pick("weight"),
    comments: pick("comments"),
    logoUrl: pick("logo_url", "logoUrl") || undefined,
    ctaUrl: pick("cta_url", "ctaUrl", "tracking_url", "trackingUrl") || undefined,
    emailContact: pick("email_contact", "emailContact") || undefined,
    websiteUrl: pick("website_url", "websiteUrl") || undefined,
  };
}
