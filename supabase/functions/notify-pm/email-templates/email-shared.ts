/**
 * Shared SLST branded email layout — dark-mode lock, Outlook-safe PNG assets.
 */
export const DEFAULT_EMAIL_ASSET_BASE =
  "https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/email-assets";

const BRAND = "#D93223";
const BRAND_DARK = "#B8281C";
const INK = "#2A2A2A";
const BODY = "#3A3A3A";
const MUTED = "#6B6B6B";
const BORDER = "#E6E2DC";
const PAGE_BG = "#F3F1EC";
const CARD_SHELL = "#F7F5F1";
const WHITE = "#FFFFFE";
const ICON_WASH = "#FDECEA";
const IMP = "!important";
const ASSET_VERSION = "20260722g";
const FONT_STACK = "'Oswald', Arial, Helvetica, sans-serif";
const FONT_LINK =
  "https://fonts.googleapis.com/css2?family=Oswald:wght@400;500;600;700&display=swap";

const DISCLAIMER_HTML =
  "SLST is an internal operations tool for Swift Nisku warehouse staff. It helps us record what is staged, what is ready to ship, and what has left the building—and to notify sales when orders depart. It is not a carrier tracking system, proof-of-delivery tool, or comprehensive order-tracking platform. Expectations beyond this operational purpose fall outside the scope of the application.";

function bg(color: string): string {
  return `background-color:${color} ${IMP};`;
}

function fg(color: string): string {
  return `color:${color} ${IMP};`;
}

export function surfaceBg(color: string): string {
  return `${bg(color)} background-image:linear-gradient(${color},${color}) ${IMP};`;
}

