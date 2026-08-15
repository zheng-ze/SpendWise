import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/plan_form.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final source = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Wallet',
    type: AccountType.cash,
  );

  RecurringPlan buildPlan({required Decimal amount}) {
    return RecurringPlan(
      id: 'p0000000-0000-0000-0000-000000000001',
      template: EntryTemplate(
        amount: amount,
        name: 'Rent',
        sourceID: source.id,
      ),
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 1, 1),
      lastResolvedDate: DateTime.utc(2025, 12, 31),
    );
  }

  Future<void> pumpForm(
    WidgetTester tester,
    Ledger ledger,
    RecurringPlan plan,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanForm(ledger: ledger, plan: plan),
        ),
      ),
    );
  }

  testWidgets('source is shown as plain text with no interactive control', (
    tester,
  ) async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {source.id: MoneySource.account(source)},
        plans: {plan.id: plan},
      ),
    );

    await pumpForm(tester, ledger, plan);

    expect(find.text('Source: Wallet'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(3));
  });

  testWidgets('editing the amount of an expense plan preserves the negative '
      'sign on save', (tester) async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {source.id: MoneySource.account(source)},
        plans: {plan.id: plan},
      ),
    );

    await pumpForm(tester, ledger, plan);
    await tester.enterText(find.byType(TextField).at(1), '99.00');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = ledger.state.plans[plan.id]!;
    expect(saved.template.amount, dec('-99'));
  });

  testWidgets('editing an income plan keeps the amount positive', (
    tester,
  ) async {
    final plan = buildPlan(amount: dec('10'));
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {source.id: MoneySource.account(source)},
        plans: {plan.id: plan},
      ),
    );

    await pumpForm(tester, ledger, plan);
    await tester.enterText(find.byType(TextField).at(1), '42.00');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = ledger.state.plans[plan.id]!;
    expect(saved.template.amount, dec('42'));
  });

  testWidgets('saving does not change lastResolvedDate', (tester) async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = Ledger(
      state: LedgerState(
        moneySources: {source.id: MoneySource.account(source)},
        plans: {plan.id: plan},
      ),
    );

    await pumpForm(tester, ledger, plan);
    await tester.enterText(find.byType(TextField).at(1), '15.00');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = ledger.state.plans[plan.id]!;
    expect(saved.lastResolvedDate, plan.lastResolvedDate);
  });
}
