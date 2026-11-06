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
  }) {
    return RecurringPlan(
      template: EntryTemplate(
        amount: dec('-10'),
        name: name,
        sourceID: source.id,
      ),
      frequency: frequency,
      anchor: anchor,
      endDate: endDate,
      lastResolvedDate: anchor.subtract(const Duration(days: 1)),
    );
  }

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
      final ended = plan(
        name: 'Zeta ended',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2025, 1, 1),
        endDate: DateTime.utc(2025, 2, 1),
      );
      final live = plan(
        name: 'Alpha live',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 3, 1),
      );

      final result = sortedPlans([ended, live], now);

      expect(result.map((p) => p.template.name), ['Alpha live', 'Zeta ended']);
    });

    test('two ended plans tiebreak by name', () {
      final b = plan(
        name: 'Bravo ended',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2025, 1, 1),
        endDate: DateTime.utc(2025, 2, 1),
      );
      final a = plan(
        name: 'Alpha ended',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2025, 1, 1),
        endDate: DateTime.utc(2025, 2, 1),
      );

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

    test('rows sort by ascending next occurrence', () {
      final sooner = plan(
        name: 'Bravo',
        frequency: RecurrenceFrequency.weekly,
        anchor: clockToday,
      );
      final later = plan(
        name: 'Alpha',
        frequency: RecurrenceFrequency.yearly,
        anchor: DateTime.utc(2026, 6, 1),
      );
      final container = buildContainer(
        buildLedger([later, sooner]),
        now: () => clockToday,
      );

      expect(read(container).rows.map((r) => r.id), [sooner.id, later.id]);
    });

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
      final salary = RecurringPlan(
        template: EntryTemplate(
          amount: dec('3000'),
          name: 'Salary',
          sourceID: source.id,
        ),
        frequency: RecurrenceFrequency.biweekly,
        anchor: DateTime.utc(2026, 1, 9),
        lastResolvedDate: DateTime.utc(2026, 1, 8),
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
      final move = RecurringPlan(
        template: EntryTemplate(
          amount: dec('-500'),
          name: 'To savings',
          sourceID: source.id,
          destinationID: target.id,
        ),
        frequency: RecurrenceFrequency.quarterly,
        anchor: DateTime.utc(2026, 1, 9),
        lastResolvedDate: DateTime.utc(2026, 1, 8),
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

    test('a plan whose account is missing names it Unknown', () {
      final orphan = plan(
        name: 'Orphan',
        frequency: RecurrenceFrequency.yearly,
        anchor: DateTime.utc(2026, 2, 1),
      );
      final container = buildContainer(
        Ledger(state: LedgerState(plans: {orphan.id: orphan})),
        now: () => clockToday,
      );

      expect(read(container).rows.single.caption, 'Every year / Unknown');
    });

    test('an ended plan has no date, and sorts last', () {
      final ended = plan(
        name: 'Aardvark',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2025, 1, 1),
        endDate: DateTime.utc(2025, 2, 1),
      );
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
      final one = plan(
        name: 'One',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 2, 1),
      );
      final two = plan(
        name: 'Two',
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 2, 2),
      );
      final single = buildContainer(buildLedger([one]));
      final pair = buildContainer(buildLedger([one, two]));
      final none = buildContainer(buildLedger([]));

      expect(read(single).countLabel, '1 plan');
      expect(read(pair).countLabel, '2 plans');
      expect(read(none).countLabel, '0 plans');
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
