import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/location_intelligence.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';
import '../shared/order_history_dialog.dart';

/// Persisted collapse state for the dashboard Warehouse Floor Map section.
final floorMapCollapsedProvider =
    StateNotifierProvider<FloorMapCollapsedNotifier, bool>((ref) {
  return FloorMapCollapsedNotifier(ref);
});

class FloorMapCollapsedNotifier extends StateNotifier<bool> {
  FloorMapCollapsedNotifier(this._ref) : super(false) {
    _hydrate();
  }

  final Ref _ref;

  Future<void> _hydrate() async {
    final prefs = await _ref.read(prefsProvider.future);
    state = prefs.floorMapCollapsed;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await _ref.read(prefsProvider.future);
    await prefs.setFloorMapCollapsed(state);
  }
}

/// Nisku warehouse floor map — layout locked to the Paint reference edit.
///
/// - Long aisles (A–E, G, K, M): seat boxes spanning the full aisle well
/// - Short aisles (N–Z): shorter seat runs; SE **NOT US** cutout to their right
/// - South Wall stops where NOT US begins
/// - East Stainless only beside the long-aisle block (above NOT US)
class WarehouseFloorMap extends ConsumerWidget {
  const WarehouseFloorMap({super.key, required this.staging});

  final List<StagingEntry> staging;

  static const _recvAisles = ['A', 'B', 'C', 'D', 'E', 'G', 'K'];
  static const _shipLong = ['M'];
  static const _shipShort = ['N', 'P', 'Q', 'R', 'Y', 'Z'];
  static const _levels = ['A', 'B', 'C', 'D', 'E', 'F'];

  /// Modestly compact bay seats — still easy to click, less dashboard height.
  static const double _seat = 13;
  static const double _gap = 1.5;
  static double get _rowH => _seat + _gap;

  /// Long = 02–30 (every bay). Short = 02–12.
  static List<String> longBays() => [
        for (var n = 2; n <= 30; n++) n.toString().padLeft(2, '0'),
      ];

  static List<String> shortBays() => [
        for (var n = 2; n <= 12; n++) n.toString().padLeft(2, '0'),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(floorMapCollapsedProvider);

    Widget header() => Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                ref.read(floorMapCollapsedProvider.notifier).toggle(),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'WAREHOUSE FLOOR MAP',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                    color: IndustrialTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
        );

