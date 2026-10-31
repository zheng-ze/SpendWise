import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_edit_sheet.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import '../../../support/number_pad_support.dart';
import '../../../support/pump_app.dart';
import '../../../support/sheet_contract.dart';
import '../../../support/ui_test_timeout.dart';
import '../budget_shell_test_support.dart';

const _budgetID = 'b1';
const _title = 'Change limit';
const _saveLabel = 'Save';
const _seededAmountLength = 6;

Ledger _ledger() => Ledger(
  state: LedgerState(
    budgets: {
      _budgetID: Budget(
        id: _budgetID,
        categoryID: null,
        limit: Decimal.fromInt(100),
      ),
    },
  ),
);

Future<void> _openEditor(WidgetTester tester, Ledger ledger) async {
  await pumpApp(tester, const BudgetsFlow(), ledger: ledger);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(BudgetsFlow)),
  );
  container
      .read(budgetsListViewModelProvider.notifier)
      .requestBudgetDetail(_budgetID);
  await tester.pumpAndSettle();
  container
      .read(budgetDetailViewModelProvider(_budgetID).notifier)
      .requestEdit();
  await chooseEditAction(tester, 'Change limit');
}

Future<void> _replaceAmount(WidgetTester tester, String digits) async {
  for (var i = 0; i < _seededAmountLength; i++) {
    await tapPadBackspace(tester);
  }
  for (final digit in digits.split('')) {
    await tapPadLabel(tester, digit);
  }
}

void main() {
  testWidgets('mo-budget-edit-default shows the copy and saves once', (
    tester,
  ) async {
    final ledger = _ledger();
    await _openEditor(tester, ledger);

    expect(find.text(_title), findsOneWidget);
    expect(find.text('Monthly limit / SGD'), findsOneWidget);
    expect(find.text('100.00'), findsOneWidget);
    expect(find.text('Applies from'), findsNothing);
    expect(find.text('Cancel'), findsNothing);

    await _replaceAmount(tester, '250');
    await tester.tap(find.text(_saveLabel));
    await tester.pumpAndSettle();

    expect(find.byType(BudgetLimitEditSheet), findsNothing);
    expect(ledger.state.budgets[_budgetID]!.limit, Decimal.fromInt(250));
  }, timeout: uiTestTimeout);

  testWidgets('mo-budget-edit-default drag-down dismissal writes nothing', (
    tester,
  ) async {
    final ledger = _ledger();
    await _openEditor(tester, ledger);
    await _replaceAmount(tester, '9');

    await tester.drag(
      find.descendant(of: find.byType(AppSheet), matching: find.text(_title)),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BudgetLimitEditSheet), findsNothing);
    expect(ledger.state.budgets[_budgetID]!.limit, Decimal.fromInt(100));
  }, timeout: uiTestTimeout);

  testWidgets('sf-limit keeps the amount and shows the reason outside', (
    tester,
  ) async {
    final ledger = _ledger();
    await _openEditor(tester, ledger);
    await _replaceAmount(tester, '75');
    ledger.deleteBudget(_budgetID);

    await tester.tap(find.text(_saveLabel));
    await tester.pumpAndSettle();

    expectAlertOutsideSheet(tester);
    expect(
      find.textContaining('Could not save budget limit\n'),
      findsOneWidget,
    );
    expect(find.text('75'), findsOneWidget);
    expect(find.text(_saveLabel), findsOneWidget);
  }, timeout: uiTestTimeout);
}
