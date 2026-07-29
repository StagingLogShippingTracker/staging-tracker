/**
 * Branded HTML for non-ship PM notifications — SST Industrial Command Center shell.
 */

import {
  DEFAULT_EMAIL_ASSET_BASE,
  displayOrNone,
  renderBrandedEmail,
  type AccentTone,
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
    sectionTitle: "Notifications",
  };
}

export function renderReturnNotificationEmail(
  body: Record<string, unknown>,
  attachmentUrls: string[] = [],
): string {
  const soRaw = pick(body, "so", "so_number");
  const so = displayOrNone(soRaw);
  const customer = displayOrNone(pick(body, "customer"));
  const details = displayOrNone(pick(body, "details", "comments", "notes"));
  return renderBrandedEmail({
    ...baseFromBody(body, attachmentUrls),
    statusLabel: "Return",
    statusTone: "amber",
    title: "Return notification",
    preview: `Return notification for SO ${so}`,
    subtitle: "Return recorded in SST",
    hero: {
      eyebrow: "Return",
      value: soRaw || "—",
      unit: "SO#",
      stats: [
        { label: "Customer", value: pick(body, "customer") || "None", accent: "sky" },
      ],
    },
    cards: [
      {
        title: "Return details",
        accent: "amber",
        rows: [
          { label: "SO#", value: so },
          { label: "Customer", value: customer },
        ],
      },
      {
        title: "Notes",
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
  const soRaw = pick(body, "so", "so_number");
  const so = displayOrNone(soRaw);
  const customer = displayOrNone(pick(body, "customer"));
  const reason = displayOrNone(pick(body, "reason"));
  const pickedBy = displayOrNone(pick(body, "picked_by", "pickedBy"));
  const returnedBy = displayOrNone(pick(body, "returned_by", "returnedBy"));
  return renderBrandedEmail({
    ...baseFromBody(body, attachmentUrls),
    statusLabel: "Returned",
    statusTone: "mint",
    title: "Returned to stock",
    preview: `SO ${so} returned to stock`,
    subtitle: "Stock return recorded in SST",
    hero: {
      eyebrow: "Stock return",
      value: soRaw || "—",
      unit: "SO#",
      stats: [
        { label: "Customer", value: pick(body, "customer") || "None", accent: "sky" },
        { label: "Returned by", value: pick(body, "returned_by", "returnedBy") || "None", accent: "mint" },
      ],
    },
    cards: [
      {
        title: "Return to stock",
        accent: "mint",
        rows: [
          { label: "SO#", value: so },
          { label: "Customer", value: customer },
          { label: "Picked By", value: pickedBy },
          { label: "Returned By", value: returnedBy },
        ],
      },
      {
        title: "Reason",
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
  const poRaw = pick(body, "po", "po_number");
  const po = displayOrNone(poRaw);
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
    statusLabel: "PO",
    statusTone: "amber",
    title: "PO notification",
    preview: `PO notification: ${po}`,
    subtitle: "Purchase order update from SST",
    hero: {
      eyebrow: "Purchase order",
      value: poRaw || "—",
      unit: "PO#",
      stats: [
        { label: "Vendor", value: pick(body, "vendor", "customer") || "None", accent: "sky" },
      ],
    },
    cards: [
      {
        title: "PO notification",
        accent: "amber",
        rows,
      },
      {
        title: "Details",
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
  const tones: AccentTone[] = ["amber", "sky", "mint", "purple"];
  const cards = list.slice(0, 12).map((item, i) => {
    const row = (item && typeof item === "object")
      ? item as Record<string, unknown>
      : {};
    const po = displayOrNone(pick(row, "po", "po_number"));
    const vendor = displayOrNone(pick(row, "vendor", "customer"));
    const containers = displayOrNone(pick(row, "containers", "type"));
    const details = displayOrNone(pick(row, "details", "comments", "notes"));
    return {
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
      title: "Bulk PO",
      accent: "amber" as AccentTone,
      rows: [{ label: "POs", value: "None" }],
    });
  }
  return renderBrandedEmail({
    ...baseFromBody(body, attachmentUrls),
    statusLabel: "Bulk PO",
    statusTone: "purple",
    title: "Bulk PO notification",
    preview: `Bulk PO notification (${list.length} POs)`,
    subtitle: `${list.length} purchase order${list.length === 1 ? "" : "s"} from SST`,
    hero: {
      eyebrow: "Bulk receiving",
      value: String(list.length),
      unit: "POs",
      stats: [
        { label: "Status", value: "Queued", accent: "purple" },
      ],
    },
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
