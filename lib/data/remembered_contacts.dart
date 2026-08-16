import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Local MRU cache of person names, matching Document Generator
/// `remembered_contacts.json` (most recent first, max 60).
class RememberedContactsStore {
  RememberedContactsStore();

  static const maxRememberedContacts = 60;
  static const fileName = 'remembered_contacts.json';

  List<String> names = [];

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, fileName));
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        names = [];
        return;
      }
      final body = jsonDecode(await file.readAsString());
      if (body is! List) {
        names = [];
        return;
      }
      final out = <String>[];
      final seen = <String>{};
      for (final raw in body) {
        final name = '$raw'.trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        if (seen.contains(key)) continue;
        seen.add(key);
        out.add(name);
        if (out.length >= maxRememberedContacts) break;
      }
      names = out;
    } catch (_) {
      names = [];
    }
  }

  Future<void> save() async {
    final file = await _file();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(names),
    );
  }

  /// Returns true when the in-memory list changed.
  Future<bool> remember(String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return false;
    final key = name.toLowerCase();
    final existingIdx = names.indexWhere((n) => n.toLowerCase() == key);
    if (existingIdx == 0) return false;
    final next = <String>[name];
    for (final n in names) {
      if (n.toLowerCase() == key) continue;
      next.add(n);
      if (next.length >= maxRememberedContacts) break;
    }
    names = next;
    await save();
    return true;
  }

  Future<bool> forget(String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return false;
    final key = name.toLowerCase();
    final next = names.where((n) => n.toLowerCase() != key).toList();
    if (next.length == names.length) return false;
    names = next;
    await save();
    return true;
  }

  Future<void> clear() async {
    names = [];
    await save();
  }
}

/// Typeahead filter used by Document Generator [EmployeeDirectory.filter].
Iterable<String> filterPersonNames(
  List<String> names,
  String query, {
  int limit = 24,
}) {
  if (names.isEmpty) return const Iterable<String>.empty();
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return names.take(limit);
  final starts = <String>[];
  final contains = <String>[];
  for (final n in names) {
    final lower = n.toLowerCase();
    if (lower.startsWith(q)) {
      starts.add(n);
    } else if (lower.contains(q)) {
      contains.add(n);
    }
    if (starts.length + contains.length >= limit * 2) break;
  }
  return [...starts, ...contains].take(limit);
}
