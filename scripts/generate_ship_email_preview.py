"""Generate assets/email/preview-ship-confirmation.html from sample mockup data."""
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]

BRAND = "#D93223"
BRAND_DARK = "#B92820"
INK = "#1E293B"
SUBTLE = "#94A3B8"
BORDER = "#E2E8F0"
SURFACE_SUBTLE = "#F3F5F8"
CARD_BG = "#FAFBFC"
WHITE = "#FFFFFF"

gear = (
    '<svg xmlns="http://www.w3.org/2000/svg" width="180" height="180" viewBox="0 0 180 180">'
    '<g fill="none" stroke="#CBD5E1" stroke-width="1.2" opacity="0.45">'
    '<circle cx="40" cy="40" r="14"/><circle cx="40" cy="40" r="6"/>'
    '<path d="M40 22v4M40 54v4M22 40h4M54 40h4M27 27l3 3M50 50l3 3M53 27l-3 3M27 53l3-3"/>'
    '<circle cx="140" cy="55" r="18"/><circle cx="140" cy="55" r="7"/>'
    '<path d="M140 32v5M140 73v5M117 55h5M158 55h5"/>'
    '<path d="M30 120l10-6 10 6v10l-10 6-10-6z"/><path d="M40 114v22"/>'
    '<path d="M110 130l12-8 12 8-4 14h-16z"/>'
    '<path d="M70 160l8-5 8 5-3 9H73z"/>'
    "</g></svg>"
)
GEAR_WATERMARK = f'url("data:image/svg+xml,{quote(gear)}")'

svgs = {
    "clipboard": (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 28 28" fill="none">'
        f'<rect x="7" y="5" width="14" height="18" rx="2" stroke="{BRAND}" stroke-width="1.8"/>'
        f'<rect x="10" y="3" width="8" height="4" rx="1" fill="{BRAND}"/>'
        f'<path d="M10 12h8M10 16h8M10 20h5" stroke="{BRAND}" stroke-width="1.6" stroke-linecap="round"/>'
        f"</svg>"
    ),
    "truck": (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 28 28" fill="none">'
        f'<path d="M3 16V9a2 2 0 0 1 2-2h10v11H5a2 2 0 0 1-2-2z" stroke="{BRAND}" stroke-width="1.8"/>'
        f'<path d="M15 11h5l3 4v4h-8V11z" stroke="{BRAND}" stroke-width="1.8" stroke-linejoin="round"/>'
        f'<circle cx="8" cy="20" r="2.2" stroke="{BRAND}" stroke-width="1.6"/>'
        f'<circle cx="20" cy="20" r="2.2" stroke="{BRAND}" stroke-width="1.6"/>'
        f"</svg>"
    ),
    "cargo": (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 28 28" fill="none">'
        f'<path d="M5 12l9-5 9 5v9l-9 5-9-5v-9z" stroke="{BRAND}" stroke-width="1.8" stroke-linejoin="round"/>'
        f'<path d="M5 12l9 5 9-5M14 17v9" stroke="{BRAND}" stroke-width="1.6"/>'
        f"</svg>"
    ),
    "chat": (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 28 28" fill="none">'
        f'<path d="M6 7h16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H12l-5 4v-4H6a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2z" stroke="{BRAND}" stroke-width="1.8" stroke-linejoin="round"/>'
        f'<path d="M9 12h10M9 16h6" stroke="{BRAND}" stroke-width="1.6" stroke-linecap="round"/>'
        f"</svg>"
    ),
    "search": (
        '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18" fill="none">'
        '<circle cx="8" cy="8" r="5.5" stroke="#fff" stroke-width="1.8"/>'
        '<path d="M12.5 12.5L16 16" stroke="#fff" stroke-width="1.8" stroke-linecap="round"/>'
        "</svg>"
    ),
    "mail": (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">'
        f'<rect x="1.5" y="3" width="13" height="10" rx="1.5" stroke="{BRAND_DARK}" stroke-width="1.4"/>'
        f'<path d="M2 4l6 5 6-5" stroke="{BRAND_DARK}" stroke-width="1.4" stroke-linejoin="round"/>'
        f"</svg>"
    ),
    "globe": (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16" fill="none">'
        f'<circle cx="8" cy="8" r="6" stroke="{BRAND_DARK}" stroke-width="1.4"/>'
        f'<path d="M2 8h12M8 2c2 2.2 2 9.8 0 12M8 2c-2 2.2-2 9.8 0 12" stroke="{BRAND_DARK}" stroke-width="1.2"/>'
        f"</svg>"
    ),
}


