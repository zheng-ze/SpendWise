import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/plan/plan_list_screen.dart';

import '../../../support/semantics_test_support.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final source = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Wallet',
    type: AccountType.cash,
  );

  Future<void> pumpScreen(WidgetTester tester, Ledger ledger) async {
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlanListScreen()),
      ),
    );
    // Flushes PlanListNotifier.build()'s Future so the screen's initial
    // AsyncData state is in place before a test interacts with it.
    await tester.pump();
  }

  testWidgets('empty state shows message and no Edit/Done toggle', (
    tester,
  ) async {
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {source.id: MoneySource.account(source)},
      ),
    );

    await pumpScreen(tester, ledger);

    expect(find.text('No recurring plans yet'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('no add button is rendered anywhere', (tester) async {
    final plan = RecurringPlan(
      template: EntryTemplate(
        amount: dec('-10'),
        name: 'Rent',
        sourceID: source.id,
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 1, 1),
      lastResolvedDate: DateTime.utc(2025, 12, 31),
    );
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {source.id: MoneySource.account(source)},
        plans: {plan.id: plan},
      ),
    );

    await pumpScreen(tester, ledger);

    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('row caption shows frequency and source, amount colored by '
      'sign', (tester) async {
    final expensePlan = RecurringPlan(
      template: EntryTemplate(
        amount: dec('-25'),
        name: 'Rent',
        sourceID: source.id,
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 1, 1),
      lastResolvedDate: DateTime.utc(2025, 12, 31),
    );
    final incomePlan = RecurringPlan(
      template: EntryTemplate(
        amount: dec('500'),
        name: 'Salary',
        sourceID: source.id,
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 2, 1),
      lastResolvedDate: DateTime.utc(2026, 1, 31),
    );
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {source.id: MoneySource.account(source)},
        plans: {expensePlan.id: expensePlan, incomePlan.id: incomePlan},
      ),
    );

    await pumpScreen(tester, ledger);

    expect(find.text('Monthly · Wallet'), findsNWidgets(2));

    final expenseAmount = tester.widget<Text>(find.text(r'$25.00'));
    final incomeAmount = tester.widget<Text>(find.text(r'$500.00'));
    final theme = Theme.of(tester.element(find.byType(PlanListScreen)));
    final expenseColor = expenseAmount.style?.color;
    final incomeColor = incomeAmount.style?.color;

    expect(incomeColor, isNot(expenseColor));
    expect(expenseColor, theme.colorScheme.onSurfaceVariant);
  });

  testWidgets('swiping a plan and confirming removes it from plans', (
    tester,
  ) async {
    final plan = RecurringPlan(
      template: EntryTemplate(
        amount: dec('-10'),
        name: 'Rent',
        sourceID: source.id,
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 1, 1),
      lastResolvedDate: DateTime.utc(2025, 12, 31),
    );
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {source.id: MoneySource.account(source)},
        plans: {plan.id: plan},
      ),
    );

    await pumpScreen(tester, ledger);

    await tester.drag(find.text('Rent'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(ledger.state.plans.containsKey(plan.id), isFalse);
  });

  testWidgets(
    'the delete custom semantic action opens the same confirm dialog as '
    'the swipe and removes the plan once confirmed',
    (tester) async {
      final handle = tester.ensureSemantics();
      final plan = RecurringPlan(
        template: EntryTemplate(
          amount: dec('-10'),
          name: 'Rent',
          sourceID: source.id,
        ),
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 1),
        lastResolvedDate: DateTime.utc(2025, 12, 31),
      );
      final ledger = Ledger(
        state: LedgerState(
          moneySources: {source.id: MoneySource.account(source)},
          plans: {plan.id: plan},
        ),
      );

      await pumpScreen(tester, ledger);

      await performCustomSemanticsAction(
        tester,
        of: find.text('Rent'),
        label: 'Delete Rent',
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete Rent?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(ledger.state.plans.containsKey(plan.id), isFalse);
      handle.dispose();
    },
  );
}
