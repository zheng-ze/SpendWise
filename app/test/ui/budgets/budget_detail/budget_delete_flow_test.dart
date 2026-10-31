import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_pane.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/ui_test_timeout.dart';
import '../budget_shell_test_support.dart';

const _budgetID = 'b2';
const _otherBudgetID = 'b1';
const _editLabel = 'Edit';
const _deleteActionLabel = 'Delete budget';
const _cancelLabel = 'Cancel';
const _confirmLabel = 'Delete';
const _confirmTitle = 'Delete the Food budget?';
const _confirmBody =
    'Your entries stay as they are. Only the limit is removed.';
const _deletedTitle = 'This budget was deleted';
const _deletedBody = 'It was removed on another screen or device.';
const _backToBudgetsLabel = 'Back to Budgets';
const _foodTitle = 'Food';
const _outsideOffset = Offset(5, 5);
const _frames = 20;
const _frameStep = Duration(milliseconds: 16);

final _confirmButton = find.widgetWithText(FilledButton, _confirmLabel);
final _cancelButton = find.widgetWithText(TextButton, _cancelLabel);

Entry _lunch() => Entry(
  amount: Decimal.fromInt(-7),
  name: 'Lunch',
  sourceID: budgetShellAccount.id,
  categoryID: budgetShellFood.id,
  date: DateTime.utc(2026, 3, 1),
);

Ledger _ledgerWithEntry(Entry entry) {
  final base = buildShellLedger().state;
  return Ledger(
    state: LedgerState(
      moneySources: base.moneySources,
      categories: base.categories,
      budgets: base.budgets,
      entries: {entry.id: entry},
    ),
  );
}

