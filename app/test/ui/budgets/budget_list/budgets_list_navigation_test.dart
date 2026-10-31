import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_flow.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view.dart';
import 'package:spendwise/ui/budgets/budget_list/budgets_list_view_model.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';

import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';

Budget _overall() =>
    Budget(id: 'b1', categoryID: null, limit: Decimal.fromInt(100));

void main() {
  testWidgets('fr-budgets Add budget opens the Add budget sheet', (
    tester,
  ) async {
    final ledger = Ledger(state: LedgerState());
    await pumpApp(tester, const BudgetsFlow(), ledger: ledger);
    await tester.tap(find.text('Add budget'));
    await tester.pumpAndSettle();
    final header = find.descendant(
      of: find.byType(AppSheet),
      matching: find.text('Add budget'),
    );
    expect(header, findsOneWidget);
    expect(ledger.state.budgets, isEmpty);
  }, timeout: uiTestTimeout);

  for (final size in [
    ParitySize.phone,
    ParitySize.compact,
    ParitySize.desktop,
  ]) {
    testWidgets('mo-budgets/mo-desk-budgets cap navigation ${size.name}', (
      tester,
    ) async {
      final budget = _overall();
      final ledger = Ledger(state: LedgerState(budgets: {budget.id: budget}));
      await pumpApp(tester, const BudgetsFlow(), ledger: ledger, size: size);
      final amount = find.text('S\$100.00');
      await tester.drag(amount, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(ledger.state.budgets.containsKey(budget.id), isTrue);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BudgetsFlow)),
      );
      await tester.tap(amount);
      await tester.pumpAndSettle();
      expect(
        container.exists(budgetDetailViewModelProvider(budget.id)),
        isTrue,
      );
    }, timeout: uiTestTimeout);
  }

  testWidgets('le-budgets-err Try again recovers the same list owner', (
    tester,
  ) async {
    var fail = true;
    final ledger = Ledger(state: LedgerState());
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        analysisComputeRunnerProvider.overrideWithValue((state) async {
          if (fail) throw StateError('Data unavailable');
          return syncComputeRunner(state);
        }),
      ],
    );
    addTearDown(container.dispose);
    final app = const MaterialApp(home: BudgetsRoot());
    final scope = UncontrolledProviderScope(container: container, child: app);
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
    final owner = container.read(budgetsListViewModelProvider.notifier);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(container.read(budgetsListViewModelProvider.notifier), same(owner));
    final state = container.read(budgetsListViewModelProvider).requireValue;
    expect(state.error, isNull);
    expect(state.overview!.hasBudgets, isFalse);
  }, timeout: uiTestTimeout);
}
