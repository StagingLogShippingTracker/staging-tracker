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

/// SLST wordmark image ("SLST — Staging Log & Shipping Tracker").
///
/// The source art is charcoal on transparent; in dark mode it is tinted to the
/// light ink colour so it stays legible.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      'assets/slst-wordmark.png',
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      color: dark ? SlstColors.darkInk : null,
      errorBuilder: (_, _, _) => Text(
        'SLST',
        style: TextStyle(
          fontFamily: kBrandFontFamily,
          fontSize: height * 0.8,
          color: SlstColors.brand,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPI stat card (Windows: white card with red top accent + Win11 concept icon)
// ---------------------------------------------------------------------------

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 3.5, color: SlstColors.brand),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                          color: dark ? SlstColors.darkMuted : SlstColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 26,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                          color: dark ? SlstColors.darkInk : SlstColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  icon,
                  size: 26,
                  color: dark ? SlstColors.darkMuted : SlstColors.subtle,
                ),
              ],
            ),
          ),
        ],
    );

    return Container(
      decoration: BoxDecoration(
        color: dark ? SlstColors.darkSurface : SlstColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dark ? SlstColors.darkBorder : SlstColors.border),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: body),
            ),
    );
  }
}

/// KPI tile used on the touch-first (Material 3) dashboard/reports grids.
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

// ---------------------------------------------------------------------------
// Pill action buttons (web .btn-purple / .btn-notify / success / danger)
// ---------------------------------------------------------------------------

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.onPressed,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      disabledBackgroundColor: color.withValues(alpha: 0.4),
      disabledForegroundColor: Colors.white70,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: compact ? const Size(0, 34) : const Size(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(
        fontFamily: kBodyFontFamily,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        fontSize: compact ? 12.5 : 13.5,
      ),
    );
    if (icon == null) {
      return FilledButton(onPressed: onPressed, style: style, child: Text(label));
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: compact ? 15 : 18),
      label: Text(label),
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

// ---------------------------------------------------------------------------
// Section card with header controls (Staging Entries / Shipped Log panels)
// ---------------------------------------------------------------------------

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.headerActions = const [],
    this.subHeader,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final List<Widget> headerActions;
  final Widget? subHeader;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? SlstColors.darkSurface : SlstColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? SlstColors.darkBorder : SlstColors.border),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0D0F172A),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: dark ? SlstColors.darkInk : SlstColors.ink,
                  ),
                ),
                if (headerActions.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: headerActions,
                  ),
              ],
            ),
          ),
          if (subHeader != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: subHeader!,
            ),
          const Divider(),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status legend (Partial / Ship Today / Ship Tomorrow / Future / Corp Pick /
// Customer Pick-Up / Awaiting Instructions)
// ---------------------------------------------------------------------------

typedef _LegendEntry = ({String label, Color light, Color dark});

const List<_LegendEntry> _legend = [
  (label: 'Partial', light: SlstColors.statusPartial, dark: SlstColors.statusPartialDark),
  (label: 'Ship Today', light: SlstColors.statusToday, dark: SlstColors.statusTodayDark),
  (label: 'Ship Tomorrow', light: SlstColors.statusTomorrow, dark: SlstColors.statusTomorrowDark),
  (label: 'Ship On Future Date', light: SlstColors.statusFuture, dark: SlstColors.statusFutureDark),
  (label: 'Corp Pick', light: SlstColors.statusCorpPick, dark: SlstColors.statusCorpPickDark),
  (label: 'Customer Pick-Up', light: SlstColors.statusCustomerPick, dark: SlstColors.statusCustomerPickDark),
  (label: 'Awaiting Instructions', light: SlstColors.surface, dark: SlstColors.darkSurfaceMuted),
];

/// Windows/desktop swatch legend (compact colour chips + labels).
class StagingStatusLegend extends StatelessWidget {
  const StagingStatusLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final item in _legend)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dark ? item.dark : item.light,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.18)
                        : const Color(0x140F172A),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: dark ? SlstColors.darkMuted : SlstColors.muted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Collapsible touch-first legend (Material 3 chips inside an ExpansionTile).
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

/// Row highlight color for a staging status (theme aware).
Color? statusRowColor(BuildContext context, String dbStatus) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final ui = StatusRules.formatUi(dbStatus).toLowerCase();
  if (ui == 'ship today' || StatusRules.isOverdue(dbStatus)) {
    return dark ? SlstColors.statusTodayDark : SlstColors.statusToday;
  }
  if (ui == 'ship tomorrow') {
    return dark ? SlstColors.statusTomorrowDark : SlstColors.statusTomorrow;
  }
  if (StatusRules.isYmd(dbStatus)) {
    return dark ? SlstColors.statusFutureDark : SlstColors.statusFuture;
  }
  if (ui == 'partial') {
    return dark ? SlstColors.statusPartialDark : SlstColors.statusPartial;
  }
  if (ui.contains('corp pick')) {
    return dark ? SlstColors.statusCorpPickDark : SlstColors.statusCorpPick;
  }
  if (ui.contains('customer pick')) {
    return dark ? SlstColors.statusCustomerPickDark : SlstColors.statusCustomerPick;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Quick search field
// ---------------------------------------------------------------------------

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
        suffixIcon: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (controller.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Clear',
              onPressed: () {
                controller.clear();
                onChanged?.call('');
              },
              icon: const Icon(Icons.close),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coming soon card + site footer (web parity)
// ---------------------------------------------------------------------------

class ComingSoonCard extends StatelessWidget {
  const ComingSoonCard({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? SlstColors.darkSurfaceMuted : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? SlstColors.darkBorder : SlstColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: dark ? SlstColors.darkMuted : SlstColors.subtle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: dark ? SlstColors.darkMuted : SlstColors.subtle,
            ),
          ),
        ],
      ),
    );
  }
}

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final subtle = dark ? SlstColors.darkMuted : SlstColors.subtle;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Divider(color: dark ? SlstColors.darkBorder : SlstColors.border),
          const SizedBox(height: 14),
          Text(
            'Designed, developed, and maintained by Brice Johnson.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: dark ? SlstColors.darkMuted : SlstColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              'Open-source components are used under their respective licenses. '
              'All other software, design, and content are the property of Brice Johnson. '
              'All rights reserved. Unauthorized use, reproduction, or distribution is prohibited.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, height: 1.5, color: subtle),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: dark
                  ? Colors.black.withValues(alpha: 0.28)
                  : const Color(0xFFEDF0F4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0F172A),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Opacity(
              opacity: dark ? 0.35 : 0.75,
              child: Image.asset(
                'assets/slst-mark.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.local_shipping, color: SlstColors.subtle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title row with optional action buttons (touch-first screens).
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

// ---------------------------------------------------------------------------
// Container count entry (staging / quick ship forms)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Photos
// ---------------------------------------------------------------------------

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

Future<void> showPhotosDialog(
  BuildContext context, {
  required String title,
  required List<String> paths,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: paths.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No photos attached.'),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: paths.length,
                        itemBuilder: (context, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            AppConfig.publicPhotoUrl(paths[i]),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.black12,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Card for one staging/shipped entry. Supports both a Windows-style row tint
/// ([color]) and the touch-first status accent bar + chip ([dbStatus]).
class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.details,
    this.dbStatus,
    this.color,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final List<String> details;
  final String? dbStatus;
  final Color? color;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = dbStatus == null ? null : statusStyleOf(context, dbStatus!);
    return Card(
      color: color,
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
              fontFamily: kBrandFontFamily,
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

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  Color confirmColor = SlstColors.danger,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
