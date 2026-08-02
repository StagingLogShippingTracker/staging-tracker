/**
 * Local preview renderer for SLST notify-pm email templates.
 * Writes light + dark forced previews for every notification type.
 * Run: deno run --allow-write --allow-read scripts/preview-email-templates.ts
 */
import {
  renderPoNotificationEmail,
  renderBulkPoNotificationEmail,
  renderReturnNotificationEmail,
  renderReturnToStockEmail,
} from "../supabase/functions/notify-pm/email-templates/notification-email.ts";
import { renderShipConfirmationEmail } from "../supabase/functions/notify-pm/email-templates/ship-confirmation.ts";
import {
  ASSET_VERSION,
  renderBrandedEmail,
  type BrandedEmailOptions,
} from "../supabase/functions/notify-pm/email-templates/email-shared.ts";

const outDir = new URL("../.tmp-email-preview/", import.meta.url);
const distDir = new URL("../dist/email-previews/", import.meta.url);

/** Force previewScheme on HTML that already went through type-specific renderers. */
function withScheme(html: string, scheme: "light" | "dark"): string {
  // Re-render path: type renderers don't accept previewScheme, so patch attributes + inject force CSS.
  let out = html
    .replace(/data-preview="[^"]*"/, `data-preview="${scheme}"`)
    .replace(
      /<meta name="color-scheme" content="[^"]*">/,
      `<meta name="color-scheme" content="${scheme}">`,
    )
    .replace(
      /<meta name="supported-color-schemes" content="[^"]*">/,
      `<meta name="supported-color-schemes" content="${scheme}">`,
    );

  const forceCss =
    scheme === "dark"
      ? `
    html[data-preview="dark"] { color-scheme: dark !important; }
    html[data-preview="dark"] body,
    html[data-preview="dark"] .og-page,
    html[data-preview="dark"] .email-container,
    html[data-preview="dark"] .og-shell,
    html[data-preview="dark"] .og-canvas {
      background-color: #090D16 !important;
      color: #F9FAFB !important;
    }
    html[data-preview="dark"] .og-header {
      background-color: #111827 !important;
      border-color: #374151 !important;
    }
    html[data-preview="dark"] .og-card {
      background-color: #1F2937 !important;
      border-color: #374151 !important;
    }
    html[data-preview="dark"] .og-headline,
    html[data-preview="dark"] .og-value { color: #F9FAFB !important; }
    html[data-preview="dark"] .og-subtitle,
    html[data-preview="dark"] .og-label { color: #9CA3AF !important; }
    html[data-preview="dark"] .og-disclaimer,
    html[data-preview="dark"] .og-footer { color: #3C424C !important; }
    html[data-preview="dark"] .og-divider { border-color: #374151 !important; }
    html[data-preview="dark"] .email-container.og-shell { border-color: #374151 !important; }
`
      : `
    html[data-preview="light"] { color-scheme: light !important; }
    html[data-preview="light"] body,
    html[data-preview="light"] .og-page,
    html[data-preview="light"] .email-container,
    html[data-preview="light"] .og-shell,
    html[data-preview="light"] .og-canvas {
      background-color: #E8EAF1 !important;
      color: #111827 !important;
    }
    html[data-preview="light"] .og-header {
      background-color: #FFFFFF !important;
      border-color: #C5CDD8 !important;
    }
    html[data-preview="light"] .og-card {
      background-color: #FFFFFF !important;
      border-color: #C5CDD8 !important;
    }
    html[data-preview="light"] .og-headline,
    html[data-preview="light"] .og-value { color: #111827 !important; }
    html[data-preview="light"] .og-subtitle,
    html[data-preview="light"] .og-label { color: #6B7280 !important; }
    html[data-preview="light"] .og-disclaimer,
    html[data-preview="light"] .og-footer { color: #9AA3B2 !important; }
    html[data-preview="light"] .og-divider { border-color: #C5CDD8 !important; }
    html[data-preview="light"] .email-container.og-shell { border-color: #C5CDD8 !important; }
`;

  out = out.replace("</style>", `${forceCss}\n  </style>`);
  return out;
}

const poBody = {
  po: "1223344",
  vendor: "Test Vendor Co.",
  details: "Receiving dock notes for preview",
  notification_type: "po_notification",
};

const shipData = {
  so: "1233322",
  customer: "Aecon Industrial",
  carrier: "Rosenau",
  shippedAt: "7/27/2026, 11:09:55 PM",
  shippedBy: "Brice Johnson",
  containers: "1 Skid",
  weight: "233",
  comments: "Leave at south gate",
};

const poHtml = renderPoNotificationEmail(poBody);
const shipHtml = renderShipConfirmationEmail(shipData);
const returnHtml = renderReturnNotificationEmail({
  so: "1233322",
  customer: "Aecon Industrial",
  details: "Damaged packaging",
});
const returnStockHtml = renderReturnToStockEmail({
  so: "445566",
  customer: "Arc Resources Ltd.",
  reason: "Wrong part staged",
  picked_by: "Floor Team",
  returned_by: "Brice Johnson",
});
const bulkHtml = renderBulkPoNotificationEmail({
  pos: [
    { po: "1001", vendor: "Acme", containers: "2 Skids", details: "AM receipt" },
    { po: "1002", vendor: "Beta", containers: "1 Crate", details: "None" },
    { po: "1003", vendor: "Gamma", containers: "3 Boxes", details: "Hold for QC" },
  ],
});

