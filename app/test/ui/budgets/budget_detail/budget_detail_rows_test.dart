import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/budgets/budget_detail/budget_detail_view_model.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';
import 'package:spendwise/ui/transactions/daily_list/day_header.dart';

import '../../../support/ui_test_timeout.dart';
import 'budget_detail_test_support.dart';

const _entryScrollStep = 200.0;

void main() {
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
  final coffee = Entry(
    amount: dec('-4'),
    name: 'Coffee',
    sourceID: checkingAccount.id,
    date: DateTime.utc(2026, 10, 2),
  );

  testWidgets('counted expense total reaches the rendered day header', (
    tester,
  ) async {
    final budget = detailBudget();
    final ledger = detailLedger(budgets: [budget], entries: [lunch, topUp]);
    final container = await pumpDetailScreen(tester, ledger: ledger);
    final state = detailState(container);
    final header = tester.widget<DayHeader>(find.byType(DayHeader));
    expect(header.net, dec('-50'));
    expect(state.spent, dec('50'));
    expect(state.projection?.projection.summary?.spent, state.spent);
  }, timeout: uiTestTimeout);

  testWidgets('Edit requests the existing limit history step from the page', (
    tester,
  ) async {
    final container = await pumpDetailScreen(
      tester,
      ledger: detailLedger(budgets: [detailBudget()]),
    );

    await tester.tap(find.byTooltip('Edit limit history'));
    await tester.pump();

    expect(detailState(container).step, isA<BudgetLimitEditRequested>());
  }, timeout: uiTestTimeout);

  testWidgets('tapping a counted register row opens its entry form', (
    tester,
  ) async {
    await pumpDetailScreen(
      tester,
      ledger: detailLedger(budgets: [detailBudget()], entries: [lunch]),
    );

    await tester.scrollUntilVisible(find.text('Lunch'), _entryScrollStep);
    await tester.pump();
    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();

    final form = tester.widget<EntryForm>(find.byType(EntryForm));
    expect(form.entryId, lunch.id);
  }, timeout: uiTestTimeout);

  testWidgets(
    'swipe-deleting a counted row during a pending refresh removes the row',
    (tester) async {
      final runner = GatedComputeRunner();
      final container = await pumpDetailScreen(
        tester,
        ledger: detailLedger(budgets: [detailBudget()], entries: [lunch]),
        runner: runner.call,
      );
      addTearDown(runner.release);

      runner.hold();
      container.read(ledgerProvider)!.addEntry(coffee);
      await tester.pump();
      expect(detailState(container).phase, BudgetDetailPhase.loading);

      await tester.drag(find.text('Coffee'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Coffee'), findsNothing);
      expect(find.text('Lunch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );
}
