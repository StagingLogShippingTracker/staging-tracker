import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/status.dart';
import '../shared/log_tables.dart';
import '../shared/widgets.dart';
import 'verification_audit.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final narrow = MediaQuery.sizeOf(context).width < 600;

    final overdue =
        data.staging.where((e) => StatusRules.isOverdue(e.status)).toList();
    final shipToday = data.staging
        .where(
          (e) =>
              StatusRules.formatUi(e.status) == 'Ship Today' &&
              !StatusRules.isOverdue(e.status),
        )
        .toList();
    final shipTomorrow = data.staging
        .where((e) => StatusRules.formatUi(e.status) == 'Ship Tomorrow')
        .toList();
    final awaiting = data.staging
        .where((e) => e.status.toLowerCase() == 'awaiting instructions')
        .toList();
    final corpPick = data.staging
        .where((e) => e.status.toLowerCase().contains('corp pick'))
        .toList();
    final returned = data.shipped
        .where((e) => e.carrier.toUpperCase() == 'RETURNED TO STOCK')
        .toList();

    const gap = 10.0;

    return ListView(
      padding: slstPagePadding(context),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 900
                ? 6
                : constraints.maxWidth >= 600
                    ? 3
                    : 2;
            final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
            final tiles = [
              (label: 'Overdue', value: overdue.length, icon: Icons.warning_amber_outlined),
              (label: 'Ship Today', value: shipToday.length, icon: Icons.today_outlined),
              (label: 'Tomorrow', value: shipTomorrow.length, icon: Icons.event_outlined),
              (label: 'Corp Pick', value: corpPick.length, icon: Icons.business_outlined),
              (label: 'Awaiting', value: awaiting.length, icon: Icons.hourglass_empty),
              (label: 'Returned', value: returned.length, icon: Icons.assignment_return_outlined),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final t in tiles)
                  SizedBox(
                    width: w,
                    child: KpiCard(label: t.label, value: t.value, icon: t.icon),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Staging Verification',
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Run system diagnostics and verify staging location accuracy '
                'to resolve discrepancies and keep the warehouse inventory '
                'synced. Progress is saved automatically — you can pause and '
                'resume an audit at any time.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? SlstColors.darkMuted
                      : SlstColors.muted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PillButton(
                    label: 'Staging Verification Report (All)',
                    icon: Icons.checklist_rtl,
                    color: SlstColors.purple,
                    onPressed: () =>
                        startVerificationAudit(context, ref, AuditMode.all),
                  ),
                  PillButton(
                    label: 'Aisle Locations Only',
                    icon: Icons.view_week_outlined,
                    color: SlstColors.info,
                    onPressed: () =>
                        startVerificationAudit(context, ref, AuditMode.aisle),
                  ),
                  PillButton(
                    label: 'Shipping Locations Only',
                    icon: Icons.local_shipping_outlined,
                    color: SlstColors.warning,
                    onPressed: () => startVerificationAudit(
                        context, ref, AuditMode.nonAisle),
                  ),
                  PillButton(
                    label: 'Discrepancies Report',
                    icon: Icons.report_gmailerrorred,
                    color: SlstColors.danger,
                    onPressed: () => startVerificationAudit(
                        context, ref, AuditMode.discrepancies),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Staging Breakdown',
          headerActions: [
            PillButton(
              label: 'Changelog',
              icon: Icons.history,
              color: SlstColors.info,
              compact: true,
              onPressed: () => showChangelogDialog(context, ref),
            ),
          ],
          subHeader: narrow
              ? DropdownButtonFormField<String>(
                  initialValue: _filter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Staging category',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Staging')),
                    DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                    DropdownMenuItem(value: 'today', child: Text('Ship Today')),
                    DropdownMenuItem(
                      value: 'tomorrow',
                      child: Text('Tomorrow'),
                    ),
                    DropdownMenuItem(
                      value: 'awaiting',
                      child: Text('Awaiting'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _filter = v ?? _filter),
                )
              : SegmentedButton<String>(
                  style: SegmentedButton.styleFrom(
                    textStyle: const TextStyle(
                      fontFamily: kBodyFontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All Staging')),
                    ButtonSegment(value: 'overdue', label: Text('Overdue')),
                    ButtonSegment(value: 'today', label: Text('Ship Today')),
                    ButtonSegment(value: 'tomorrow', label: Text('Tomorrow')),
                    ButtonSegment(value: 'awaiting', label: Text('Awaiting')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) =>
                      setState(() => _filter = s.first),
                ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Builder(
            builder: (context) {
              final list = switch (_filter) {
                'overdue' => overdue,
                'today' => shipToday,
                'tomorrow' => shipTomorrow,
                'awaiting' => awaiting,
                _ => data.staging,
              };
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No entries in this bucket.')),
                );
              }
              return Column(
                children: [
                  for (final e in list)
                    EntryCard(
                      title: 'SO ${e.so}',
                      subtitle: e.customer,
                      details: [
                        '${StatusRules.formatUi(e.status)} · ${e.location}',
                        e.type,
                      ],
                      color: statusRowColor(context, e.status),
                    ),
                ],
              );
            },
          ),
        ),
        const BrandFooter(),
      ],
    );
  }
}
