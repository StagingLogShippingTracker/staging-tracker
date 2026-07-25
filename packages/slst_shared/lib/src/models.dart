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
    );
  }
}

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

int _asInt(dynamic v) {
  if (v is int) return v;
  return int.tryParse('$v') ?? 0;
}

List<String> _asStringList(dynamic v) {
  if (v is List) return v.map((e) => '$e').toList();
  return const [];
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse('$v');
}