// Sanity: app sync pill must never appear in production email HTML.
for (const [name, html] of Object.entries({
  ship: shipHtml,
  po: poHtml,
  bulk: bulkHtml,
  ret: returnHtml,
  stock: returnStockHtml,
})) {
  if (/Live\s*sync/i.test(html) || />\s*Live\s*</i.test(html)) {
    throw new Error(`App sync pill still present in ${name} email HTML`);
  }
  if (!html.includes("E8EAF1") || !html.includes("prefers-color-scheme: dark")) {
    throw new Error(`Dual-theme markers missing in ${name} email HTML`);
  }
}

await Deno.mkdir(outDir, { recursive: true });
await Deno.mkdir(distDir, { recursive: true });

const pairs: Array<[string, string]> = [
  ["ship", shipHtml],
  ["po", poHtml],
  ["return", returnHtml],
  ["return-stock", returnStockHtml],
  ["bulk-po", bulkHtml],
];

const files: Array<[string, string]> = [];
for (const [base, html] of pairs) {
  files.push([`${base}-light.html`, withScheme(html, "light")]);
  files.push([`${base}-dark.html`, withScheme(html, "dark")]);
}

files.push([
  "index.html",
  `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="color-scheme" content="light dark" />
  <title>SLST email previews · ${ASSET_VERSION}</title>
  <style>
    body {
      margin: 0;
      font-family: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #E8EAF1;
      color: #111827;
    }
    header {
      padding: 28px 32px 12px;
      border-bottom: 1px solid #C5CDD8;
      background: #FFFFFF;
    }
    header h1 { margin: 0 0 6px; font-size: 22px; letter-spacing: -0.02em; }
    header p { margin: 0; color: #6B7280; font-size: 14px; }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
      gap: 14px;
      padding: 24px 32px 40px;
    }
    a.card {
      display: block;
      text-decoration: none;
      color: inherit;
      background: #FFFFFF;
      border: 1px solid #C5CDD8;
      border-radius: 10px;
      padding: 16px 18px;
    }
    a.card:hover { border-color: #3B82F6; background: #F4F6FA; }
    a.card .type { font-size: 11px; letter-spacing: .08em; text-transform: uppercase; color: #6B7280; }
    a.card .title { margin-top: 6px; font-size: 16px; font-weight: 650; }
    a.card .meta { margin-top: 8px; font-size: 12px; color: #9AA3B2; }
  </style>
</head>
<body>
  <header>
    <h1>SLST PM email previews</h1>
    <p>Dual theme · light default · dark via prefers-color-scheme · asset ${ASSET_VERSION}</p>
  </header>
  <div class="grid">
    <a class="card" href="ship-light.html"><div class="type">ship_confirm · light</div><div class="title">Ship confirmation</div><div class="meta">Cool light (default)</div></a>
    <a class="card" href="ship-dark.html"><div class="type">ship_confirm · dark</div><div class="title">Ship confirmation</div><div class="meta">Industrial dark</div></a>
    <a class="card" href="po-light.html"><div class="type">po_notification · light</div><div class="title">PO notification</div><div class="meta">Cool light</div></a>
    <a class="card" href="po-dark.html"><div class="type">po_notification · dark</div><div class="title">PO notification</div><div class="meta">Industrial dark</div></a>
    <a class="card" href="bulk-po-light.html"><div class="type">bulk_po · light</div><div class="title">Bulk PO</div><div class="meta">Cool light</div></a>
    <a class="card" href="bulk-po-dark.html"><div class="type">bulk_po · dark</div><div class="title">Bulk PO</div><div class="meta">Industrial dark</div></a>
    <a class="card" href="return-light.html"><div class="type">return · light</div><div class="title">Return notification</div><div class="meta">Cool light</div></a>
    <a class="card" href="return-dark.html"><div class="type">return · dark</div><div class="title">Return notification</div><div class="meta">Industrial dark</div></a>
    <a class="card" href="return-stock-light.html"><div class="type">return_to_stock · light</div><div class="title">Returned to stock</div><div class="meta">Cool light</div></a>
    <a class="card" href="return-stock-dark.html"><div class="type">return_to_stock · dark</div><div class="title">Returned to stock</div><div class="meta">Industrial dark</div></a>
  </div>
</body>
</html>`,
]);

// Keep renderBrandedEmail import "used" for typecheck / future previewScheme wiring.
void (renderBrandedEmail as unknown as (o: BrandedEmailOptions) => string);

for (const [name, content] of files) {
  await Deno.writeTextFile(new URL(name, outDir), content);
  await Deno.writeTextFile(new URL(name, distDir), content);
}

console.log("Wrote previews to .tmp-email-preview/ and dist/email-previews/");
console.log("ASSET_VERSION", ASSET_VERSION);
