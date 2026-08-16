"""Regenerate local browser preview for ship-confirmation email (concept-matched)."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "email" / "preview-ship-confirmation.html"

ASSET_BASE = (
    "https://gdrpdiwykmnybmkadlrv.supabase.co/storage/v1/object/public/email-assets"
)
ASSET_VERSION = "20260722b"


def asset(key: str) -> str:
    return f"{ASSET_BASE}/{key}.png?v={ASSET_VERSION}"


BRAND = "#D93223"
BRAND_DARK = "#B92820"
INK = "#2A2A2A"
BODY = "#3A3A3A"
MUTED = "#6B6B6B"
BORDER = "#E6E2DC"
PAGE_BG = "#F3F1EC"
CARD_SHELL = "#F7F5F1"
WHITE = "#FFFFFF"
ICON_WASH = "#FDECEA"


def card(icon: str, title: str, rows: list[tuple[str, str]]) -> str:
    rows_html = "".join(
        f"""<tr><td style="padding:0 0 10px 0;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.35;color:{INK};">
        <div style="font-weight:700;color:{INK};">{label}</div>
        <div style="font-weight:400;color:{BODY};padding-top:2px;">{value}</div>
        </td></tr>"""
        for label, value in rows
    )
    return f"""
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="{WHITE}"
      style="background-color:{WHITE};border:1px solid {BORDER};border-radius:14px;box-shadow:0 4px 14px rgba(42,42,42,0.06);">
      <tr><td bgcolor="{WHITE}" style="padding:20px 18px 12px 18px;background-color:{WHITE};">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"><tr>
          <td width="44" valign="top" style="padding-right:12px;">
            <table role="presentation" width="40" height="40" bgcolor="{ICON_WASH}" style="width:40px;height:40px;background-color:{ICON_WASH};border-radius:10px;">
              <tr><td align="center" valign="middle" bgcolor="{ICON_WASH}">
                <img src="{icon}" width="24" height="24" alt="" style="display:block;margin:0 auto;border:0;" />
              </td></tr>
            </table>
          </td>
          <td valign="middle">
            <div style="font-family:Arial,Helvetica,sans-serif;font-size:12px;font-weight:700;letter-spacing:0.12em;color:{BRAND};text-transform:uppercase;">{title}</div>
          </td>
        </tr></table>
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin-top:14px;">{rows_html}</table>
      </td></tr>
    </table>"""


def main() -> None:
    wm = asset("watermark-gears")
    logo = asset("slst-logo-email")
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="color-scheme" content="light only" />
  <meta name="supported-color-schemes" content="light" />
  <title>Ship confirmation preview</title>
  <style>
    :root {{ color-scheme: light only; }}
    body {{ margin:0; background:{PAGE_BG}; }}
    @media (prefers-color-scheme: dark) {{
      body, table, td {{ background-color:{PAGE_BG} !important; color:{INK} !important; }}
    }}
  </style>
</head>
<body bgcolor="{PAGE_BG}" style="margin:0;padding:0;background-color:{PAGE_BG};">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="{PAGE_BG}"
    style="background-color:{PAGE_BG};background-image:url('{wm}');background-repeat:repeat;">
    <tr><td align="center" style="padding:36px 16px;">
      <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" bgcolor="{CARD_SHELL}"
        style="width:100%;max-width:600px;background-color:{CARD_SHELL};border-radius:18px;border:1px solid {BORDER};box-shadow:0 18px 48px rgba(42,42,42,0.10);">
        <tr><td align="center" style="padding:42px 36px 10px 36px;background-image:url('{wm}');background-repeat:repeat;">
          <img src="{logo}" width="300" alt="Swift Staging &amp; Shipping Log" style="display:block;margin:0 auto;border:0;max-width:86%;height:auto;" />
        </td></tr>
        <tr><td align="center" style="padding:26px 36px 6px 36px;">
          <h1 style="margin:0;font-family:Arial,Helvetica,sans-serif;font-size:28px;line-height:1.28;font-weight:700;color:{INK};">Your order has now been shipped!</h1>
        </td></tr>
        <tr><td align="center" style="padding:8px 36px 26px 36px;">
          <p style="margin:0;font-family:Arial,Helvetica,sans-serif;font-size:16px;color:{BODY};">Order details:</p>
        </td></tr>
        <tr><td style="padding:0 22px 10px 22px;">
          <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
            <td width="50%" valign="top" style="padding:8px;">{card(asset("icon-clipboard"), "ORDER SUMMARY", [("SO#", "1233322"), ("Customer", "Test")])}</td>
            <td width="50%" valign="top" style="padding:8px;">{card(asset("icon-truck"), "SHIPPING INFORMATION", [("Carrier", "Rosenau"), ("Shipped At", "7/14/2026, 11:09:55 PM"), ("Shipped By", "Brice Johnson")])}</td>
          </tr><tr>
            <td width="50%" valign="top" style="padding:8px;">{card(asset("icon-cargo"), "CARGO DETAILS", [("Container(s)", "1 Skid"), ("Total Weight (In lbs)", "233")])}</td>
            <td width="50%" valign="top" style="padding:8px;">{card(asset("icon-chat"), "ADDITIONAL NOTES", [("Comments", "None")])}</td>
          </tr></table>
        </td></tr>
        <tr><td align="center" style="padding:26px 36px 34px 36px;">
          <a href="https://www.swiftsupply.ca" style="display:inline-block;background:linear-gradient(90deg,{BRAND},{BRAND_DARK});background-color:{BRAND};color:#fff;font-family:Arial,Helvetica,sans-serif;font-size:13px;font-weight:700;letter-spacing:0.08em;text-decoration:none;padding:16px 34px;border-radius:999px;box-shadow:0 10px 24px rgba(217,50,35,0.35);">
            <img src="{asset("icon-search")}" width="16" height="16" alt="" style="vertical-align:middle;margin-right:10px;border:0;" />
            <span style="vertical-align:middle;">VIEW FULL TRACKING DETAILS</span>
          </a>
        </td></tr>
        <tr><td style="padding:0 36px;"><div style="border-top:1px solid {BORDER};"></div></td></tr>
        <tr><td style="padding:22px 36px 32px 36px;">
          <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
            <td style="font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.55;color:{INK};">
              <strong>Thank you for using Swift Staging &amp; Shipping Log!</strong><br />
              Swift Staging &amp; Shipping Log<br />
              <span style="font-size:12px;color:{MUTED};">Copyright © 2026 Swift Supply. All rights reserved.</span>
            </td>
            <td align="right" style="font-family:Arial,Helvetica,sans-serif;font-size:13px;white-space:nowrap;">
              <a href="mailto:warehouse1@swiftsupply.ca" style="color:{BRAND};"><img src="{asset("icon-mail")}" width="14" height="14" alt="" style="vertical-align:middle;margin-right:5px;border:0;" />Email</a>
              &nbsp;&nbsp;
              <a href="https://www.swiftsupply.ca" style="color:{BRAND};"><img src="{asset("icon-globe")}" width="14" height="14" alt="" style="vertical-align:middle;margin-right:5px;border:0;" />Website</a>
            </td>
          </tr></table>
        </td></tr>
      </table>
      <div style="font-family:Arial,Helvetica,sans-serif;font-size:11px;color:{MUTED};padding-top:18px;">Sent via Swift Staging &amp; Shipping Log · Swift Supply</div>
      <p style="font-family:Arial,Helvetica,sans-serif;font-size:12px;color:{MUTED};max-width:600px;text-align:left;margin:24px auto 0;">
        Local preview — images load from the live <code>email-assets</code> Edge Function. Open this file after deploy.
      </p>
    </td></tr>
  </table>
</body>
</html>
"""
    OUT.write_text(html, encoding="utf-8")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
