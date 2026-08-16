import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'person_name_memory.dart';

const _seededFromRosterKey = 'slst.person_memory.seeded_from_roster';

/// Loads local name cache, syncs `shared_contacts`, and one-time seeds from
/// the legacy `person_by` roster (honoring cloud tombstones).
class ContactMemoryHost extends ConsumerStatefulWidget {
  const ContactMemoryHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ContactMemoryHost> createState() => _ContactMemoryHostState();
}

class _ContactMemoryHostState extends ConsumerState<ContactMemoryHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedIfNeeded());
  }

  Future<void> _seedIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seededFromRosterKey) == true) return;
    Iterable<String> seed = const [];
    try {
      seed = await ref.read(rosterRepoProvider).valuesFor(personRosterType);
    } catch (_) {}
    await ref.read(personNameMemoryProvider.notifier).sync(seedNames: seed);
    await prefs.setBool(_seededFromRosterKey, true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
