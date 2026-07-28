/**
 * SST Industrial Command Center email layout — dark-first.
 * Tokens mirror lib/core/theme.dart IndustrialTheme.
 */

export const DEFAULT_EMAIL_ASSET_BASE =
  "https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/email-assets";

export const ASSET_VERSION = "20260728sst";

const FONT =
  "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";
const MONO =
  "'JetBrains Mono', Consolas, 'Courier New', monospace";

/** IndustrialTheme-aligned tokens (dark operations). */
const PAGE = "#090D16";
const SHELL = "#1F2937";
const HEADER = "#111827";
const CARD = "#111827";
const BORDER = "#374151";
const TEXT = "#F9FAFB";
const MUTED = "#9CA3AF";
const MINT = "#10B981";
const SKY = "#3B82F6";
const AMBER = "#F59E0B";
const PURPLE = "#8B5CF6";
const DANGER = "#EF4444";

export type AccentTone = "mint" | "sky" | "amber" | "purple" | "orange" | "blue";

const ACCENT: Record<"mint" | "sky" | "amber" | "purple", string> = {
  mint: MINT,
  sky: SKY,
  amber: AMBER,
  purple: PURPLE,
};

function resolveAccent(tone: AccentTone | undefined, fallback: "mint" | "sky"): string {
  // Legacy orange/blue map onto industrial amber/sky.
  if (tone === "orange") return AMBER;
  if (tone === "blue") return SKY;
  if (tone === "mint" || tone === "sky" || tone === "amber" || tone === "purple") {
    return ACCENT[tone];
  }
  return ACCENT[fallback];
}

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
      const valuePad = isLast ? "" : " padding-bottom: 10px;";
      const monoValue =
        /^(SO#|PO#|Linked SO#)$/i.test(r.label.trim());
      return `
                      <tr>
                        <td class="og-label" style="font-size: 10px; font-weight: 700; letter-spacing: 0.85px; text-transform: uppercase; color: ${MUTED}; padding-bottom: 3px; word-break: normal; overflow-wrap: break-word;">${esc(r.label)}</td>
                      </tr>
                      <tr>
                        <td class="og-value" style="font-size: 14px; font-weight: 600; color: ${TEXT}; font-family: ${monoValue ? MONO : FONT}; word-break: normal; overflow-wrap: break-word;${valuePad}">${r.value}</td>
                      </tr>`;
    })
    .join("");
}

