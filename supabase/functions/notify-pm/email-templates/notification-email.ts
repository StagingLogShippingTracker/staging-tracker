/**
 * Branded HTML for non-ship PM notifications (return, PO, etc.).
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
    subtitle: "The following return was reported from SLST:",
    cards: [
      {
        iconKey: "icon-clipboard",
        title: "RETURN DETAILS",
        rows: [
          { label: "SO#", value: so },
          { label: "Customer", value: customer },
        ],
      },
      {
        iconKey: "icon-chat",
        title: "NOTES",
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
    subtitle: "An order was returned to stock from SLST:",
    cards: [
      {
        iconKey: "icon-truck",
        title: "RETURN TO STOCK",
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
  const customer = displayOrNone(pick(body, "customer"));
  const so = displayOrNone(pick(body, "so", "so_number", "linked_so", "linkedSo"));
  const details = displayOrNone(pick(body, "details", "comments", "notes"));
  const rows: Array<{ label: string; value: string }> = [
    { label: "PO#", value: po },
    { label: "Customer", value: customer },
  ];
  if (so !== "None") rows.push({ label: "Linked SO#", value: so });
  return renderBrandedEmail({
    ...baseFromBody(body, attachmentUrls),
    title: "PO notification",
    preview: `PO notification: ${po}`,
    subtitle: "Purchase order notification from SLST:",
    cards: [
      {
        iconKey: "icon-clipboard",
        title: "PO NOTIFICATION",
        rows,
      },
      {
        iconKey: "icon-chat",
        title: "DETAILS",
        rows: [{ label: "Notes", value: details }],
      },
    ],
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
    default:
      return null;
  }
}
