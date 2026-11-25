import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_list/budget_selection.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';

import '../../../support/phone_shell.dart';

const _budgetID = 'b1';

final _budget = Budget(
  id: _budgetID,
  categoryID: null,
  limit: Decimal.parse('100'),
);

ProviderContainer _container() {
  final ledger = Ledger(state: LedgerState(budgets: {_budgetID: _budget}));
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWithValue(ledger),
      analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _mountFlow(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: phoneShell(const BudgetsFlow(header: SizedBox.shrink())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a request set before the flow mounts selects that budget', (
    tester,
  ) async {
    final container = _container();
    container.read(pendingBudgetSelectionProvider.notifier).select(_budgetID);

    await _mountFlow(tester, container);

    expect(container.read(selectedBudgetProvider), _budgetID);
    expect(container.read(pendingBudgetSelectionProvider), isNull);
  });

  testWidgets('a request set while the flow is mounted selects that budget', (
    tester,
  ) async {
    final container = _container();
    await _mountFlow(tester, container);

    container.read(pendingBudgetSelectionProvider.notifier).select(_budgetID);
    await tester.pumpAndSettle();

    expect(container.read(selectedBudgetProvider), _budgetID);
    expect(container.read(pendingBudgetSelectionProvider), isNull);
  });

  testWidgets('no request selects nothing', (tester) async {
    final container = _container();

    await _mountFlow(tester, container);

    expect(container.read(selectedBudgetProvider), isNull);
    expect(container.read(pendingBudgetSelectionProvider), isNull);
  });
}
