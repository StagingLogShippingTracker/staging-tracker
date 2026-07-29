/**
 * SST ship-confirmation HTML email — Industrial Command Center shell.
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
    sectionTitle: "Shipped Staging Entries Log",
    statusLabel: "Shipped",
    statusTone: "mint",
    title: "Your order has now been shipped",
    preview: `SO# ${so} for ${customer} has shipped via ${carrier}.`,
    subtitle: "Shipment recorded in SST — industrial staging & shipping ops",
    hero: {
      eyebrow: "Shipment",
      value: so || "—",
      unit: "SO#",
      stats: [
        { label: "Customer", value: data.customer?.trim() || "None", accent: "sky" },
        { label: "Carrier", value: data.carrier?.trim() || "None", accent: "mint" },
        { label: "Weight", value: `${data.weight?.trim() || "—"} lbs`, accent: "amber" },
      ],
    },
    attachmentUrls,
    ctaUrl: data.ctaUrl,
    ctaLabel: "Open Swift Supply",
    emailContact: data.emailContact,
    websiteUrl: data.websiteUrl,
    year: data.year,
    cards: [
      {
        title: "Order summary",
        accent: "amber",
        rows: [
          { label: "SO#", value: so || "None" },
          { label: "Customer", value: customer },
        ],
      },
      {
        title: "Shipping information",
        accent: "sky",
        rows: [
          { label: "Carrier", value: carrier },
          { label: "Shipped At", value: shippedAt },
          { label: "Shipped By", value: shippedBy },
        ],
      },
      {
        title: "Cargo details",
        accent: "mint",
        rows: [
          { label: "Container(s)", value: containers },
          { label: "Total Weight (In lbs)", value: weight },
        ],
      },
      {
        title: "Additional notes",
        accent: "purple",
        rows: [{ label: "Comments", value: comments }],
      },
    ],
  });
}

export function renderShipConfirmationPlain(data: ShipConfirmationData): string {
  return [
    "SST — Staging & Shipping Tracker",
    "Your order has now been shipped",
    "",
    "Shipment details:",
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
    logoUrl: logoFromPayload || undefined,
    ctaUrl: pick("cta_url", "ctaUrl", "tracking_url", "trackingUrl") ||
      undefined,
    emailContact: pick("email_contact", "emailContact") || undefined,
    websiteUrl: pick("website_url", "websiteUrl") ||
      "https://www.swiftsupply.ca",
    assetBaseUrl: assetBase,
  };
}
