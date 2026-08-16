import 'dart:math' as math;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/format_weight.dart';
import '../../core/theme.dart';

/// Horizontal scrollbar + chevron chrome is for mouse (Windows/desktop).
/// Android uses finger swipe — hide arrows/scrollbar there.
bool get showHorizontalScrollChrome {
  if (kIsWeb) return true;
  return !Platform.isAndroid;
}

/// Standard async-state framing for operational pages.
///
/// Existing data stays visible during background synchronization; only an
/// empty first load blocks the page so KPI placeholders are never mistaken for
/// live inventory.
class AsyncPanel extends StatelessWidget {
  const AsyncPanel({
    super.key,
    required this.loading,
    required this.syncing,
    required this.isEmpty,
    required this.error,
    required this.onRetry,
    required this.child,
    this.emptyTitle = 'No records found',
    this.emptyMessage = 'There are no records to display yet.',
  });

  final bool loading;
  final bool syncing;
  final bool isEmpty;
  final String? error;
  final Future<void> Function() onRetry;
  final Widget child;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final hasStaleData = !isEmpty;
    if (loading && !hasStaleData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (error != null && !hasStaleData) {
      return _AsyncMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load records',
        message: error!,
        action: SlstAsyncButton(label: 'Retry', onPressed: onRetry),
      );
    }
    if (isEmpty) {
      return _AsyncMessage(
        icon: Icons.inventory_2_outlined,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          _AsyncBanner(
            icon: Icons.cloud_off_outlined,
            message: 'Showing the last available data. ${error!}',
            action: SlstAsyncButton(
              label: 'Retry',
              compact: true,
              onPressed: onRetry,
            ),
          )
        else if (syncing)
          const _AsyncBanner(
            icon: Icons.sync,
            message: 'Refreshing live operational data…',
          ),
        Expanded(child: child),
      ],
    );
  }
}

class _AsyncBanner extends StatelessWidget {
  const _AsyncBanner({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: IndustrialTheme.chromeAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: IndustrialTheme.chromeAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: IndustrialTheme.chromeAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12))),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

class _AsyncMessage extends StatelessWidget {
  const _AsyncMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.symmetric(vertical: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: IndustrialTheme.chromeOf(context).surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: IndustrialTheme.chromeOf(context).border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: IndustrialTheme.chromeOf(context).muted),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Button that prevents duplicate async operations while work is in flight.
class SlstAsyncButton extends StatefulWidget {
  const SlstAsyncButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final Future<void> Function() onPressed;
  final bool compact;

  @override
  State<SlstAsyncButton> createState() => _SlstAsyncButtonState();
}

class _SlstAsyncButtonState extends State<SlstAsyncButton> {
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _running
          ? null
          : () async {
              setState(() => _running = true);
              try {
                await widget.onPressed();
              } finally {
                if (mounted) setState(() => _running = false);
              }
            },
      style: widget.compact
          ? FilledButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      child: _running
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(widget.label),
    );
  }
}

/// Page section title — Inter caps with optional trailing actions.
class IndustrialPageTitle extends StatelessWidget {
  const IndustrialPageTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: IndustrialTheme.chromeOf(context).ink,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: IndustrialTheme.chromeOf(context).muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: trailing,
            ),
        ],
      ),
    );
  }
}

