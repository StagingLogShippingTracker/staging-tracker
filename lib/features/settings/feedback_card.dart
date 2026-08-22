import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';

/// Warehouse feedback inbox — Settings → Feedback (mirrors shipping-label Help).
const kWarehouseFeedbackEmail = 'warehouse2@swiftsupply.ca';

/// Roster name Make / contacts use for [kWarehouseFeedbackEmail].
const kWarehouseFeedbackPmName = 'Warehouse 2';

/// Make PM-email scenario matches `*_notification` types (PO / return).
const kWarehouseFeedbackNotificationType = 'feedback_notification';

/// Settings card that opens an authenticated feedback form emailed via notify-pm.
class FeedbackCard extends ConsumerWidget {
  const FeedbackCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.feedback_outlined,
                  size: 20,
                  color: IndustrialTheme.chromeAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  'Feedback',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: IndustrialTheme.chromeOf(context).ink,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'SEND TO WAREHOUSE',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Report bugs, request features, or share notes with '
              '$kWarehouseFeedbackEmail.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                openFeedbackForm(
                  context,
                  prefillContact: user?.email,
                );
              },
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Send feedback'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openFeedbackForm(
  BuildContext context, {
  String? prefillContact,
  String? prefillName,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _FeedbackFormDialog(
      prefillContact: prefillContact,
      prefillName: prefillName,
    ),
  );
}

class _FeedbackFormDialog extends ConsumerStatefulWidget {
  const _FeedbackFormDialog({
    this.prefillContact,
    this.prefillName,
  });

  final String? prefillContact;
  final String? prefillName;

  @override
  ConsumerState<_FeedbackFormDialog> createState() =>
      _FeedbackFormDialogState();
}

class _FeedbackFormDialogState extends ConsumerState<_FeedbackFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _summary;
  late final TextEditingController _details;
  var _category = 'General';
  var _sending = false;
  String _installedVersion = '';

  static const _categories = [
    'General',
    'Bug / crash',
    'Staging / inventory',
    'Shipping / notifications',
    'Update / installer',
    'Feature request',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.prefillName ?? '');
    _contact = TextEditingController(text: widget.prefillContact ?? '');
    _summary = TextEditingController();
    _details = TextEditingController();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _installedVersion = '${info.version}+${info.buildNumber}');
    } catch (_) {}
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _summary.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final details = _details.text.trim();
    if (details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a message before sending.')),
      );
      return;
    }

    setState(() => _sending = true);
    final summary = _summary.text.trim();
    final name = _name.text.trim();
    final contact = _contact.text.trim();
    final subjectSummary = summary.isEmpty ? _category : summary;
    final platform = Platform.isWindows
        ? 'windows'
        : Platform.isAndroid
            ? 'android'
            : Platform.operatingSystem;

    try {
      await ref.read(notifyRepoProvider).sendPmNotification({
        'to': kWarehouseFeedbackEmail,
        'to_email': kWarehouseFeedbackEmail,
        'email': kWarehouseFeedbackEmail,
        'pm_email': kWarehouseFeedbackEmail,
        'recipient': kWarehouseFeedbackEmail,
        // Make Outlook module rejects empty CC; match other PM emails.
        'cc': 'warehouse1@swiftsupply.ca',
        'subject': 'Swift Staging & Shipping Log feedback: $subjectSummary',
        'notification_type': kWarehouseFeedbackNotificationType,
        'category': _category,
        'name': name,
        'contact': contact,
        'summary': summary,
        'details': details,
        'message': details,
        'app_version': _installedVersion,
        'platform': platform,
        'pm_name': kWarehouseFeedbackPmName,
        // Same legacy key PO notifications send for older Make mappings.
        'customer': 'App feedback',
        'body':
            'Swift Staging & Shipping Log feedback<br><br>'
            '<b>Category</b> | $_category<br>'
            '<b>Name</b> | ${name.isEmpty ? '(not provided)' : name}<br>'
            '<b>Contact</b> | ${contact.isEmpty ? '(not provided)' : contact}<br>'
            '<b>Summary</b> | ${summary.isEmpty ? '(none)' : summary}<br>'
            '<b>Version</b> | ${_installedVersion.isEmpty ? '(unknown)' : _installedVersion}<br>'
            '<b>Platform</b> | $platform<br><br>'
            '$details',
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback sent. Thank you.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send feedback: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send feedback'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your message is emailed to $kWarehouseFeedbackEmail '
                'via the secure notify-pm server (no sign-in required).',
                style: TextStyle(
                  color: IndustrialTheme.chromeOf(context).muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _category,
                decoration: const InputDecoration(labelText: 'CATEGORY'),
                items: [
                  for (final c in _categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'YOUR NAME (OPTIONAL)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contact,
                decoration: const InputDecoration(
                  labelText: 'EMAIL / PHONE (OPTIONAL)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _summary,
                decoration: const InputDecoration(labelText: 'SUMMARY'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _details,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'MESSAGE',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _submit,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined, size: 18),
          label: Text(_sending ? 'Sending…' : 'Submit'),
        ),
      ],
    );
  }
}
