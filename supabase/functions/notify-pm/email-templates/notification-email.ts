/**
 * Branded HTML for non-ship PM notifications — Industrial Command Center shell.
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
    subtitle: "Return recorded by the Swift Nisku warehouse",
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
    subtitle: "Stock return recorded by the Swift Nisku warehouse",
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
    subtitle: "Purchase order update from the Swift Nisku warehouse",
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
    subtitle: `${list.length} purchase order${list.length === 1 ? "" : "s"} from the Swift Nisku warehouse`,
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

export function renderFeedbackEmail(
  body: Record<string, unknown>,
  attachmentUrls: string[] = [],
): string {
  const category = displayOrNone(pick(body, "category"));
  const name = displayOrNone(pick(body, "name", "sender_name", "from_name"));
  const contact = displayOrNone(
    pick(body, "contact", "reply_to", "from_email", "sender_email"),
  );
  const summary = displayOrNone(pick(body, "summary", "subject_summary"));
  const details = displayOrNone(
    pick(body, "details", "message", "comments", "notes"),
  );
  const version = displayOrNone(pick(body, "app_version", "version"));
  const platform = displayOrNone(pick(body, "platform"));
  return renderBrandedEmail({
    ...baseFromBody(body, attachmentUrls),
    statusLabel: "Feedback",
    statusTone: "sky",
    title: "App feedback",
    preview: `Feedback: ${pick(body, "summary", "category") || "message"}`,
    subtitle: "In-app feedback from Settings",
    hero: {
      eyebrow: "Feedback",
      value: pick(body, "category") || "General",
      unit: "Category",
      stats: [
        { label: "Version", value: pick(body, "app_version", "version") || "None", accent: "sky" },
        { label: "Platform", value: pick(body, "platform") || "None", accent: "mint" },
      ],
    },
    cards: [
      {
        title: "Sender",
        accent: "sky",
        rows: [
          { label: "Name", value: name },
          { label: "Contact", value: contact },
          { label: "Category", value: category },
        ],
      },
      {
        title: "Message",
        accent: "amber",
        rows: [
          { label: "Summary", value: summary },
          { label: "Details", value: details },
          { label: "Version", value: version },
          { label: "Platform", value: platform },
        ],
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
    case "bulk_po_notification":
      return renderBulkPoNotificationEmail(body, attachmentUrls);
    case "feedback":
      return renderFeedbackEmail(body, attachmentUrls);
    default:
      return null;
  }
}