/** Info card: dark surface, left accent bar (industrial status language). */
export function infoCard(opts: {
  accent: AccentTone;
  title: string;
  icon?: string;
  iconKey?: string;
  fields: Array<{ label: string; value: string }>;
}): string {
  const accent = resolveAccent(opts.accent, "sky");
  const emoji =
    opts.icon ??
    (opts.iconKey ? ICON_EMOJI[opts.iconKey] : undefined) ??
    "📋";
  return `
                  <td class="col-stack og-card" valign="top" width="49%" style="width: 49%; background-color: ${CARD}; border-radius: 8px; border: 1px solid ${BORDER}; border-left: 3px solid ${accent}; padding: 14px 14px 12px 14px; word-break: normal; overflow-wrap: break-word;">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td class="og-title" style="font-size: 11px; font-weight: 800; color: ${accent}; text-transform: uppercase; letter-spacing: 0.7px; padding-bottom: 12px; word-break: normal; overflow-wrap: break-word;">
                          <span style="margin-right: 4px;">${emoji}</span> ${esc(opts.title)}
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
    accent?: AccentTone;
    rows: Array<{ label: string; value: string }>;
  }>,
): string {
  const rendered = cards.map((card, i) => {
    const accent = card.accent ?? (i % 2 === 0 ? "amber" : "sky");
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
    const bottomPad = isLastRow ? "24px" : "12px";
    const gap =
      `<td class="col-gap" width="10" style="width: 10px; max-width: 10px; font-size: 1px; line-height: 1px; padding: 0;">&nbsp;</td>`;
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
                        style="display: block; width: 100%; max-width: 520px; height: auto; border-radius: 8px; border: 1px solid ${BORDER};" />
                    </a>
                  </td>
                </tr>`).join("");
  return `
          <tr>
            <td style="padding-bottom: 20px;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" class="og-card"
                style="background-color: ${CARD}; border-radius: 8px; border: 1px solid ${BORDER}; border-left: 3px solid ${AMBER}; padding: 14px;">
                <tr>
                  <td class="og-title" style="font-size: 11px; font-weight: 800; color: ${AMBER}; text-transform: uppercase; letter-spacing: 0.7px; padding-bottom: 10px;">
                    <span style="margin-right: 4px;">📎</span> ATTACHMENTS
                  </td>
                </tr>
                <tr>
                  <td class="og-label" style="font-size: 10px; font-weight: 700; letter-spacing: 0.85px; text-transform: uppercase; color: ${MUTED}; padding-bottom: 3px;">Files</td>
                </tr>
                <tr>
                  <td class="og-value" style="font-size: 14px; font-weight: 600; color: ${TEXT};">
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

function brandHeader(swiftLogoUrl: string): string {
  return `
          <tr>
            <td style="padding-bottom: 22px;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: ${HEADER}; border: 1px solid ${BORDER}; border-radius: 8px;">
                <tr>
                  <td style="padding: 14px 16px;">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td align="left" valign="middle">
                          <img class="logo-swift" src="${esc(swiftLogoUrl)}" alt="Swift Supply" width="120"
                            style="display: block; max-width: 120px; height: auto; border: 0;">
                        </td>
                        <td align="right" valign="middle">
                          <span class="sst-badge" style="display: inline-block; padding: 7px 12px; border-radius: 6px; border: 1px solid ${SKY}; background-color: rgba(59,130,246,0.12); color: ${SKY}; font-size: 12px; font-weight: 800; letter-spacing: 1.2px; font-family: ${FONT};">SST</span>
                        </td>
                      </tr>
                      <tr>
                        <td colspan="2" style="padding-top: 10px;">
                          <div style="font-size: 10px; font-weight: 700; letter-spacing: 0.9px; text-transform: uppercase; color: ${MUTED}; font-family: ${FONT};">
                            Swift Staging Tracker · Industrial ops
                          </div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>`;
}

export type BrandedEmailOptions = {
  title: string;
  preview: string;
  subtitle?: string;
  cards: Array<{
    iconKey?: string;
    icon?: string;
    title: string;
    accent?: AccentTone;
    rows: Array<{ label: string; value: string }>;
  }>;
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
  const swiftLogoUrl = emailAssetUrl("swift-supply-logo-email", assetBase);
  const title = esc(opts.title);
  const subtitle = esc(opts.subtitle ?? "Order details:");
  const preview = esc(opts.preview);
  const attachmentUrls = opts.attachmentUrls ?? [];
  const ctaUrl =
    (opts.ctaUrl ?? "").trim() ||
    (opts.websiteUrl ?? "").trim() ||
    "https://www.swiftsupply.ca";
  const ctaLabel = esc(opts.ctaLabel ?? "OPEN SWIFT SUPPLY");
  const grid = opts.cardsGridHtml ?? cardsGridHtml(opts.cards);
  const year = opts.year ?? new Date().getFullYear();

  const ctaBlock = `
          <tr>
            <td align="center" style="padding-bottom: 26px;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" class="og-cta" style="border-radius: 8px; background-color: ${SKY}; padding: 13px 26px;">
                    <a href="${esc(ctaUrl)}" target="_blank" style="font-size: 12px; font-weight: 800; color: ${TEXT}; text-decoration: none; display: inline-block; letter-spacing: 0.7px; text-transform: uppercase; font-family: ${FONT};">
                      ${ctaLabel}
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>`;

  return `<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="color-scheme" content="dark">
  <meta name="supported-color-schemes" content="dark">
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
  </style>
  <![endif]-->
  <style>
    body, table, td, a { text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
    table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
    img { -ms-interpolation-mode: bicubic; border: 0; height: auto; line-height: 100%; outline: none; text-decoration: none; }
    body {
      height: 100% !important; margin: 0 !important; padding: 0 !important; width: 100% !important;
      background-color: ${PAGE}; font-family: ${FONT}; color-scheme: dark;
    }
    @media screen and (max-width: 600px) {
      .email-container { width: 100% !important; max-width: 100% !important; padding: 14px !important; }
      .cards-row { width: 100% !important; table-layout: fixed !important; }
      .col-stack {
        display: table-cell !important;
        width: 49% !important;
        max-width: 49% !important;
        box-sizing: border-box !important;
      }
      .col-gap {
        display: table-cell !important;
        width: 8px !important;
        max-width: 8px !important;
        font-size: 1px !important;
        line-height: 1px !important;
        padding: 0 !important;
      }
      .og-card { padding: 12px 10px !important; }
    }
    @media screen and (max-width: 380px) {
      .col-stack { display: block !important; width: 100% !important; max-width: 100% !important; }
      .col-gap {
        display: block !important;
        width: 100% !important;
        max-width: 100% !important;
        height: 10px !important;
      }
    }
  </style>
</head>
<body class="og-page" style="margin: 0; padding: 28px 0; background-color: ${PAGE}; font-family: ${FONT};">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:${PAGE};">
    ${preview}
  </div>

  <table role="presentation" class="og-page" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: ${PAGE};">
    <tr>
      <td align="center">

        <table role="presentation" class="email-container og-shell" border="0" cellpadding="0" cellspacing="0" width="600" bgcolor="${SHELL}" style="background-color: ${SHELL}; border-radius: 10px; border: 1px solid ${BORDER}; padding: 22px 22px 18px;">

          ${brandHeader(swiftLogoUrl)}

          <!-- LIVE STRIPE -->
          <tr>
            <td style="padding-bottom: 18px;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td style="height: 3px; line-height: 3px; font-size: 0; background: linear-gradient(90deg, ${SKY} 0%, ${MINT} 55%, ${PURPLE} 100%); border-radius: 2px;">&nbsp;</td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- HEADLINE -->
          <tr>
            <td style="padding-bottom: 18px;">
              <h1 class="og-headline" style="margin: 0 0 6px 0; font-size: 22px; font-weight: 800; color: ${TEXT}; letter-spacing: -0.3px; font-family: ${FONT};">
                ${title}
              </h1>
              <p class="og-subtitle" style="margin: 0; font-size: 13px; color: ${MUTED}; font-weight: 500; font-family: ${FONT};">
                ${subtitle}
              </p>
            </td>
          </tr>

          ${grid}
          ${attachmentsSection(attachmentUrls)}
          ${ctaBlock}

          <!-- DIVIDER -->
          <tr>
            <td class="og-divider" style="border-top: 1px solid ${BORDER}; padding-bottom: 16px;"></td>
          </tr>

          <!-- FOOTER -->
          <tr>
            <td align="left" class="og-footer" style="font-size: 12px; color: ${MUTED}; line-height: 1.5; font-family: ${FONT};">
              <strong class="og-thanks" style="color: ${TEXT};">Swift notification via SST</strong><br>
              Swift Staging Tracker — industrial staging &amp; shipping ops
              <div class="og-disclaimer" style="margin-top: 12px; font-size: 10px; line-height: 1.45; color: ${MUTED};">
                SST is an internal operations tool for Swift Nisku warehouse staff. It records what is staged, ready to ship, and departed—and notifies sales when orders leave. It is not a carrier tracking system, proof-of-delivery tool, or comprehensive order-tracking platform.
              </div>
              <div class="og-disclaimer" style="margin-top: 8px; font-size: 10px; line-height: 1.45; color: ${MUTED};">
                SST is a pilot project designed and developed by Brice Johnson and is not an official Swift corporate product. © ${year}
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

// Back-compat exports (legacy names map to industrial tokens)
export const ORANGE = AMBER;
export const BLUE = SKY;
export const L_CARD = CARD;
export const darkModeCss = () => "";
export const PAGE_BG = PAGE;
export const CARD_SHELL = SHELL;
export const INK = TEXT;
export const BODY = MUTED;
export const MUTED_TOKEN = MUTED;
export const BORDER_TOKEN = BORDER;
export const WHITE = TEXT;
export function surfaceBg(color: string): string {
  return `background-color:${color};`;
}
export function detailCard(opts: {
  iconUrl: string;
  title: string;
  accent: AccentTone;
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

// Re-export accent constants for tests/preview tooling
export { PAGE, SHELL, HEADER, CARD, BORDER, TEXT, MUTED, MINT, SKY, AMBER, PURPLE, DANGER };
