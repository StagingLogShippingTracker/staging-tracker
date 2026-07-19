import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slst/core/theme.dart';
import 'package:slst/data/app_state.dart';
import 'package:slst/domain/models.dart';
import 'package:slst/domain/status.dart';
import 'package:slst/features/shared/log_tables.dart';
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

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [currentUserProvider.overrideWithValue(null)],
    child: MaterialApp(
      theme: buildSlstTheme(dark: false),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  test('StatusRules maps Ship Today/Tomorrow to YMD', () {
    final today = StatusRules.todayYmd();
    final tomorrow = StatusRules.tomorrowYmd();
    expect(StatusRules.toDb('Ship Today'), today);
    expect(StatusRules.toDb('Ship Tomorrow'), tomorrow);
    expect(StatusRules.formatUi(today), 'Ship Today');
    expect(StatusRules.formatUi(tomorrow), 'Ship Tomorrow');
  });

  test('ContainerCounts builds type labels', () {
    const c = ContainerCounts(skids: 2, boxes: 1);
    expect(c.total, 3);
    expect(c.typeLabel, contains('2 Skids'));
    expect(c.typeLabel, contains('1 Box'));
  });

  test('Overdue detection', () {
    expect(StatusRules.isOverdue('2000-01-01'), isTrue);
    expect(StatusRules.isOverdue('Ready to Ship'), isFalse);
  });

  test('Container totals include a true containers sum', () {
    final data = AppData(staging: [_staging(), _staging(id: '2', so: 'SO-1')]);
    final totals = data.containerTotals;
    expect(totals['containers'], 6);
    expect(totals['orders'], 2);
    expect(totals['skids'], 4);
  });

  testWidgets('KPI card renders label, value and red accent', (tester) async {
    await tester.pumpWidget(
      _wrap(const KpiCard(label: 'Orders', value: 12, icon: Icons.description)),
    );
    expect(find.text('ORDERS'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('Status legend lists all seven statuses', (tester) async {
    await tester.pumpWidget(_wrap(const StagingStatusLegend()));
    for (final label in [
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

  testWidgets('Staging table shows entry columns while signed out',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _wrap(StagingLogCard(entries: [_staging()], expanded: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Staging Entries'), findsOneWidget);
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
          entries: [_shipped(), _shipped(id: '10', carrier: 'RETURNED TO STOCK')],
          expanded: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shipped Log'), findsOneWidget);
    expect(find.text('Day & Ross'), findsOneWidget);
    expect(find.text('RETURNED TO STOCK'), findsOneWidget);
  });
}
