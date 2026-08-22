class StagingEntry {
  StagingEntry({
    required this.id,
    required this.so,
    required this.customer,
    required this.status,
    required this.location,
    required this.type,
    required this.qty,
    this.weight,
    this.comments,
    this.stagedBy,
    this.photoUrls = const [],
    this.entryDate,
  });

  final String id;
  final String so;
  final String customer;
  final String status;
  final String location;
  final String type;
  final int qty;
  final String? weight;
  final String? comments;
  final String? stagedBy;
  final List<String> photoUrls;
  final DateTime? entryDate;

  factory StagingEntry.fromMap(Map<String, dynamic> m) {
    return StagingEntry(
      id: '${m['id']}',
      so: (m['so'] ?? '').toString(),
      customer: (m['customer'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      location: (m['location'] ?? '').toString(),
      type: (m['type'] ?? '').toString(),
      qty: _asInt(m['qty']),
      weight: m['weight']?.toString(),
      comments: m['comments']?.toString(),
      stagedBy: m['staged_by']?.toString(),
      photoUrls: _asStringList(m['photo_urls']),
      entryDate: _asDate(m['entry_date']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'so': so,
        'customer': customer,
        'status': status,
        'location': location,
        'type': type,
        'qty': qty,
        'weight': weight,
        'comments': comments,
        'staged_by': stagedBy,
        'photo_urls': photoUrls,
      };
}

class ShippedEntry {
  ShippedEntry({
    required this.id,
    required this.so,
    required this.customer,
    required this.carrier,
    required this.location,
    required this.type,
    required this.qty,
    this.weight,
    this.comments,
    this.shippedBy,
    this.pmdEmail,
    this.photoUrls = const [],
    this.shippedAt,
    this.notificationStatus = 'none',
    this.notificationError,
    this.notifiedAt,
  });

  final String id;
  final String so;
  final String customer;
  final String carrier;
  final String location;
  final String type;
  final int qty;
  final String? weight;
  final String? comments;
  final String? shippedBy;
  final String? pmdEmail;
  final List<String> photoUrls;
  final DateTime? shippedAt;
  final String notificationStatus;
  final String? notificationError;
  final DateTime? notifiedAt;

  bool get notificationSent => notificationStatus == 'sent';
  bool get notificationFailed => notificationStatus == 'failed';
  bool get notificationPending => notificationStatus == 'pending';

  factory ShippedEntry.fromMap(Map<String, dynamic> m) {
    return ShippedEntry(
      id: '${m['id']}',
      so: (m['so'] ?? '').toString(),
      customer: (m['customer'] ?? '').toString(),
      carrier: (m['carrier'] ?? '').toString(),
      location: (m['location'] ?? '').toString(),
      type: (m['type'] ?? '').toString(),
      qty: _asInt(m['qty']),
      weight: m['weight']?.toString(),
      comments: m['comments']?.toString(),
      shippedBy: m['shipped_by']?.toString(),
      pmdEmail: m['pmd_email']?.toString(),
      photoUrls: _asStringList(m['photo_urls']),
      shippedAt: _asDate(m['shipped_at']),
      notificationStatus: (m['notification_status'] ?? 'none').toString(),
      notificationError: m['notification_error']?.toString(),
      notifiedAt: _asDate(m['notified_at']),
    );
  }
}

class ChangelogEntry {
  ChangelogEntry({
    required this.id,
    required this.tableName,
    required this.action,
    required this.userEmail,
    this.createdAt,
  });

  final String id;
  final String tableName;
  final String action;
  final String userEmail;
  final DateTime? createdAt;

  factory ChangelogEntry.fromMap(Map<String, dynamic> m) {
    return ChangelogEntry(
      id: '${m['id']}',
      tableName: (m['table_name'] ?? '').toString(),
      action: (m['action'] ?? '').toString(),
      userEmail: (m['user_email'] ?? '').toString(),
      createdAt: _asDate(m['created_at']),
    );
  }
}

/// Append-only row from [notification_log] (written by notify-pm).
class NotificationLogEntry {
  NotificationLogEntry({
    required this.id,
    required this.notificationType,
    required this.status,
    required this.channel,
    this.pmName,
    this.pmEmail,
    this.so,
    this.po,
    this.customer,
    this.vendor,
    this.carrier,
    this.subject,
    this.sentBy,
    this.errorDetail,
    this.payload = const {},
    this.createdAt,
  });

  final String id;
  final String notificationType;
  final String status;
  final String channel;
  final String? pmName;
  final String? pmEmail;
  final String? so;
  final String? po;
  final String? customer;
  final String? vendor;
  final String? carrier;
  final String? subject;
  final String? sentBy;
  final String? errorDetail;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  String get typeLabel {
    switch (notificationType) {
      case 'ship_confirm':
      case 'ship_notification':
        return 'Ship confirm';
      case 'quick_ship':
        return 'Quick ship';
      case 'return_to_stock':
      case 'return_to_stock_notification':
        return 'Return to stock';
      case 'po_notification':
        return 'PO';
      case 'bulk_po_notification':
        return 'Bulk PO';
      case 'return_notification':
        return 'Return';
      case 'feedback':
      case 'feedback_notification':
        return 'Feedback';
      default:
        return notificationType.isEmpty ? 'Unknown' : notificationType;
    }
  }

  factory NotificationLogEntry.fromMap(Map<String, dynamic> m) {
    final rawPayload = m['payload'];
    return NotificationLogEntry(
      id: '${m['id']}',
      notificationType: (m['notification_type'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      channel: (m['channel'] ?? 'email').toString(),
      pmName: m['pm_name']?.toString(),
      pmEmail: m['pm_email']?.toString(),
      so: m['so']?.toString(),
      po: m['po']?.toString(),
      customer: m['customer']?.toString(),
      vendor: m['vendor']?.toString(),
      carrier: m['carrier']?.toString(),
      subject: m['subject']?.toString(),
      sentBy: m['sent_by']?.toString(),
      errorDetail: m['error_detail']?.toString(),
      payload: rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : const {},
      createdAt: _asDate(m['created_at']),
    );
  }
}

/// Query options for [NotificationLogRepository.list].
class NotificationLogQuery {
  const NotificationLogQuery({
    this.from,
    this.to,
    this.year,
    this.month,
    this.pmName,
    this.notificationType,
    this.status,
    this.channel,
    this.search,
    this.sortBy = NotificationLogSort.createdAt,
    this.ascending = false,
    this.limit = 500,
  });

  final DateTime? from;
  final DateTime? to;
  final int? year;
  final int? month;
  final String? pmName;
  final String? notificationType;
  final String? status;
  final String? channel;
  final String? search;
  final NotificationLogSort sortBy;
  final bool ascending;
  final int limit;
}

enum NotificationLogSort { createdAt, pmName, notificationType, status }

class ContactPerson {
  ContactPerson({
    required this.name,
    required this.designation,
    required this.email,
    required this.ext,
    required this.direct,
    required this.mobile,
    required this.branch,
  });

  final String name;
  final String designation;
  final String email;
  final String ext;
  final String direct;
  final String mobile;
  final String branch;

  factory ContactPerson.fromMap(Map<String, dynamic> m) {
    return ContactPerson(
      name: (m['name'] ?? '').toString(),
      designation: (m['designation'] ?? '').toString(),
      email: (m['email'] ?? '').toString(),
      ext: (m['ext'] ?? '').toString(),
      direct: (m['direct'] ?? '').toString(),
      mobile: (m['mobile'] ?? '').toString(),
      branch: (m['branch'] ?? '').toString(),
    );
  }
}

class PhotoBytes {
  const PhotoBytes({required this.bytes, required this.name});
  final List<int> bytes;
  final String name;
}

class ContainerCounts {
  const ContainerCounts({
    this.skids = 0,
    this.boxes = 0,
    this.crates = 0,
    this.pipe = 0,
    this.other = 0,
  });

  final int skids;
  final int boxes;
  final int crates;
  final int pipe;
  final int other;

  int get total => skids + boxes + crates + pipe + other;

  bool sameCounts(ContainerCounts o) =>
      skids == o.skids &&
      boxes == o.boxes &&
      crates == o.crates &&
      pipe == o.pipe &&
      other == o.other;

  ContainerCounts operator +(ContainerCounts o) => ContainerCounts(
        skids: skids + o.skids,
        boxes: boxes + o.boxes,
        crates: crates + o.crates,
        pipe: pipe + o.pipe,
        other: other + o.other,
      );

  factory ContainerCounts.parse(String type) {
    var skids = 0, boxes = 0, crates = 0, pipe = 0, other = 0;
    for (final part in type.split(',')) {
      final seg = part.trim().toLowerCase();
      if (seg.isEmpty) continue;
      final n = int.tryParse(RegExp(r'^\d+').stringMatch(seg) ?? '') ?? 1;
      if (seg.contains('skid')) {
        skids += n;
      } else if (seg.contains('box')) {
        boxes += n;
      } else if (seg.contains('crate')) {
        crates += n;
      } else if (seg.contains('pipe') || seg.contains('rod')) {
        pipe += n;
      } else {
        other += n;
      }
    }
    return ContainerCounts(
      skids: skids,
      boxes: boxes,
      crates: crates,
      pipe: pipe,
      other: other,
    );
  }

  String get typeLabel {
    final parts = <String>[];
    if (skids > 0) parts.add(_fmt(skids, 'Skid'));
    if (boxes > 0) parts.add(_fmt(boxes, 'Box'));
    if (crates > 0) parts.add(_fmt(crates, 'Crate'));
    if (pipe > 0) parts.add(_fmt(pipe, 'Pipe/Rod'));
    if (other > 0) parts.add(_fmt(other, 'Other'));
    return parts.join(', ');
  }

  static String _fmt(int n, String singular) {
    final plural = switch (singular) {
      'Box' => 'Boxes',
      'Pipe/Rod' => 'Pipe/Rod',
      'Other' => 'Other',
      _ => '${singular}s',
    };
    return n == 1 ? '1 $singular' : '$n $plural';
  }
}

int _asInt(dynamic v) {
  if (v is int) return v;
  return int.tryParse('$v') ?? 0;
}

List<String> _asStringList(dynamic v) {
  if (v is List) {
    return v.map((e) => '$e').where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse('$v');
}
