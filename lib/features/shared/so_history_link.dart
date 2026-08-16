import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'order_history_dialog.dart';

/// Tappable SO number that opens Order History.
///
/// Uses Material 3 [TextButton] stadium hover (soft oval pill) — never an
/// underline. Shared by staging/shipped logs, floor-map popovers, and KPI
/// detail dialogs so hover treatment stays consistent across clients.
class SoHistoryLink extends ConsumerWidget {
  const SoHistoryLink(
    this.so, {
    super.key,
    this.maxWidth,
    this.fontSize = 13,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  final String so;
  final double? maxWidth;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = so.isEmpty ? '—' : so;
    return Tooltip(
      message: so.isEmpty ? '' : 'Open Order History for SO $so',
      child: TextButton(
        style: ButtonStyle(
          padding: WidgetStatePropertyAll(padding),
          minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          foregroundColor: const WidgetStatePropertyAll(IndustrialTheme.chromeAccent),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed)) {
              return IndustrialTheme.chromeAccent.withValues(alpha: 0.18);
            }
            return null;
          }),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
        ),
        onPressed: so.isEmpty
            ? null
            : () => showOrderHistoryDialog(context, ref, so: so),
        child: maxWidth == null
            ? Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IndustrialTheme.mono(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: IndustrialTheme.chromeAccent,
                ).copyWith(decoration: TextDecoration.none),
              )
            : ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth!),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IndustrialTheme.mono(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: IndustrialTheme.chromeAccent,
                  ).copyWith(decoration: TextDecoration.none),
                ),
              ),
      ),
    );
  }
}
