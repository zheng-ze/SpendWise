import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_limit_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';

import '../../../support/ui_test_timeout.dart';

void main() {
  final budget = Budget(
    id: 'b1',
    categoryID: null,
    limitEvents: [
      LimitEvent(
        effectiveFromMonth: null,
        value: Decimal.parse('100'),
        kind: LimitEventKind.defaultLimit,
      ),
    ],
    createdAtMonth: const YearMonth(2026, 1),
  );

  testWidgets(
    'detail providers stay alive through route exit and then dispose',
    (tester) async {
      final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
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
          child: const MaterialApp(home: BudgetsFlow()),
        ),
      );
      await tester.pumpAndSettle();
      container
          .read(budgetsListViewModelProvider.notifier)
          .requestBudgetDetail(budget.id);
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container.exists(budgetDetailViewModelProvider(budget.id)),
        isTrue,
      );
      expect(container.exists(budgetLimitViewModelProvider(budget.id)), isTrue);

      await tester.pumpAndSettle();
      expect(
        container.exists(budgetDetailViewModelProvider(budget.id)),
        isFalse,
      );
      expect(
        container.exists(budgetLimitViewModelProvider(budget.id)),
        isFalse,
      );
    },
    timeout: uiTestTimeout,
  );
}