Future<void> _openEdit(WidgetTester tester, ShellLayoutMode mode) async {
  final phone = mode == ShellLayoutMode.phone;
  final trigger = phone ? find.byTooltip(_editLabel) : find.text(_editLabel);
  await tester.tap(trigger);
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pumpConfirmation(
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
  await _openEdit(tester, mode);
  await chooseEditAction(tester, _deleteActionLabel);
  return container;
}

void _expectUntouched(Ledger ledger) {
  expect(ledger.state.budgets.keys, containsAll([_budgetID, _otherBudgetID]));
  expect(ledger.state.budgets[_budgetID]!.limit, Decimal.fromInt(50));
}

Future<void> _expectEditStillWorks(
  WidgetTester tester,
  ShellLayoutMode mode,
) async {
  await _openEdit(tester, mode);
  expect(find.text(_deleteActionLabel), findsOneWidget);
}

void main() {
  for (final mode in [ShellLayoutMode.phone, ShellLayoutMode.open]) {
    testWidgets('mo-budget-delete ${mode.name}: shows the budget copy with '
        'Cancel and a filled Delete', (tester) async {
      await _pumpConfirmation(tester, mode);

      expect(find.text(_confirmTitle), findsOneWidget);
      expect(find.text(_confirmBody), findsOneWidget);
      expect(_cancelButton, findsOneWidget);
      expect(_confirmButton, findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('mo-budget-delete ${mode.name}: Cancel writes nothing and '
        'Edit still works', (tester) async {
      final ledger = buildShellLedger();
      await _pumpConfirmation(tester, mode, ledger: ledger);

      await tester.tap(_cancelButton);
      await tester.pumpAndSettle();

      expect(find.text(_confirmTitle), findsNothing);
      _expectUntouched(ledger);
      await _expectEditStillWorks(tester, mode);
    }, timeout: uiTestTimeout);

    testWidgets('mo-budget-delete ${mode.name}: Back writes nothing and '
        'Edit still works', (tester) async {
      final ledger = buildShellLedger();
      await _pumpConfirmation(tester, mode, ledger: ledger);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(_confirmTitle), findsNothing);
      _expectUntouched(ledger);
      await _expectEditStillWorks(tester, mode);
    }, timeout: uiTestTimeout);

    testWidgets('mo-budget-delete ${mode.name}: outside tap writes nothing '
        'and Edit still works', (tester) async {
      final ledger = buildShellLedger();
      await _pumpConfirmation(tester, mode, ledger: ledger);

      await tester.tapAt(_outsideOffset);
      await tester.pumpAndSettle();

      expect(find.text(_confirmTitle), findsNothing);
      _expectUntouched(ledger);
      await _expectEditStillWorks(tester, mode);
    }, timeout: uiTestTimeout);

    testWidgets('mo-budget-delete ${mode.name}: Delete removes the budget '
        'once, keeps entries and never renders the deleted state', (
      tester,
    ) async {
      final entry = _lunch();
      final ledger = _ledgerWithEntry(entry);
      final container = await _pumpConfirmation(tester, mode, ledger: ledger);
      final revision = ledger.revision;

      await tester.tap(_confirmButton);
      for (var frame = 0; frame < _frames; frame++) {
        await tester.pump(_frameStep);
        expect(find.text(_deletedTitle), findsNothing);
      }
      await tester.pumpAndSettle();

      expect(ledger.revision, revision + 1);
      expect(ledger.state.budgets.keys, [_otherBudgetID]);
      expect(ledger.state.entries.containsKey(entry.id), isTrue);
      expect(container.read(selectedBudgetProvider), isNull);
      expect(find.byType(BudgetDetailScreen), findsNothing);
      expect(find.byType(BudgetPaneBody), findsNothing);
    }, timeout: uiTestTimeout);
  }

  testWidgets('a replaced selection while the dialog is up writes nothing', (
    tester,
  ) async {
    final ledger = buildShellLedger();
    final container = await _pumpConfirmation(
      tester,
      ShellLayoutMode.open,
      ledger: ledger,
    );
    final revision = ledger.revision;

    container.read(selectedBudgetProvider.notifier).select(_otherBudgetID);
    await tester.pumpAndSettle();
    await tester.tap(_confirmButton);
    await tester.pumpAndSettle();

    expect(ledger.revision, revision);
    _expectUntouched(ledger);
  }, timeout: uiTestTimeout);

  testWidgets('a replaced ledger while the dialog is up writes nothing', (
    tester,
  ) async {
    final oldLedger = buildShellLedger();
    final container = await _pumpConfirmation(
      tester,
      ShellLayoutMode.open,
      ledger: oldLedger,
    );
    final replacement = buildShellLedger();
    final revision = oldLedger.revision;

    container.read(budgetShellLedgerFixture.notifier).state = replacement;
    await tester.pumpAndSettle();
    await tester.tap(_confirmButton);
    await tester.pumpAndSettle();

    expect(oldLedger.revision, revision);
    _expectUntouched(oldLedger);
    _expectUntouched(replacement);
  }, timeout: uiTestTimeout);

  testWidgets('a budget deleted remotely while the dialog is up gets no '
      'second delete', (tester) async {
    final ledger = buildShellLedger();
    await _pumpConfirmation(tester, ShellLayoutMode.open, ledger: ledger);

    ledger.deleteBudget(_budgetID);
    await tester.pumpAndSettle();
    final revision = ledger.revision;
    await tester.tap(_confirmButton);
    await tester.pumpAndSettle();

    expect(ledger.revision, revision);
    expect(ledger.state.budgets.keys, [_otherBudgetID]);
  }, timeout: uiTestTimeout);

  for (final mode in [ShellLayoutMode.phone, ShellLayoutMode.open]) {
    testWidgets('mo-budget-deleted ${mode.name}: a remote delete shows the '
        'last title, the copy and no Edit', (tester) async {
      final ledger = buildShellLedger();
      await pumpBudgetShell(tester, mode: mode, ledger: ledger);
      await tapBudget(tester, _budgetID);

      ledger.deleteBudget(_budgetID);
      await tester.pumpAndSettle();

      expect(find.text(_foodTitle), findsWidgets);
      expect(find.text(_deletedTitle), findsOneWidget);
      expect(find.text(_deletedBody), findsOneWidget);
      expect(find.text(_backToBudgetsLabel), findsOneWidget);
      expect(find.byTooltip(_editLabel), findsNothing);
      expect(find.text(_editLabel), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('mo-budget-deleted ${mode.name}: Back to Budgets clears the '
        'selection', (tester) async {
      final ledger = buildShellLedger();
      final container = await pumpBudgetShell(
        tester,
        mode: mode,
        ledger: ledger,
      );
      await tapBudget(tester, _budgetID);
      ledger.deleteBudget(_budgetID);
      await tester.pumpAndSettle();

      await tester.tap(find.text(_backToBudgetsLabel));
      await tester.pumpAndSettle();

      expect(container.read(selectedBudgetProvider), isNull);
      expect(find.text(_deletedTitle), findsNothing);
    }, timeout: uiTestTimeout);
  }
}
