import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/recurrence_picker.dart';

void main() {
  late Future<RecurrenceFrequency?> pendingOutcome;

  Future<void> openSheet(
    WidgetTester tester, {
    RecurrenceFrequency? selected,
  }) async {
    // The half-height sheet holds six rows, taller than the default 800x600
    // test surface, so a row can go unbuilt outside the ListView viewport.
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                pendingOutcome = showRecurrencePickerSheet(
                  context: context,
                  selected: selected,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists one time plus every frequency', (tester) async {
    await openSheet(tester);

    expect(find.text('One time'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Biweekly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Quarterly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
  });

  testWidgets('shows a checkmark only on the selected row', (tester) async {
    await openSheet(tester, selected: RecurrenceFrequency.monthly);

    final monthlyRow = find.ancestor(
      of: find.text('Monthly'),
      matching: find.byType(ListTile),
    );
    final weeklyRow = find.ancestor(
      of: find.text('Weekly'),
      matching: find.byType(ListTile),
    );

    expect(
      find.descendant(of: monthlyRow, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: weeklyRow, matching: find.byIcon(Icons.check)),
      findsNothing,
    );
  });

  testWidgets('null selection shows the checkmark on One time', (tester) async {
    await openSheet(tester, selected: null);

    final oneTimeRow = find.ancestor(
      of: find.text('One time'),
      matching: find.byType(ListTile),
    );

    expect(
      find.descendant(of: oneTimeRow, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets('tapping a row sets the frequency and dismisses', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Biweekly'));
    await tester.pumpAndSettle();

    expect(await pendingOutcome, RecurrenceFrequency.biweekly);
  });

  testWidgets('tapping One time clears the frequency', (tester) async {
    await openSheet(tester, selected: RecurrenceFrequency.yearly);

    await tester.tap(find.text('One time'));
    await tester.pumpAndSettle();

    expect(await pendingOutcome, isNull);
  });
}
