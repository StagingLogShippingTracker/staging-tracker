/**
 * SLST Industrial Command Center email layout.
 * Mirrors lib/core/theme.dart IndustrialTheme + app shell chrome
 * (header bar, Live sync pill, surface cards, status badges, BrandFooter).
 */

export const DEFAULT_EMAIL_ASSET_BASE =
  "https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/email-assets";

export const ASSET_VERSION = "20260728sst-darkforce";

/** App BrandMark — same asset as Flutter `assets/slst-app-icon.png`. */
const SLST_MARK_URL =
  "https://raw.githubusercontent.com/StagingLogShippingTracker/staging-tracker/main/assets/slst-app-icon.png";

/** Match GoogleFonts.inter / JetBrains Mono from the Flutter app. */
const FONT =
  "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";
const MONO =
  "'JetBrains Mono', ui-monospace, Consolas, 'Courier New', monospace";

/** IndustrialTheme tokens — exact hex from lib/core/theme.dart */
const PAGE = "#090D16"; // darkBase scaffold
const SHELL = "#1F2937"; // darkSurface card/panel
const HEADER = "#111827"; // darkHeader header & sidebar
const CARD = "#1F2937"; // darkSurface
const INSET = "#111827"; // darkHeader field wells
const BORDER = "#374151"; // borderStroke
const TEXT = "#F9FAFB"; // textPrimary
const MUTED = "#9CA3AF"; // textMuted
const MINT = "#10B981";
const SKY = "#3B82F6";
const AMBER = "#F59E0B";
const PURPLE = "#8B5CF6";
const DANGER = "#EF4444";
const SLATE = "#4B5563";
const SURFACE_HIGH = "#273549";

export type AccentTone =
  | "mint"
  | "sky"
  | "amber"
  | "purple"
  | "orange"
  | "blue"
  | "danger"
  | "slate";

const ACCENT: Record<"mint" | "sky" | "amber" | "purple" | "danger" | "slate", string> = {
  mint: MINT,
  sky: SKY,
  amber: AMBER,
  purple: PURPLE,
  danger: DANGER,
  slate: SLATE,
};

function resolveAccent(
  tone: AccentTone | undefined,
  fallback: "mint" | "sky" = "sky",
): string {
  if (tone === "orange") return AMBER;
  if (tone === "blue") return SKY;
  if (
    tone === "mint" ||
    tone === "sky" ||
    tone === "amber" ||
    tone === "purple" ||
    tone === "danger" ||
    tone === "slate"
  ) {
    return ACCENT[tone];
  }
  return ACCENT[fallback];
}

/** Soft tint fills matching IndustrialStatusBadge (alpha ~0.18). */
function accentFill(accent: string): string {
  switch (accent) {
    case MINT:
      return "rgba(16,185,129,0.18)";
    case SKY:
      return "rgba(59,130,246,0.18)";
    case AMBER:
      return "rgba(245,158,11,0.18)";
    case PURPLE:
      return "rgba(139,92,246,0.18)";
    case DANGER:
      return "rgba(239,68,68,0.20)";
    default:
      return "rgba(75,85,99,0.28)";
  }
}

function accentBorder(accent: string): string {
  switch (accent) {
    case MINT:
      return "rgba(16,185,129,0.35)";
    case SKY:
      return "rgba(59,130,246,0.35)";
    case AMBER:
      return "rgba(245,158,11,0.35)";
    case PURPLE:
      return "rgba(139,92,246,0.35)";
    case DANGER:
      return "rgba(239,68,68,0.35)";
    default:
      return BORDER;
  }
}

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

