import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/plans/plan_list/plan_list_view_model.dart';
import 'package:spendwise/ui/plans/plan_list/plan_selection.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final source = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Wallet',
    type: AccountType.cash,
  );

  RecurringPlan plan({
    required String name,
    required RecurrenceFrequency frequency,
    required DateTime anchor,
    DateTime? endDate,
    String amount = '-10',
    String? destinationID,
  }) {
    return RecurringPlan(
      template: EntryTemplate(
        amount: dec(amount),
        name: name,
        sourceID: source.id,
        destinationID: destinationID,
      ),
      frequency: frequency,
      anchor: anchor,
      endDate: endDate,
      lastResolvedDate: anchor.subtract(const Duration(days: 1)),
    );
  }

  RecurringPlan endedPlan(String name) => plan(
    name: name,
    frequency: RecurrenceFrequency.monthly,
    anchor: DateTime.utc(2025, 12, 20),
    endDate: DateTime.utc(2026, 1, 10),
  );

  Ledger buildLedger(List<RecurringPlan> plans) {
    return Ledger(
      state: LedgerState(
        moneySources: {source.id: MoneySource.account(source)},
        plans: {for (final p in plans) p.id: p},
      ),
    );
  }

  ProviderContainer buildContainer(Ledger ledger, {DateTime Function()? now}) {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        if (now != null) clockProvider.overrideWithValue(now),
      ],
    );
    addTearDown(container.dispose);
    container.listen(planListViewModelProvider, (previous, next) {});
    return container;
  }

  group('sortedPlans', () {
    final now = DateTime.utc(2026, 1, 1);

    test('ended plans sort after every plan with a next occurrence', () {
      final ended = endedPlan('Zeta ended');
      final live = plan(
        name: 'Alpha live',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 3, 1),
      );

      final result = sortedPlans([ended, live], now);

      expect(result.map((p) => p.template.name), ['Alpha live', 'Zeta ended']);
    });

    test('two ended plans tiebreak by name', () {
      final b = endedPlan('Bravo ended');
      final a = endedPlan('Alpha ended');

      final result = sortedPlans([b, a], now);

      expect(result.map((p) => p.template.name), [
        'Alpha ended',
        'Bravo ended',
      ]);
    });

    test('two plans sharing the same next occurrence tiebreak by name', () {
      final anchor = DateTime.utc(2026, 2, 1);
      final b = plan(
        name: 'Bravo live',
        frequency: RecurrenceFrequency.monthly,
        anchor: anchor,
      );
      final a = plan(
        name: 'Alpha live',
        frequency: RecurrenceFrequency.monthly,
        anchor: anchor,
      );

      final result = sortedPlans([b, a], now);

      expect(result.map((p) => p.template.name), ['Alpha live', 'Bravo live']);
    });

    test('a plan due sooner sorts before one due later', () {
      final later = plan(
        name: 'Later',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 6, 1),
      );
      final sooner = plan(
        name: 'Sooner',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 15),
      );

      final result = sortedPlans([later, sooner], now);

      expect(result.map((p) => p.template.name), ['Sooner', 'Later']);
    });
  });

  group('PlanListNotifier', () {
    final clockToday = DateTime.utc(2026, 1, 1);
    final target = Account(
      id: 'a0000000-0000-0000-0000-000000000002',
      name: 'Savings',
      type: AccountType.savings,
    );

    PlanListViewState read(ProviderContainer container) =>
        container.read(planListViewModelProvider).requireValue;

    test('an expense plan projects date, caption and signed amount', () {
      final rent = plan(
        name: 'Rent',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 5),
      );
      final container = buildContainer(
        buildLedger([rent]),
        now: () => clockToday,
      );

      final row = read(container).rows.single;

      expect(row.name, 'Rent');
      expect(row.nextDate, (day: '5', month: 'Jan'));
      expect(row.caption, 'Every month / Wallet');
      expect(row.amount, '-10.00');
      expect(row.kind, AmountKind.expense);
    });

    test('an income plan projects a plus-signed income amount', () {
      final salary = plan(
        name: 'Salary',
        frequency: RecurrenceFrequency.biweekly,
        anchor: DateTime.utc(2026, 1, 9),
        amount: '3000',
      );
      final container = buildContainer(
        buildLedger([salary]),
        now: () => clockToday,
      );

      final row = read(container).rows.single;

      expect(row.amount, '+3,000.00');
      expect(row.kind, AmountKind.income);
      expect(row.caption, 'Every two weeks / Wallet');
    });

    test('a plan with a destination is a transfer without a sign', () {
      final move = plan(
        name: 'To savings',
        frequency: RecurrenceFrequency.quarterly,
        anchor: DateTime.utc(2026, 1, 9),
        amount: '-500',
        destinationID: target.id,
      );
      final ledger = Ledger(
        state: LedgerState(
          moneySources: {
            source.id: MoneySource.account(source),
            target.id: MoneySource.account(target),
          },
          plans: {move.id: move},
        ),
      );
      final container = buildContainer(ledger, now: () => clockToday);

      final row = read(container).rows.single;

      expect(row.amount, '500.00');
      expect(row.kind, AmountKind.transfer);
      expect(row.caption, 'Every three months / Wallet');
    });

    test('an ended plan has no date, and sorts last', () {
      final ended = endedPlan('Aardvark');
      final live = plan(
        name: 'Zebra',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 3, 1),
      );
      final container = buildContainer(
        buildLedger([ended, live]),
        now: () => clockToday,
      );

      final rows = read(container).rows;

      expect(rows.map((r) => r.id), [live.id, ended.id]);
      expect(rows.last.nextDate, isNull);
      expect(rows.first.nextDate, isNotNull);
    });

    test('the count label is singular for one plan and plural otherwise', () {
      expect(planCountLabel(1), '1 plan');
      expect(planCountLabel(2), '2 plans');
      expect(planCountLabel(0), '0 plans');
    });

    test('selectPlan sets the selected plan in state and provider', () {
      final one = plan(
        name: 'One',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 2, 1),
      );
      final container = buildContainer(buildLedger([one]));
      final viewModel = container.read(planListViewModelProvider.notifier);

      viewModel.selectPlan(one.id);

      expect(container.read(selectedPlanProvider), one.id);
    });

    test('a ledger change refreshes the rows', () {
      final first = plan(
        name: 'First',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 2, 1),
      );
      final second = plan(
        name: 'Second',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 2, 2),
      );
      final ledger = buildLedger([first, second]);
      final container = buildContainer(ledger);

      ledger.deletePlan(second.id);

      expect(read(container).rows.map((r) => r.id), [first.id]);
      expect(read(container).countLabel, '1 plan');
    });

    test('advancing today refreshes the next-occurrence order', () {
      var now = DateTime.utc(2026, 1, 1);
      final early = plan(
        name: 'Early',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 5),
      );
      final late = plan(
        name: 'Late',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 20),
      );
      final container = buildContainer(
        buildLedger([early, late]),
        now: () => now,
      );
      final before = read(container);

      now = DateTime.utc(2026, 1, 10);
      container.invalidate(todayProvider);

      final after = read(container);
      expect(before.rows.map((r) => r.id), [early.id, late.id]);
      expect(after.rows.map((r) => r.id), [late.id, early.id]);
    });

    test('an unmounted view model stops listening to the ledger', () async {
      final one = plan(
        name: 'One',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 2, 1),
      );
      final ledger = ListenerTrackingLedger(buildLedger([one]).state);
      final container = ProviderContainer(
        overrides: [ledgerProvider.overrideWithValue(ledger)],
      );
      addTearDown(container.dispose);
      final mounted = container.listen(planListViewModelProvider, (_, _) {});
      expect(ledger.isListened, isTrue);

      mounted.close();
      await container.pump();

      expect(ledger.isListened, isFalse);
    });
  });
}

class ListenerTrackingLedger extends Ledger {
  ListenerTrackingLedger(LedgerState state) : super(state: state);

  bool get isListened => hasListeners;
}