/// Consistent filter / toolbar row used above logs and secondary lists.
class IndustrialFilterRow extends StatelessWidget {
  const IndustrialFilterRow({
    super.key,
    required this.children,
    this.spacing = 8,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// Compact horizontal summary strip (counts / tallies).
class IndustrialSummaryStrip extends StatelessWidget {
  const IndustrialSummaryStrip({super.key, required this.items});

  final List<({String label, String value, Color? accent})> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: IndustrialTheme.chromeOf(context).surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IndustrialTheme.chromeOf(context).border),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        children: [
          for (final item in items)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.value,
                  style: IndustrialTheme.mono(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: item.accent ?? IndustrialTheme.chromeOf(context).ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: IndustrialTheme.chromeOf(context).muted,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Muted pastel status pill — soft tint fill + accent text (color on pill only).
class IndustrialStatusBadge extends StatelessWidget {
  const IndustrialStatusBadge({super.key, required this.status});

  final String status;

  static ({Color fill, Color accent}) colorsFor(
    String status, {
    Brightness brightness = Brightness.dark,
  }) {
    final s = status.toLowerCase();
    if (s.contains('overdue') || s.contains('urgent')) {
      return (fill: const Color(0x33EF4444), accent: const Color(0xFFEF4444));
    }
    if (s.contains('today') ||
        s.contains('dispatch') ||
        s.contains('ready') ||
        s == 'shipped') {
      return (
        fill: IndustrialTheme.mintGreen.withValues(alpha: 0.18),
        accent: IndustrialTheme.mintGreen,
      );
    }
    if (s.contains('tomorrow') ||
        s.contains('transit') ||
        s.contains('progress')) {
      return (
        fill: IndustrialTheme.skyBlue.withValues(alpha: 0.18),
        accent: IndustrialTheme.skyBlue,
      );
    }
    if (s.contains('partial') || s.contains('returned')) {
      return (
        fill: IndustrialTheme.amber.withValues(alpha: 0.18),
        accent: IndustrialTheme.amber,
      );
    }
    if (s.contains('awaiting') || s.contains('pending')) {
      final accent = brightness == Brightness.light
          ? IndustrialTheme.awaiting
          : IndustrialTheme.slateMuted;
      return (
        fill: accent.withValues(
          alpha: brightness == Brightness.light ? 0.40 : 0.28,
        ),
        accent: accent,
      );
    }
    if (s.contains('delivered') || s.contains('completed')) {
      return (
        fill: IndustrialTheme.slateMuted.withValues(alpha: 0.28),
        accent: IndustrialTheme.textMuted,
      );
    }
    if (s.contains('future') ||
        s.contains('corp') ||
        s.contains('customer pick')) {
      return (
        fill: IndustrialTheme.purple.withValues(alpha: 0.18),
        accent: IndustrialTheme.purple,
      );
    }
    return (
      fill: IndustrialTheme.darkHeader,
      accent: IndustrialTheme.textMuted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(
      status,
      brightness: Theme.of(context).brightness,
    );
    // Align + widthFactor shrink-wraps under fixed column widths so the
    // decorated Container does not stretch to the full STATUS cell.
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: colors.fill,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
        ),
        child: Text(
          status.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.35,
            color: colors.accent,
          ),
        ),
      ),
    );
  }
}

/// Accent bar color for a status label (left edge of log / kanban cards).
Color industrialStatusAccent(BuildContext context, String status) =>
    IndustrialStatusBadge.colorsFor(
      status,
      brightness: Theme.of(context).brightness,
    ).accent;

/// Subtle location / zone chip used in staging & shipped grids.
class IndustrialZonePill extends StatelessWidget {
  const IndustrialZonePill(this.location, {super.key});

  final String location;

  @override
  Widget build(BuildContext context) {
    final value = location.trim().isEmpty ? '—' : location.trim();
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: IndustrialTheme.chromeOf(context).header,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: IndustrialTheme.chromeOf(context).border),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: IndustrialTheme.mono(
            fontSize: 11,
            color: value == '—'
                ? IndustrialTheme.chromeOf(context).muted
                : IndustrialTheme.chromeAccent,
          ),
        ),
      ),
    );
  }
}

/// Muted olive-tint weight chip (matches log mockup + industrial palette).
class IndustrialWeightPill extends StatelessWidget {
  const IndustrialWeightPill(this.weight, {super.key});

  final String? weight;

  @override
  Widget build(BuildContext context) {
    final value = formatWeightDisplay(weight);
    if (value.isEmpty) {
      return Text(
        '—',
        style: IndustrialTheme.mono(
          fontSize: 12,
          color: IndustrialTheme.chromeOf(context).muted,
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF365314).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: IndustrialTheme.mintGreen.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: IndustrialTheme.mono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFA3E635),
          ),
        ),
      ),
    );
  }
}

