import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_state.dart';
import '../shared/widgets.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SearchField(
            controller: _search,
            hint: 'Search name, email, branch…',
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: contacts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load contacts: $e')),
            data: (list) {
              final filtered = list.where((c) {
                if (_q.isEmpty) return true;
                final hay =
                    '${c.name} ${c.designation} ${c.email} ${c.branch} ${c.ext}'
                        .toLowerCase();
                return hay.contains(_q);
              }).toList()
                ..sort((a, b) => a.name.compareTo(b.name));
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  return Card(
                    child: ListTile(
                      title: Text(
                        c.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${c.designation}\n${c.branch} · Ext ${c.ext}\n${c.email}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          if (c.email.contains('@'))
                            IconButton(
                              tooltip: 'Email',
                              onPressed: () => launchUrl(
                                Uri(scheme: 'mailto', path: c.email),
                              ),
                              icon: const Icon(Icons.email_outlined),
                            ),
                          if (c.mobile.isNotEmpty)
                            IconButton(
                              tooltip: 'Call mobile',
                              onPressed: () => launchUrl(
                                Uri(scheme: 'tel', path: c.mobile),
                              ),
                              icon: const Icon(Icons.phone_iphone),
                            ),
                          if (c.direct.isNotEmpty)
                            IconButton(
                              tooltip: 'Call direct',
                              onPressed: () => launchUrl(
                                Uri(scheme: 'tel', path: c.direct),
                              ),
                              icon: const Icon(Icons.phone),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