def icon(kind: str) -> str:
    return f"data:image/svg+xml,{quote(svgs[kind])}"


def card(kind: str, title: str, rows: list[tuple[str, str]]) -> str:
    rows_html = "".join(
        f'<tr><td style="padding:3px 0;font-family:Arial,Helvetica,sans-serif;font-size:14px;'
        f'line-height:1.5;color:{INK};"><strong style="font-weight:700;">{lab}</strong>&nbsp;{val}</td></tr>'
        for lab, val in rows
    )
    return f"""
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:{WHITE};border:1px solid {BORDER};border-radius:12px;box-shadow:0 2px 10px rgba(15,23,42,0.05);">
      <tr><td style="padding:18px 16px;">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
          <tr>
            <td width="40" valign="top" style="padding-right:12px;">
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="36" height="36" style="width:36px;height:36px;background-color:#FFF5F4;border-radius:8px;">
                <tr><td align="center" valign="middle" style="width:36px;height:36px;text-align:center;vertical-align:middle;">
                  <img src="{icon(kind)}" width="22" height="22" alt="" style="display:block;margin:0 auto;border:0;outline:none;" />
                </td></tr>
              </table>
            </td>
            <td valign="top">
              <div style="font-family:Arial,Helvetica,sans-serif;font-size:11px;font-weight:700;letter-spacing:0.1em;color:{BRAND};padding-bottom:8px;text-transform:uppercase;">{title}</div>
              <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">{rows_html}</table>
            </td>
          </tr>
        </table>
      </td></tr>
    </table>"""


