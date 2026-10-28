import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ledger/analysis/budgets/budget_counted_entries.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';

import '../../../support/ui_test_timeout.dart';
import 'budget_detail_test_support.dart';

void main() {
  final october = DateTime.utc(2026, 10, 28);

  final lunch = Entry(
    amount: dec('-10'),
    name: 'Lunch',
    sourceID: checkingAccount.id,
    date: DateTime.utc(2026, 10, 1),
  );
  final topUp = Entry(
    amount: dec('40'),
    name: 'Top up',
    sourceID: checkingAccount.id,
    destinationID: savingsAccount.id,
    date: DateTime.utc(2026, 10, 1),
  );

  test(
    'counted rows reconcile with the headline spend and the day total',
    () async {
      final container = detailContainer(
        ledger: detailLedger(
          budgets: [detailBudget()],
          entries: [lunch, topUp],
        ),
        clock: DetailClock(october),
      );
      keepDetailAlive(container);

      final snapshot = (await settledDetail(container)).snapshot!;
      final amounts = [for (final row in snapshot.countedEntries) row.amount];

      expect(amounts, unorderedEquals([dec('10'), dec('40')]));
      expect(snapshot.spent, dec('50'));
      expect(budgetCountedTotal(snapshot.countedEntries), snapshot.spent);
      expect(snapshot.projection.summary?.spent, snapshot.spent);
    },
  );

  testWidgets('Edit requests the existing limit history step from the page', (
    tester,
  ) async {
    final container = await tester.runAsync(() async {
      final created = detailContainer(
        ledger: detailLedger(budgets: [detailBudget()]),
        clock: DetailClock(october),
      );
      keepDetailAlive(created);
      await pumpEventQueue();
      return created;
    });
    if (container == null) fail('the detail container was not created');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: BudgetDetailScreen(budgetID: detailBudgetID),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Edit limit history'));
    await tester.pump();

    expect(detailState(container).step, isA<BudgetLimitEditRequested>());
  }, timeout: uiTestTimeout);
}
