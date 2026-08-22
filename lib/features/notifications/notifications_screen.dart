import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../../platform/photo_picker.dart';
import '../shared/entry_suggestion_fields.dart';
import '../shared/industrial_widgets.dart';
import '../shared/widgets.dart';
import 'notification_log_panel.dart';

enum _NotifyKind { po, bulkPo, returnNotify }

enum _PageMode { send, log }

class _BulkPoRow {
  _BulkPoRow()
      : po = TextEditingController(),
        vendor = TextEditingController(),
        pmEmail = TextEditingController(),
        details = TextEditingController(),
        skids = TextEditingController(),
        boxes = TextEditingController(),
        crates = TextEditingController(),
        pipe = TextEditingController(),
        other = TextEditingController();

  final TextEditingController po;
  final TextEditingController vendor;
  final TextEditingController pmEmail;
  final TextEditingController details;
  final TextEditingController skids;
  final TextEditingController boxes;
  final TextEditingController crates;
  final TextEditingController pipe;
  final TextEditingController other;
  final photos = <PhotoBytes>[];

  void dispose() {
    po.dispose();
    vendor.dispose();
    pmEmail.dispose();
    details.dispose();
    skids.dispose();
    boxes.dispose();
    crates.dispose();
    pipe.dispose();
    other.dispose();
  }

  ContainerCounts get containers => countsFromControllers(
        skids: skids,
        boxes: boxes,
        crates: crates,
        pipe: pipe,
        other: other,
      );
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _PageMode _pageMode = _PageMode.send;
  _NotifyKind _kind = _NotifyKind.po;
  final _po = TextEditingController();
  final _so = TextEditingController();
  final _vendor = TextEditingController();
  final _customer = TextEditingController();
  final _pmEmail = TextEditingController();
  final _details = TextEditingController();
  bool _busy = false;
  final _photos = <PhotoBytes>[];
  final _picker = PhotoPickerService();
  final _bulkRows = <_BulkPoRow>[_BulkPoRow()];

