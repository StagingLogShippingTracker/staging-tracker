import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_staging_log/core/theme.dart';
import 'package:swift_staging_log/data/app_state.dart';
import 'package:swift_staging_log/domain/location_intelligence.dart';
import 'package:swift_staging_log/features/shared/location_selector.dart';
import 'package:swift_staging_log/features/shared/widgets.dart';

class SelectorHarness extends ConsumerStatefulWidget {
  const SelectorHarness({super.key});

  @override
  ConsumerState<SelectorHarness> createState() => _SelectorHarnessState();
}

class _SelectorHarnessState extends ConsumerState<SelectorHarness> {
  String selected = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Selected: $selected'),
          FilledButton(
            key: const Key('open-location-selector'),
            onPressed: () async {
              final result = await showLocationSelector(
                context,
                ref,
                so: 'SO-200',
              );
              if (result != null) setState(() => selected = result.value);
            },
            child: const Text('Choose location'),
          ),
        ],
      ),
    );
  }
}

Widget testApp() => ProviderScope(
  overrides: [
    appDataProvider.overrideWith(
      (ref) => AppDataNotifier(ref, initialize: false),
    ),
    currentUserProvider.overrideWithValue(null),
    recentBinMovementsProvider.overrideWith((ref) async => []),
    for (final category in LocationCategory.values)
      locationSuggestionsProvider(category).overrideWith((ref) async {
        if (category == LocationCategory.aisle) {
          return ['A-01-A-1', 'A-01-A-2'];
        }
        return <String>[];
      }),
  ],
  child: MaterialApp(
    theme: buildSlstTheme(dark: false),
    home: const SelectorHarness(),
  ),
);

void main() {
  testWidgets('phone selector drills in, goes back, and closes with X', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp());

    await tester.tap(find.byKey(const Key('open-location-selector')));
    await tester.pumpAndSettle();
    for (final category in LocationCategory.values) {
      expect(find.text(category.label), findsOneWidget);
    }
    expect(find.byKey(const Key('location-selector-close')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Aisle Location'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-selector-input')), findsOneWidget);
    expect(find.text('A-01-A-1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('location-selector-back')));
    await tester.pumpAndSettle();
    expect(find.text('Floor Locations'), findsOneWidget);

    await tester.tap(find.byKey(const Key('location-selector-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-selector-close')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone selector accepts a free-text location without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp());

    await tester.tap(find.byKey(const Key('open-location-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outside'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('location-selector-input')),
      'North Yard',
    );
    await tester.pump();
    expect(find.textContaining('Use new location'), findsOneWidget);
    await tester.tap(find.byKey(const Key('location-selector-add-new')));
    await tester.pumpAndSettle();

    expect(find.text('Selected: North Yard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('container amount fields render empty on a phone', (
    tester,
  ) async {
    final controllers = List.generate(5, (_) => TextEditingController());
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContainerInputs(
            skids: controllers[0],
            boxes: controllers[1],
            crates: controllers[2],
            pipe: controllers[3],
            other: controllers[4],
            onChanged: () {},
          ),
        ),
      ),
    );
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .every((field) => field.controller?.text.isEmpty ?? false),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
