/**
 * Local preview renderer for notify-pm email templates.
 * Run: deno run --allow-write --allow-read scripts/preview-email-templates.ts
 */
import {
  renderPoNotificationEmail,
  renderBulkPoNotificationEmail,
  renderReturnNotificationEmail,
  renderReturnToStockEmail,
} from "../supabase/functions/notify-pm/email-templates/notification-email.ts";
import { renderShipConfirmationEmail } from "../supabase/functions/notify-pm/email-templates/ship-confirmation.ts";
import { ASSET_VERSION } from "../supabase/functions/notify-pm/email-templates/email-shared.ts";

const outDir = new URL("../.tmp-email-preview/", import.meta.url);

function forceTheme(html: string, theme: "light" | "dark"): string {
  if (theme === "light") {
    return html
      .replace(
        /@media \(prefers-color-scheme: dark\) \{/g,
        "@media (prefers-color-scheme: dark) and (min-width: 99999px) {",
      )
      .replace(
        '<body class="og-page"',
        '<body class="og-page preview-light" data-preview="light"',
      )
      .replace(
        '<body class="body og-page"',
        '<body class="body og-page preview-light" data-preview="light"',
      );
  }
  const darkForce = `
  <style type="text/css">
    body, .og-page { background-color:#1F1F1F !important; }
    .email-container, .og-shell { background-color:#2e3033 !important; }
    .og-card { background-color:#151515 !important; }
    .og-title-orange, .og-title-blue { color:#f0f0f0 !important; }
    .og-label { color:#a8a8a8 !important; }
    .og-value { color:#f2f2f2 !important; }
    .og-disclaimer { color:#999999 !important; }
    .logo-light { display:none !important; }
    .logo-dark { display:block !important; }
  </style>`;
  return html
    .replace("</head>", `${darkForce}</head>`)
    .replace(
      '<body class="og-page"',
      '<body class="og-page preview-dark" data-preview="dark"',
    )
    .replace(
      '<body class="body og-page"',
      '<body class="body og-page preview-dark" data-preview="dark"',
    );
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

await Deno.mkdir(outDir, { recursive: true });

const files: Array<[string, string]> = [
  ["ship-light.html", forceTheme(shipHtml, "light")],
  ["ship-dark.html", forceTheme(shipHtml, "dark")],
  ["po-light.html", forceTheme(poHtml, "light")],
  ["po-dark.html", forceTheme(poHtml, "dark")],
  ["return-light.html", forceTheme(returnHtml, "light")],
  ["return-dark.html", forceTheme(returnHtml, "dark")],
  ["return-stock-light.html", forceTheme(returnStockHtml, "light")],
  ["return-stock-dark.html", forceTheme(returnStockHtml, "dark")],
  ["bulk-po-light.html", forceTheme(bulkHtml, "light")],
  ["bulk-po-dark.html", forceTheme(bulkHtml, "dark")],
  [
    "index.html",
    `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>SST email previews · ${ASSET_VERSION}</title>
  <style>
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #0f1419;
      color: #e8eaed;
    }
    header {
      padding: 28px 32px 12px;
      border-bottom: 1px solid #2a3340;
    }
    header h1 { margin: 0 0 6px; font-size: 22px; letter-spacing: -0.02em; }
    header p { margin: 0; color: #9aa3af; font-size: 14px; }
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
      background: #171c24;
      border: 1px solid #2a3340;
      border-radius: 12px;
      padding: 16px 18px;
    }
    a.card:hover { border-color: #3b82f6; background: #1b2230; }
    a.card .type { font-size: 11px; letter-spacing: .08em; text-transform: uppercase; color: #9aa3af; }
    a.card .title { margin-top: 6px; font-size: 16px; font-weight: 650; }
    a.card .meta { margin-top: 8px; font-size: 12px; color: #7d8794; }
  </style>
</head>
<body>
  <header>
    <h1>SST PM email previews</h1>
    <p>Generated from live <code>notify-pm</code> templates · asset ${ASSET_VERSION}</p>
  </header>
  <div class="grid">
    <a class="card" href="ship-light.html"><div class="type">ship_confirm / quick_ship</div><div class="title">Ship confirmation — light</div><div class="meta">Order shipped to PM</div></a>
    <a class="card" href="ship-dark.html"><div class="type">ship_confirm / quick_ship</div><div class="title">Ship confirmation — dark</div><div class="meta">Forced dark preview</div></a>
    <a class="card" href="po-light.html"><div class="type">po_notification</div><div class="title">PO notification — light</div><div class="meta">Single PO arrival</div></a>
    <a class="card" href="po-dark.html"><div class="type">po_notification</div><div class="title">PO notification — dark</div><div class="meta">Forced dark preview</div></a>
    <a class="card" href="bulk-po-light.html"><div class="type">bulk_po_notification</div><div class="title">Bulk PO — light</div><div class="meta">Multiple POs in one mail</div></a>
    <a class="card" href="bulk-po-dark.html"><div class="type">bulk_po_notification</div><div class="title">Bulk PO — dark</div><div class="meta">Forced dark preview</div></a>
    <a class="card" href="return-light.html"><div class="type">return_notification</div><div class="title">Return notification — light</div><div class="meta">Customer/return notes</div></a>
    <a class="card" href="return-dark.html"><div class="type">return_notification</div><div class="title">Return notification — dark</div><div class="meta">Forced dark preview</div></a>
    <a class="card" href="return-stock-light.html"><div class="type">return_to_stock</div><div class="title">Returned to stock — light</div><div class="meta">Inventory put-back</div></a>
    <a class="card" href="return-stock-dark.html"><div class="type">return_to_stock</div><div class="title">Returned to stock — dark</div><div class="meta">Forced dark preview</div></a>
  </div>
</body>
</html>`,
  ],
];

for (const [name, content] of files) {
  await Deno.writeTextFile(new URL(name, outDir), content);
}

console.log("Wrote previews to .tmp-email-preview/");
console.log("ASSET_VERSION", ASSET_VERSION);
