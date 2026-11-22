import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_form.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/inputs/amount_field.dart';
import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/ledger_fixtures.dart';
import '../../../support/number_pad_support.dart';
import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';
import '../budget_shell_test_support.dart';

const _addLabel = 'Add budget';
const _pickerTitle = 'Choose category';
const _dragDown = Offset(0, 900);
const _outsideTap = Offset(5, 5);

TransactionCategory _category(String name, {String? parentID}) => testCategory(
  name: name,
  colorHex: '#00AA00',
  parentID: parentID,
  symbol: 'restaurant',
);

final _food = _category('Food');
final _dining = _category('Dining', parentID: _food.id);
final _transport = _category('Transport');

Ledger _ledgerWith() {
  final categories = [_food, _dining, _transport];
  return Ledger(
    state: LedgerState(
      categories: {for (final category in categories) category.id: category},
    ),
  );
}

Future<ProviderContainer> _pumpFlow(WidgetTester tester, Ledger ledger) async {
  await pumpApp(
    tester,
    const BudgetsFlow(header: SizedBox.shrink()),
    ledger: ledger,
  );
  return ProviderScope.containerOf(tester.element(find.byType(BudgetsFlow)));
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.text(_addLabel));
  await tester.pumpAndSettle();
}

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(AppSheet), matching: finder);

Future<void> _dragDismiss(WidgetTester tester) async {
  await tester.drag(_inSheet(find.text(_addLabel)), _dragDown);
  await tester.pumpAndSettle();
}

Future<void> _enterAmount(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tapPadLabel(tester, digit);
  }
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text('Category'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'mo-budget-add reopens with an empty draft and admits one sheet',
    (tester) async {
      final container = await _pumpFlow(tester, _ledgerWith());
      await _openForm(tester);
      await _enterAmount(tester, '7');
      container.read(budgetsListViewModelProvider.notifier).requestNewBudget();
      await tester.pumpAndSettle();
      expect(find.byType(BudgetForm), findsOneWidget);

      await _dragDismiss(tester);
      await _openForm(tester);

      expect(find.text('0.00'), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('mo-budget-add drag-down dismissal on phone writes nothing', (
    tester,
  ) async {
    final ledger = _ledgerWith();
    await _pumpFlow(tester, ledger);
    await _openForm(tester);
    await _enterAmount(tester, '9');

    await _dragDismiss(tester);

    expect(find.byType(BudgetForm), findsNothing);
    expect(ledger.state.budgets, isEmpty);
  }, timeout: uiTestTimeout);

  testWidgets('mo-budget-pick dismissal leaves the category unchanged', (
    tester,
  ) async {
    await _pumpFlow(tester, _ledgerWith());
    await _openForm(tester);

    await _openPicker(tester);
    await tester.tapAt(_outsideTap);
    await tester.pumpAndSettle();

    expect(find.text(_pickerTitle), findsNothing);
    expect(find.byType(BudgetForm), findsOneWidget);
    expect(find.text('All spending'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets(
    'a live resize keeps the route and draft and swaps pad for field',
    (tester) async {
      final container = await pumpBudgetShell(
        tester,
        mode: ShellLayoutMode.open,
      );
      await _openForm(tester);
      await _enterAmount(tester, '42');
      await _openPicker(tester);
      final state = tester.state(find.byType(BudgetForm));

      container.read(budgetShellModeFixture.notifier).state =
          ShellLayoutMode.desktop;
      await tester.pumpAndSettle();
      expect(find.text(_pickerTitle), findsOneWidget);
      await tester.tapAt(_outsideTap);
      await tester.pumpAndSettle();

      expect(tester.state(find.byType(BudgetForm)), same(state));
      expect(find.byType(NumberPad), findsNothing);
      final field = tester.widget<AmountField>(find.byType(AmountField));
      expect(field.controller.text, '42');
    },
    timeout: uiTestTimeout,
  );
}
