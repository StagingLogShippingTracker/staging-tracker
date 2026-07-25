/**
 * SLST ship-confirmation HTML email — concept-matched layout.
 */
import {
  DEFAULT_EMAIL_ASSET_BASE,
  displayOrNone,
  emailAssetUrl,
  esc,
  renderBrandedEmail,
} from "./email-shared.ts";

export type ShipConfirmationData = {
  so: string;
  customer: string;
  carrier: string;
  shippedAt: string;
  shippedBy: string;
  containers: string;
  weight: string;
  comments: string;
  logoUrl?: string;
  ctaUrl?: string;
  emailContact?: string;
  websiteUrl?: string;
  year?: number;
  assetBaseUrl?: string;
};

export { DEFAULT_EMAIL_ASSET_BASE, emailAssetUrl };

export function renderShipConfirmationEmail(
  data: ShipConfirmationData,
  attachmentUrls: string[] = [],
): string {
  const assetBase = data.assetBaseUrl ?? DEFAULT_EMAIL_ASSET_BASE;
  const so = esc(data.so);
  const customer = displayOrNone(data.customer);
  const carrier = displayOrNone(data.carrier);
  const shippedAt = displayOrNone(data.shippedAt);
  const shippedBy = displayOrNone(data.shippedBy);
  const containers = displayOrNone(data.containers);
  const weight = displayOrNone(data.weight);
  const comments = displayOrNone(data.comments);
  return renderBrandedEmail({
    assetBaseUrl: assetBase,
    logoUrl: data.logoUrl,
    title: "Your order has now been shipped!",
    preview: `SO# ${so} for ${customer} has shipped via ${carrier}.`,
    subtitle: "Order details:",
    attachmentUrls,
    ctaUrl: data.ctaUrl,
    emailContact: data.emailContact,
    websiteUrl: data.websiteUrl,
    year: data.year,
    cards: [
      {
        iconKey: "icon-clipboard",
        title: "ORDER SUMMARY",
        accent: "orange",
        rows: [
          { label: "SO#", value: so || "None" },
          { label: "Customer", value: customer },
        ],
      },
      {
        iconKey: "icon-truck",
        title: "SHIPPING INFORMATION",
        accent: "blue",
        rows: [
          { label: "Carrier", value: carrier },
          { label: "Shipped At", value: shippedAt },
          { label: "Shipped By", value: shippedBy },
        ],
      },
      {
        iconKey: "icon-cargo",
        title: "CARGO DETAILS",
        accent: "orange",
        rows: [
          { label: "Container(s)", value: containers },
          { label: "Total Weight (In lbs)", value: weight },
        ],
      },
      {
        iconKey: "icon-chat",
        title: "ADDITIONAL NOTES",
        accent: "blue",
        rows: [{ label: "Comments", value: comments }],
      },
    ],
  });
}

export function renderShipConfirmationPlain(data: ShipConfirmationData): string {
  return [
    "Your order has now been shipped!",
    "",
    "Order details:",
    `SO#: ${data.so || "None"}`,
    `Customer: ${data.customer || "None"}`,
    `Carrier: ${data.carrier || "None"}`,
    `Shipped At: ${data.shippedAt || "None"}`,
    `Shipped By: ${data.shippedBy || "None"}`,
    `Container(s): ${data.containers || "None"}`,
    `Total Weight (lbs): ${data.weight || "None"}`,
    `Comments: ${data.comments || "None"}`,
  ].join("\n");
}

export function isShipConfirmationType(
  notificationType: string | undefined | null,
): boolean {
  const t = String(notificationType ?? "").trim().toLowerCase();
  return t === "ship_confirm" || t === "quick_ship";
}

export function shipDataFromPayload(
  body: Record<string, unknown>,
): ShipConfirmationData {
  const pick = (...keys: string[]): string => {
    for (const k of keys) {
      const v = body[k];
      if (v != null && String(v).trim()) return String(v).trim();
    }
    return "";
  };
  const assetBase = pick("asset_base_url", "assetBaseUrl") ||
    DEFAULT_EMAIL_ASSET_BASE;
  const logoFromPayload = pick("logo_url", "logoUrl");
  return {
    so: pick("so", "so_number"),
    customer: pick("customer"),
    carrier: pick("carrier"),
    shippedAt: pick("shipped_at", "shippedAt"),
    shippedBy: pick("shipped_by", "shippedBy"),
    containers: pick("containers", "type", "container"),
    weight: pick("weight"),
    comments: pick("comments"),
    // Optional payload logo override; branded layout always uses light SLST logo.
    logoUrl: logoFromPayload || undefined,
    ctaUrl: pick("cta_url", "ctaUrl", "tracking_url", "trackingUrl") ||
      undefined,
    emailContact: pick("email_contact", "emailContact") || undefined,
    websiteUrl: pick("website_url", "websiteUrl") ||
      "https://www.swiftsupply.ca",
    assetBaseUrl: assetBase,
  };
}
