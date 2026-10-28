import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_screen.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';

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
    'counted rows group into one day total that equals the headline spend',
    () async {
      final container = detailContainer(
        ledger: detailLedger(
          budgets: [detailBudget()],
          entries: [lunch, topUp],
        ),
        clock: DetailClock(october),
      );
      keepDetailAlive(container);

      final state = await settledDetail(container);
      final amounts = [for (final row in state.countedEntries) row.amount];
      final dayTotals = <DateTime, Decimal>{};
      for (final row in state.countedEntries) {
        final day = startOfDayUtc(row.entry.date);
        dayTotals[day] = (dayTotals[day] ?? Decimal.zero) + row.amount;
      }

      expect(amounts, unorderedEquals([dec('10'), dec('40')]));
      expect(dayTotals, {DateTime.utc(2026, 10, 1): dec('50')});
      expect(state.spent, dec('50'));
      expect(state.projection?.projection.summary?.spent, state.spent);
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

  testWidgets('tapping a counted register row opens its entry form', (
    tester,
  ) async {
    final container = await tester.runAsync(() async {
      final created = detailContainer(
        ledger: detailLedger(budgets: [detailBudget()], entries: [lunch]),
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
    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();

    expect(find.byType(EntryForm), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets(
    'swipe-deleting a counted row during a pending refresh removes the row',
    (tester) async {
      final ledger = detailLedger(budgets: [detailBudget()], entries: [lunch]);
      final container = await tester.runAsync(() async {
        final created = detailContainer(
          ledger: ledger,
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
      container
          .read(ledgerProvider)!
          .addCategory(
            TransactionCategory(
              id: 'c0000000-0000-0000-0000-000000000002',
              name: 'Travel',
              kind: CategoryKind.expense,
              colorHex: '#0000AA',
              includeInAnalysis: true,
              parentID: null,
              symbol: 'flight',
            ),
          );
      await tester.pump();
      await tester.drag(find.text('Lunch'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Lunch'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );
}
