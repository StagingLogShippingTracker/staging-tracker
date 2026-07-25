import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';

/// High-contrast status pill for industrial grids and inspectors.
///
/// Colour map: today/dispatch/ready → mint; tomorrow/transit → sky;
/// partial/awaiting → amber; delivered/completed → slate; future/corp → purple.
class IndustrialStatusBadge extends StatelessWidget {
  const IndustrialStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg = IndustrialTheme.slateMuted;
    const fg = Colors.white;

    final s = status.toLowerCase();
    if (s.contains('today') ||
        s.contains('dispatch') ||
        s.contains('ready')) {
      bg = IndustrialTheme.mintGreen;
    } else if (s.contains('tomorrow') ||
        s.contains('transit') ||
        s.contains('progress')) {
      bg = IndustrialTheme.skyBlue;
    } else if (s.contains('partial') ||
        s.contains('awaiting') ||
        s.contains('pending')) {
      bg = IndustrialTheme.amber;
    } else if (s.contains('delivered') || s.contains('completed')) {
      bg = IndustrialTheme.slateMuted;
    } else if (s.contains('future') || s.contains('corp')) {
      bg = IndustrialTheme.purple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
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
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: compact ? 9 : null,
                    letterSpacing: compact ? 0.5 : null,
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
                color: IndustrialTheme.textPrimary,
              ),
            ),
            if (subtext.isNotEmpty) ...[
              SizedBox(height: compact ? 2 : 4),
              Text(
                subtext,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: compact ? 10 : null,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
    // Compact strip cards fill their Expanded slot width.
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
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: IndustrialTheme.darkHeader,
        border: Border(
          top: BorderSide(color: IndustrialTheme.borderStroke, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: hotkeyButtons),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            floorTotalsText,
            style: IndustrialTheme.mono(
              fontSize: 12,
              color: IndustrialTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Right slide-over inspector drawer (400px).
class SlideOverInspector extends StatelessWidget {
  const SlideOverInspector({
    super.key,
    required this.title,
    required this.body,
    required this.onClose,
  });

  final String title;
  final Widget body;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      decoration: const BoxDecoration(
        color: IndustrialTheme.darkSurface,
        border: Border(
          left: BorderSide(color: IndustrialTheme.borderStroke, width: 1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: IndustrialTheme.borderStroke),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: IndustrialTheme.textMuted,
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
  }
}

/// Entry UUID (or any id) rendered in JetBrains Mono.
class IndustrialIdText extends StatelessWidget {
  const IndustrialIdText(
    this.id, {
    super.key,
    this.fontSize = 12,
    this.color = IndustrialTheme.textMuted,
    this.maxLines = 1,
  });

  final String id;
  final double fontSize;
  final Color color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      id,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: IndustrialTheme.mono(fontSize: fontSize, color: color),
    );
  }
}
