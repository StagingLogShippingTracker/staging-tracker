import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:swift_staging_log/core/theme.dart';
import 'package:swift_staging_log/data/app_state.dart';
import 'package:swift_staging_log/data/remembered_contacts.dart';
import 'package:swift_staging_log/domain/models.dart';
import 'package:swift_staging_log/features/shared/entry_suggestion_fields.dart';

void main() {
  test('person name typeahead matches Document Generator filter', () {
    final names = ['Alice', 'Bob', 'Alina', 'Charlie'];
    expect(filterPersonNames(names, '').toList(), names);
    expect(filterPersonNames(names, 'al').toList(), ['Alice', 'Alina']);
    expect(filterPersonNames(names, 'ob').toList(), ['Bob']);
  });

  test('carrier suggestions exclude hidden and legacy sentinel values', () {
    final result = filterCarrierSuggestions(
      [
        'Hi-Way 9',
        'RETURNED TO STOCK',
        'Consolidated',
        'Unassigned Carrier',
        ' hi-way 9 ',
        'Day & Ross',
        'Banish Me',
      ],
      hidden: ['banish me'],
    );

    expect(result, ['Day & Ross', 'Hi-Way 9']);
  });

  testWidgets('contact field searches identity and stores email', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final contacts = [
      ContactPerson(
        name: 'Amber Shuya',
        designation: 'Project Manager',
        email: 'amber.shuya@swiftsupply.ca',
        ext: '109',
        direct: '',
        mobile: '',
        branch: 'Corporate Projects',
      ),
      ContactPerson(
        name: 'No Email',
        designation: 'Warehouse',
        email: 'N/A',
        ext: '',
        direct: '',
        mobile: '',
        branch: 'Corporate',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [contactsProvider.overrideWith((ref) async => contacts)],
        child: MaterialApp(
          theme: buildSlstTheme(dark: false),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: ContactEmailField(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'project manager');
    await tester.pump();
    expect(find.text('Amber Shuya'), findsOneWidget);
    expect(find.text('Project Manager'), findsOneWidget);
    expect(find.text('amber.shuya@swiftsupply.ca'), findsOneWidget);
    expect(find.text('No Email'), findsNothing);

    await tester.tap(find.text('Amber Shuya'));
    await tester.pump();
    expect(controller.text, 'amber.shuya@swiftsupply.ca');
    expect(tester.takeException(), isNull);
  });

  testWidgets('carrier field selects remembered values and accepts new text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carrierSuggestionsProvider.overrideWith(
            (ref) async => ['Day & Ross', 'Hi-Way 9'],
          ),
        ],
        child: MaterialApp(
          theme: buildSlstTheme(dark: false),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: CarrierSuggestionField(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pump();
    await tester.tap(find.text('Hi-Way 9'));
    await tester.pump();
    expect(controller.text, 'Hi-Way 9');

    await tester.enterText(find.byType(TextField), 'New Freight Co');
    expect(controller.text, 'New Freight Co');
    expect(tester.takeException(), isNull);
  });
}