  @override
  void dispose() {
    _po.dispose();
    _so.dispose();
    _vendor.dispose();
    _customer.dispose();
    _pmEmail.dispose();
    _details.dispose();
    for (final row in _bulkRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final ops = ref.read(operationsProvider);
      switch (_kind) {
        case _NotifyKind.returnNotify:
          await ops.sendReturnNotification(
            so: _so.text.trim(),
            customer: _customer.text.trim(),
            pmEmail: _pmEmail.text.trim(),
            details: _details.text.trim(),
            photos: _photos,
          );
        case _NotifyKind.po:
          await ops.sendPoNotification(
            po: _po.text.trim(),
            vendor: _vendor.text.trim(),
            pmEmail: _pmEmail.text.trim(),
            linkedSo: _so.text.trim().isEmpty ? null : _so.text.trim(),
            details: _details.text.trim(),
            photos: _photos,
          );
        case _NotifyKind.bulkPo:
          final items = <BulkPoItem>[];
          for (final row in _bulkRows) {
            final po = row.po.text.trim();
            if (po.isEmpty) continue;
            final counts = row.containers;
            if (counts.total <= 0) {
              throw Exception('PO $po needs at least one container.');
            }
            final email = row.pmEmail.text.trim();
            if (!email.contains('@')) {
              throw Exception('PO $po needs a valid PM email.');
            }
            items.add(
              BulkPoItem(
                po: po,
                vendor: row.vendor.text.trim(),
                pmEmail: email,
                containers: counts,
                details: row.details.text.trim(),
                photos: List<PhotoBytes>.from(row.photos),
              ),
            );
          }
          if (items.isEmpty) {
            throw Exception('Add at least one PO with a PO #.');
          }
          await ops.sendBulkPoNotification(items: items);
      }
      if (mounted) {
        showOk(context, 'Notification sent');
        setState(() {
          _photos.clear();
          _details.clear();
          for (final row in _bulkRows) {
            row.photos.clear();
          }
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _pageModeToggle(bool narrow) {
    if (narrow) {
      return DropdownButtonFormField<_PageMode>(
        initialValue: _pageMode,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Page',
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(value: _PageMode.send, child: Text('Send')),
          DropdownMenuItem(
            value: _PageMode.log,
            child: Text('Notification log'),
          ),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _pageMode = v);
        },
      );
    }
    return SegmentedButton<_PageMode>(
      segments: const [
        ButtonSegment(
          value: _PageMode.send,
          icon: Icon(Icons.send_outlined),
          label: Text('Send'),
        ),
        ButtonSegment(
          value: _PageMode.log,
          icon: Icon(Icons.history),
          label: Text('Notification log'),
        ),
      ],
      selected: {_pageMode},
      showSelectedIcon: false,
      onSelectionChanged: (s) => setState(() => _pageMode = s.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 720;

    return ColoredBox(
      color: IndustrialTheme.chromeOf(context).base,
      child: ListView(
        padding: slstPagePadding(context, includeCompactChrome: true),
        children: [
          IndustrialPageTitle(
            'Notifications',
            subtitle: _pageMode == _PageMode.log
                ? 'Delivery history — filter, sort, and export'
                : 'PM email via secure notify-pm server',
          ),
          _pageModeToggle(narrow),
          const SizedBox(height: 16),
          if (_pageMode == _PageMode.log) ...[
            const NotificationLogPanel(),
          ] else ...[
            Card(
              margin: EdgeInsets.zero,
              color: IndustrialTheme.chromeAccent.withValues(alpha: 0.10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: IndustrialTheme.chromeAccent.withValues(alpha: 0.35),
                ),
              ),
              child: const ListTile(
                leading: Icon(
                  Icons.shield_outlined,
                  color: IndustrialTheme.chromeAccent,
                ),
                title: Text(
                  'Secure delivery',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Notifications are sent through a secure server function (no sign-in required). '
                  'Webhook credentials never ship inside the app binary. '
                  'Deliveries are recorded in Notification log.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (narrow)
              DropdownButtonFormField<_NotifyKind>(
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Notification type',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: _NotifyKind.po,
                    child: Text('PO Notify'),
                  ),
                  DropdownMenuItem(
                    value: _NotifyKind.bulkPo,
                    child: Text('Bulk PO Notify'),
                  ),
                  DropdownMenuItem(
                    value: _NotifyKind.returnNotify,
                    child: Text('Return Notify'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _kind = v);
                },
              )
            else
              SegmentedButton<_NotifyKind>(
                segments: const [
                  ButtonSegment(
                    value: _NotifyKind.po,
                    icon: Icon(Icons.receipt_long),
                    label: Text('PO Notify'),
                  ),
                  ButtonSegment(
                    value: _NotifyKind.bulkPo,
                    icon: Icon(Icons.playlist_add_check),
                    label: Text('Bulk PO Notify'),
                  ),
                  ButtonSegment(
                    value: _NotifyKind.returnNotify,
                    icon: Icon(Icons.keyboard_return),
                    label: Text('Return Notify'),
                  ),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
            const SizedBox(height: 16),
            if (_kind == _NotifyKind.bulkPo)
              _buildBulkForm(scheme)
            else
              _buildSingleForm(),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                // Match Settings → Send feedback (theme primary / brand accent).
                backgroundColor: SlstColors.brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor: scheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy ? null : _send,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_busy ? 'Sending…' : 'Send notification'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleForm() {
    final isReturn = _kind == _NotifyKind.returnNotify;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isReturn) ...[
              TextField(
                controller: _po,
                decoration: const InputDecoration(labelText: 'PO #'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _so,
              decoration: InputDecoration(
                labelText: isReturn ? 'SO #' : 'Linked SO (optional)',
              ),
            ),
            const SizedBox(height: 12),
            if (isReturn)
              CustomerSuggestionField(controller: _customer)
            else
              TextField(
                controller: _vendor,
                decoration: const InputDecoration(labelText: 'Vendor'),
                textCapitalization: TextCapitalization.words,
              ),
            const SizedBox(height: 12),
            ContactEmailField(controller: _pmEmail),
            const SizedBox(height: 12),
            TextField(
              controller: _details,
              decoration: const InputDecoration(labelText: 'Details'),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: PhotoAttachButtons(
                picker: _picker,
                photos: _photos,
                attachLabel: 'Attach photos',
                onChanged: (next) => setState(() {
                  _photos
                    ..clear()
                    ..addAll(next);
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkForm(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter each morning PO with containers, vendor, PM email, notes, '
          'and optional photos/scans. One digest email is sent per PM '
          '(attachments from that PM\'s POs are included).',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _bulkRows.length; i++) ...[
          _bulkCard(i),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: () => setState(() => _bulkRows.add(_BulkPoRow())),
          icon: const Icon(Icons.add),
          label: const Text('Add another PO'),
        ),
      ],
    );
  }

  Widget _bulkCard(int index) {
    final row = _bulkRows[index];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'PO ${index + 1}',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (_bulkRows.length > 1)
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: () => setState(() {
                      _bulkRows.removeAt(index).dispose();
                    }),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            TextField(
              controller: row.po,
              decoration: const InputDecoration(labelText: 'PO #'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: row.vendor,
              decoration: const InputDecoration(labelText: 'Vendor'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            ContactEmailField(controller: row.pmEmail),
            const SizedBox(height: 12),
            const Text(
              'Containers received',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ContainerInputs(
              skids: row.skids,
              boxes: row.boxes,
              crates: row.crates,
              pipe: row.pipe,
              other: row.other,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: row.details,
              decoration: const InputDecoration(labelText: 'Comment (Details)'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: PhotoAttachButtons(
                picker: _picker,
                photos: row.photos,
                attachLabel: 'Attach photos',
                onChanged: (next) => setState(() {
                  row.photos
                    ..clear()
                    ..addAll(next);
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
