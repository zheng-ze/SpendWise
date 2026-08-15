import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/plan_list_screen.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final source = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Wallet',
    type: AccountType.cash,
  );

  Future<void> pumpScreen(WidgetTester tester, Ledger ledger) {
    return tester.pumpWidget(MaterialApp(home: PlanListScreen(ledger: ledger)));
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
}
