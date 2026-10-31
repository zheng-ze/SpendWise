import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_edit_sheet.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_sheet_occupancy.dart';

import '../../../support/ui_test_timeout.dart';
import '../budget_shell_test_support.dart';

const _budgetID = 'b2';
const _otherBudgetID = 'b1';
const _editLabel = 'Edit';
const _changeLimitLabel = 'Change limit';
const _deleteLabel = 'Delete budget';
const _actionsTitle = 'Edit budget';
const _outsideSheetOffset = Offset(5, 5);
const _handOffFrames = 30;
const _frameStep = Duration(milliseconds: 16);

final _actionRows = find.descendant(
  of: find.byType(AppPickerSheet),
  matching: find.byType(ListTile),
);
final _limitEditor = find.byType(BudgetLimitEditSheet);

Future<void> _openActions(WidgetTester tester, ShellLayoutMode mode) async {
  final phone = mode == ShellLayoutMode.phone;
  final trigger = phone ? find.byTooltip(_editLabel) : find.text(_editLabel);
  await tester.tap(trigger);
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pumpWithActions(
  WidgetTester tester,
  ShellLayoutMode mode, {
  Ledger? ledger,
}) async {
  final container = await pumpBudgetShell(
    tester,
    mode: mode,
    ledger: ledger ?? buildShellLedger(),
  );
  await tapBudget(tester, _budgetID);
  await _openActions(tester, mode);
  return container;
}

void _expectLimits(Ledger ledger) {
  expect(ledger.state.budgets[_budgetID]!.limit, Decimal.fromInt(50));
  expect(ledger.state.budgets[_otherBudgetID]!.limit, Decimal.fromInt(100));
}

Future<void> _dismissOutside(WidgetTester tester) async {
  await tester.tapAt(_outsideSheetOffset);
  await tester.pumpAndSettle();
}

void main() {
  for (final mode in [ShellLayoutMode.phone, ShellLayoutMode.open]) {
    testWidgets('${mode.name}: Edit shows exactly the two action rows', (
      tester,
    ) async {
      await _pumpWithActions(tester, mode);

      expect(find.text(_actionsTitle), findsOneWidget);
      expect(_actionRows, findsNWidgets(2));
      expect(find.text(_changeLimitLabel), findsOneWidget);
      expect(find.text(_deleteLabel), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('${mode.name}: dismissing the actions changes nothing', (
      tester,
    ) async {
      final ledger = buildShellLedger();
      final container = await _pumpWithActions(tester, mode, ledger: ledger);

      await _dismissOutside(tester);

      expect(_actionRows, findsNothing);
      expect(_limitEditor, findsNothing);
      expect(container.read(selectedBudgetProvider), _budgetID);
      _expectLimits(ledger);
    }, timeout: uiTestTimeout);

    testWidgets('${mode.name}: Change limit hands off to the editor with the '
        'shell covered on every frame', (tester) async {
      final container = await _pumpWithActions(tester, mode);
      await tester.tap(find.text(_changeLimitLabel));
      for (var frame = 0; frame < _handOffFrames; frame++) {
        await tester.pump(_frameStep);
        expect(container.read(shellSheetOccupancyProvider).hasSheets, isTrue);
      }
      await tester.pumpAndSettle();

      expect(_limitEditor, findsOneWidget);
      expect(find.text('50.00'), findsWidgets);
      expect(container.read(selectedBudgetProvider), _budgetID);
    }, timeout: uiTestTimeout);
  }

  testWidgets('Edit after dismissing Change limit reopens the actions', (
    tester,
  ) async {
    await _pumpWithActions(tester, ShellLayoutMode.open);
    await tester.tap(find.text(_changeLimitLabel));
    await tester.pumpAndSettle();
    await _dismissOutside(tester);
    expect(_limitEditor, findsNothing);

    await _openActions(tester, ShellLayoutMode.open);

    expect(_actionRows, findsNWidgets(2));
  }, timeout: uiTestTimeout);

  testWidgets('a replaced selection leaves nothing to choose and writes '
      'nothing', (tester) async {
    final ledger = buildShellLedger();
    final container = await _pumpWithActions(
      tester,
      ShellLayoutMode.open,
      ledger: ledger,
    );

    container.read(selectedBudgetProvider.notifier).select(_otherBudgetID);
    await tester.pumpAndSettle();

    expect(_actionRows, findsNothing);
    expect(_limitEditor, findsNothing);
    _expectLimits(ledger);
  }, timeout: uiTestTimeout);

  testWidgets('a replaced ledger leaves nothing to choose and writes '
      'nothing', (tester) async {
    final oldLedger = buildShellLedger();
    final container = await _pumpWithActions(
      tester,
      ShellLayoutMode.open,
      ledger: oldLedger,
    );
    final replacement = buildShellLedger();

    container.read(budgetShellLedgerFixture.notifier).state = replacement;
    await tester.pumpAndSettle();

    expect(_actionRows, findsNothing);
    expect(_limitEditor, findsNothing);
    _expectLimits(oldLedger);
    _expectLimits(replacement);
  }, timeout: uiTestTimeout);

  testWidgets('a budget deleted remotely while the actions are open opens '
      'no editor', (tester) async {
    final ledger = buildShellLedger();
    await _pumpWithActions(tester, ShellLayoutMode.open, ledger: ledger);

    ledger.deleteBudget(_budgetID);
    await tester.pumpAndSettle();
    await tester.tap(find.text(_changeLimitLabel));
    await tester.pumpAndSettle();

    expect(_limitEditor, findsNothing);
    expect(ledger.state.budgets.containsKey(_budgetID), isFalse);
    expect(ledger.state.budgets[_otherBudgetID]!.limit, Decimal.fromInt(100));
  }, timeout: uiTestTimeout);
}
