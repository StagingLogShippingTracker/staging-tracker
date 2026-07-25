import { renderShipConfirmationEmail } from "./supabase/functions/notify-pm/email-templates/ship-confirmation.ts";
import { renderPoNotificationEmail } from "./supabase/functions/notify-pm/email-templates/notification-email.ts";
import { ASSET_VERSION } from "./supabase/functions/notify-pm/email-templates/email-shared.ts";

const ship = renderShipConfirmationEmail({
  so: "1233322",
  customer: "Test",
  carrier: "Rosenau",
  shippedAt: "7/14/2026, 11:09:55 PM",
  shippedBy: "Brice Johnson",
  containers: "1 Skid",
  weight: "233",
  comments: "None",
  ctaUrl: "https://example.com/track",
});

const po = renderPoNotificationEmail({
  po: "PO-99881",
  vendor: "Acme Industrial",
  so: "1233322",
  details: "Partial delivery expected Friday.",
});

const out = ".tmp-email-preview";
await Deno.mkdir(out, { recursive: true });
await Deno.writeTextFile(`${out}/from-reference-light.html`, ship);
await Deno.writeTextFile(
  `${out}/from-reference-dark.html`,
  ship
    .replace(
      '<meta name="color-scheme" content="light dark">',
      '<meta name="color-scheme" content="dark">',
    )
    .replace(
      "</style>\n</head>",
      `</style>
  <style type="text/css">
    body, .og-page { background-color:#121314 !important; }
    .email-container, .og-shell { background-color:#1e2022 !important; border-color:#2d3033 !important; }
    .og-card { background-color:#141517 !important; border-left:1px solid #282a2d !important; border-right:1px solid #282a2d !important; border-bottom:1px solid #282a2d !important; }
    .og-headline { color:#ffffff !important; }
    .og-subtitle { color:#a0a0a0 !important; }
    .og-title-orange { color:#ff8a65 !important; }
    .og-title-blue { color:#4fc3f7 !important; }
    .og-label { color:#888888 !important; }
    .og-value { color:#ffffff !important; }
    .og-plus { color:#888888 !important; }
    .og-footer { color:#888888 !important; }
    .og-thanks { color:#aaaaaa !important; }
    .og-link { color:#ff5252 !important; }
    .og-divider { border-top-color:#333639 !important; }
    .logo-light { display:none !important; width:0 !important; height:0 !important; overflow:hidden !important; }
    .logo-dark { display:block !important; width:150px !important; max-width:160px !important; height:auto !important; }
  </style>
</head>`,
    ),
);
await Deno.writeTextFile(`${out}/from-reference-po.html`, po);

const checks = [
  ['width="150"', ship.includes('width="150"')],
  ["max-width: 160px", ship.includes("max-width: 160px")],
  ["#fbf9f5", ship.includes("#fbf9f5")],
  ["#f4f4f5", ship.includes("#f4f4f5")],
  ["#e65100", ship.includes("#e65100")],
  ["#0288d1", ship.includes("#0288d1")],
  ["#121314", ship.includes("#121314")],
  ["#ff8a65", ship.includes("#ff8a65")],
  ["no width=250", !ship.includes('width="250"')],
  ["no Oswald", !ship.includes("Oswald")],
];
console.log("ASSET_VERSION", ASSET_VERSION);
for (const [k, ok] of checks) console.log(ok ? "OK" : "FAIL", k);
console.log("ship bytes", ship.length, "po bytes", po.length);