    if (collapsed) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: header(),
        ),
      );
    }

    final index = _FloorOccupancyIndex(staging);
    final long = longBays();
    final short = shortBays();

    // Density metric for the “yard efficiency” dashboard direction.
    // Total seats = long aisles × long bays + short aisles × short bays.
    final longAisles = [..._recvAisles, ..._shipLong];
    final shortAisles = [..._shipShort];
    final totalSeats =
        longAisles.length * long.length + shortAisles.length * short.length;
    var occupiedSeats = 0;
    for (final a in longAisles) {
      for (final bay in long) {
        final key = '$a-$bay';
        if (index.bayEntries(key).isNotEmpty) occupiedSeats++;
      }
    }
    for (final a in shortAisles) {
      for (final bay in short) {
        final key = '$a-$bay';
        if (index.bayEntries(key).isNotEmpty) occupiedSeats++;
      }
    }
    final densityPct = totalSeats == 0
        ? 0
        : ((occupiedSeats / totalSeats) * 100).round().clamp(0, 100);

    final longRows = _recvAisles.length + _shipLong.length;
    final shortRows = _shipShort.length;
    final longH = longRows * _rowH;
    final shortH = shortRows * _rowH;
    final westH = longH + shortH;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header(),
            const SizedBox(height: 2),
            Text(
              'Nisku terminal · click bays, zones, or A–F / 1–2 slots · '
              'Density $densityPct%',
              softWrap: true,
              overflow: TextOverflow.fade,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            const _StatusLegend(),
            const SizedBox(height: 8),
            // Building with a single SE “bite” (NOT US) cut out of the outline.
            // Geometry is exact: no extra west-rail fudge, no phantom dividers —
            // south wall + bite share one squared bottom edge.
            LayoutBuilder(
              builder: (context, constraints) {
                const westW = 80.0;
                const eastW = 62.0;
                const vRuleW = 1.0;
                const aislePadTop = 3.0;
                const aislePadLeft = 4.0;
                const headerH = 30.0;
                const corpH = 22.0;
                const southH = 48.0;
                const shortAisleFlex = 11;
                const biteFlex = 18;
                const shortFlexTotal = shortAisleFlex + biteFlex; // 29
                const compactMapWidth = 720.0;
                final narrow = constraints.maxWidth < 700;
                final layoutW = narrow ? compactMapWidth : constraints.maxWidth;

                final bodyH = aislePadTop + westH;
                final totalH = headerH + corpH + bodyH + southH;
                final biteTop = headerH + corpH + aislePadTop + longH;
                final biteH = shortH + southH;

                // Well = aisle column between west rail and east stainless.
                final wellW =
                    layoutW - westW - vRuleW - vRuleW - eastW;
                final wellInner = (wellW - aislePadLeft).clamp(0.0, wellW);
                // Bite covers empty flex right of short aisles + east VRule + east rail.
                final biteW =
                    wellInner * (biteFlex / shortFlexTotal) + vRuleW + eastW;

                final mapBody = SizedBox(
                  width: layoutW,
                  height: totalH,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // ── L-shaped warehouse (SE left empty for the bite) ──
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: headerH,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF121826),
                                border: Border.all(
                                  color: IndustrialTheme.borderStroke,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: _Pane(
                                      label: 'Offices',
                                      entries: index.zoneEntries('Offices'),
                                    ),
                                  ),
                                  _VRule(),
                                  Expanded(
                                    flex: 4,
                                    child: _Pane(
                                      label: 'Stainless',
                                      entries: index.zoneEntries('Stainless'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            height: corpH,
                            child: ColoredBox(
                              color: const Color(0xFF121826),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Center(
                                      child: SizedBox(
                                        width: 118,
                                        height: 16,
                                        child: _Pane(
                                          label: 'Corp Drop-Off',
                                          entries:
                                              index.zoneEntries('Corp Drop'),
                                          compact: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    flex: 4,
                                    child: SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Body — height locked to aisle stack (no SE bleed).
                          SizedBox(
                            height: bodyH,
                            child: ColoredBox(
                              color: const Color(0xFF121826),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: westW,
                                    height: bodyH,
                                    child: DecoratedBox(
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color:
                                                IndustrialTheme.borderStroke,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: aislePadTop,
                                        ),
                                        child: _WestRail(
                                          shortH: shortH,
                                          rowH: _rowH,
                                          index: index,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _VRule(),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        aislePadLeft,
                                        aislePadTop,
                                        0,
                                        0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (final a in [
                                            ..._recvAisles,
                                            ..._shipLong,
                                          ])
                                            _AisleRow(
                                              aisle: a,
                                              bays: long,
                                              fillWidth: true,
                                              index: index,
                                              onBayTap: (k) =>
                                                  _showBayDrillDown(
                                                context,
                                                k,
                                                index,
                                              ),
                                            ),
                                          SizedBox(
                                            height: shortH,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: shortAisleFlex,
                                                  child: Column(
                                                    children: [
                                                      for (final a
                                                          in _shipShort)
                                                        _AisleRow(
                                                          aisle: a,
                                                          bays: short,
                                                          fillWidth: true,
                                                          index: index,
                                                          onBayTap: (k) =>
                                                              _showBayDrillDown(
                                                            context,
                                                            k,
                                                            index,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                // Empty — single bite covers SE
                                                const Expanded(
                                                  flex: biteFlex,
                                                  child: SizedBox.shrink(),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _VRule(),
                                  SizedBox(
                                    width: eastW,
                                    height: aislePadTop + longH,
                                    child: DecoratedBox(
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color:
                                                IndustrialTheme.borderStroke,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      child: _Pane(
                                        label: 'Stainless',
                                        entries:
                                            index.zoneEntries('Stainless'),
                                        verticalText: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // South Wall — only left of the bite; flush bottom.
                          SizedBox(
                            height: southH,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: (layoutW - biteW).clamp(0.0, layoutW),
                                  height: southH,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF121826),
                                      border: Border.all(
                                        color: IndustrialTheme.borderStroke,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: _Pane(
                                      label: 'South Wall',
                                      entries:
                                          index.zoneEntries('South Wall'),
                                      heroTag: 'south-wall-pane',
                                      onOpen: () => _openSouthWallFocus(
                                        context,
                                        index,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // ── ONE continuous NOT US bite (squared bottom) ──
                      Positioned(
                        right: 0,
                        top: biteTop,
                        width: biteW,
                        height: biteH,
                        child: const _NotUsBite(),
                      ),
                    ],
                  ),
                );
                // Phone/narrow: horizontal ScrollView (not InteractiveViewer).
                // Nesting is orthogonal to the page ListView so pan keeps
                // working after bay InkWells paint occupancy colors.
                if (narrow) {
                  return SizedBox(
                    height: totalH,
                    width: constraints.maxWidth,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      physics: const ClampingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      child: mapBody,
                    ),
                  );
                }
                return mapBody;
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showBayDrillDown(
    BuildContext context,
    String bayKey,
    _FloorOccupancyIndex index,
  ) {
    final bayEntries = index.bayEntries(bayKey);
    final qty = bayEntries.fold<int>(0, (s, e) => s + e.qty);

    return _showFloorMapDialog(
      context: context,
      title: bayKey,
      titleMono: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final level in _levels)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      level,
                      style: IndustrialTheme.mono(
                        fontSize: 11,
                        color: IndustrialTheme.textMuted,
                      ),
                    ),
                  ),
                  for (final side in ['1', '2']) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: _SubSlotChip(
                        label: '$level-$side',
                        fullLocation: '$bayKey-$level-$side',
                        entries: index.slotEntries('$bayKey-$level-$side'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            bayEntries.isEmpty
                ? 'Empty bay'
                : '${bayEntries.length} jobs · $qty containers',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static Future<void> _openSouthWallFocus(
    BuildContext context,
    _FloorOccupancyIndex index,
  ) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _SouthWallFocusPage(index: index);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

/// Shared floor-map dialog: fixed footer Close (no AlertDialog actions float).
Future<void> _showFloorMapDialog({
  required BuildContext context,
  required String title,
  required Widget body,
  bool titleMono = false,
}) {
  final size = MediaQuery.sizeOf(context);
  final maxW = min(420.0, size.width - 40);
  final maxH = size.height * 0.8;

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: IndustrialTheme.darkSurface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: titleMono
                      ? IndustrialTheme.mono(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: IndustrialTheme.textPrimary,
                        )
                      : const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: IndustrialTheme.textPrimary,
                        ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: body,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Column card for a staging entry — SO is a tappable order-history link.
class _FloorEntryCard extends ConsumerWidget {
  const _FloorEntryCard({
    required this.entry,
    this.showLocation = false,
  });

  final StagingEntry entry;
  final bool showLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showOrderHistoryDialog(context, ref, so: entry.so),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                entry.so,
                style: IndustrialTheme.mono(
                  fontWeight: FontWeight.w700,
                  color: IndustrialTheme.skyBlue,
                ).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: IndustrialTheme.skyBlue,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                showLocation
                    ? '${entry.customer} · ${entry.location} · ${entry.type}'
                    : '${entry.customer} · ${entry.type} · ${entry.stagedBy}',
                style: const TextStyle(
                  color: IndustrialTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                StatusRules.formatUi(entry.status),
                style: IndustrialTheme.mono(
                  fontSize: 10,
                  color: IndustrialTheme.skyBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single SE bite cut out of the warehouse outline (one shape).
/// Lighter blue + diagonal hatch marks “not applicable” floor space.
class _NotUsBite extends StatelessWidget {
  const _NotUsBite();

  static const _fill = Color(0xFF1E3A5F); // lighter than dark map panes
  static const _stripe = Color(0xFF3B6EA5);
  static const _label = Color(0xFF93C5FD);

  @override
  Widget build(BuildContext context) {
    const corner = BorderRadius.only(topLeft: Radius.circular(4));
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: IndustrialTheme.borderStroke, width: 1.5),
        borderRadius: corner,
      ),
      child: ClipRRect(
        borderRadius: corner,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: _fill),
            const CustomPaint(painter: _NotUsHatchPainter(color: _stripe)),
            Center(
              child: Text(
                'NOT US',
                textAlign: TextAlign.center,
                style: IndustrialTheme.mono(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _label,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotUsHatchPainter extends CustomPainter {
  const _NotUsHatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    const spacing = 8.0;
    // Diagonal stripes (\\) across the full bite.
    final extent = size.width + size.height;
    for (var d = -size.height; d < extent; d += spacing) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NotUsHatchPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _WestRail extends StatelessWidget {
  const _WestRail({
    required this.shortH,
    required this.rowH,
    required this.index,
  });

  final double shortH;
  final double rowH;
  final _FloorOccupancyIndex index;

  @override
  Widget build(BuildContext context) {
    // Receiving aisles A B C D E G K — Box Rack at D+E (rows 3–4).
    const recvCount = 7;
    final recvH = recvCount * rowH;
    final beforeBox = 3 * rowH;
    final boxH = 2 * rowH;
    final afterBoxInRecv = recvH - beforeBox - boxH;
    // M is long (in longH after recv). Shipping short starts after M.
    final mH = rowH;
    final beforeShipBox = mH; // align S.Box with N–P after M
    final shipBoxH = 2 * rowH;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: recvH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    SizedBox(height: beforeBox),
                    SizedBox(
                      height: boxH,
                      child: _Pane(
                        label: 'Box\nRack',
                        entries: index.zoneEntries('Box Rack'),
                        compact: true,
                      ),
                    ),
                    SizedBox(height: afterBoxInRecv),
                  ],
                ),
              ),
              _VRule(),
              Expanded(
                child: _Pane(
                  label: 'Receiving\n(Buyouts)',
                  entries: const [],
                  muted: true,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: mH + shortH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    SizedBox(height: beforeShipBox),
                    SizedBox(
                      height: shipBoxH,
                      child: _Pane(
                        label: 'S.Box',
                        entries: index.zoneEntries('Shipping Box Rack'),
                        compact: true,
                      ),
                    ),
                    Expanded(
                      child: _Pane(
                        label: 'W-Doors',
                        entries: index.zoneEntries('W-Doors'),
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
              _VRule(),
              Expanded(
                child: _Pane(
                  label: 'Shipping\nAreas',
                  entries: index.zoneEntries('Shipping Areas'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, color: IndustrialTheme.borderStroke);
}

class _Pane extends ConsumerWidget {
  const _Pane({
    required this.label,
    required this.entries,
    this.compact = false,
    this.muted = false,
    this.verticalText = false,
    this.heroTag,
    this.onOpen,
  });

  final String label;
  final List<StagingEntry> entries;
  final bool compact;
  final bool muted;
  final bool verticalText;
  final Object? heroTag;
  final VoidCallback? onOpen;

  void _openZone(BuildContext context) {
    if (muted) return;
    if (onOpen != null) {
      onOpen!();
      return;
    }
    final title = label.replaceAll('\n', ' ');
    _showFloorMapDialog(
      context: context,
      title: title,
      body: entries.isEmpty
          ? const Text(
              'No active staging in this zone.',
              style: TextStyle(color: IndustrialTheme.textMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _FloorEntryCard(entry: entries[i], showLocation: true),
                ],
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occupied = entries.isNotEmpty && !muted;
    final border =
        muted ? IndustrialTheme.borderStroke : _borderForEntries(entries);
    final tip = muted
        ? label.replaceAll('\n', ' ')
        : (entries.isEmpty
            ? '${label.replaceAll('\n', ' ')} · empty · click for details'
            : '${label.replaceAll('\n', ' ')} · ${entries.length} jobs · '
                '${entries.fold<int>(0, (s, e) => s + e.qty)} containers · '
                'click for list');

    final text = Text(
      label.toUpperCase(),
      textAlign: TextAlign.center,
      style: IndustrialTheme.mono(
        fontSize: compact ? 8 : 9,
        fontWeight: FontWeight.bold,
        color: occupied
            ? IndustrialTheme.textPrimary
            : IndustrialTheme.textMuted,
      ),
      maxLines: verticalText ? 12 : 3,
      overflow: TextOverflow.ellipsis,
    );

    final body = muted
        ? Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            decoration: BoxDecoration(
              color: IndustrialTheme.darkHeader.withValues(alpha: 0.55),
              border: Border.all(color: border.withValues(alpha: 0.85)),
            ),
            child:
                verticalText ? RotatedBox(quarterTurns: 1, child: text) : text,
          )
        : _OccupancyBox(
            colors: _statusBandColors(entries),
            borderColor: border.withValues(alpha: 0.85),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child:
                verticalText ? RotatedBox(quarterTurns: 1, child: text) : text,
          );

    if (muted) {
      return Tooltip(
        message: tip,
        waitDuration: const Duration(milliseconds: 350),
        child: body,
      );
    }

    Widget interactive = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openZone(context),
        child: body,
      ),
    );
    if (heroTag != null) {
      interactive = Hero(
        tag: heroTag!,
        child: Material(
          type: MaterialType.transparency,
          child: interactive,
        ),
      );
    }

    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 350),
      child: interactive,
    );
  }
}

/// Full-screen South Wall staging focus: 2x4 free-flow sections (SW 1-8).
class _SouthWallFocusPage extends StatelessWidget {
  const _SouthWallFocusPage({required this.index});

  final _FloorOccupancyIndex index;

  static const _top = [1, 2, 3, 4];
  static const _bottom = [5, 6, 7, 8];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920, maxHeight: 640),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Hero(
                tag: 'south-wall-pane',
                child: Material(
                  color: const Color(0xFF121826),
                  elevation: 12,
                  shadowColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(
                      color: IndustrialTheme.borderStroke,
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'SOUTH WALL',
                                style: IndustrialTheme.mono(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: IndustrialTheme.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close, size: 20),
                              color: IndustrialTheme.textMuted,
                            ),
                          ],
                        ),
                      ),
                      const Divider(
                        height: 1,
                        color: IndustrialTheme.borderStroke,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < _top.length; i++) ...[
                                    if (i > 0)
                                      const VerticalDivider(
                                        width: 1,
                                        thickness: 1,
                                        color: IndustrialTheme.borderStroke,
                                      ),
                                    Expanded(
                                      child: _SouthWallSectionCell(
                                        section: _top[i],
                                        entries: index
                                            .southWallSectionEntries(_top[i]),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: IndustrialTheme.borderStroke,
                            ),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < _bottom.length; i++) ...[
                                    if (i > 0)
                                      const VerticalDivider(
                                        width: 1,
                                        thickness: 1,
                                        color: IndustrialTheme.borderStroke,
                                      ),
                                    Expanded(
                                      child: _SouthWallSectionCell(
                                        section: _bottom[i],
                                        entries: index.southWallSectionEntries(
                                          _bottom[i],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SouthWallSectionCell extends StatelessWidget {
  const _SouthWallSectionCell({
    required this.section,
    required this.entries,
  });

  final int section;
  final List<StagingEntry> entries;

  void _openSection(BuildContext context) {
    final label = 'SW $section';
    _showFloorMapDialog(
      context: context,
      title: label,
      titleMono: true,
      body: entries.isEmpty
          ? const Text(
              'No active staging in this section.',
              style: TextStyle(color: IndustrialTheme.textMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _FloorEntryCard(entry: entries[i], showLocation: true),
                ],
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = _borderForEntries(entries);
    final tip = entries.isEmpty
        ? 'SW $section · empty · click for details'
        : 'SW $section · ${entries.length} jobs · '
            '${entries.fold<int>(0, (s, e) => s + e.qty)} containers · click';

    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSection(context),
          child: _OccupancyBox(
            colors: _statusBandColors(entries),
            borderColor: border.withValues(alpha: 0.85),
            padding: const EdgeInsets.all(8),
            child: Text(
              'SW $section',
              textAlign: TextAlign.center,
              style: IndustrialTheme.mono(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: entries.isEmpty
                    ? IndustrialTheme.textMuted
                    : IndustrialTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend();

  @override
  Widget build(BuildContext context) {
    const items = <(String, Color)>[
      ('Empty', Color(0xFF111827)),
      ('Today / Ready', IndustrialTheme.mintGreen),
      ('Tomorrow / Transit', IndustrialTheme.skyBlue),
      ('Partial / Awaiting', IndustrialTheme.amber),
      ('Future / Corp', IndustrialTheme.purple),
      ('Occupied', IndustrialTheme.slateMuted),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final chips = [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.$2,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: item.$1 == 'Empty'
                            ? IndustrialTheme.borderStroke
                            : item.$2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.$1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
            ),
        ];
        // Prefer wrapping when width allows; otherwise scroll so labels
        // like "Future / Corp" are never mid-truncated.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Wrap(
              spacing: 0,
              runSpacing: 6,
              children: chips,
            ),
          ),
        );
      },
    );
  }
}

class _AisleRow extends StatelessWidget {
  const _AisleRow({
    required this.aisle,
    required this.bays,
    required this.index,
    required this.onBayTap,
    this.fillWidth = false,
  });

  final String aisle;
  final List<String> bays;
  final _FloorOccupancyIndex index;
  final ValueChanged<String> onBayTap;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final seats = <Widget>[
      for (var i = 0; i < bays.length; i++) ...[
        if (i > 0) SizedBox(width: WarehouseFloorMap._gap),
        if (fillWidth)
          Expanded(
            child: _BaySeat(
              bayKey: '$aisle-${bays[i]}',
              entries: index.bayEntries('$aisle-${bays[i]}'),
              onTap: () => onBayTap('$aisle-${bays[i]}'),
            ),
          )
        else
          _BaySeat(
            bayKey: '$aisle-${bays[i]}',
            size: WarehouseFloorMap._seat,
            entries: index.bayEntries('$aisle-${bays[i]}'),
            onTap: () => onBayTap('$aisle-${bays[i]}'),
          ),
      ],
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: WarehouseFloorMap._gap),
      child: SizedBox(
        height: WarehouseFloorMap._seat,
        child: Row(
          children: [
              SizedBox(
              width: 12,
              child: Text(
                aisle,
                style: IndustrialTheme.mono(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: IndustrialTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 3),
            if (fillWidth)
              Expanded(child: Row(children: seats))
            else
              ...seats,
          ],
        ),
      ),
    );
  }
}

class _BaySeat extends StatelessWidget {
  const _BaySeat({
    required this.bayKey,
    required this.entries,
    required this.onTap,
    this.size,
  });

  final String bayKey;
  final List<StagingEntry> entries;
  final VoidCallback onTap;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final border = _borderForEntries(entries);
    final jobs = entries.length;
    final qty = entries.fold<int>(0, (s, e) => s + e.qty);
    final tip = entries.isEmpty
        ? '$bayKey · empty'
        : '$bayKey · $jobs jobs · $qty containers';

    final box = _OccupancyBox(
      colors: _statusBandColors(entries),
      borderColor: border,
      borderRadius: BorderRadius.circular(3),
    );

    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: size == null
              ? SizedBox.expand(child: box)
              : SizedBox(width: size, height: size, child: box),
        ),
      ),
    );
  }
}

class _SubSlotChip extends ConsumerWidget {
  const _SubSlotChip({
    required this.label,
    required this.fullLocation,
    required this.entries,
  });

  final String label;
  final String fullLocation;
  final List<StagingEntry> entries;

  void _openSlot(BuildContext context) {
    _showFloorMapDialog(
      context: context,
      title: fullLocation,
      titleMono: true,
      body: entries.isEmpty
          ? const Text(
              'Empty slot — no active staging here.',
              style: TextStyle(color: IndustrialTheme.textMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _FloorEntryCard(entry: entries[i]),
                ],
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final border = _borderForEntries(entries);
    final tip = entries.isEmpty
        ? '$fullLocation · empty · click'
        : '$fullLocation · ${entries.length} jobs · '
            '${entries.fold<int>(0, (s, e) => s + e.qty)} containers · click';

    return Tooltip(
      message: tip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSlot(context),
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 28,
            child: _OccupancyBox(
              colors: _statusBandColors(entries),
              borderColor: border,
              borderRadius: BorderRadius.circular(4),
              child: Text(
                label,
                style: IndustrialTheme.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: entries.isEmpty
                      ? IndustrialTheme.textMuted
                      : IndustrialTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _emptyFill() => IndustrialTheme.darkHeader;
Color _emptyBorder() => IndustrialTheme.borderStroke;

/// Distinct status colors for a location, urgency-sorted (highest first).
List<Color> _statusBandColors(List<StagingEntry> entries) {
  if (entries.isEmpty) return [_emptyFill()];
  final bestByUi = <String, StagingEntry>{};
  for (final e in entries) {
    final ui = StatusRules.formatUi(e.status);
    final prev = bestByUi[ui];
    if (prev == null ||
        StatusRules.urgencyWeight(e.status) >
            StatusRules.urgencyWeight(prev.status)) {
      bestByUi[ui] = e;
    }
  }
  final ordered = bestByUi.values.toList()
    ..sort(
      (a, b) =>
          StatusRules.urgencyWeight(b.status) -
          StatusRules.urgencyWeight(a.status),
    );
  return [for (final e in ordered) _colorForStatus(e.status)];
}

Color _borderForEntries(List<StagingEntry> entries) {
  if (entries.isEmpty) return _emptyBorder();
  return _statusBandColors(entries).first;
}

Color _colorForStatus(String dbStatus) {
  final ui = StatusRules.formatUi(dbStatus).toLowerCase();
  if (ui.contains('today') ||
      StatusRules.isOverdue(dbStatus) ||
      ui.contains('ready')) {
    return IndustrialTheme.mintGreen;
  }
  if (ui.contains('tomorrow') || ui.contains('transit')) {
    return IndustrialTheme.skyBlue;
  }
  if (ui.contains('partial') || ui.contains('awaiting')) {
    return IndustrialTheme.amber;
  }
  if (ui.contains('future') ||
      ui.contains('corp pick') ||
      (StatusRules.isYmd(dbStatus) &&
          StatusRules.formatUi(dbStatus) == dbStatus)) {
    return IndustrialTheme.purple;
  }
  if (ui.contains('corp')) return IndustrialTheme.purple;
  return IndustrialTheme.slateMuted;
}

/// Paints equal vertical status bands + a full outer border (grid outline intact).
class _OccupancyBox extends StatelessWidget {
  const _OccupancyBox({
    required this.colors,
    required this.borderColor,
    this.borderRadius = BorderRadius.zero,
    this.padding,
    this.child,
  });

  final List<Color> colors;
  final Color borderColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OccupancyPainter(
        colors: colors.isEmpty ? [_emptyFill()] : colors,
        borderColor: borderColor,
        borderRadius: borderRadius,
      ),
      child: child == null
          ? null
          : Padding(
              padding: padding ?? EdgeInsets.zero,
              child: Center(child: child),
            ),
    );
  }
}

class _OccupancyPainter extends CustomPainter {
  const _OccupancyPainter({
    required this.colors,
    required this.borderColor,
    required this.borderRadius,
  });

  final List<Color> colors;
  final Color borderColor;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final outer = Offset.zero & size;
    final rrect = borderRadius.toRRect(outer);

    canvas.save();
    canvas.clipRRect(rrect);
    if (colors.length == 1) {
      canvas.drawRect(outer, Paint()..color = colors.first);
    } else {
      final bandW = size.width / colors.length;
      for (var i = 0; i < colors.length; i++) {
        // Slight overlap avoids sub-pixel seams between bands.
        final left = i * bandW;
        final right = (i == colors.length - 1) ? size.width : (i + 1) * bandW + 0.5;
        canvas.drawRect(
          Rect.fromLTRB(left, 0, right, size.height),
          Paint()..color = colors[i],
        );
      }
      // Subtle separators between bands (not the outer grid).
      final sep = Paint()
        ..color = const Color(0x66000000)
        ..strokeWidth = 1;
      for (var i = 1; i < colors.length; i++) {
        final x = i * bandW;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), sep);
      }
    }
    canvas.restore();

    // Full block outline — same role as the old DecoratedBox border.
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _OccupancyPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderRadius != borderRadius ||
      !_listEquals(oldDelegate.colors, colors);

  static bool _listEquals(List<Color> a, List<Color> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _FloorOccupancyIndex {
  _FloorOccupancyIndex(List<StagingEntry> staging) : _all = staging {
    for (final e in staging) {
      final loc = e.location.trim();
      if (loc.isEmpty) continue;
      final upper = loc.toUpperCase();
      final parsed = parseAisleLocation(loc);

      if (parsed != null) {
        final bay = parsed.bayKey;
        _bay.putIfAbsent(bay, () => []).add(e);
        for (final slot in parsed.coveredSlots) {
          _slot.putIfAbsent(slot.toUpperCase(), () => []).add(e);
        }
        continue;
      }

      final bayOnly = RegExp(r'^([A-Z])-(\d{2})$', caseSensitive: false)
          .firstMatch(upper);
      if (bayOnly != null) {
        final bay =
            '${bayOnly.group(1)!.toUpperCase()}-${bayOnly.group(2)!}';
        _bay.putIfAbsent(bay, () => []).add(e);
        continue;
      }

      _loose.add(e);
    }
  }

  final List<StagingEntry> _all;
  final Map<String, List<StagingEntry>> _bay = {};
  final Map<String, List<StagingEntry>> _slot = {};
  final List<StagingEntry> _loose = [];

  List<StagingEntry> bayEntries(String bayKey) {
    final direct = List<StagingEntry>.from(_bay[bayKey] ?? const []);
    final prefix = '$bayKey-'.toUpperCase();
    final key = bayKey.toUpperCase();
    for (final e in _loose) {
      final u = e.location.trim().toUpperCase();
      if (u == key || u.startsWith(prefix)) direct.add(e);
    }
    return direct;
  }

  List<StagingEntry> slotEntries(String fullLocation) {
    final key = fullLocation.toUpperCase();
    final direct = List<StagingEntry>.from(_slot[key] ?? const []);
    for (final e in _loose) {
      if (e.location.trim().toUpperCase() == key) direct.add(e);
    }
    return direct;
  }

  List<StagingEntry> zoneEntries(String zoneName) {
    final needles = _zoneNeedles(zoneName);
    return [
      for (final e in _all)
        if (_matchesZone(e.location, needles, zoneName)) e,
    ];
  }

  /// Entries staged in a specific South Wall section (SW 1–8).
  List<StagingEntry> southWallSectionEntries(int section) {
    if (section < 1 || section > 8) return const [];
    return [
      for (final e in _all)
        if (parseSouthWallSection(e.location) == section) e,
    ];
  }

  static List<String> _zoneNeedles(String zoneName) {
    switch (zoneName.toLowerCase()) {
      case 'corp drop':
        return ['corp drop', 'corpdrop', 'corp drop-off', 'corp drop off'];
      case 'box rack':
        return ['box rack', 'boxrack', 'box shelves', 'box shelf'];
      case 'shipping box rack':
        return ['shipping box rack', 'ship box rack', 'shipping boxrack'];
      case 'w-doors':
        // Needles for free-text labels; door numbers matched via regex below.
        return ['w-doors', 'w doors', 'wdoors'];
      case 'shipping areas':
        // No broad 'w-' — W-17..W-23 belong to W-Doors only.
        return [
          'shipping areas',
          'shipping area',
          'stage for shipping',
          'shipping wall',
          'murray',
          'murrays',
          'misc',
        ];
      case 'south wall':
        return ['south wall', 'southwall'];
      case 'stainless':
        return ['stainless'];
      case 'offices':
        return ['offices', 'office'];
      default:
        return [zoneName.toLowerCase()];
    }
  }

  /// W-Doors: doors W-17 through W-23 (inclusive), plus free-text zone labels.
  /// Matches even when parseAisleLocation would treat a fuller bin as aisle W.
  static final _wDoorsDoorRe = RegExp(r'\bw-(1[7-9]|2[0-3])\b');

  static bool _isWDoorsLocation(String location) {
    final loc = location.trim().toLowerCase();
    if (loc.isEmpty) return false;
    if (loc.contains('w-doors') ||
        loc.contains('w doors') ||
        loc.contains('wdoors')) {
      return true;
    }
    return _wDoorsDoorRe.hasMatch(loc);
  }

  static bool _matchesZone(
    String location,
    List<String> needles,
    String zoneName,
  ) {
    final loc = location.trim().toLowerCase();
    if (loc.isEmpty) return false;

    final zone = zoneName.toLowerCase();

    // W-Doors wins even for aisle-parseable W-17..W-23 forms.
    if (zone == 'w-doors') return _isWDoorsLocation(location);

    // South Wall: any SW 1–8 section label, or free-text "south wall".
    if (zone == 'south wall') {
      if (parseSouthWallSection(location) != null) return true;
      return needles.any(loc.contains);
    }

    if (parseAisleLocation(location) != null) return false;

    // Bay-only W-17..W-23 must not light Shipping Areas (or other zones).
    if (_isWDoorsLocation(location)) return false;

    if (zone == 'shipping areas' &&
        (loc.contains('box rack') || loc.contains('boxrack'))) {
      return false;
    }
    if (zone == 'box rack' && loc.contains('shipping')) {
      return false;
    }
    return needles.any(loc.contains);
  }
}
