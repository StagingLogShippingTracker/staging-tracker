/**
 * Local preview renderer for notify-pm email templates.
 * Run: deno run --allow-write --allow-read scripts/preview-email-templates.ts
 */
import { renderPoNotificationEmail, renderBulkPoNotificationEmail, renderReturnNotificationEmail } from "../supabase/functions/notify-pm/email-templates/notification-email.ts";
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
        '<body class="body og-page"',
        '<body class="body og-page preview-light" data-preview="light"',
      );
  }
  // Inject forced dark overrides after themeCss so preview matches concept dark
  const darkForce = `
  <style type="text/css">
    body, .og-page { background-color:#1F1F1F !important; background-image:linear-gradient(#1F1F1F,#1F1F1F) !important; }
    .og-shell, .og-footer, .og-logo-cell { background-color:#2B2B2B !important; background-image:linear-gradient(#2B2B2B,#2B2B2B) !important; }
    .og-card, .og-white { background-color:#0D0D0D !important; background-image:linear-gradient(#0D0D0D,#0D0D0D) !important; }
    .og-text, .og-text strong, .og-text h1, .og-value { color:#F5F5F5 !important; }
    .og-body { color:#E0E0E0 !important; }
    .og-muted, .og-label { color:#A8A8A8 !important; }
    .og-section-orange, .og-brand { color:#E85D04 !important; }
    .og-section-blue { color:#3B82F6 !important; }
    .og-accent-orange { background-color:#E85D04 !important; background-image:linear-gradient(#E85D04,#E85D04) !important; }
    .og-accent-blue { background-color:#3B82F6 !important; background-image:linear-gradient(#3B82F6,#3B82F6) !important; }
    .logo-light, .logo-light-wrap { display:none !important; max-height:0 !important; overflow:hidden !important; width:0 !important; height:0 !important; }
    .logo-dark-wrap { display:block !important; max-height:60px !important; overflow:hidden !important; width:auto !important; height:auto !important; }
    .logo-dark { display:block !important; max-height:60px !important; width:auto !important; height:auto !important; }
  </style>`;
  return html
    .replace("</head>", `${darkForce}</head>`)
    .replace(
      '<body class="body og-page"',
      '<body class="body og-page preview-dark" data-ogsb data-ogsc data-preview="dark"',
    );
}

const poBody = {
  po: "1223344",
  vendor: "Test",
  details: "Test 2",
  notification_type: "po_notification",
};

const shipData = {
  so: "1233322",
  customer: "Test",
  carrier: "Rosenau",
  shippedAt: "7/14/2026, 11:09:55 PM",
  shippedBy: "Brice Johnson",
  containers: "1 Skid",
  weight: "233",
  comments: "None",
};

const poHtml = renderPoNotificationEmail(poBody);
const shipHtml = renderShipConfirmationEmail(shipData);
const returnHtml = renderReturnNotificationEmail({
  so: "1233322",
  customer: "Test",
  details: "Damaged packaging",
});
const bulkHtml = renderBulkPoNotificationEmail({
  pos: [
    { po: "1001", vendor: "Acme", containers: "2 Skids", details: "AM receipt" },
    { po: "1002", vendor: "Beta", containers: "1 Crate", details: "None" },
  ],
});

await Deno.mkdir(outDir, { recursive: true });

const files: Array<[string, string]> = [
  ["po-light.html", forceTheme(poHtml, "light")],
  ["po-dark.html", forceTheme(poHtml, "dark")],
  ["ship-light.html", forceTheme(shipHtml, "light")],
  ["ship-dark.html", forceTheme(shipHtml, "dark")],
  ["return-light.html", forceTheme(returnHtml, "light")],
  ["bulk-po-light.html", forceTheme(bulkHtml, "light")],
  ["index.html", `<!DOCTYPE html><html><head><meta charset="utf-8"><title>SLST email preview ${ASSET_VERSION}</title>
  <style>body{font-family:system-ui;margin:24px;background:#eee} a{display:block;margin:8px 0;font-size:18px}</style></head>
  <body><h1>Email previews (ASSET ${ASSET_VERSION})</h1>
  <a href="po-light.html">PO — light</a>
  <a href="po-dark.html">PO — dark</a>
  <a href="ship-light.html">Ship — light</a>
  <a href="ship-dark.html">Ship — dark</a>
  <a href="return-light.html">Return — light</a>
  <a href="bulk-po-light.html">Bulk PO — light</a>
  </body></html>`],
];

for (const [name, content] of files) {
  await Deno.writeTextFile(new URL(name, outDir), content);
  // structural checks
  if (name.endsWith(".html") && name !== "index.html") {
    const checks = [
      ["cream card", "#F5F0E8"],
      ["orange accent", "#E85D04"],
      ["blue accent", "#3B82F6"],
      ["og-label", "og-label"],
      ["og-value", "og-value"],
      ["globe icon", "icon-globe"],
      ["light logo", "slst-logo-email.png"],
      ["dark logo", "slst-logo-email-dark.png"],
      ["large h1", "font-size:32px"],
    ];
    for (const [label, needle] of checks) {
      if (!content.includes(needle)) {
        console.error(`MISSING in ${name}: ${label} (${needle})`);
      }
    }
  }
}

console.log("Wrote previews to .tmp-email-preview/");
console.log("ASSET_VERSION", ASSET_VERSION);
console.log(
  "PO light has blue DETAILS accent:",
  poHtml.includes("og-accent-blue") && poHtml.includes("DETAILS"),
);
console.log(
  "PO subtitle:",
  poHtml.includes("Order details:"),
);
console.log(
  "Website uses globe:",
  poHtml.includes("icon-globe"),
);
console.log(
  "Website does NOT reuse mail for globe slot incorrectly paired:",
  !poHtml.includes('icon-mail.png') || poHtml.includes('icon-globe'),
);
