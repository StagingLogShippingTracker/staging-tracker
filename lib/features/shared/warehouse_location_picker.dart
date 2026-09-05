import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/popup_gate.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/location_intelligence.dart';
import '../../domain/models.dart';
import '../dashboard/warehouse_floor_map.dart';

/// Full-screen floor map for assigning a staging location by tap.
Future<String?> showWarehouseLocationPicker(
  BuildContext context,
  WidgetRef ref, {
  required LocationCategory category,
}) async {
  final mode = category.mapPickMode;
  if (mode == null) return null;
  final staging = ref.read(appDataProvider).staging;

  return PopupGate.exclusive<String>(PopupKeys.locationMap, () {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close location map',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return _WarehouseLocationPickerPage(
          category: category,
          mode: mode,
          staging: staging,
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    );
  });
}

class _WarehouseLocationPickerPage extends StatefulWidget {
  const _WarehouseLocationPickerPage({
    required this.category,
    required this.mode,
    required this.staging,
  });

  final LocationCategory category;
  final WarehouseMapPickMode mode;
  final List<StagingEntry> staging;

  @override
  State<_WarehouseLocationPickerPage> createState() =>
      _WarehouseLocationPickerPageState();
}

class _WarehouseLocationPickerPageState
    extends State<_WarehouseLocationPickerPage> {
  void _complete(String location) {
    Navigator.of(context).pop(location.trim());
  }

  @override
  Widget build(BuildContext context) {
    final chrome = IndustrialTheme.chromeOf(context);
    final instructions = switch (widget.mode) {
      WarehouseMapPickMode.aisle =>
        'Orange-highlighted aisle bays are selectable — tap a bay, then a slot '
        '(A-1 through F-2). Dark hatched areas are locked out.',
      WarehouseMapPickMode.floor =>
        'Orange-highlighted zones are selectable — Corp Drop-Off, Box Rack, '
        'Stainless, W-Doors, or South Wall (then SW 1–8). Dark hatched areas '
        'are locked out.',
      WarehouseMapPickMode.shipping =>
        'Orange-highlighted S.Box and Shipping Areas are selectable. Dark '
        'hatched areas are locked out.',
    };

    return Material(
      color: chrome.base,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      widget.category.label.toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                instructions,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: chrome.muted,
                      height: 1.35,
                    ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: WarehouseFloorMap(
                  staging: widget.staging,
                  pickConfig: WarehouseFloorMapPickConfig(
                    mode: widget.mode,
                    onPick: _complete,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
