import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../platform/photo_picker.dart';
import '../shared/widgets.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _po = TextEditingController();
  final _so = TextEditingController();
  final _customer = TextEditingController();
  final _pmEmail = TextEditingController();
  final _details = TextEditingController();
  bool _returnMode = false;
  bool _busy = false;
  final _photos = <PhotoBytes>[];
  final _picker = PhotoPickerService();

  @override
  void dispose() {
    _po.dispose();
    _so.dispose();
    _customer.dispose();
    _pmEmail.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      showError(context, 'Sign in required to send notifications.');
      return;
    }
    setState(() => _busy = true);
    try {
      final ops = ref.read(operationsProvider);
      if (_returnMode) {
        await ops.sendReturnNotification(
          so: _so.text.trim(),
          customer: _customer.text.trim(),
          pmEmail: _pmEmail.text.trim(),
          details: _details.text.trim(),
          photos: _photos,
        );
      } else {
        await ops.sendPoNotification(
          po: _po.text.trim(),
          customer: _customer.text.trim(),
          pmEmail: _pmEmail.text.trim(),
          linkedSo: _so.text.trim().isEmpty ? null : _so.text.trim(),
          details: _details.text.trim(),
          photos: _photos,
        );
      }
      if (mounted) {
        showOk(context, 'Notification sent');
        setState(() {
          _photos.clear();
          _details.clear();
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('PM Notifications', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Notifications are sent through an authenticated server function. '
          'Webhook credentials never ship inside the app binary.',
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('PO notify')),
            ButtonSegment(value: true, label: Text('Return notify')),
          ],
          selected: {_returnMode},
          onSelectionChanged: (s) => setState(() => _returnMode = s.first),
        ),
        const SizedBox(height: 12),
        if (!_returnMode)
          TextField(
            controller: _po,
            decoration: const InputDecoration(labelText: 'PO #'),
          ),
        if (!_returnMode) const SizedBox(height: 8),
        TextField(
          controller: _so,
          decoration: InputDecoration(
            labelText: _returnMode ? 'SO #' : 'Linked SO (optional)',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _customer,
          decoration: const InputDecoration(labelText: 'Customer'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pmEmail,
          decoration: const InputDecoration(labelText: 'PM email'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _details,
          decoration: const InputDecoration(labelText: 'Details'),
          maxLines: 4,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final files = await _picker.pickPreferred();
                setState(() => _photos.addAll(files));
              },
              icon: const Icon(Icons.attach_file),
              label: Text('Attach photos (${_photos.length})'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (_busy || user == null) ? null : _send,
          icon: const Icon(Icons.send),
          label: Text(
            user == null
                ? 'Sign in to send'
                : (_busy ? 'Sending…' : 'Send notification'),
          ),
        ),
      ],
    );
  }
}
