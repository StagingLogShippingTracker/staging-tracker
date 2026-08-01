/**
 * Local preview renderer for SLST notify-pm email templates.
 * Product theme is always industrial dark (light and dark device modes).
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
const distDir = new URL("../dist/email-previews/", import.meta.url);

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
await Deno.mkdir(distDir, { recursive: true });

const files: Array<[string, string]> = [
  ["ship-dark.html", shipHtml],
  ["po-dark.html", poHtml],
  ["return-dark.html", returnHtml],
  ["return-stock-dark.html", returnStockHtml],
  ["bulk-po-dark.html", bulkHtml],
  // Aliases — product emails stay dark in light device mode too.
  ["ship-light.html", shipHtml],
  ["po-light.html", poHtml],
  ["return-light.html", returnHtml],
  ["return-stock-light.html", returnStockHtml],
  ["bulk-po-light.html", bulkHtml],
  [
    "index.html",
    `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="color-scheme" content="dark only" />
  <title>SLST email previews · ${ASSET_VERSION}</title>
  <style>
    body {
      margin: 0;
      font-family: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #090D16;
      color: #F9FAFB;
    }
    header {
      padding: 28px 32px 12px;
      border-bottom: 1px solid #374151;
    }
    header h1 { margin: 0 0 6px; font-size: 22px; letter-spacing: -0.02em; }
    header p { margin: 0; color: #9CA3AF; font-size: 14px; }
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
      background: #1F2937;
      border: 1px solid #374151;
      border-radius: 10px;
      padding: 16px 18px;
    }
    a.card:hover { border-color: #3B82F6; background: #111827; }
    a.card .type { font-size: 11px; letter-spacing: .08em; text-transform: uppercase; color: #9CA3AF; }
    a.card .title { margin-top: 6px; font-size: 16px; font-weight: 650; }
    a.card .meta { margin-top: 8px; font-size: 12px; color: #6B7280; }
  </style>
</head>
<body>
  <header>
    <h1>SLST PM email previews</h1>
    <p>Always industrial dark · Inter + JetBrains Mono · asset ${ASSET_VERSION}</p>
  </header>
  <div class="grid">
    <a class="card" href="ship-dark.html"><div class="type">ship_confirm / quick_ship</div><div class="title">Ship confirmation</div><div class="meta">Industrial dark (all device modes)</div></a>
    <a class="card" href="po-dark.html"><div class="type">po_notification</div><div class="title">PO notification</div><div class="meta">Industrial dark</div></a>
    <a class="card" href="bulk-po-dark.html"><div class="type">bulk_po_notification</div><div class="title">Bulk PO</div><div class="meta">Industrial dark</div></a>
    <a class="card" href="return-dark.html"><div class="type">return_notification</div><div class="title">Return notification</div><div class="meta">Industrial dark</div></a>
    <a class="card" href="return-stock-dark.html"><div class="type">return_to_stock</div><div class="title">Returned to stock</div><div class="meta">Industrial dark</div></a>
  </div>
</body>
</html>`,
  ],
];

for (const [name, content] of files) {
  await Deno.writeTextFile(new URL(name, outDir), content);
  await Deno.writeTextFile(new URL(name, distDir), content);
}

console.log("Wrote previews to .tmp-email-preview/ and dist/email-previews/");
console.log("ASSET_VERSION", ASSET_VERSION);
