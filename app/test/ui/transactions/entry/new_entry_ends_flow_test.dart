import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/ui_test_timeout.dart';

import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';

import 'new_entry_session_harness.dart';

const _outsideTap = Offset(5, 5);
const _nameKey = ValueKey('new-entry-name');
const _everyMonth = 'Every month';
const _chooseDate = 'Choose date';

enum _Origin { pad, name }

EntryFormViewState _state(EntryHarness harness) =>
    harness.container.read(entryFormViewModelProvider(null)).value!;

Future<EntryHarness> _openAdd(WidgetTester tester, _Origin origin) async {
  final harness = await pumpShell(tester);
  await openAdd(tester, harness);
  if (origin == _Origin.name) {
    await tester.tap(find.byKey(_nameKey));
    await tester.pumpAndSettle();
  }
  return harness;
}

Future<void> _tapRow(WidgetTester tester, String key) async {
  final row = find.byKey(ValueKey('new-entry-$key'));
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Future<void> _chooseEndsAction(WidgetTester tester, String label) async {
  await _tapRow(tester, 'ends');
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _makeRecurring(WidgetTester tester) async {
  await _tapRow(tester, 'repeat');
  await tester.tap(find.text(_everyMonth));
  await tester.pumpAndSettle();
}

void _expectInputsDismissed(WidgetTester tester) {
  expect(find.byType(NumberPad), findsNothing);
  expect(tester.testTextInput.isVisible, isFalse);
}

void main() {
  for (final origin in _Origin.values) {
    group('from ${origin.name} focus', () {
      testWidgets('Repeat accepts a frequency and keeps inputs dismissed', (
        tester,
      ) async {
        final harness = await _openAdd(tester, origin);

        await _makeRecurring(tester);

        expect(_state(harness).recurrence, RecurrenceFrequency.monthly);
        expect(find.text(_everyMonth), findsOneWidget);
        _expectInputsDismissed(tester);
      }, timeout: uiTestTimeout);

      testWidgets('dismissing Repeat keeps the frequency and the inputs down', (
        tester,
      ) async {
        final harness = await _openAdd(tester, origin);

        await _tapRow(tester, 'repeat');
        await tester.tapAt(_outsideTap);
        await tester.pumpAndSettle();

        expect(_state(harness).recurrence, isNull);
        expect(find.byType(AppSheet), findsOneWidget);
        _expectInputsDismissed(tester);
      }, timeout: uiTestTimeout);

      testWidgets('Ends Choose date applies the date and keeps inputs down', (
        tester,
      ) async {
        final harness = await _openAdd(tester, origin);
        await _makeRecurring(tester);

        await _chooseEndsAction(tester, _chooseDate);
        expect(find.byType(DatePickerSheet), findsOneWidget);
        await tester.tap(find.byKey(pickerDoneKey));
        await tester.pumpAndSettle();

        expect(_state(harness).hasEndDate, isTrue);
        expect(_state(harness).endDate, _state(harness).date);
        _expectInputsDismissed(tester);
      }, timeout: uiTestTimeout);

      testWidgets(
        'dismissing the Ends choice or the calendar changes nothing',
        (tester) async {
          final harness = await _openAdd(tester, origin);
          await _makeRecurring(tester);

          await _tapRow(tester, 'ends');
          await tester.tapAt(_outsideTap);
          await tester.pumpAndSettle();
          await _chooseEndsAction(tester, _chooseDate);
          await tester.tapAt(_outsideTap);
          await tester.pumpAndSettle();

          expect(_state(harness).hasEndDate, isFalse);
          expect(_state(harness).endDate, isNull);
          expect(find.byType(AppSheet), findsOneWidget);
          _expectInputsDismissed(tester);
        },
        timeout: uiTestTimeout,
      );
    });
  }

  group('Ends choice', () {
    testWidgets('lists Never and Choose date with no Cancel', (tester) async {
      await _openAdd(tester, _Origin.pad);
      await _makeRecurring(tester);

      await _tapRow(tester, 'ends');

      expect(find.byType(AppPickerHeader), findsOneWidget);
      expect(find.text('Never'), findsNWidgets(2));
      expect(find.text(_chooseDate), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('Never keeps the cached date and shows Never', (tester) async {
      final harness = await _openAdd(tester, _Origin.pad);
      await _makeRecurring(tester);
      harness.form.applyPickedEndDate(DateTime.utc(2030, 5, 1));
      await tester.pumpAndSettle();

      await _tapRow(tester, 'ends');
      await tester.tap(find.text('Never').last);
      await tester.pumpAndSettle();

      expect(_state(harness).hasEndDate, isFalse);
      expect(_state(harness).endDate, DateTime.utc(2030, 5, 1));
      expect(find.text('Never'), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('Does not repeat removes the Ends row and its state', (
      tester,
    ) async {
      final harness = await _openAdd(tester, _Origin.pad);
      await _makeRecurring(tester);
      harness.form.applyPickedEndDate(DateTime.utc(2030, 5, 1));
      await tester.pumpAndSettle();

      await _tapRow(tester, 'repeat');
      await tester.tap(find.text('Does not repeat').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('new-entry-ends')), findsNothing);
      expect(_state(harness).hasEndDate, isFalse);
      expect(_state(harness).endDate, isNull);
    }, timeout: uiTestTimeout);

    testWidgets('a retired Add opens no calendar after the choice', (
      tester,
    ) async {
      final harness = await _openAdd(tester, _Origin.pad);
      await _makeRecurring(tester);
      await _tapRow(tester, 'ends');

      addDismiss(tester)();
      await tester.pumpAndSettle();
      await tester.tap(find.text(_chooseDate));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerSheet), findsNothing);
      expect(find.byType(AppSheet), findsNothing);
      await harness.opened;
    }, timeout: uiTestTimeout);
  });

  testWidgets('tapping the Name label from the pad focuses Name only', (
    tester,
  ) async {
    await _openAdd(tester, _Origin.pad);
    expect(find.byType(NumberPad), findsOneWidget);

    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();

    expect(find.byType(NumberPad), findsNothing);
    expect(tester.testTextInput.isVisible, isTrue);
    final name = tester.widget<TextField>(find.byKey(_nameKey));
    expect(name.focusNode!.hasFocus, isTrue);

    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();

    expect(name.focusNode!.hasFocus, isTrue);
    expect(find.byType(NumberPad), findsNothing);
    expect(tester.testTextInput.isVisible, isTrue);
  }, timeout: uiTestTimeout);
}
