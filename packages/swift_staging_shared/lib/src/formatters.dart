import 'package:intl/intl.dart';

final _shipNotifyFmt = DateFormat('M/d/yyyy, h:mm:ss a');
final _localAuditFmt = DateFormat('M/d/yy h:mm a');
final _ymdFmt = DateFormat('yyyy-MM-dd');

/// Timestamp used in ship / quick-ship PM notification payloads.
String formatShipNotificationTimestamp([DateTime? at]) =>
    _shipNotifyFmt.format(at ?? DateTime.now());

/// Compact local timestamp for audit / history UI.
String formatLocalAuditTimestamp(DateTime at) => _localAuditFmt.format(at);

/// Calendar date only.
String formatYmd(DateTime at) => _ymdFmt.format(at);
