/**
 * SLST industrial email layout — dual theme.
 * Default/fallback: cool light (photo 2). Dark via prefers-color-scheme +
 * Outlook [data-ogsb]/[data-ogsc] (photo 3). Never dark-only / hybrid mud.
 */

export const DEFAULT_EMAIL_ASSET_BASE =
  "https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/email-assets";

export const ASSET_VERSION = "20260802dual-theme";

/** App BrandMark — same asset as Flutter `assets/slst-app-icon.png`. */
const SLST_MARK_URL =
  "https://raw.githubusercontent.com/StagingLogShippingTracker/staging-tracker/cursor/sst-industrial-email-redesign/assets/slst-app-icon.png";

/**
 * Faded SLST wordmark for BrandFooter — baked #9CA3AF @ 0.35 opacity to mirror
 * Flutter BrandFooter (muted modulate + dark Opacity 0.35).
 */
const SLST_WORDMARK_FOOTER_URL =
  "https://raw.githubusercontent.com/StagingLogShippingTracker/staging-tracker/cursor/sst-industrial-email-redesign/assets/email/slst-wordmark-footer.png";

/** Match GoogleFonts.inter / JetBrains Mono from the Flutter app. */
const FONT =
  "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";
const MONO =
  "'JetBrains Mono', ui-monospace, Consolas, 'Courier New', monospace";

/** Light tokens — cool white-ish industrial (good light screenshot). */
const L_PAGE = "#E8EAF1";
const L_HEADER = "#FFFFFF";
const L_SHELL = "#FFFFFF";
const L_CARD = "#FFFFFF";
const L_INSET = "#F4F6FA";
const L_BORDER = "#C5CDD8";
const L_TEXT = "#111827";
const L_MUTED = "#6B7280";
/** Footer washout on light canvas. */
const L_FOOTER_FADE = "#9AA3B2";

/** Dark tokens — IndustrialTheme (good dark screenshot). */
const D_PAGE = "#090D16";
const D_HEADER = "#111827";
const D_SHELL = "#1F2937";
const D_CARD = "#1F2937";
const D_INSET = "#111827";
const D_BORDER = "#374151";
const D_TEXT = "#F9FAFB";
const D_MUTED = "#9CA3AF";
/** Baked #9CA3AF @ 0.35 over PAGE #090D16. */
const D_FOOTER_FADE = "#3C424C";

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
      return L_BORDER;
  }
}