function isMonoLabel(label: string): boolean {
  return /^(SO#|PO#|Linked SO#|Total Weight|Weight)$/i.test(label.trim());
}

function fieldRows(
  rows: Array<{ label: string; value: string }>,
): string {
  return rows
    .map((r, i) => {
      const isLast = i === rows.length - 1;
      const valuePad = isLast ? "" : " padding-bottom: 12px;";
      const monoValue = isMonoLabel(r.label);
      return `
                      <tr>
                        <td class="og-label" style="font-family: ${FONT}; font-size: 10px; font-weight: 700; letter-spacing: 0.85px; text-transform: uppercase; color: ${MUTED}; padding-bottom: 3px; word-break: normal; overflow-wrap: break-word;">${esc(r.label)}</td>
                      </tr>
                      <tr>
                        <td class="og-value" style="font-family: ${monoValue ? MONO : FONT}; font-size: ${monoValue ? "13px" : "13px"}; font-weight: ${monoValue ? "700" : "600"}; color: ${TEXT}; word-break: normal; overflow-wrap: break-word;${valuePad}">${r.value}</td>
                      </tr>`;
    })
    .join("");
}

/** Status pill — IndustrialStatusBadge language. */
export function statusBadge(label: string, tone: AccentTone = "mint"): string {
  const accent = resolveAccent(tone, "mint");
  const fill = accentFill(accent);
  const border = accentBorder(accent);
  return `<span class="og-status" style="display: inline-block; padding: 2px 7px; border-radius: 4px; background-color: ${fill}; border: 1px solid ${border}; font-family: ${FONT}; font-size: 10px; font-weight: 700; letter-spacing: 0.35px; text-transform: uppercase; color: ${accent}; line-height: 1.4;">${esc(label)}</span>`;
}

/** Live sync pill from app shell _TopHeader. */
function liveSyncPill(): string {
  return `
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" style="display: inline-table;">
                      <tr>
                        <td style="padding: 4px 10px; border-radius: 12px; background-color: rgba(16,185,129,0.16); border: 1px solid rgba(16,185,129,0.45);">
                          <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                            <tr>
                              <td valign="middle" style="padding-right: 6px;">
                                <div style="width: 7px; height: 7px; border-radius: 50%; background-color: ${MINT}; line-height: 7px; font-size: 7px;">&nbsp;</div>
                              </td>
                              <td valign="middle" style="font-family: ${FONT}; font-size: 11px; font-weight: 700; color: ${MINT}; white-space: nowrap;">
                                Live sync
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>`;
}

/**
 * App-shell brand strip: SLST logo mark + Live sync.
 * Optional Swift mark on the right for corporate context.
 */
function shellChrome(opts: {
  sectionTitle: string;
  swiftLogoUrl: string;
}): string {
  return `
          <!-- APP SHELL: brand + live (mirrors rail / drawer mark) -->
          <tr>
            <td style="background-color: ${HEADER}; border-bottom: 1px solid ${BORDER}; padding: 12px 16px;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td align="left" valign="middle" style="padding-right: 12px;">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                      <tr>
                        <td valign="middle" style="padding-right: 10px;">
                          <img src="${SLST_MARK_URL}?v=${ASSET_VERSION}" width="36" height="36" alt="SLST"
                            style="display: block; width: 36px; height: 36px; border-radius: 6px; border: 1px solid ${BORDER};">
                        </td>
                      </tr>
                    </table>
                  </td>
                  <td align="right" valign="middle">
                    ${liveSyncPill()}
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- APP SHELL: section header (mirrors _TopHeader) -->
          <tr>
            <td style="background-color: ${HEADER}; border-bottom: 1px solid ${BORDER}; padding: 14px 16px;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td align="left" valign="middle" style="font-family: ${FONT}; font-size: 15px; font-weight: 700; color: ${TEXT};">
                    ${esc(opts.sectionTitle)}
                  </td>
                  <td align="right" valign="middle" width="100">
                    <img class="logo-swift" src="${esc(opts.swiftLogoUrl)}" alt="Swift Supply" width="88"
                      style="display: block; max-width: 88px; height: auto; border: 0; opacity: 0.92;">
                  </td>
                </tr>
              </table>
            </td>
          </tr>`;
}

/** LogSummaryCard-style hero metric block. */
export function heroSummary(opts: {
  eyebrow: string;
  value: string;
  unit: string;
  stats?: Array<{ label: string; value: string; accent?: AccentTone }>;
}): string {
  const stats = opts.stats ?? [];
  const statsHtml = stats.length
    ? `
                <tr>
                  <td style="padding-top: 12px; border-top: 1px solid ${BORDER};">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        ${stats
                          .map((s, i) => {
                            const accent = resolveAccent(s.accent, "sky");
                            const pad = i === 0 ? "" : " padding-left: 12px;";
                            return `
                        <td valign="top" style="width: ${Math.floor(100 / stats.length)}%;${pad}">
                          <div style="font-family: ${FONT}; font-size: 10px; font-weight: 700; letter-spacing: 0.85px; text-transform: uppercase; color: ${MUTED}; padding-bottom: 4px;">${esc(s.label)}</div>
                          <div style="font-family: ${FONT}; font-size: 12.5px; font-weight: 600; color: ${accent};">${esc(s.value)}</div>
                        </td>`;
                          })
                          .join("")}
                      </tr>
                    </table>
                  </td>
                </tr>`
    : "";

  return `
          <tr>
            <td style="padding: 16px 16px 0 16px;">
              <table role="presentation" class="og-card" border="0" cellpadding="0" cellspacing="0" width="100%"
                style="background-color: ${SHELL}; border-radius: 6px; border: 1px solid ${BORDER};">
                <tr>
                  <td style="padding: 14px 16px;">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td style="font-family: ${FONT}; font-size: 10px; font-weight: 700; letter-spacing: 0.85px; text-transform: uppercase; color: ${MUTED}; padding-bottom: 8px;">
                          ${esc(opts.eyebrow)}
                        </td>
                      </tr>
                      <tr>
                        <td>
                          <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                            <tr>
                              <td valign="bottom" style="font-family: ${MONO}; font-size: 28px; font-weight: 800; color: ${TEXT}; line-height: 1; letter-spacing: -0.5px;">
                                ${esc(opts.value)}
                              </td>
                              <td valign="bottom" style="padding-left: 8px; padding-bottom: 4px; font-family: ${FONT}; font-size: 11px; font-weight: 700; letter-spacing: 0.6px; text-transform: uppercase; color: ${MUTED};">
                                ${esc(opts.unit)}
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                      ${statsHtml}
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>`;
}

/** Info card: dark surface, 6px radius, left accent — industrial log card. */
export function infoCard(opts: {
  accent: AccentTone;
  title: string;
  icon?: string;
  iconKey?: string;
  fields: Array<{ label: string; value: string }>;
}): string {
  const accent = resolveAccent(opts.accent, "sky");
  return `
                  <td class="col-stack og-card" valign="top" width="49%" style="width: 49%; background-color: ${SHELL}; border-radius: 6px; border: 1px solid ${BORDER}; border-left: 3px solid ${accent}; padding: 14px 14px 12px 14px; word-break: normal; overflow-wrap: break-word;">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td class="og-title" style="font-family: ${FONT}; font-size: 10px; font-weight: 700; color: ${accent}; text-transform: uppercase; letter-spacing: 0.85px; padding-bottom: 12px; word-break: normal; overflow-wrap: break-word;">
                          ${esc(opts.title)}
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
    const bottomPad = isLastRow ? "0" : "10px";
    const gap =
      `<td class="col-gap" width="10" style="width: 10px; max-width: 10px; font-size: 1px; line-height: 1px; padding: 0;">&nbsp;</td>`;
    const rightCell = right ??
      `<td class="col-stack" valign="top" width="49%" style="width: 49%; padding: 0;">&nbsp;</td>`;
    rowHtml.push(`
          <tr>
            <td style="padding: 10px 16px ${bottomPad} 16px;">
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
                        style="display: block; width: 100%; max-width: 520px; height: auto; border-radius: 6px; border: 1px solid ${BORDER};" />
                    </a>
                  </td>
                </tr>`).join("");
  return `
          <tr>
            <td style="padding: 10px 16px 0 16px;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" class="og-card"
                style="background-color: ${SHELL}; border-radius: 6px; border: 1px solid ${BORDER}; border-left: 3px solid ${AMBER}; padding: 14px;">
                <tr>
                  <td class="og-title" style="font-family: ${FONT}; font-size: 10px; font-weight: 700; color: ${AMBER}; text-transform: uppercase; letter-spacing: 0.85px; padding-bottom: 10px;">
                    ATTACHMENTS
                  </td>
                </tr>
                <tr>
                  <td class="og-label" style="font-family: ${FONT}; font-size: 10px; font-weight: 700; letter-spacing: 0.85px; text-transform: uppercase; color: ${MUTED}; padding-bottom: 3px;">Files</td>
                </tr>
                <tr>
                  <td class="og-value" style="font-family: ${FONT}; font-size: 13px; font-weight: 600; color: ${TEXT};">
                    ${attachmentUrls.length} attached image${attachmentUrls.length === 1 ? "" : "s"}
                  </td>
                </tr>
              </table>
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" style="margin-top: 10px;">
                ${gallery}
              </table>
            </td>
          </tr>`;
}

export type BrandedEmailOptions = {
  title: string;
  preview: string;
  subtitle?: string;
  /** Mirrors AppShell section title (e.g. Shipped Staging Entries Log). */
  sectionTitle?: string;
  /** IndustrialStatusBadge label + tone. */
  statusLabel?: string;
  statusTone?: AccentTone;
  /** Optional LogSummaryCard hero above detail cards. */
  hero?: {
    eyebrow: string;
    value: string;
    unit: string;
    stats?: Array<{ label: string; value: string; accent?: AccentTone }>;
  };
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
  emailContact?: string;
  websiteUrl?: string;
  year?: number;
};

export function renderBrandedEmail(opts: BrandedEmailOptions): string {
  const assetBase = opts.assetBaseUrl ?? DEFAULT_EMAIL_ASSET_BASE;
  const swiftLogoUrl = emailAssetUrl("swift-supply-logo-email", assetBase);
  const title = esc(opts.title);
  const subtitle = esc(opts.subtitle ?? "Order details");
  const preview = esc(opts.preview);
  const sectionTitle = opts.sectionTitle ?? "Notifications";
  const attachmentUrls = opts.attachmentUrls ?? [];
  const grid = opts.cardsGridHtml ?? cardsGridHtml(opts.cards);
  const year = opts.year ?? new Date().getFullYear();
  const hero = opts.hero
    ? heroSummary(opts.hero)
    : "";
  const badge = opts.statusLabel
    ? `<div style="padding-bottom: 10px;">${statusBadge(opts.statusLabel, opts.statusTone ?? "mint")}</div>`
    : "";

  return `<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" data-preview="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="color-scheme" content="dark only">
  <meta name="supported-color-schemes" content="dark only">
  <meta name="x-apple-disable-message-reformatting">
  <title>${title}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@600;700;800&display=swap" rel="stylesheet">
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
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@600;700;800&display=swap');
    :root { color-scheme: dark only; supported-color-schemes: dark only; }
    body, table, td, a { text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
    table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
    img { -ms-interpolation-mode: bicubic; border: 0; height: auto; line-height: 100%; outline: none; text-decoration: none; }
    body, .og-page, .email-container, .og-shell {
      background-color: ${PAGE} !important;
      color: ${TEXT} !important;
    }
    body {
      height: 100% !important; margin: 0 !important; padding: 0 !important; width: 100% !important;
      font-family: ${FONT}; color-scheme: dark only;
    }
    .og-card { background-color: ${SHELL} !important; border-color: ${BORDER} !important; }
    .og-headline, .og-value { color: ${TEXT} !important; }
    .og-subtitle, .og-label, .og-disclaimer, .og-footer { color: ${MUTED} !important; }
    /* Keep industrial dark even when the device/client is in light mode. */
    @media (prefers-color-scheme: light) {
      body, .og-page, .email-container, .og-shell {
        background-color: ${PAGE} !important;
        color: ${TEXT} !important;
      }
      .og-card { background-color: ${SHELL} !important; border-color: ${BORDER} !important; }
      .og-headline, .og-value { color: ${TEXT} !important; }
      .og-subtitle, .og-label, .og-disclaimer, .og-footer { color: ${MUTED} !important; }
    }
    @media (prefers-color-scheme: dark) {
      body, .og-page, .email-container, .og-shell {
        background-color: ${PAGE} !important;
        color: ${TEXT} !important;
      }
    }
    @media screen and (max-width: 600px) {
      .email-container { width: 100% !important; max-width: 100% !important; }
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
<body class="og-page" style="margin: 0; padding: 24px 0; background-color: ${PAGE}; font-family: ${FONT};">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:${PAGE};">
    ${preview}
  </div>

  <table role="presentation" class="og-page" border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: ${PAGE};">
    <tr>
      <td align="center" style="padding: 0 12px;">

        <!-- Outer shell = app window on darkBase scaffold -->
        <table role="presentation" class="email-container og-shell" border="0" cellpadding="0" cellspacing="0" width="600"
          bgcolor="${PAGE}" style="background-color: ${PAGE}; border-radius: 8px; border: 1px solid ${BORDER}; overflow: hidden;">

          ${shellChrome({ sectionTitle, swiftLogoUrl })}

          <!-- CONTENT CANVAS (scaffold / page body) -->
          <tr>
            <td style="background-color: ${PAGE}; padding: 0;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">

                <!-- Title block -->
                <tr>
                  <td style="padding: 18px 16px 0 16px;">
                    ${badge}
                    <h1 class="og-headline" style="margin: 0 0 6px 0; font-family: ${FONT}; font-size: 20px; font-weight: 700; color: ${TEXT}; letter-spacing: -0.2px; line-height: 1.25;">
                      ${title}
                    </h1>
                    <p class="og-subtitle" style="margin: 0; font-family: ${FONT}; font-size: 11.5px; line-height: 1.25; color: ${MUTED}; font-weight: 500;">
                      ${subtitle}
                    </p>
                  </td>
                </tr>

                ${hero}
                ${grid}
                ${attachmentsSection(attachmentUrls)}

                <!-- BrandFooter (widgets.dart) -->
                <tr>
                  <td align="center" class="og-footer" style="padding: 20px 16px 22px 16px; font-family: ${FONT};">
                    <div style="padding-bottom: 8px;">
                      <img src="${SLST_MARK_URL}?v=${ASSET_VERSION}" width="36" height="36" alt="SLST"
                        style="display: inline-block; width: 36px; height: 36px; border-radius: 6px; border: 1px solid ${BORDER};">
                    </div>
                    <div style="font-size: 12px; color: ${MUTED}; padding-bottom: 14px;">
                      Designed &amp; developed by Brice Johnson
                    </div>
                    <div class="og-disclaimer" style="font-size: 10px; line-height: 1.45; color: ${MUTED}; max-width: 520px;">
                      SLST is an internal operations tool for Swift Nisku warehouse staff. It records what is staged, ready to ship, and departed—and notifies sales when orders leave. It is not a carrier tracking system, proof-of-delivery tool, or comprehensive order-tracking platform.
                    </div>
                    <div class="og-disclaimer" style="margin-top: 8px; font-size: 10px; line-height: 1.45; color: ${MUTED};">
                      SLST is a pilot project and is not an official Swift corporate product. © ${year}
                    </div>
                  </td>
                </tr>

              </table>
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

export {
  PAGE,
  SHELL,
  HEADER,
  CARD,
  INSET,
  BORDER,
  TEXT,
  MUTED,
  MINT,
  SKY,
  AMBER,
  PURPLE,
  DANGER,
  SLATE,
};