def main() -> None:
    order = card("clipboard", "ORDER SUMMARY", [("SO#", "1233322"), ("Customer", "Test")])
    shipping = card(
        "truck",
        "SHIPPING INFORMATION",
        [
            ("Carrier", "Rosenau"),
            ("Shipped At", "7/14/2026, 11:09:55 PM"),
            ("Shipped By", "Brice Johnson"),
        ],
    )
    cargo = card(
        "cargo",
        "CARGO DETAILS",
        [("Container(s)", "1 Skid"), ("Total Weight (In lbs)", "233")],
    )
    notes = card("chat", "ADDITIONAL NOTES", [("Comments", "None")])
    bg = (
        f"background-color:{CARD_BG};background-image:{GEAR_WATERMARK};"
        f"background-repeat:repeat;background-size:180px 180px;"
    )

    html = f"""<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>SLST Preview — Ship Confirmation</title>
  <!--
    Local browser preview of the ship-confirmation email.
    Sample data matches the design mockup (SO 1233322, Rosenau, etc.).
    Production HTML is generated by:
      supabase/functions/notify-pm/email-templates/ship-confirmation.ts
  -->
  <style type="text/css">
    body, table, td, a {{ -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }}
    body {{ margin: 0 !important; padding: 0 !important; width: 100% !important; }}
    a {{ color: {BRAND_DARK}; }}
    @media only screen and (max-width: 620px) {{
      .email-card {{ width: 100% !important; }}
      .stack-col {{ display: block !important; width: 100% !important; max-width: 100% !important; box-sizing: border-box !important; }}
      .footer-right {{ text-align: left !important; padding-top: 14px !important; }}
    }}
  </style>
</head>
<body style="margin:0;padding:0;background-color:{SURFACE_SUBTLE};">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:{SURFACE_SUBTLE};">
    <tr>
      <td align="center" style="padding:28px 12px;">
        <table role="presentation" class="email-card" width="600" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:600px;background-color:{CARD_BG};border-radius:16px;border:1px solid {BORDER};box-shadow:0 12px 40px rgba(15,23,42,0.08);overflow:hidden;">
          <tr>
            <td align="center" style="padding:36px 28px 8px 28px;{bg}">
              <img src="../staging-shipping-logo.png" width="220" alt="SLST — Staging Log &amp; Shipping Tracker" style="display:block;margin:0 auto;border:0;max-width:220px;height:auto;" />
              <div style="font-family:Arial,Helvetica,sans-serif;font-size:11px;font-weight:700;letter-spacing:0.16em;color:{INK};padding-top:12px;text-transform:uppercase;">
                STAGING LOG &amp; SHIPPING TRACKER
              </div>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:22px 28px 6px 28px;{bg}">
              <h1 style="margin:0;font-family:Arial,Helvetica,sans-serif;font-size:26px;line-height:1.3;font-weight:700;color:{INK};">
                Your order has now been shipped!
              </h1>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:0 28px 20px 28px;{bg}">
              <p style="margin:0;font-family:Arial,Helvetica,sans-serif;font-size:15px;color:{INK};">Order details:</p>
            </td>
          </tr>
          <tr>
            <td style="padding:0 18px 8px 18px;{bg}">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td class="stack-col" width="50%" valign="top" style="width:50%;padding:6px;">{order}</td>
                  <td class="stack-col" width="50%" valign="top" style="width:50%;padding:6px;">{shipping}</td>
                </tr>
                <tr>
                  <td class="stack-col" width="50%" valign="top" style="width:50%;padding:6px;">{cargo}</td>
                  <td class="stack-col" width="50%" valign="top" style="width:50%;padding:6px;">{notes}</td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:20px 28px 28px 28px;{bg}">
              <a href="https://www.swiftsupply.ca" style="display:inline-block;background:linear-gradient(90deg, {BRAND} 0%, {BRAND_DARK} 100%);background-color:{BRAND};color:{WHITE};font-family:Arial,Helvetica,sans-serif;font-size:13px;font-weight:700;letter-spacing:0.07em;text-decoration:none;padding:15px 30px;border-radius:999px;box-shadow:0 6px 18px rgba(217,50,35,0.35);">
                <img src="{icon('search')}" width="16" height="16" alt="" style="display:inline-block;vertical-align:middle;margin-right:8px;border:0;" />
                <span style="vertical-align:middle;">VIEW FULL TRACKING DETAILS</span>
              </a>
            </td>
          </tr>
          <tr>
            <td style="padding:0 28px;background-color:{CARD_BG};">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr><td style="border-top:1px solid {BORDER};font-size:0;line-height:0;">&nbsp;</td></tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:20px 28px 28px 28px;background-color:{CARD_BG};">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td class="stack-col" valign="top" style="font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.55;color:{INK};">
                    <strong style="font-weight:700;">Thank you for using SLST!</strong><br />
                    SLST - Staging Log &amp; Shipping Tracker<br />
                    <span style="font-size:12px;color:{SUBTLE};">Copyright © 2026 SLST. All rights reserved.</span>
                  </td>
                  <td class="stack-col footer-right" valign="top" align="right" style="font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.9;white-space:nowrap;">
                    <a href="mailto:warehouse1@swiftsupply.ca" style="color:{BRAND_DARK};text-decoration:underline;">
                      <img src="{icon('mail')}" width="14" height="14" alt="" style="display:inline-block;vertical-align:middle;margin-right:4px;border:0;" />
                      <span style="vertical-align:middle;">Email</span>
                    </a>
                    &nbsp;&nbsp;&nbsp;
                    <a href="https://www.swiftsupply.ca" style="color:{BRAND_DARK};text-decoration:underline;">
                      <img src="{icon('globe')}" width="14" height="14" alt="" style="display:inline-block;vertical-align:middle;margin-right:4px;border:0;" />
                      <span style="vertical-align:middle;">Website</span>
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
        <div style="font-family:Arial,Helvetica,sans-serif;font-size:11px;color:{SUBTLE};padding-top:16px;">
          Local preview · production emails use the Edge Function template
        </div>
      </td>
    </tr>
  </table>
</body>
</html>
"""
    out = ROOT / "assets" / "email" / "preview-ship-confirmation.html"
    out.write_text(html, encoding="utf-8")
    print(f"Wrote {out} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
