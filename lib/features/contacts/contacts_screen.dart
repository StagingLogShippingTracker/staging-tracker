import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../shared/industrial_widgets.dart';
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

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: IndustrialTheme.darkBase,
      child: Column(
      children: [
        Padding(
          padding: slstPagePadding(context, top: 16, bottom: 8),
          child: const IndustrialPageTitle('Contacts'),
        ),
        Padding(
          padding: slstPagePadding(context, top: 0, bottom: 8),
          child: SearchField(
            controller: _search,
            hint: 'Search name, email, branch…',
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: contacts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Failed to load contacts: $e')),
            data: (list) {
              final filtered = list.where((c) {
                if (_q.isEmpty) return true;
                final hay =
                    '${c.name} ${c.designation} ${c.email} ${c.branch} ${c.ext}'
                        .toLowerCase();
                return hay.contains(_q);
              }).toList()
                ..sort((a, b) => a.name.compareTo(b.name));
              if (filtered.isEmpty) {
                return const Center(child: Text('No contacts match.'));
              }
              return ListView.builder(
                padding: slstPagePadding(context, top: 0, bottom: 12),
                itemCount: filtered.length + 1,
                itemBuilder: (context, i) {
                  if (i == filtered.length) return const BrandFooter();
                  final c = filtered[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: IndustrialTheme.skyBlue.withValues(alpha: 0.18),
                            child: Text(
                              _initials(c.name),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: IndustrialTheme.skyBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontSize: 15),
                                ),
                                Text(
                                  c.designation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  '${c.branch} · Ext ${c.ext}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (c.email.contains('@'))
                            IconButton.filledTonal(
                              tooltip: c.email,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    SlstColors.blue.withValues(alpha: 0.1),
                                foregroundColor: SlstColors.blue,
                              ),
                              onPressed: () => launchUrl(
                                Uri(scheme: 'mailto', path: c.email),
                              ),
                              icon: const Icon(Icons.email_outlined, size: 20),
                            ),
                          if (c.mobile.isNotEmpty)
                            IconButton.filledTonal(
                              tooltip: 'Mobile ${c.mobile}',
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    SlstColors.green.withValues(alpha: 0.1),
                                foregroundColor: SlstColors.green,
                              ),
                              onPressed: () => launchUrl(
                                Uri(scheme: 'tel', path: c.mobile),
                              ),
                              icon:
                                  const Icon(Icons.smartphone, size: 20),
                            ),
                          if (c.direct.isNotEmpty)
                            IconButton.filledTonal(
                              tooltip: 'Direct ${c.direct}',
                              style: IconButton.styleFrom(
                                backgroundColor: IndustrialTheme.skyBlue.withValues(alpha: 0.18),
                                foregroundColor: SlstColors.brand,
                              ),
                              onPressed: () => launchUrl(
                                Uri(scheme: 'tel', path: c.direct),
                              ),
                              icon: const Icon(Icons.phone, size: 20),
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
    ),
    );
  }
}