/// Compact filter dropdown for log toolbars (zone / status / stager / …).
class IndustrialFilterDropdown extends StatelessWidget {
  const IndustrialFilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 140,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 38,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: IndustrialTheme.chromeOf(context).header,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: IndustrialTheme.chromeOf(context).border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            isExpanded: true,
            isDense: true,
            icon: const Icon(Icons.expand_more, size: 18),
            iconEnabledColor: IndustrialTheme.chromeOf(context).muted,
            dropdownColor: IndustrialTheme.chromeOf(context).surface,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: IndustrialTheme.chromeOf(context).ink,
            ),
            items: [
              for (final item in items)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

/// Wide summary card used above Active Staging / Shipped logs.
class LogSummaryCard extends StatelessWidget {
  const LogSummaryCard({
    super.key,
    required this.eyebrow,
    required this.value,
    required this.unit,
    required this.stats,
    this.compact = false,
  });

  final String eyebrow;
  final String value;
  final String unit;
  final List<({String label, String value, Color? accent})> stats;

  /// Dense layout for short viewports so entry lists stay above the fold.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pad = compact
        ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
        : const EdgeInsets.fromLTRB(16, 14, 16, 14);
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: IndustrialTheme.chromeOf(context).surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IndustrialTheme.chromeOf(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: compact ? 9 : null,
            ),
          ),
          SizedBox(height: compact ? 4 : 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: IndustrialTheme.mono(
                  fontSize: compact ? 22 : 32,
                  fontWeight: FontWeight.w800,
                  color: IndustrialTheme.chromeOf(context).ink,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(bottom: compact ? 2 : 6),
                child: Text(
                  unit.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: IndustrialTheme.chromeOf(context).muted,
                  ),
                ),
              ),
            ],
          ),
          if (stats.isNotEmpty) ...[
            SizedBox(height: compact ? 6 : 12),
            if (compact)
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  for (final item in stats)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${item.value} ',
                            style: IndustrialTheme.mono(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: item.accent ?? IndustrialTheme.chromeOf(context).ink,
                            ),
                          ),
                          TextSpan(
                            text: item.label.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: IndustrialTheme.chromeOf(context).muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              )
            else
              IndustrialSummaryStrip(items: stats),
          ],
        ],
      ),
    );
  }
}

/// Industrial metric summary card. Wrap in [Expanded] inside a [Row]/[Flex].
class IndustrialKpiCard extends StatelessWidget {
  const IndustrialKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.subtext,
    this.onTap,
    this.compact = false,
  });

  /// Dense single-row KPI strip variant.
  const IndustrialKpiCard.compact({
    super.key,
    required this.label,
    required this.value,
    this.subtext = '',
    this.onTap,
  }) : compact = true;

  final String label;
  final String value;
  final String subtext;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      clipBehavior: Clip.antiAlias,
      // Intrinsic height: label + value + subtitle only — never stretch to
      // fill a tall grid cell on narrow layouts.
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 12 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: compact ? 9 : null,
                height: compact ? 1.1 : null,
                letterSpacing: compact ? 0.2 : null,
              ),
            ),
            SizedBox(height: compact ? 4 : 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IndustrialTheme.mono(
                fontSize: compact ? 18 : 24,
                fontWeight: FontWeight.bold,
                color: IndustrialTheme.chromeOf(context).ink,
              ),
            ),
            if (subtext.isNotEmpty) ...[
              SizedBox(height: compact ? 2 : 4),
              Text(
                subtext,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: compact ? 9 : null),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
    // Width fills the strip/grid cell; height stays content-sized.
    final sized = compact
        ? SizedBox(width: double.infinity, child: card)
        : card;
    if (onTap == null) return sized;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: sized,
      ),
    );
  }
}

/// Persistent bottom command dock (hotkeys + floor tallies).
class CommandDock extends StatelessWidget {
  const CommandDock({
    super.key,
    required this.hotkeyButtons,
    required this.floorTotalsText,
  });

  final List<Widget> hotkeyButtons;
  final String floorTotalsText;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IndustrialTheme.chromeOf(context).header,
      child: Container(
        height: 56,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: IndustrialTheme.chromeOf(context).header,
          border: Border(
            top: BorderSide(color: IndustrialTheme.chromeOf(context).border, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: hotkeyButtons),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                floorTotalsText,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: IndustrialTheme.mono(
                  fontSize: 12,
                  color: IndustrialTheme.chromeOf(context).muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether the log inspector should open as a centered/popup sheet
/// (mobile portrait) instead of the right-side slide-over.
bool useInspectorPopup(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final portrait = size.height >= size.width;
  return portrait && size.width < IndustrialTheme.tokens.compactBreakpoint;
}

/// Right slide-over inspector drawer (400px), or bordered popup panel.
class SlideOverInspector extends StatelessWidget {
  const SlideOverInspector({
    super.key,
    required this.title,
    required this.body,
    required this.onClose,
    this.width = 400,
    this.asPopup = false,
  });

  final String title;
  final Widget body;
  final VoidCallback onClose;
  final double width;
  final bool asPopup;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final panelWidth = asPopup
        ? double.infinity
        : math.min(width, size.width * 0.92);
    final panel = Container(
      width: panelWidth,
      decoration: BoxDecoration(
        color: IndustrialTheme.chromeOf(context).surface,
        borderRadius: asPopup ? BorderRadius.circular(8) : null,
        border: asPopup
            ? Border.all(color: IndustrialTheme.chromeOf(context).border)
            : Border(
                left: BorderSide(
                  color: IndustrialTheme.chromeOf(context).border,
                  width: 1,
                ),
              ),
      ),
      clipBehavior: asPopup ? Clip.antiAlias : Clip.none,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: IndustrialTheme.chromeOf(context).border),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: IndustrialTheme.chromeOf(context).muted,
                  ),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: body,
            ),
          ),
        ],
      ),
    );

    // Safety net if accidentally parented under unbounded height (ListView).
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return SizedBox(height: size.height, child: panel);
        }
        return panel;
      },
    );
  }
}