export function darkModeCss(): string {
  const lockBg = (cls: string, color: string) => `
    @media (prefers-color-scheme: dark) {
      .${cls}:not([class^="x_"]), .${cls}:not([class^="x_"]) td, .${cls}:not([class^="x_"]) div, .${cls}:not([class^="x_"]) table {
        ${bg(color)} background-image:linear-gradient(${color},${color}) ${IMP};
      }
    }
    [data-ogsb] .${cls}, [data-ogsb].${cls}, .${cls}[data-ogsb], [data-ogab] .${cls}, .${cls}[data-ogab] {
      ${bg(color)} background-image:linear-gradient(${color},${color}) ${IMP};
    }`;
  const lockFg = (cls: string, color: string) => `
    @media (prefers-color-scheme: dark) {
      .${cls}:not([class^="x_"]), .${cls}:not([class^="x_"]) *, .${cls}:not([class^="x_"]) span, .${cls}:not([class^="x_"]) strong,
      .${cls}:not([class^="x_"]) h1, .${cls}:not([class^="x_"]) p, .${cls}:not([class^="x_"]) div, .${cls}:not([class^="x_"]) a {
        ${fg(color)}
      }
    }
    [data-ogsc] .${cls}, [data-ogsc].${cls}, .${cls}[data-ogsc],
    [data-ogac] .${cls}, [data-ogac].${cls}, .${cls}[data-ogac] {
      ${fg(color)}
    }`;
  const ctaGrad = `linear-gradient(${BRAND},${BRAND_DARK})`;
  return `
    :root, html { color-scheme:light only ${IMP}; supported-color-schemes:light only ${IMP}; }
    ${lockBg("og-page", PAGE_BG)}
    ${lockBg("og-shell", CARD_SHELL)}
    ${lockBg("og-white", WHITE)}
    ${lockBg("og-icon", ICON_WASH)}
    ${lockBg("og-footer", CARD_SHELL)}
    ${lockFg("og-text", INK)}
    ${lockFg("og-body", BODY)}
    ${lockFg("og-muted", MUTED)}
    ${lockFg("og-brand", BRAND)}
    @media (prefers-color-scheme: dark) {
      .og-border { border-color:${BORDER} ${IMP}; }
      .og-cta, .og-cta span {
        ${fg(WHITE)} border-color:${BRAND} ${IMP};
        ${bg(BRAND)} background-image:${ctaGrad} ${IMP};
      }
    }
    [data-ogsb] .og-cta, [data-ogsb].og-cta, .og-cta[data-ogsb], [data-ogab] .og-cta, .og-cta[data-ogab] {
      ${bg(BRAND)} background-image:${ctaGrad} ${IMP};
    }
    [data-ogsc] .og-cta, [data-ogsc].og-cta, .og-cta[data-ogsc],
    [data-ogac] .og-cta, .og-cta[data-ogac] { ${fg(WHITE)} }
  `;
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

export function detailCard(opts: {
  iconUrl: string;
  title: string;
  rows: Array<{ label: string; value: string }>;
}): string {
  const whiteSurf = surfaceBg(WHITE);
  const iconSurf = surfaceBg(ICON_WASH);
  const rowsHtml = opts.rows
    .map(
      (r) => `
        <tr>
          <td class="og-text" style="padding:0 0 10px 0;font-family:${FONT_STACK};font-size:14px;line-height:1.35;${whiteSurf}">
            <div class="og-text" style="font-weight:700;color:${INK};mso-line-height-rule:exactly;">
              ${esc(r.label)}
            </div>
            <div class="og-body" style="font-weight:400;padding-top:2px;color:${BODY};mso-line-height-rule:exactly;">
              ${r.value}
            </div>
          </td>
        </tr>`,
    )
    .join("");
  return `
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="og-white og-border"
      style="${whiteSurf} border:2px solid ${BORDER};border-radius:14px;box-shadow:0 4px 14px rgba(42,42,42,0.06);">
      <tr>
        <td class="og-white" style="padding:20px 18px 12px 18px;${whiteSurf}">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
            <tr>
              <td width="44" valign="top" style="padding-right:12px;${whiteSurf}">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="40" height="40" class="og-icon"
                  style="width:40px;height:40px;${iconSurf} border-radius:10px;">
                  <tr>
                    <td align="center" valign="middle" class="og-icon"
                      style="width:40px;height:40px;text-align:center;vertical-align:middle;${iconSurf}">
                      <img src="${esc(opts.iconUrl)}" width="24" height="24" alt=""
                        style="display:block;margin:0 auto;border:0;outline:none;-ms-interpolation-mode:bicubic;" />
                    </td>
                  </tr>
                </table>
              </td>
              <td valign="middle" class="og-brand" style="${whiteSurf}">
                <div class="og-brand" style="font-family:${FONT_STACK};font-size:12px;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:${BRAND};mso-line-height-rule:exactly;">
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

const LOGO_HALO =
  "filter:drop-shadow(0 0 2px #FFFFFF);-webkit-filter:drop-shadow(0 0 2px #FFFFFF);";

export function headerLogosBlock(swiftLogoUrl: string, slstLogoUrl: string): string {
  const rowHeight = 124;
  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" class="logo-row" style="margin:0 auto;width:100%;">
    <tr>
      <td align="center" valign="middle" style="vertical-align:middle;text-align:center;padding:0;">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" style="margin:0 auto;">
          <tr>
            <td align="center" valign="middle" height="${rowHeight}" style="vertical-align:middle;text-align:center;padding:0 20px 0 0;height:${rowHeight}px;">
              <img class="logo-swift" src="${esc(swiftLogoUrl)}" width="200" height="62" alt="Swift Supply"
                style="display:block;margin:0 auto;border:0;outline:none;width:200px;max-width:38vw;height:auto;vertical-align:middle;-ms-interpolation-mode:bicubic;${LOGO_HALO}" />
            </td>
            <td align="center" valign="middle" height="${rowHeight}" style="vertical-align:middle;text-align:center;padding:0;height:${rowHeight}px;">
              <img class="logo-img" src="${esc(slstLogoUrl)}" width="260" height="124" alt="SLST — Staging Log &amp; Shipping Tracker"
                style="display:block;margin:0 auto;border:0;outline:none;width:260px;max-width:46vw;height:auto;vertical-align:middle;-ms-interpolation-mode:bicubic;${LOGO_HALO}" />
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>`;
}

function attachmentsSection(
  attachmentUrls: string[],
  assetBase: string,
): string {
  if (!attachmentUrls.length) return "";
  const cargo = emailAssetUrl("icon-cargo", assetBase);
  const thumbs = attachmentUrls.slice(0, 8).map((url, i) => `
    <td class="stack-col stack-col-pad" width="50%" valign="top" style="width:50%;padding:8px;">
      <a href="${esc(url)}" style="text-decoration:none;">
        <img src="${esc(url)}" width="260" alt="Attachment ${i + 1}"
          style="display:block;width:100%;max-width:260px;height:auto;border-radius:10px;border:2px solid ${BORDER};" />
      </a>
    </td>`).join("");
  const rows: string[] = [];
  for (let i = 0; i < attachmentUrls.length && i < 8; i += 2) {
    const pair = thumbs.split("</td>").filter((s) => s.includes("<td")).slice(i, i + 2);
    if (pair.length) rows.push(`<tr>${pair.map((p) => p + "</td>").join("")}</tr>`);
  }
  const gallery = attachmentUrls.slice(0, 8).map((url, i) => `
    <tr>
      <td style="padding:8px 0;">
        <a href="${esc(url)}" style="text-decoration:none;">
          <img src="${esc(url)}" width="520" alt="Attachment ${i + 1}"
            style="display:block;width:100%;max-width:520px;height:auto;border-radius:10px;border:2px solid ${BORDER};" />
        </a>
      </td>
    </tr>`).join("");
  return `
    <tr>
      <td class="og-shell" style="padding:0 22px 10px 22px;${surfaceBg(CARD_SHELL)}">
        ${detailCard({
          iconUrl: cargo,
          title: "ATTACHMENTS",
          rows: [{
            label: "Files",
            value: `${attachmentUrls.length} attached image${attachmentUrls.length === 1 ? "" : "s"}`,
          }],
        })}
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:12px;">
          ${gallery}
        </table>
      </td>
    </tr>`;
}

export type BrandedEmailOptions = {
  title: string;
  preview: string;
  subtitle?: string;
  cards: Array<{
    iconKey: string;
    title: string;
    rows: Array<{ label: string; value: string }>;
  }>;
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
  const slstLogoUrl = (opts.logoUrl && opts.logoUrl.trim()) ||
    emailAssetUrl("slst-logo-email", assetBase);
  const swiftLogoUrl = emailAssetUrl("swift-supply-logo-email", assetBase);
  const title = esc(opts.title);
  const subtitle = esc(opts.subtitle ?? "");
  const preview = esc(opts.preview);
  const year = opts.year ?? new Date().getFullYear();
  const emailContact = (opts.emailContact ?? "warehouse1@swiftsupply.ca").trim();
  const mailto = `mailto:${emailContact}`;
  const mail = emailAssetUrl("icon-mail", assetBase);
  const watermarkUrl = esc(emailAssetUrl("watermark-gears", assetBase));
  const pageSurf = `${surfaceBg(PAGE_BG)} background-image:url('${watermarkUrl}'),linear-gradient(${PAGE_BG},${PAGE_BG}) ${IMP}; background-repeat:no-repeat,repeat ${IMP}; background-position:center top,top left ${IMP}; background-size:600px auto,auto ${IMP};`;
  const shellSurf = surfaceBg(CARD_SHELL);
  const attachmentUrls = opts.attachmentUrls ?? [];

  const cardHtml = opts.cards.map((card, i) => {
    const html = detailCard({
      iconUrl: emailAssetUrl(card.iconKey, assetBase),
      title: card.title,
      rows: card.rows,
    });
    const col = i % 2 === 0 ? "left" : "right";
    return { html, col, row: Math.floor(i / 2) };
  });

  const rowsByIndex = new Map<number, string[]>();
  for (const item of cardHtml) {
    const row = rowsByIndex.get(item.row) ?? [];
    row.push(`
      <td class="stack-col stack-col-pad" width="50%" valign="top" style="width:50%;padding:8px;">
        ${item.html}
      </td>`);
    rowsByIndex.set(item.row, row);
  }
  const cardsTable = [...rowsByIndex.entries()]
    .sort(([a], [b]) => a - b)
    .map(([, cols]) => `<tr>${cols.join("")}${cols.length === 1 ? '<td class="stack-col" width="50%" style="width:50%;padding:8px;"></td>' : ""}</tr>`)
    .join("");

  return `<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" style="color-scheme:light only;">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <meta name="color-scheme" content="light only" />
  <meta name="supported-color-schemes" content="light only" />
  <meta name="x-apple-disable-message-reformatting" />
  <title>${title}</title>
  <link href="${FONT_LINK}" rel="stylesheet" type="text/css" />
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
    td, th, div, p, a, span, strong, h1 { font-family: ${FONT_STACK} !important; }
  </style>
  <![endif]-->
  <style type="text/css">
    :root { color-scheme: light only !important; supported-color-schemes: light only !important; }
    body, table, td, a { -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
    table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
    img { -ms-interpolation-mode: bicubic; border: 0; outline: none; text-decoration: none; }
    body { margin: 0 !important; padding: 0 !important; width: 100% !important; ${surfaceBg(PAGE_BG)} }
    a { ${fg(BRAND)} }
    ${darkModeCss()}
    @media only screen and (max-width: 620px) {
      .email-card { width: 100% !important; }
      .stack-col { display: block !important; width: 100% !important; max-width: 100% !important; box-sizing: border-box !important; padding-left: 0 !important; padding-right: 0 !important; }
      .stack-col-pad { padding: 8px 0 !important; }
      .footer-right { text-align: left !important; padding-top: 16px !important; }
      .logo-swift { width: 150px !important; max-width: 38vw !important; height: auto !important; }
      .logo-img { width: 200px !important; max-width: 46vw !important; height: auto !important; }
      .logo-row td { padding: 0 10px !important; }
    }
  </style>
</head>
<body class="body slst-light og-page" style="margin:0;padding:0;${pageSurf}">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;${fg(PAGE_BG)}">
    ${preview}
  </div>
  <table role="presentation" class="og-page" width="100%" cellpadding="0" cellspacing="0" border="0"
    style="${pageSurf}">
    <tr>
      <td align="center" class="og-page" style="padding:36px 16px 28px 16px;${pageSurf}">
        <!--[if mso]>
        <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0"><tr><td>
        <![endif]-->
        <table role="presentation" class="email-card og-shell og-border" width="600" cellpadding="0" cellspacing="0" border="0"
          style="width:100%;max-width:600px;${shellSurf} border-radius:18px;border:2px solid ${BORDER};box-shadow:0 18px 48px rgba(42,42,42,0.10);overflow:hidden;">
          <tr>
            <td align="center" class="og-shell" style="padding:42px 36px 10px 36px;${shellSurf}">
              ${headerLogosBlock(swiftLogoUrl, slstLogoUrl)}
            </td>
          </tr>
          <tr>
            <td align="center" class="og-shell og-text" style="padding:26px 36px 6px 36px;${shellSurf}">
              <h1 class="og-text" style="margin:0;font-family:${FONT_STACK};font-size:28px;line-height:1.28;font-weight:700;color:${INK};">
                ${title}
              </h1>
            </td>
          </tr>
          ${subtitle ? `
          <tr>
            <td align="center" class="og-shell og-text" style="padding:8px 36px 26px 36px;${shellSurf}">
              <p class="og-body" style="margin:0;font-family:${FONT_STACK};font-size:16px;line-height:1.4;color:${BODY};">
                ${subtitle}
              </p>
            </td>
          </tr>` : ""}
          <tr>
            <td class="og-shell" style="padding:0 22px 10px 22px;${shellSurf}">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                ${cardsTable}
              </table>
            </td>
          </tr>
          ${attachmentsSection(attachmentUrls, assetBase)}
          <tr>
            <td class="og-shell" style="padding:8px 36px 18px 36px;${shellSurf}">
              <p class="og-muted" style="margin:0;font-family:${FONT_STACK};font-size:11px;line-height:1.6;color:${MUTED};text-align:center;">
                <strong class="og-text" style="font-weight:600;color:${INK};">About SLST</strong><br />
                ${esc(DISCLAIMER_HTML)}
              </p>
            </td>
          </tr>
          <tr>
            <td class="og-shell" style="padding:0 36px;${shellSurf}">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td class="og-shell og-border" style="border-top:2px solid ${BORDER};font-size:0;line-height:0;${shellSurf}">&nbsp;</td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td class="og-shell og-footer" style="padding:22px 36px 32px 36px;${shellSurf}">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td class="stack-col og-text" valign="top"
                    style="font-family:${FONT_STACK};font-size:13px;line-height:1.55;${shellSurf}">
                    <strong class="og-text" style="font-weight:700;color:${INK};">Thank you for using SLST!</strong><br />
                    <span class="og-body" style="color:${BODY};">SLST - Staging Log &amp; Shipping Tracker</span><br />
                    <span class="og-muted" style="font-size:12px;color:${MUTED};">Copyright © ${year} SLST. All rights reserved.</span>
                  </td>
                  <td class="stack-col footer-right" valign="middle" align="right"
                    style="font-family:${FONT_STACK};font-size:13px;line-height:1.9;white-space:nowrap;${shellSurf}">
                    <a class="og-brand" href="${esc(mailto)}" style="text-decoration:underline;color:${BRAND};">
                      <img src="${esc(mail)}" width="14" height="14" alt=""
                        style="display:inline-block;vertical-align:middle;margin-right:5px;border:0;" />
                      Email
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
        <div class="og-muted" style="font-family:${FONT_STACK};font-size:11px;padding-top:18px;color:${MUTED};">
          Sent via SLST · Swift Supply
        </div>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

export { BRAND, BODY, INK, BORDER, PAGE_BG, CARD_SHELL, WHITE, MUTED };
