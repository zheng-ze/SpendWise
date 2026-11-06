import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/plans/plan_form/plan_form.dart';
import 'package:spendwise/ui/plans/plan_list/plan_selection.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/ui_test_timeout.dart';
import '../plans_shell_test_support.dart';

const _frameMode = ShellLayoutMode.phone;
const _sheetTitle = 'Edit plan';
const _cancelLabel = 'Cancel';
const _saveLabel = 'Save plan';
const _accountLabel = 'Account';
const _repeatLabel = 'Repeat';
const _endsLabel = 'Ends';
const _endDateLabel = 'End date';
const _chooseDateLabel = 'Choose date';
const _neverLabel = 'Never';
const _onADateLabel = 'On a date';
const _noRepeatLabel = 'Does not repeat';
const _quarterlyLabel = 'Every three months';
const _newName = 'Flat rent';
const _newAmount = '1300';
const _outsideOffset = Offset(5, 5);

final _editButton = find.widgetWithText(FilledButton, _sheetTitle);
final _form = find.byType(PlanForm);
Finder _inForm(String text) =>
    find.descendant(of: _form, matching: find.text(text));

final _nameField = find
    .descendant(of: _form, matching: find.byType(TextField))
    .first;
final _amountField = find.descendant(
  of: find.byType(AmountField),
  matching: find.byType(TextField),
);

Future<ProviderContainer> _pumpEdit(
  WidgetTester tester,
  ShellLayoutMode mode,
  Brightness brightness,
  Ledger ledger,
) async {
  final container = await pumpPlansShell(
    tester,
    mode: mode,
    ledger: ledger,
    brightness: brightness,
  );
  await tapPlan(tester, plansShellExpensePlan.id);
  await tester.tap(_editButton);
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tapRow(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ListTile, label));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _choosePicked(WidgetTester tester, String label) async {
  final row = find.descendant(
    of: find.byType(AppPickerSheet),
    matching: find.text(label),
  );
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    const mode = _frameMode;
    final label = 'mo-plan-edit ${mode.name} (${brightness.name})';

    testWidgets('$label opens the sheet without Cancel', (tester) async {
      await _pumpEdit(tester, mode, brightness, buildPlansShellLedger());

      expect(_inForm(_sheetTitle), findsOneWidget);
      expect(find.text(_cancelLabel), findsNothing);
      expect(find.text(_saveLabel), findsOneWidget);
      expect(_inForm('Checking'), findsOneWidget);
      expect(find.text('1200.00'), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('$label locked Account row opens nothing', (tester) async {
      await _pumpEdit(tester, mode, brightness, buildPlansShellLedger());

      await _tapRow(tester, _accountLabel);

      expect(find.byType(AppPickerSheet), findsNothing);
      expect(_form, findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('$label Repeat lists frequencies without no-repeat', (
      tester,
    ) async {
      await _pumpEdit(tester, mode, brightness, buildPlansShellLedger());

      await _tapRow(tester, _repeatLabel);

      expect(find.text(_quarterlyLabel), findsOneWidget);
      expect(find.text(_noRepeatLabel), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('$label Save plan writes the edits and closes', (tester) async {
      final ledger = buildPlansShellLedger();
      await _pumpEdit(tester, mode, brightness, ledger);

      await tester.enterText(_nameField, _newName);
      await tester.enterText(_amountField, _newAmount);
      await _tapRow(tester, _repeatLabel);
      await _choose(tester, _quarterlyLabel);
      await _choose(tester, _saveLabel);

      final stored = ledger.state.plans[plansShellExpensePlan.id]!;
      expect(stored.template.name, _newName);
      expect(stored.template.amount, Decimal.parse('-1300'));
      expect(stored.frequency, RecurrenceFrequency.quarterly);
      expect(_form, findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('$label tapping outside writes nothing', (tester) async {
      final ledger = buildPlansShellLedger();
      await _pumpEdit(tester, mode, brightness, ledger);
      final revision = ledger.revision;

      await tester.enterText(_nameField, _newName);
      await tester.tapAt(_outsideOffset);
      await tester.pumpAndSettle();

      expect(_form, findsNothing);
      expect(ledger.revision, revision);
    }, timeout: uiTestTimeout);

    testWidgets(
      'mo-plan-end ${mode.name} (${brightness.name}) Ends reveals and '
      'hides the End date row',
      (tester) async {
        await _pumpEdit(tester, mode, brightness, buildPlansShellLedger());
        expect(_inForm(_neverLabel), findsOneWidget);
        expect(_inForm(_endDateLabel), findsNothing);

        await _tapRow(tester, _endsLabel);
        await _choose(tester, _chooseDateLabel);

        expect(_inForm(_onADateLabel), findsOneWidget);
        expect(_inForm(_endDateLabel), findsOneWidget);

        await _tapRow(tester, _endsLabel);
        await _choosePicked(tester, _neverLabel);

        expect(_inForm(_endDateLabel), findsNothing);
        expect(_inForm(_neverLabel), findsOneWidget);
      },
      timeout: uiTestTimeout,
    );
  }

  testWidgets('a changed selection removes the open sheet', (tester) async {
    final ledger = buildPlansShellLedger();
    final container = await _pumpEdit(
      tester,
      ShellLayoutMode.open,
      Brightness.light,
      ledger,
    );
    final revision = ledger.revision;

    container
        .read(selectedPlanProvider.notifier)
        .select(plansShellIncomePlan.id);
    await tester.pumpAndSettle();

    expect(_form, findsNothing);
    expect(ledger.revision, revision);
  }, timeout: uiTestTimeout);

  testWidgets('open pane header shows the new name after Save plan', (
    tester,
  ) async {
    await _pumpEdit(
      tester,
      ShellLayoutMode.open,
      Brightness.light,
      buildPlansShellLedger(),
    );
    final paneTitle = find.descendant(
      of: find.byKey(shellDetailPaneKey),
      matching: find.text(_newName),
    );

    await tester.enterText(_nameField, _newName);
    await _choose(tester, _saveLabel);

    expect(paneTitle, findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('replacing the ledger removes the open sheet', (tester) async {
    final container = await _pumpEdit(
      tester,
      ShellLayoutMode.open,
      Brightness.light,
      buildPlansShellLedger(),
    );

    container.read(plansShellLedgerFixture.notifier).state =
        buildPlansShellLedger();
    await tester.pumpAndSettle();

    expect(_form, findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('removing the form also closes its open picker', (tester) async {
    final container = await _pumpEdit(
      tester,
      ShellLayoutMode.open,
      Brightness.light,
      buildPlansShellLedger(),
    );
    await _tapRow(tester, _repeatLabel);
    expect(find.byType(AppPickerSheet), findsOneWidget);

    container.read(plansShellLedgerFixture.notifier).state =
        buildPlansShellLedger();
    await tester.pumpAndSettle();

    expect(_form, findsNothing);
    expect(find.byType(AppPickerSheet), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('deleting the plan removes the open sheet', (tester) async {
    final ledger = buildPlansShellLedger();
    await _pumpEdit(tester, ShellLayoutMode.open, Brightness.light, ledger);

    ledger.deletePlan(plansShellExpensePlan.id);
    await tester.pumpAndSettle();

    expect(_form, findsNothing);
  }, timeout: uiTestTimeout);
}
