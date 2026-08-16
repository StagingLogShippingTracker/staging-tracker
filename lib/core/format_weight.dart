import 'package:intl/intl.dart';

final _weightIntFormat = NumberFormat('#,##0', 'en_US');

/// Formats a stored weight for on-screen display (e.g. `12222` → `12,222`).
///
/// Keeps an optional unit suffix (`lbs`, `kg`). Values that are not numeric
/// are returned unchanged. Does not mutate stored data.
String formatWeightDisplay(String? raw, {String empty = ''}) {
  final value = (raw ?? '').trim();
  if (value.isEmpty || value == '—') {
    return value.isEmpty ? empty : value;
  }

  final match = RegExp(
    r'^([+-]?)(\d{1,3}(?:,\d{3})*|\d+)(?:\.(\d+))?\s*(.*)$',
  ).firstMatch(value);
  if (match == null) return value;

  final sign = match.group(1) ?? '';
  final digits = (match.group(2) ?? '').replaceAll(',', '');
  final fraction = match.group(3);
  final unit = (match.group(4) ?? '').trim();
  final whole = int.tryParse(digits);
  if (whole == null) return value;

  final grouped = '$sign${_weightIntFormat.format(whole)}';
  final number = fraction == null ? grouped : '$grouped.$fraction';
  if (unit.isEmpty) return number;
  return '$number $unit';
}