/// Entry UUID (or any id) rendered in JetBrains Mono.
class IndustrialIdText extends StatelessWidget {
  const IndustrialIdText(
    this.id, {
    super.key,
    this.fontSize = 12,
    this.color,
    this.maxLines = 1,
  });

  final String id;
  final double fontSize;
  final Color? color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      id,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: IndustrialTheme.mono(
        fontSize: fontSize,
        color: color ?? IndustrialTheme.chromeOf(context).muted,
      ),
    );
  }
}

/// Column header label for custom industrial log grids.
class IndustrialColumnHeader extends StatelessWidget {
  const IndustrialColumnHeader(this.text, {super.key, this.width});

  final String text;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: IndustrialTheme.chromeOf(context).muted,
        ),
      ),
    );
    if (width == null) return label;
    return SizedBox(width: width, child: label);
  }
}

/// Horizontal scroll chrome: visible [Scrollbar] plus left/right page chevrons.
///
/// [builder] must attach [controller] to the horizontal scrollable it returns
/// (e.g. [ListView] or [SingleChildScrollView]).
class HorizontalScrollWithArrows extends StatefulWidget {
  const HorizontalScrollWithArrows({
    super.key,
    required this.builder,
    this.scrollStep,
  });

  final Widget Function(BuildContext context, ScrollController controller)
  builder;
  final double? scrollStep;

  @override
  State<HorizontalScrollWithArrows> createState() =>
      _HorizontalScrollWithArrowsState();
}

class _HorizontalScrollWithArrowsState
    extends State<HorizontalScrollWithArrows> {
  final _controller = ScrollController();
  bool _canBack = false;
  bool _canForward = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncArrows());
  }

  @override
  void dispose() {
    _controller.removeListener(_syncArrows);
    _controller.dispose();
    super.dispose();
  }

  void _syncArrows() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final canBack = pos.pixels > pos.minScrollExtent + 0.5;
    final canForward = pos.pixels < pos.maxScrollExtent - 0.5;
    if (canBack != _canBack || canForward != _canForward) {
      setState(() {
        _canBack = canBack;
        _canForward = canForward;
      });
    }
  }

  Future<void> _page(bool forward) async {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final step =
        widget.scrollStep ?? math.max(180.0, pos.viewportDimension * 0.8);
    final target = (pos.pixels + (forward ? step : -step)).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollable = NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _syncArrows();
        return false;
      },
      child: widget.builder(context, _controller),
    );

    // Android: finger-swipe only — no arrows / forced scrollbar chrome.
    if (!showHorizontalScrollChrome) {
      return scrollable;
    }

    // Do not use CrossAxisAlignment.stretch — this widget is often hosted inside
    // a vertical ListView (unbounded max height). Stretch then collapses the
    // row to zero height and the staging/shipped grids disappear entirely.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _HorizontalScrollArrow(
          icon: Icons.chevron_left,
          tooltip: 'Scroll left',
          enabled: _canBack,
          onPressed: () => _page(false),
        ),
        Expanded(
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
            child: scrollable,
          ),
        ),
        _HorizontalScrollArrow(
          icon: Icons.chevron_right,
          tooltip: 'Scroll right',
          enabled: _canForward,
          onPressed: () => _page(true),
        ),
      ],
    );
  }
}

class _HorizontalScrollArrow extends StatelessWidget {
  const _HorizontalScrollArrow({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        icon: Icon(
          icon,
          size: 22,
          color: enabled
              ? IndustrialTheme.chromeOf(context).ink
              : IndustrialTheme.chromeOf(context).muted.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
