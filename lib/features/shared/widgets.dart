import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_config.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';

/// Resolves the [StatusStyle] for a raw DB status string.
StatusStyle statusStyleOf(BuildContext context, String dbStatus) {
  return statusStyleFor(
    uiLabel: StatusRules.formatUi(dbStatus),
    isDateStatus: StatusRules.isYmd(dbStatus),
    overdue: StatusRules.isOverdue(dbStatus),
    brightness: Theme.of(context).brightness,
  );
}

/// KPI tile used on the dashboard/reports grids.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            height: 1.1,
                          ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small status pill matching the legacy web legend colors.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.dbStatus, this.compact = false});

  final String dbStatus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = statusStyleOf(context, dbStatus);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: style.fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: compact ? 12 : 14, color: style.accent),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: style.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Legend explaining the status colors (mirrors the legacy web legend).
class StatusLegend extends StatelessWidget {
  const StatusLegend({super.key});

  static const _statuses = [
    'Partial',
    'Ship Today',
    'Ship Tomorrow',
    '2099-12-31', // renders as a future-date sample
    'Corp Pick',
    'Customer Pick-Up',
    'Awaiting Instructions',
  ];

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: const Border(),
      title: Text(
        'Status legend',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
      ),
      leading: const Icon(Icons.palette_outlined, size: 20),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _statuses) StatusChip(dbStatus: s, compact: true),
            ],
          ),
        ),
      ],
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');
                },
                icon: const Icon(Icons.clear),
              ),
      ),
    );
  }
}

/// Section title row with optional action buttons.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actions = const [],
  });

  final String title;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: SlstColors.brand),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class ContainerInputs extends StatelessWidget {
  const ContainerInputs({
    super.key,
    required this.skids,
    required this.boxes,
    required this.crates,
    required this.pipe,
    required this.other,
    required this.onChanged,
  });

  final TextEditingController skids;
  final TextEditingController boxes;
  final TextEditingController crates;
  final TextEditingController pipe;
  final TextEditingController other;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    Widget field(String label, TextEditingController c) {
      return Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label, isDense: true),
          onChanged: (_) => onChanged(),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            field('Skids', skids),
            const SizedBox(width: 8),
            field('Boxes', boxes),
            const SizedBox(width: 8),
            field('Crates', crates),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            field('Pipe/Rod', pipe),
            const SizedBox(width: 8),
            field('Other', other),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

ContainerCounts countsFromControllers({
  required TextEditingController skids,
  required TextEditingController boxes,
  required TextEditingController crates,
  required TextEditingController pipe,
  required TextEditingController other,
}) {
  int p(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
  return ContainerCounts(
    skids: p(skids),
    boxes: p(boxes),
    crates: p(crates),
    pipe: p(pipe),
    other: p(other),
  );
}

/// Card for one staging/shipped entry: status accent bar, SO title, chips.
class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.details,
    this.dbStatus,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final List<String> details;
  final String? dbStatus;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = dbStatus == null ? null : statusStyleOf(context, dbStatus!);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: style?.accent ?? scheme.outlineVariant),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontSize: 16),
                            ),
                          ),
                          if (style != null)
                            StatusChip(dbStatus: dbStatus!, compact: true),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      for (final d in details)
                        Text(
                          d,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(child: trailing),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhotoThumbRow extends StatelessWidget {
  const PhotoThumbRow({super.key, required this.paths});
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final url = AppConfig.publicPhotoUrl(paths[i]);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 72,
                height: 72,
                color: Colors.black12,
                child: const Icon(Icons.broken_image),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Footer credit carried over from the legacy web app.
class BrandFooter extends StatelessWidget {
  const BrandFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Text(
            'SLST — STAGING LOG & SHIPPING TRACKER',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SLSTBrand',
              fontSize: 11,
              letterSpacing: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Designed & developed by Brice Johnson',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

Future<void> showError(BuildContext context, Object error) async {
  if (!context.mounted) return;
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.toString()),
      backgroundColor: scheme.error,
    ),
  );
}

Future<void> showOk(BuildContext context, String message) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: SlstColors.green,
    ),
  );
}
