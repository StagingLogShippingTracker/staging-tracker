import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:slst/core/theme.dart';
import 'package:slst/data/app_state.dart';
import 'package:slst/data/log_view_mode.dart';
import 'package:slst/domain/models.dart';
import 'package:slst/domain/status.dart';
import 'package:slst/features/reports/verification_audit.dart';
import 'package:slst/features/shared/log_tables.dart';
import 'package:slst/features/shared/order_history_dialog.dart';
import 'package:slst/features/shared/widgets.dart';

StagingEntry _staging({
  String id = '1',
  String so = 'SO-1001',
  String status = 'Partial',
}) {
  return StagingEntry(
    id: id,
    so: so,
    customer: 'Acme Industrial',
    status: status,
    location: 'A-01-B-1',
    type: '2 Skids, 1 Box',
    qty: 3,
    weight: '450 lbs',
    comments: 'Handle with care',
    stagedBy: 'Brice',
    entryDate: DateTime(2026, 7, 1, 9, 30),
  );
}

ShippedEntry _shipped({String id = '9', String carrier = 'Day & Ross'}) {
  return ShippedEntry(
    id: id,
    so: 'SO-2002',
    customer: 'Northern Mechanical',
    carrier: carrier,
    location: 'B-04-C-2',
    type: '1 Crate',
    qty: 1,
    shippedBy: 'Brice',
    pmdEmail: 'Jordan',
    shippedAt: DateTime(2026, 7, 2, 15, 45),
  );
}

