import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../domain/location_intelligence.dart';
import '../../domain/models.dart';
import '../../domain/status.dart';

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
              'Nisku terminal · click a bay for A–F / 1–2 slots',
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
                const southH = 24.0;
                const shortAisleFlex = 11;
                const biteFlex = 18;
                const shortFlexTotal = shortAisleFlex + biteFlex; // 29

                final bodyH = aislePadTop + westH;
                final totalH = headerH + corpH + bodyH + southH;
                final biteTop = headerH + corpH + aislePadTop + longH;
                final biteH = shortH + southH;

                // Well = aisle column between west rail and east stainless.
                final wellW =
                    constraints.maxWidth - westW - vRuleW - vRuleW - eastW;
                final wellInner = (wellW - aislePadLeft).clamp(0.0, wellW);
                // Bite covers empty flex right of short aisles + east VRule + east rail.
                final biteW =
                    wellInner * (biteFlex / shortFlexTotal) + vRuleW + eastW;

                return SizedBox(
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
                                  width: (constraints.maxWidth - biteW)
                                      .clamp(0.0, constraints.maxWidth),
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

    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: IndustrialTheme.darkSurface,
          title: Text(
            bayKey,
            style: IndustrialTheme.mono(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: IndustrialTheme.textPrimary,
            ),
          ),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                              entries:
                                  index.slotEntries('$bayKey-$level-$side'),
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
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

/// Single SE bite cut out of the warehouse outline (one shape).
class _NotUsBite extends StatelessWidget {
  const _NotUsBite();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        border: Border.all(color: IndustrialTheme.borderStroke, width: 1.5),
        // Only the inner L-corner is rounded; bottom/right stay squared to the frame.
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
        ),
      ),
      child: Text(
        'NOT US',
        textAlign: TextAlign.center,
        style: IndustrialTheme.mono(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF111827),
        ),
      ),
    );
  }
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
                    const Spacer(),
                  ],
                ),
              ),
              _VRule(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: beforeShipBox,
                      child: _Pane(
                        label: 'Shipping',
                        entries: const [],
                        muted: true,
                        compact: true,
                      ),
                    ),
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

class _Pane extends StatelessWidget {
  const _Pane({
    required this.label,
    required this.entries,
    this.compact = false,
    this.muted = false,
    this.verticalText = false,
  });

  final String label;
  final List<StagingEntry> entries;
  final bool compact;
  final bool muted;
  final bool verticalText;

  @override
  Widget build(BuildContext context) {
    final occupied = entries.isNotEmpty && !muted;
    final fill = muted
        ? IndustrialTheme.darkHeader.withValues(alpha: 0.55)
        : _colorForEntries(entries);
    final border =
        muted ? IndustrialTheme.borderStroke : _borderForEntries(entries);
    final tip = muted
        ? label.replaceAll('\n', ' ')
        : (entries.isEmpty
            ? '${label.replaceAll('\n', ' ')} · empty'
            : '${label.replaceAll('\n', ' ')} · ${entries.length} jobs · '
                '${entries.fold<int>(0, (s, e) => s + e.qty)} containers');

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

    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 350),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border.withValues(alpha: 0.85)),
        ),
        child: verticalText ? RotatedBox(quarterTurns: 1, child: text) : text,
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
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        for (final item in items)
          Row(
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                    ),
              ),
            ],
          ),
      ],
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
    final fill = _colorForEntries(entries);
    final border = _borderForEntries(entries);
    final jobs = entries.length;
    final qty = entries.fold<int>(0, (s, e) => s + e.qty);
    final tip = entries.isEmpty
        ? '$bayKey · empty'
        : '$bayKey · $jobs jobs · $qty containers';

    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: border, width: 1),
      ),
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

class _SubSlotChip extends StatelessWidget {
  const _SubSlotChip({
    required this.label,
    required this.fullLocation,
    required this.entries,
  });

  final String label;
  final String fullLocation;
  final List<StagingEntry> entries;

  @override
  Widget build(BuildContext context) {
    final fill = _colorForEntries(entries);
    final border = _borderForEntries(entries);
    final tip = entries.isEmpty
        ? '$fullLocation · empty'
        : '$fullLocation · ${entries.length} jobs · '
            '${entries.fold<int>(0, (s, e) => s + e.qty)} containers';

    return Tooltip(
      message: tip,
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border),
        ),
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
    );
  }
}

Color _emptyFill() => IndustrialTheme.darkHeader;
Color _emptyBorder() => IndustrialTheme.borderStroke;

Color _colorForEntries(List<StagingEntry> entries) {
  if (entries.isEmpty) return _emptyFill();
  StagingEntry? worst;
  var worstWeight = -1;
  for (final e in entries) {
    final w = StatusRules.urgencyWeight(e.status);
    if (w > worstWeight) {
      worstWeight = w;
      worst = e;
    }
  }
  return _colorForStatus(worst!.status);
}

Color _borderForEntries(List<StagingEntry> entries) {
  if (entries.isEmpty) return _emptyBorder();
  return _colorForEntries(entries);
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

class _FloorOccupancyIndex {
  _FloorOccupancyIndex(List<StagingEntry> staging) : _all = staging {
    for (final e in staging) {
      final loc = e.location.trim();
      if (loc.isEmpty) continue;
      final upper = loc.toUpperCase();
      final parsed = parseAisleLocation(loc);

      if (parsed != null) {
        final bay =
            '${parsed.aisle}-${parsed.bay.toString().padLeft(2, '0')}';
        final slotSuffix = parsed.suffix == '1+2' ? '1' : parsed.suffix;
        final slot = '$bay-${parsed.level}-$slotSuffix';
        _bay.putIfAbsent(bay, () => []).add(e);
        _slot.putIfAbsent(slot.toUpperCase(), () => []).add(e);
        if (parsed.suffix == '1+2') {
          _slot
              .putIfAbsent('$bay-${parsed.level}-2'.toUpperCase(), () => [])
              .add(e);
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

  static List<String> _zoneNeedles(String zoneName) {
    switch (zoneName.toLowerCase()) {
      case 'corp drop':
        return ['corp drop', 'corpdrop', 'corp drop-off', 'corp drop off'];
      case 'box rack':
        return ['box rack', 'boxrack', 'box shelves', 'box shelf'];
      case 'shipping box rack':
        return ['shipping box rack', 'ship box rack', 'shipping boxrack'];
      case 'shipping areas':
        return [
          'shipping areas',
          'shipping area',
          'stage for shipping',
          'shipping wall',
          'murray',
          'murrays',
          'misc',
          'w-',
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

  static bool _matchesZone(
    String location,
    List<String> needles,
    String zoneName,
  ) {
    final loc = location.trim().toLowerCase();
    if (loc.isEmpty) return false;
    if (parseAisleLocation(location) != null) return false;
    if (zoneName.toLowerCase() == 'shipping areas' &&
        (loc.contains('box rack') || loc.contains('boxrack'))) {
      return false;
    }
    if (zoneName.toLowerCase() == 'box rack' && loc.contains('shipping')) {
      return false;
    }
    return needles.any(loc.contains);
  }
}
