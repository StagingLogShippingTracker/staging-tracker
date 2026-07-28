/**
 * Branded HTML for non-ship PM notifications (return, PO, etc.) — SST industrial.
 */

import {
  DEFAULT_EMAIL_ASSET_BASE,
  displayOrNone,
  renderBrandedEmail,
} from "./email-shared.ts";

function pick(body: Record<string, unknown>, ...keys: string[]): string {
  for (const k of keys) {
    const v = body[k];
    if (v != null && String(v).trim()) return String(v).trim();
  }
  return "";
}

function baseFromBody(
  body: Record<string, unknown>,
  attachmentUrls: string[],
) {
  const assetBase = pick(body, "asset_base_url", "assetBaseUrl") ||
    DEFAULT_EMAIL_ASSET_BASE;
  return {
    assetBaseUrl: assetBase,
    attachmentUrls,
  };
}

export function renderReturnNotificationEmail(
  body: Record<string, unknown>,
  attachmentUrls: string[] = [],
): string {
  const so = displayOrNone(pick(body, "so", "so_number"));
  const customer = displayOrNone(pick(body, "customer"));
  const details = displayOrNone(pick(body, "details", "comments", "notes"));
  return renderBrandedEmail({
    ...baseFromBody(body, attachmentUrls),
    title: "Return notification",
    preview: `Return notification for SO ${so}`,
    subtitle: "Return details:",
    cards: [
      {
        iconKey: "icon-clipboard",
        title: "RETURN DETAILS",
        accent: "amber",
        rows: [
          { label: "SO#", value: so },
          { label: "Customer", value: customer },
        ],
      },
      {
        iconKey: "icon-chat",
        title: "NOTES",
        accent: "purple",
        rows: [{ label: "Details", value: details }],
      },
    ],
  });
}

export function renderReturnToStockEmail(
  body: Record<string, unknown>,
  attachmentUrls: string[] = [],
): string {
  const so = displayOrNone(pick(body, "so", "so_number"));
  const customer = displayOrNone(pick(body, "customer"));
  const reason = displayOrNone(pick(body, "reason"));
  const pickedBy = displayOrNone(pick(body, "picked_by", "pickedBy"));
  const returnedBy = displayOrNone(pick(body, "returned_by", "returnedBy"));
  return renderBrandedEmail({
    ...baseFromBody(body, attachmentUrls),
    title: "Returned to stock",
    preview: `SO ${so} returned to stock`,
    subtitle: "Stock return details:",
    cards: [
      {
        iconKey: "icon-truck",
        title: "RETURN TO STOCK",
        accent: "mint",
        rows: [
          { label: "SO#", value: so },
          { label: "Customer", value: customer },
          { label: "Picked By", value: pickedBy },
          { label: "Returned By", value: returnedBy },
        ],
      },
      {
        iconKey: "icon-chat",
        title: "REASON",
        accent: "sky",
        rows: [{ label: "Reason", value: reason }],
      },
    ],
  });
}

export function renderPoNotificationEmail(
  body: Record<string, unknown>,
  attachmentUrls: string[] = [],
): string {
  const po = displayOrNone(pick(body, "po", "po_number"));
  const vendor = displayOrNone(pick(body, "vendor", "customer"));
  const so = displayOrNone(pick(body, "so", "so_number", "linked_so", "linkedSo"));
  const details = displayOrNone(pick(body, "details", "comments", "notes"));
  const rows: Array<{ label: string; value: string }> = [
    { label: "PO#", value: po },
    { label: "Vendor", value: vendor },
  ];
  if (so !== "None") rows.push({ label: "Linked SO#", value: so });
  return renderBrandedEmail({
    ...baseFromBody(body, attachmentUrls),
    title: "PO notification",
    preview: `PO notification: ${po}`,
    subtitle: "PO details:",
    cards: [
      {
        iconKey: "icon-clipboard",
        title: "PO NOTIFICATION",
        accent: "amber",
        rows,
      },
      {
        iconKey: "icon-chat",
        title: "DETAILS",
        accent: "sky",
        rows: [{ label: "Notes", value: details }],
      },
    ],
  });
}

export function renderBulkPoNotificationEmail(
  body: Record<string, unknown>,
  attachmentUrls: string[] = [],
): string {
  const raw = body.pos;
  const list = Array.isArray(raw) ? raw : [];
  const tones = ["amber", "sky", "mint", "purple"] as const;
  const cards = list.slice(0, 12).map((item, i) => {
    const row = (item && typeof item === "object")
      ? item as Record<string, unknown>
      : {};
    const po = displayOrNone(pick(row, "po", "po_number"));
    const vendor = displayOrNone(pick(row, "vendor", "customer"));
    const containers = displayOrNone(pick(row, "containers", "type"));
    const details = displayOrNone(pick(row, "details", "comments", "notes"));
    return {
      iconKey: i % 2 === 0 ? "icon-clipboard" : "icon-cargo",
      title: `PO ${po}`,
      accent: tones[i % tones.length],
      rows: [
        { label: "PO#", value: po },
        { label: "Vendor", value: vendor },
        { label: "Container(s)", value: containers },
        { label: "Notes", value: details },
      ],
    };
  });
  if (!cards.length) {
    cards.push({
      iconKey: "icon-clipboard",
      title: "BULK PO",
      accent: "amber",
      rows: [{ label: "POs", value: "None" }],
    });
  }
  return renderBrandedEmail({
    ...baseFromBody(body, attachmentUrls),
    title: "Bulk PO notification",
    preview: `Bulk PO notification (${list.length} POs)`,
    subtitle: "PO details:",
    cards,
  });
}

export function renderNotificationEmail(
  notificationType: string,
  body: Record<string, unknown>,
  attachmentUrls: string[] = [],
): string | null {
  const t = notificationType.trim().toLowerCase();
  switch (t) {
    case "return_notification":
      return renderReturnNotificationEmail(body, attachmentUrls);
    case "return_to_stock":
      return renderReturnToStockEmail(body, attachmentUrls);
    case "po_notification":
      return renderPoNotificationEmail(body, attachmentUrls);
    case "bulk_po_notification":
      return renderBulkPoNotificationEmail(body, attachmentUrls);
    default:
      return null;
  }
}
