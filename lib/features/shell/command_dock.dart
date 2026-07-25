import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/models.dart';
import '../shared/industrial_widgets.dart';
import '../shared/log_tables.dart';
import '../shipping/quick_ship_sheet.dart';
import '../staging/staging_form_sheet.dart';

typedef DockAction = ({String key, String label, VoidCallback? onPressed});

/// Shell-level command dock: contextual F1–F5 labels + floor tallies.
class ShellCommandDock extends ConsumerWidget {
  const ShellCommandDock({super.key, required this.location});

  final String location;

  /// Public so [AppShell] can bind the same callbacks to keyboard shortcuts.
  static List<DockAction> actionsFor(
    BuildContext context,
    WidgetRef ref,
    String location,
  ) {
    final user = ref.read(currentUserProvider);
    final signedIn = user != null;
    final path = Uri.tryParse(location)?.path ?? location;

    switch (path) {
      case '/staging':
        return [
          (
            key: 'F1',
            label: 'New Entry',
            onPressed: signedIn
                ? () => showStagingFormSheet(context, ref)
                : null,
          ),
          (
            key: 'F2',
            label: 'Refresh',
            onPressed: () => ref.read(appDataProvider.notifier).refresh(),
          ),
          (
            key: 'F3',
            label: 'Shipped Log',
            onPressed: () => context.go('/shipped'),
          ),
          (
            key: 'F4',
            label: 'Quick Consolidate',
            onPressed: signedIn
                ? () => showQuickConsolidateDialog(context, ref)
                : null,
          ),
          (
            key: 'F5',
            label: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ];
      case '/shipped':
        return [
          (
            key: 'F1',
            label: 'Quick Ship',
            onPressed: signedIn
                ? () => showQuickShipSheet(context, ref)
                : null,
          ),
          (
            key: 'F2',
            label: 'Refresh',
            onPressed: () => ref.read(appDataProvider.notifier).refresh(),
          ),
          (
            key: 'F3',
            label: 'Staging Log',
            onPressed: () => context.go('/staging'),
          ),
          (
            key: 'F4',
            label: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ];
      case '/reports':
        return [
          (
            key: 'F1',
            label: 'Staging Log',
            onPressed: () => context.go('/staging'),
          ),
          (
            key: 'F2',
            label: 'Shipped Log',
            onPressed: () => context.go('/shipped'),
          ),
          (
            key: 'F3',
            label: 'Refresh',
            onPressed: () => ref.read(appDataProvider.notifier).refresh(),
          ),
          (
            key: 'F4',
            label: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ];
      case '/notifications':
        return [
          (
            key: 'F1',
            label: 'Contacts',
            onPressed: () => context.go('/contacts'),
          ),
          (
            key: 'F2',
            label: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
          (
            key: 'F3',
            label: 'Refresh',
            onPressed: () => ref.read(appDataProvider.notifier).refresh(),
          ),
          (
            key: 'F4',
            label: 'Staging Log',
            onPressed: () => context.go('/staging'),
          ),
        ];
      case '/contacts':
        return [
          (
            key: 'F1',
            label: 'Notifications',
            onPressed: () => context.go('/notifications'),
          ),
          (
            key: 'F2',
            label: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
          (
            key: 'F3',
            label: 'Refresh',
            onPressed: () => ref.read(appDataProvider.notifier).refresh(),
          ),
          (
            key: 'F4',
            label: 'Staging Log',
            onPressed: () => context.go('/staging'),
          ),
        ];
      case '/settings':
        return [
          (
            key: 'F1',
            label: 'Notifications',
            onPressed: () => context.go('/notifications'),
          ),
          (
            key: 'F2',
            label: 'Contacts',
            onPressed: () => context.go('/contacts'),
          ),
          (
            key: 'F3',
            label: 'Refresh',
            onPressed: () => ref.read(appDataProvider.notifier).refresh(),
          ),
          (
            key: 'F4',
            label: signedIn ? 'Sign Out' : 'Sign In',
            onPressed: () async {
              if (signedIn) {
                await ref.read(supabaseClientProvider).auth.signOut();
              } else {
                context.push('/login');
              }
            },
          ),
        ];
      default:
        // Dashboard and unknown routes.
        return [
          (
            key: 'F1',
            label: 'New Entry',
            onPressed: signedIn
                ? () => showStagingFormSheet(context, ref)
                : null,
          ),
          (
            key: 'F2',
            label: 'Quick Ship',
            onPressed: signedIn
                ? () => showQuickShipSheet(context, ref)
                : null,
          ),
          (
            key: 'F3',
            label: 'Quick Consolidate',
            onPressed: signedIn
                ? () => showQuickConsolidateDialog(context, ref)
                : null,
          ),
          (
            key: 'F4',
            label: 'Staging Log',
            onPressed: () => context.go('/staging'),
          ),
          (
            key: 'F5',
            label: 'Reports',
            onPressed: () => context.go('/reports'),
          ),
        ];
    }
  }

  static LogicalKeyboardKey? logicalKeyFor(String hotkey) {
    switch (hotkey.toUpperCase()) {
      case 'F1':
        return LogicalKeyboardKey.f1;
      case 'F2':
        return LogicalKeyboardKey.f2;
      case 'F3':
        return LogicalKeyboardKey.f3;
      case 'F4':
        return LogicalKeyboardKey.f4;
      case 'F5':
        return LogicalKeyboardKey.f5;
      case 'F6':
        return LogicalKeyboardKey.f6;
      default:
        return null;
    }
  }

  static Map<ShortcutActivator, VoidCallback> shortcutBindings(
    List<DockAction> actions,
  ) {
    final bindings = <ShortcutActivator, VoidCallback>{};
    for (final action in actions) {
      final key = logicalKeyFor(action.key);
      final onPressed = action.onPressed;
      if (key == null || onPressed == null) continue;
      bindings[SingleActivator(key)] = onPressed;
    }
    return bindings;
  }

  static String floorTotalsText(List<StagingEntry> staging) {
    var totals = const ContainerCounts();
    for (final e in staging) {
      totals = totals + ContainerCounts.parse(e.type);
    }
    return 'FLOOR  Skids ${totals.skids}  ·  Boxes ${totals.boxes}  ·  '
        'Crates ${totals.crates}  ·  Pipe ${totals.pipe}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staging = ref.watch(appDataProvider).staging;
    final actions = actionsFor(context, ref, location);

    return CommandDock(
      floorTotalsText: floorTotalsText(staging),
      hotkeyButtons: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _HotkeyChip(
            hotkey: actions[i].key,
            label: actions[i].label,
            onPressed: actions[i].onPressed,
          ),
        ],
      ],
    );
  }
}

class _HotkeyChip extends StatelessWidget {
  const _HotkeyChip({
    required this.hotkey,
    required this.label,
    required this.onPressed,
  });

  final String hotkey;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: enabled
            ? IndustrialTheme.textPrimary
            : IndustrialTheme.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: IndustrialTheme.darkSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: IndustrialTheme.borderStroke),
            ),
            child: Text(
              hotkey,
              style: IndustrialTheme.mono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: IndustrialTheme.mintGreen,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: enabled
                  ? IndustrialTheme.textPrimary
                  : IndustrialTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
