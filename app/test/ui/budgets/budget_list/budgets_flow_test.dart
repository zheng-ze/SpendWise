import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_edit_sheet.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';

import '../../../support/ui_test_timeout.dart';
import '../budget_shell_test_support.dart';
import '../../../support/phone_shell.dart';

const _editTooltip = 'Edit';
const _changeLimitLabel = 'Change limit';
const _limitEditor = BudgetLimitEditSheet;

final _budget = Budget(id: 'b1', categoryID: null, limit: Decimal.parse('100'));

Future<ProviderContainer> _pumpFlow(WidgetTester tester, Ledger ledger) async {
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(ledger),
      analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: phoneShell(const BudgetsFlow(header: SizedBox.shrink())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openDetail(
  WidgetTester tester,
  ProviderContainer container,
  String budgetID,
) async {
  container
      .read(budgetsListViewModelProvider.notifier)
      .requestBudgetDetail(budgetID);
  await tester.pumpAndSettle();
}

Finder _editorText(String text) =>
    find.descendant(of: find.byType(_limitEditor), matching: find.text(text));

void main() {
  testWidgets(
    'detail providers stay alive through route exit and then dispose',
    (tester) async {
      final ledger = Ledger(state: LedgerState(budgets: {_budget.id: _budget}));
      final container = await _pumpFlow(tester, ledger);
      await _openDetail(tester, container, _budget.id);

      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container.exists(budgetDetailViewModelProvider(_budget.id)),
        isTrue,
      );
      expect(container.exists(budgetDetailContextProvider(_budget.id)), isTrue);

      await tester.pumpAndSettle();
      expect(
        container.exists(budgetDetailViewModelProvider(_budget.id)),
        isFalse,
      );
      expect(
        container.exists(budgetDetailContextProvider(_budget.id)),
        isFalse,
      );
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'Edit on the detail page opens the limit editor prefilled with the limit',
    (tester) async {
      final ledger = Ledger(state: LedgerState(budgets: {_budget.id: _budget}));
      final container = await _pumpFlow(tester, ledger);
      await _openDetail(tester, container, _budget.id);

      await tester.tap(find.byTooltip(_editTooltip));
      await chooseEditAction(tester, _changeLimitLabel);

      expect(find.byType(_limitEditor), findsOneWidget);
      expect(_editorText('100.00'), findsOneWidget);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'a second edit request while the action sheet is open is dropped',
    (tester) async {
      final ledger = Ledger(state: LedgerState(budgets: {_budget.id: _budget}));
      final container = await _pumpFlow(tester, ledger);
      await _openDetail(tester, container, _budget.id);
      final detail = container.read(
        budgetDetailViewModelProvider(_budget.id).notifier,
      );
      detail.requestEdit();
      await tester.pumpAndSettle();
      detail.requestEdit();
      await tester.pumpAndSettle();
      expect(find.text(_changeLimitLabel), findsOneWidget);
      await chooseEditAction(tester, _changeLimitLabel);
      expect(find.byType(_limitEditor), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byType(_limitEditor), findsNothing);
    },
    timeout: uiTestTimeout,
  );
}
