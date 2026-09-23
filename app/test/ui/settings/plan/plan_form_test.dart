import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/plan/plan_form.dart';

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

  Ledger buildLedger(RecurringPlan plan) => Ledger(
    state: LedgerState(
      moneySources: {source.id: MoneySource.account(source)},
      plans: {plan.id: plan},
    ),
  );

  Future<void> pumpForm(
    WidgetTester tester,
    Ledger ledger,
    RecurringPlan plan,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ledgerProvider.overrideWithValue(ledger)],
        child: MaterialApp(
          home: Scaffold(body: PlanForm(planId: plan.id)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('source is shown as plain text with no interactive control', (
    tester,
  ) async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = buildLedger(plan);

    await pumpForm(tester, ledger, plan);

    expect(find.text('Source: Wallet'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(3));
  });

  testWidgets('editing the amount of an expense plan preserves the negative '
      'sign on save', (tester) async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = buildLedger(plan);

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
    final ledger = buildLedger(plan);

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
    final ledger = buildLedger(plan);

    await pumpForm(tester, ledger, plan);
    await tester.enterText(find.byType(TextField).at(1), '15.00');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = ledger.state.plans[plan.id]!;
    expect(saved.lastResolvedDate, plan.lastResolvedDate);
  });

  testWidgets('blank name blocks the save button', (tester) async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = buildLedger(plan);

    await pumpForm(tester, ledger, plan);
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();

    final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('zero amount blocks the save button', (tester) async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = buildLedger(plan);

    await pumpForm(tester, ledger, plan);
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.pump();

    final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('picking a recurrence frequency updates the Repeat row', (
    tester,
  ) async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = buildLedger(plan);

    await pumpForm(tester, ledger, plan);

    expect(find.text('Monthly'), findsOneWidget);

    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();

    expect(find.text('Yearly'), findsOneWidget);
  });

  testWidgets('enabling end date defaults it to the first date, editable via '
      'its own picker', (tester) async {
    final plan = buildPlan(amount: dec('-10'));
    final ledger = buildLedger(plan);

    await pumpForm(tester, ledger, plan);

    expect(find.text('Ends on'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Ends on'), findsOneWidget);
    expect(find.text('1 Jan 2026'), findsNWidgets(2));

    await tester.tap(find.text('Ends on'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(ledger.state.plans[plan.id], plan);
  });
}