function slstFooterWordmarkUrl(): string {
  return `${SLST_WORDMARK_FOOTER_URL}?v=${ASSET_VERSION}`;
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
                        <td class="og-label" style="font-family: ${FONT}; font-size: 10px; font-weight: 700; letter-spacing: 0.85px; text-transform: uppercase; color: ${L_MUTED}; padding-bottom: 3px; word-break: normal; overflow-wrap: break-word;">${esc(r.label)}</td>
                      </tr>
                      <tr>
                        <td class="og-value" style="font-family: ${monoValue ? MONO : FONT}; font-size: 13px; font-weight: ${monoValue ? "700" : "600"}; color: ${L_TEXT}; word-break: normal; overflow-wrap: break-word;${valuePad}">${r.value}</td>
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

/**
 * Brand strip: SLST mark + section title / Swift logo.
 * Status/sync chrome intentionally omitted — recipients do not need app shell cues.
 */
function shellChrome(opts: {
  sectionTitle: string;
  swiftLogoUrl: string;
}): string {
  return `
          <!-- Brand strip -->
          <tr>
            <td class="og-header" bgcolor="${L_HEADER}" style="background-color: ${L_HEADER}; border-bottom: 1px solid ${L_BORDER}; padding: 12px 16px;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td align="left" valign="middle">
                    <img src="${SLST_MARK_URL}?v=${ASSET_VERSION}" width="36" height="36" alt="SLST"
                      style="display: block; width: 36px; height: 36px; border-radius: 6px; border: 1px solid ${L_BORDER};">
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Section header -->
          <tr>
            <td class="og-header" bgcolor="${L_HEADER}" style="background-color: ${L_HEADER}; border-bottom: 1px solid ${L_BORDER}; padding: 14px 16px;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td align="left" valign="middle" class="og-headline" style="font-family: ${FONT}; font-size: 15px; font-weight: 700; color: ${L_TEXT};">
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
                  <td style="padding-top: 12px; border-top: 1px solid ${L_BORDER};" class="og-divider">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        ${stats
                          .map((s, i) => {
                            const accent = resolveAccent(s.accent, "sky");
                            const pad = i === 0 ? "" : " padding-left: 12px;";
                            return `
                        <td valign="top" style="width: ${Math.floor(100 / stats.length)}%;${pad}">
                          <div class="og-label" style="font-family: ${FONT}; font-size: 10px; font-weight: 700; letter-spacing: 0.85px; text-transform: uppercase; color: ${L_MUTED}; padding-bottom: 4px;">${esc(s.label)}</div>
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
            <td style="padding: 16px 16px 0 16px;" class="og-canvas" bgcolor="${L_PAGE}">
              <table role="presentation" class="og-card" border="0" cellpadding="0" cellspacing="0" width="100%"
                bgcolor="${L_CARD}" style="background-color: ${L_CARD}; border-radius: 6px; border: 1px solid ${L_BORDER};">
                <tr>
                  <td class="og-card" bgcolor="${L_CARD}" style="padding: 14px 16px; background-color: ${L_CARD};">
                    <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td class="og-label" style="font-family: ${FONT}; font-size: 10px; font-weight: 700; letter-spacing: 0.85px; text-transform: uppercase; color: ${L_MUTED}; padding-bottom: 8px;">
                          ${esc(opts.eyebrow)}
                        </td>
                      </tr>
                      <tr>
                        <td>
                          <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                            <tr>
                              <td valign="bottom" class="og-headline" style="font-family: ${MONO}; font-size: 28px; font-weight: 800; color: ${L_TEXT}; line-height: 1; letter-spacing: -0.5px;">
                                ${esc(opts.value)}
                              </td>
                              <td valign="bottom" class="og-label" style="padding-left: 8px; padding-bottom: 4px; font-family: ${FONT}; font-size: 11px; font-weight: 700; letter-spacing: 0.6px; text-transform: uppercase; color: ${L_MUTED};">
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

/** Info card: surface + left accent. */
export function infoCard(opts: {
  accent: AccentTone;
  title: string;
  icon?: string;
  iconKey?: string;
  fields: Array<{ label: string; value: string }>;
}): string {
  const accent = resolveAccent(opts.accent, "sky");
  return `
                  <td class="col-stack og-card" valign="top" width="49%" bgcolor="${L_CARD}" style="width: 49%; background-color: ${L_CARD}; border-radius: 6px; border: 1px solid ${L_BORDER}; border-left: 3px solid ${accent}; padding: 14px 14px 12px 14px; word-break: normal; overflow-wrap: break-word;">
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
            <td class="og-canvas" bgcolor="${L_PAGE}" style="padding: 10px 16px ${bottomPad} 16px; background-color: ${L_PAGE};">
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
                        style="display: block; width: 100%; max-width: 520px; height: auto; border-radius: 6px; border: 1px solid ${L_BORDER};" />
                    </a>
                  </td>
                </tr>`).join("");
  return `
          <tr>
            <td class="og-canvas" bgcolor="${L_PAGE}" style="padding: 10px 16px 0 16px; background-color: ${L_PAGE};">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%" class="og-card"
                bgcolor="${L_CARD}" style="background-color: ${L_CARD}; border-radius: 6px; border: 1px solid ${L_BORDER}; border-left: 3px solid ${AMBER}; padding: 14px;">
                <tr>
                  <td class="og-title" style="font-family: ${FONT}; font-size: 10px; font-weight: 700; color: ${AMBER}; text-transform: uppercase; letter-spacing: 0.85px; padding-bottom: 10px;">
                    ATTACHMENTS
                  </td>
                </tr>
                <tr>
                  <td class="og-label" style="font-family: ${FONT}; font-size: 10px; font-weight: 700; letter-spacing: 0.85px; text-transform: uppercase; color: ${L_MUTED}; padding-bottom: 3px;">Files</td>
                </tr>
                <tr>
                  <td class="og-value" style="font-family: ${FONT}; font-size: 13px; font-weight: 600; color: ${L_TEXT};">
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

/** Dual-theme CSS: light defaults inline; dark via media + Outlook attrs. */
function themeCss(forceScheme?: "light" | "dark"): string {
  const darkBlock = `
      body, .og-page, .email-container, .og-shell, .og-canvas {
        background-color: ${D_PAGE} !important;
        color: ${D_TEXT} !important;
      }
      .og-header {
        background-color: ${D_HEADER} !important;
        border-color: ${D_BORDER} !important;
      }
      .og-card {
        background-color: ${D_SHELL} !important;
        border-color: ${D_BORDER} !important;
      }
      .og-headline, .og-value { color: ${D_TEXT} !important; }
      .og-subtitle, .og-label { color: ${D_MUTED} !important; }
      .og-disclaimer, .og-footer { color: ${D_FOOTER_FADE} !important; }
      .og-divider { border-color: ${D_BORDER} !important; }
      .email-container.og-shell {
        border-color: ${D_BORDER} !important;
      }`;

  const lightLock = `
      body, .og-page, .email-container, .og-shell, .og-canvas {
        background-color: ${L_PAGE} !important;
        color: ${L_TEXT} !important;
      }
      .og-header {
        background-color: ${L_HEADER} !important;
        border-color: ${L_BORDER} !important;
      }
      .og-card {
        background-color: ${L_CARD} !important;
        border-color: ${L_BORDER} !important;
      }
      .og-headline, .og-value { color: ${L_TEXT} !important; }
      .og-subtitle, .og-label { color: ${L_MUTED} !important; }
      .og-disclaimer, .og-footer { color: ${L_FOOTER_FADE} !important; }
      .og-divider { border-color: ${L_BORDER} !important; }
      .email-container.og-shell {
        border-color: ${L_BORDER} !important;
      }`;

  const force =
    forceScheme === "dark"
      ? `html[data-preview="dark"] { color-scheme: dark; }\n    html[data-preview="dark"] {${darkBlock}\n    }`
      : forceScheme === "light"
      ? `html[data-preview="light"] { color-scheme: light; }\n    html[data-preview="light"] {${lightLock}\n    }`
      : "";

  return `
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@600;700;800&display=swap');
    :root { color-scheme: light dark; supported-color-schemes: light dark; }
    body, table, td, a { text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
    table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
    img { -ms-interpolation-mode: bicubic; border: 0; height: auto; line-height: 100%; outline: none; text-decoration: none; }
    body {
      height: 100% !important; margin: 0 !important; padding: 0 !important; width: 100% !important;
      font-family: ${FONT};
      background-color: ${L_PAGE};
      color: ${L_TEXT};
      color-scheme: light dark;
    }
    /* Client dark mode — true industrial tokens (not muddy hybrid grays). */
    @media (prefers-color-scheme: dark) {${darkBlock}
    }
    /* Outlook.com / Outlook dark inversion hooks */
    [data-ogsb] body, [data-ogsb] .og-page, [data-ogsb] .email-container,
    [data-ogsb] .og-shell, [data-ogsb] .og-canvas,
    [data-ogab] body, [data-ogab] .og-page, [data-ogab] .email-container,
    [data-ogab] .og-shell, [data-ogab] .og-canvas {
      background-color: ${D_PAGE} !important;
      color: ${D_TEXT} !important;
    }
    [data-ogsb] .og-header, [data-ogab] .og-header {
      background-color: ${D_HEADER} !important;
      border-color: ${D_BORDER} !important;
    }
    [data-ogsb] .og-card, [data-ogab] .og-card {
      background-color: ${D_SHELL} !important;
      border-color: ${D_BORDER} !important;
    }
    [data-ogsc] .og-headline, [data-ogsc] .og-value,
    [data-ogac] .og-headline, [data-ogac] .og-value { color: ${D_TEXT} !important; }
    [data-ogsc] .og-subtitle, [data-ogsc] .og-label,
    [data-ogac] .og-subtitle, [data-ogac] .og-label { color: ${D_MUTED} !important; }
    [data-ogsc] .og-disclaimer, [data-ogsc] .og-footer,
    [data-ogac] .og-disclaimer, [data-ogac] .og-footer { color: ${D_FOOTER_FADE} !important; }
    ${force}
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
  `;
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
  /** Local preview only — force light or dark scheme in generated HTML. */
  previewScheme?: "light" | "dark";
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
  const previewAttr = opts.previewScheme ?? "auto";
  const colorSchemeMeta = opts.previewScheme === "dark"
    ? "dark"
    : opts.previewScheme === "light"
    ? "light"
    : "light dark";

  return `<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" data-preview="${previewAttr}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="color-scheme" content="${colorSchemeMeta}">
  <meta name="supported-color-schemes" content="${colorSchemeMeta}">
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
    ${themeCss(opts.previewScheme)}
  </style>
</head>
<body class="og-page" bgcolor="${L_PAGE}" style="margin: 0; padding: 24px 0; background-color: ${L_PAGE}; font-family: ${FONT}; color: ${L_TEXT};">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:${L_PAGE};">
    ${preview}
  </div>

  <table role="presentation" class="og-page" border="0" cellpadding="0" cellspacing="0" width="100%" bgcolor="${L_PAGE}" style="background-color: ${L_PAGE};">
    <tr>
      <td align="center" class="og-page" bgcolor="${L_PAGE}" style="padding: 0 12px; background-color: ${L_PAGE};">

        <table role="presentation" class="email-container og-shell" border="0" cellpadding="0" cellspacing="0" width="600"
          bgcolor="${L_PAGE}" style="background-color: ${L_PAGE}; border-radius: 8px; border: 1px solid ${L_BORDER}; overflow: hidden;">

          ${shellChrome({ sectionTitle, swiftLogoUrl })}

          <!-- CONTENT CANVAS -->
          <tr>
            <td class="og-canvas" bgcolor="${L_PAGE}" style="background-color: ${L_PAGE}; padding: 0;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%">

                <!-- Title block -->
                <tr>
                  <td class="og-canvas" bgcolor="${L_PAGE}" style="padding: 18px 16px 0 16px; background-color: ${L_PAGE};">
                    ${badge}
                    <h1 class="og-headline" style="margin: 0 0 6px 0; font-family: ${FONT}; font-size: 20px; font-weight: 700; color: ${L_TEXT}; letter-spacing: -0.2px; line-height: 1.25;">
                      ${title}
                    </h1>
                    <p class="og-subtitle" style="margin: 0; font-family: ${FONT}; font-size: 11.5px; line-height: 1.25; color: ${L_MUTED}; font-weight: 500;">
                      ${subtitle}
                    </p>
                  </td>
                </tr>

                ${hero}
                ${grid}
                ${attachmentsSection(attachmentUrls)}

                <!-- BrandFooter (lib/features/shared/widgets.dart) -->
                <tr>
                  <td align="center" class="og-footer og-canvas" bgcolor="${L_PAGE}" style="padding: 20px 16px 22px 16px; font-family: ${FONT}; background-color: ${L_PAGE};">
                    <div style="padding-bottom: 6px;">
                      <img src="${slstFooterWordmarkUrl()}" width="120" height="35" alt="SLST"
                        style="display: inline-block; width: 120px; height: auto; border: 0; outline: none;">
                    </div>
                    <div class="og-footer" style="font-size: 12px; color: ${L_FOOTER_FADE}; padding-bottom: 14px;">
                      Designed &amp; developed by Brice Johnson
                    </div>
                    <div class="og-disclaimer" style="font-size: 10px; line-height: 1.45; color: ${L_FOOTER_FADE}; max-width: 520px; margin: 0 auto;">
                      SLST is an internal operations tool for Swift Nisku warehouse staff. It records what is staged, ready to ship, and departed—and notifies sales when orders leave. It is not a carrier tracking system, proof-of-delivery tool, or comprehensive order-tracking platform.
                    </div>
                    <div class="og-disclaimer" style="margin-top: 8px; font-size: 10px; line-height: 1.45; color: ${L_FOOTER_FADE};">
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

// Back-compat exports (dark tokens as historical names; light is now default inline)
export const ORANGE = AMBER;
export const BLUE = SKY;
export const L_CARD_TOKEN = L_CARD;
export const darkModeCss = () => "";
export const PAGE_BG = L_PAGE;
export const CARD_SHELL = L_SHELL;
export const INK = L_TEXT;
export const BODY = L_MUTED;
export const MUTED_TOKEN = L_MUTED;
export const BORDER_TOKEN = L_BORDER;
export const WHITE = L_CARD;
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
  L_PAGE as PAGE,
  L_SHELL as SHELL,
  L_HEADER as HEADER,
  L_CARD as CARD,
  L_INSET as INSET,
  L_BORDER as BORDER,
  L_TEXT as TEXT,
  L_MUTED as MUTED,
  MINT,
  SKY,
  AMBER,
  PURPLE,
  DANGER,
  SLATE,
  D_PAGE,
  D_SHELL,
  D_HEADER,
  D_CARD,
  D_BORDER,
  D_TEXT,
  D_MUTED,
  D_FOOTER_FADE,
  L_FOOTER_FADE,
  SURFACE_HIGH,
};
