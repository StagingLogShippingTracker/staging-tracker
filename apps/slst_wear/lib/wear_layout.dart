import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Round-watch safe insets and compact chrome for SLST Wear.
///
/// Wear OS round faces use a circular viewport inside a square Flutter window.
/// System [SafeArea] / [MediaQuery.padding] alone leave content under the bezel
/// near the left/right edges (especially mid-list rows and top toolbars).
/// We pad toward an inscribed usable zone (~15–18% of the short side).
class WearLayout {
  WearLayout._();

  /// Fraction of shortest side used as horizontal inset on round faces.
  static const double roundHorizontalFactor = 0.17;

  /// Fraction of shortest side used as vertical inset on round faces.
  static const double roundVerticalFactor = 0.11;

  /// True when the logical window is essentially square (typical round Wear).
  static bool isLikelyRound(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.shortestSide <= 0) return false;
    final ratio = size.longestSide / size.shortestSide;
    return ratio < 1.12;
  }

  /// Combined system + circular content insets.
  static EdgeInsets contentInsets(
    BuildContext context, {
    EdgeInsets extra = EdgeInsets.zero,
    double? horizontalFactor,
    double? verticalFactor,
  }) {
    final mq = MediaQuery.of(context);
    final shortest = mq.size.shortestSide;
    final round = isLikelyRound(context);
    final h = round
        ? shortest * (horizontalFactor ?? roundHorizontalFactor)
        : math.max(8.0, shortest * 0.04);
    final v = round
        ? shortest * (verticalFactor ?? roundVerticalFactor)
        : math.max(4.0, shortest * 0.03);
    return EdgeInsets.only(
      left: math.max(mq.padding.left, h) + extra.left,
      right: math.max(mq.padding.right, h) + extra.right,
      top: math.max(mq.padding.top, v) + extra.top,
      bottom: math.max(mq.padding.bottom, v) + extra.bottom,
    );
  }

  /// Horizontal-only inset for list rows (keeps SO/customer inside the bezel).
  static EdgeInsets listHorizontal(BuildContext context) {
    final i = contentInsets(context);
    return EdgeInsets.only(left: i.left, right: i.right);
  }
}

/// Applies [WearLayout.contentInsets] without double-counting [SafeArea].
/// Prefer this over nesting [SafeArea] + manual padding on Wear screens.
class WearSafePad extends StatelessWidget {
  const WearSafePad({
    super.key,
    required this.child,
    this.extra = EdgeInsets.zero,
    this.left = true,
    this.top = true,
    this.right = true,
    this.bottom = true,
  });

  final Widget child;
  final EdgeInsets extra;
  final bool left;
  final bool top;
  final bool right;
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    final full = WearLayout.contentInsets(context, extra: extra);
    return Padding(
      padding: EdgeInsets.only(
        left: left ? full.left : 0,
        top: top ? full.top : 0,
        right: right ? full.right : 0,
        bottom: bottom ? full.bottom : 0,
      ),
      child: child,
    );
  }
}

/// Compact 40dp icon control that still meets Wear tap guidance closely.
class WearIconAction extends StatelessWidget {
  const WearIconAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: color,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Thin top bar for drill-in screens (avoids AppBar clipping on round faces).
class WearPageHeader extends StatelessWidget {
  const WearPageHeader({
    super.key,
    required this.title,
    this.onBack,
  });

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          WearIconAction(
            tooltip: 'Back',
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: Icons.arrow_back,
            color: WearLayoutMuted.muted,
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// Local color alias so wear_layout does not import theme (avoids cycles).
class WearLayoutMuted {
  static const muted = Color(0xFF9CA3AF);
}