Widget _wrap(Widget child, SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(null),
      logViewModeProvider.overrideWith(
        (ref) => LogViewModeNotifier(prefs, LogViewMode.list),
      ),
    ],
    child: MaterialApp(
      theme: buildSlstTheme(dark: false),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('StatusRules maps Ship Today/Tomorrow to YMD', () {
    final today = StatusRules.todayYmd();
    final tomorrow = StatusRules.tomorrowYmd();
    expect(StatusRules.toDb('Ship Today'), today);
    expect(StatusRules.toDb('Ship Tomorrow'), tomorrow);
    expect(StatusRules.formatUi(today), 'Ship Today');
    expect(StatusRules.formatUi(tomorrow), 'Ship Tomorrow');
  });

  test('StatusRules maps Rush/Hotshot canonically', () {
    expect(StatusRules.toDb('Rush/Hotshot'), StatusRules.rushHotshot);
    expect(StatusRules.toDb('Rush / Hotshot'), StatusRules.rushHotshot);
    expect(StatusRules.formatUi('Rush / Hotshot'), StatusRules.rushHotshot);
    expect(StatusRules.isRushHotshot('rush-hotshot'), isTrue);
    expect(StatusRules.urgencyWeight('Rush/Hotshot'), greaterThan(50));
  });

  test('ContainerCounts builds type labels', () {
    const c = ContainerCounts(skids: 2, boxes: 1);
    expect(c.total, 3);
    expect(c.typeLabel, contains('2 Skids'));
    expect(c.typeLabel, contains('1 Box'));
    expect(const ContainerCounts(boxes: 4).typeLabel, '4 Boxes');
  });

  test('ContainerCounts.parse round-trips type labels', () {
    final c = ContainerCounts.parse('2 Skids, 1 Box, 3 Pipe/Rod');
    expect(c.skids, 2);
    expect(c.boxes, 1);
    expect(c.pipe, 3);
    expect(c.crates, 0);
    expect(c.total, 6);
  });

  test('Verification audit walks the warehouse in location order', () {
    StagingEntry at(String id, String loc) => StagingEntry(
      id: id,
      so: 'SO-$id',
      customer: 'C',
      status: 'Partial',
      location: loc,
      type: '1 Skid',
      qty: 1,
    );
    final entries = [
      at('1', 'CORP DROP'),
      at('2', 'A-02-B-1'),
      at('3', 'W-1 SHIPPING'),
      at('4', 'BOX SHELF 3'),
      at('5', 'A-02-A-2'),
      at('6', 'PARTIAL BOX SHELF'),
      at('7', 'SOUTH WALL'),
    ]..sort(compareAuditLocations);
    expect(entries.map((e) => e.location).toList(), [
      'BOX SHELF 3',
      'PARTIAL BOX SHELF',
      'A-02-A-2',
      'A-02-B-1',
      'SOUTH WALL',
      'W-1 SHIPPING',
      'CORP DROP',
    ]);
  });

  test('Overdue detection', () {
    expect(StatusRules.isOverdue('2000-01-01'), isTrue);
    expect(StatusRules.isOverdue('Ready to Ship'), isFalse);
  });

  test('Container totals include a true containers sum', () {
    final data = AppData(
      staging: [
        _staging(),
        _staging(id: '2', so: 'SO-1'),
      ],
    );
    final totals = data.containerTotals;
    expect(totals['containers'], 6);
    expect(totals['orders'], 2);
    expect(totals['skids'], 4);
  });

  test('Order History separates and deduplicates bin movements', () {
    final at = DateTime(2026, 7, 3, 10);
    final result = buildOrderHistoryLogData([
      ChangelogEntry(
        id: '1',
        tableName: 'staging',
        action:
            'Bin Movement: To Shipped Log — SO SO-1001 moved from Staging Log to Shipped Log',
        userEmail: 'brice',
        createdAt: at,
      ),
      ChangelogEntry(
        id: '2',
        tableName: 'staging',
        action: 'Ship Confirmed SO: SO-1001',
        userEmail: 'brice',
        createdAt: at.add(const Duration(seconds: 1)),
      ),
      ChangelogEntry(
        id: '3',
        tableName: 'staging',
        action: 'Edited SO SO-1001',
        userEmail: 'brice',
        createdAt: at.subtract(const Duration(minutes: 1)),
      ),
    ], 'SO-1001');

    expect(result.movements, hasLength(1));
    expect(result.movements.single.label, 'To Shipped');
    expect(result.movements.single.summary, contains('SO SO-1001 moved'));
    expect(result.changelog.map((entry) => entry.action), [
      'Edited SO SO-1001',
    ]);
  });

  testWidgets('KPI card renders label and value', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const KpiCard(label: 'Orders', value: 12, icon: Icons.description),
        prefs,
      ),
    );
    expect(find.text('ORDERS'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('Status legend lists all eight statuses', (tester) async {
    await tester.pumpWidget(_wrap(const StagingStatusLegend(), prefs));
    for (final label in [
      'Rush/Hotshot',
      'Partial',
      'Ship Today',
      'Ship Tomorrow',
      'Ship On Future Date',
      'Corp Pick',
      'Customer Pick-Up',
      'Awaiting Instructions',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('Staging table shows entry columns while signed out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _wrap(StagingLogCard(entries: [_staging()], expanded: true), prefs),
    );
    await tester.pumpAndSettle();
    expect(find.text('ACTIVE STAGING ENTRIES'), findsOneWidget);
    expect(find.text('SO-1001'), findsOneWidget);
    expect(find.text('Acme Industrial'), findsOneWidget);
    // Signed out: no write affordances.
    expect(find.text('Batch Mode'), findsNothing);
    expect(find.text('New Entry'), findsNothing);
    expect(find.text('EDIT'), findsNothing);
  });

  testWidgets('Shipped table renders and flags returns', (tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _wrap(
        ShippedLogCard(
          entries: [
            _shipped(),
            _shipped(id: '10', carrier: 'RETURNED TO STOCK'),
          ],
          expanded: true,
        ),
        prefs,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SHIPPED STAGING ENTRIES'), findsOneWidget);
    expect(find.textContaining('Day & Ross'), findsWidgets);
    // Returned rows use the industrial status badge (uppercase label).
    expect(find.text('RETURNED'), findsWidgets);
  });

  testWidgets('Order History is complete and fits a phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final active = _staging();
    final shipped = ShippedEntry(
      id: 'ship-1',
      so: active.so,
      customer: active.customer,
      carrier: 'Day & Ross',
      location: active.location,
      type: '1 Skid',
      qty: 1,
      shippedBy: 'Brice',
      shippedAt: DateTime(2026, 7, 2, 15, 45),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSlstTheme(dark: false),
        home: OrderHistoryDialog(
          so: active.so,
          activeEntries: [active],
          shippedEntries: [shipped],
          historyFuture: Future.value(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order History:'), findsOneWidget);
    expect(find.byKey(const Key('order-history-close')), findsOneWidget);
    expect(find.text('Current Active Staging'), findsOneWidget);
    expect(find.text('Past Shipments'), findsOneWidget);
    expect(find.text('Bin Movements'), findsOneWidget);
    expect(find.text('Changelog History'), findsOneWidget);
    expect(find.textContaining('Shipped via Day & Ross'), findsOneWidget);
    expect(find.text('Add Entry'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
