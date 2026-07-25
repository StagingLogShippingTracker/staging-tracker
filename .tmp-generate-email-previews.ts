/**
 * Generate light/dark preview HTML from the email renderer.
 * Run: deno run --allow-write --allow-read generate_previews.ts
 */
import { renderShipConfirmationEmail } from "./supabase/functions/notify-pm/email-templates/ship-confirmation.ts";
import { ASSET_VERSION } from "./supabase/functions/notify-pm/email-templates/email-shared.ts";

const html = renderShipConfirmationEmail({
  so: "1233322",
  customer: "Test",
  carrier: "Rosenau",
  shippedAt: "7/14/2026, 11:09:55 PM",
  shippedBy: "Brice Johnson",
  containers: "1 Skid",
  weight: "233",
  comments: "None",
  ctaUrl: "https://www.swiftsupply.ca",
  emailContact: "warehouse1@swiftsupply.ca",
  websiteUrl: "https://www.swiftsupply.ca",
  year: 2026,
});

const lightForced = html
  .replace(
    "</head>",
    `<style>
      /* Force light preview (disable dark media) */
      @media (prefers-color-scheme: dark) {
        body, .og-page { background-color: #f4f4f5 !important; color: inherit !important; }
        .email-container, .og-shell { background-color: #fbf9f5 !important; border-color: #e5e2dc !important; }
        .og-card { background-color: #f1ece4 !important; border-left: none !important; border-right: none !important; border-bottom: none !important; }
        .og-headline { color: #1a1a1a !important; }
        .og-subtitle { color: #555555 !important; }
        .og-title-orange, .og-title-blue { color: #222222 !important; }
        .og-label { color: #666666 !important; }
        .og-value { color: #111111 !important; }
        .og-plus { color: #555555 !important; }
        .og-footer { color: #666666 !important; }
        .og-thanks { color: #666666 !important; }
        .og-link { color: #c62828 !important; }
        .og-divider { border-top-color: #e0dad0 !important; }
        .logo-light { display: block !important; max-height: none !important; overflow: visible !important; width: auto !important; height: auto !important; }
        .logo-dark { display: none !important; max-height: 0 !important; overflow: hidden !important; width: 0 !important; height: 0 !important; }
      }
    </style></head>`,
  );

const darkForced = html
  .replace(
    '<body class="og-page" style="margin: 0; padding: 30px 0; background-color: #f4f4f5;',
    '<body class="og-page" style="margin: 0; padding: 30px 0; background-color: #121314;',
  )
  .replace(
    'bgcolor="#fbf9f5" style="background-color: #fbf9f5;',
    'bgcolor="#1e2022" style="background-color: #1e2022;',
  )
  .replace(
    "</head>",
    `<style>
      /* Force dark preview tokens */
      body, .og-page { background-color: #121314 !important; color: #e1e1e1 !important; }
      .email-container, .og-shell { background-color: #1e2022 !important; border-color: #2d3033 !important; }
      .og-card {
        background-color: #141517 !important;
        border-left: 1px solid #282a2d !important;
        border-right: 1px solid #282a2d !important;
        border-bottom: 1px solid #282a2d !important;
      }
      .og-headline { color: #ffffff !important; }
      .og-subtitle { color: #a0a0a0 !important; }
      .og-title-orange { color: #ff8a65 !important; }
      .og-title-blue { color: #4fc3f7 !important; }
      .og-label { color: #888888 !important; }
      .og-value { color: #ffffff !important; }
      .og-plus { color: #888888 !important; }
      .og-footer { color: #888888 !important; }
      .og-thanks { color: #aaaaaa !important; }
      .og-link { color: #ff5252 !important; }
      .og-divider { border-top-color: #333639 !important; }
      .logo-light { display: none !important; max-height: 0 !important; overflow: hidden !important; width: 0 !important; height: 0 !important; }
      .logo-dark { display: block !important; max-height: none !important; overflow: visible !important; width: auto !important; height: auto !important; }
    </style></head>`,
  );

const outDir = new URL("./.tmp-email-preview/", import.meta.url);
await Deno.mkdir(outDir, { recursive: true });
await Deno.writeTextFile(new URL("from-reference-light.html", outDir), lightForced);
await Deno.writeTextFile(new URL("from-reference-dark.html", outDir), darkForced);
console.log("ASSET_VERSION", ASSET_VERSION);
console.log("logo150", (html.match(/width="150"/g) || []).length);
console.log("max160", (html.match(/max-width: 160px/g) || []).length);
console.log("bad260", html.includes("260") || html.includes('width="250"') || html.includes("font-size: 32px"));
