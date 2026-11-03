import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/plan/plan_list_view_model.dart';

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
    DateTime? lastResolvedDate,
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
      lastResolvedDate:
          lastResolvedDate ?? anchor.subtract(const Duration(days: 1)),
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

      final result = sortedPlans(
        [ended, live],
        buildLedger([ended, live]).state,
        now,
      );

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

      final result = sortedPlans([b, a], buildLedger([b, a]).state, now);

      expect(result.map((p) => p.template.name), [
        'Alpha ended',
        'Bravo ended',
      ]);
    });

    test('two plans sharing the same non-null next occurrence tiebreak by '
        'name (the strengthening over V1)', () {
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

      expect(
        a.nextOccurrence(onOrAfter: now),
        b.nextOccurrence(onOrAfter: now),
      );

      final result = sortedPlans([b, a], buildLedger([b, a]).state, now);

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

      final result = sortedPlans(
        [later, sooner],
        buildLedger([later, sooner]).state,
        now,
      );

      expect(result.map((p) => p.template.name), ['Sooner', 'Later']);
    });
  });

  test('the projection sorts plans by ascending next occurrence', () {
    final today = DateTime.utc(2026, 1, 1);
    final sooner = plan(
      name: 'Bravo',
      frequency: RecurrenceFrequency.weekly,
      anchor: today,
    );
    final later = plan(
      name: 'Alpha',
      frequency: RecurrenceFrequency.yearly,
      anchor: DateTime.utc(2026, 6, 1),
    );
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(buildLedger([later, sooner])),
        clockProvider.overrideWithValue(() => today),
      ],
    );
    addTearDown(container.dispose);

    final projection = container.read(planListProjectionProvider).requireValue;

    expect(projection.plans.map((p) => p.id), [sooner.id, later.id]);
  });

  test('a plan due today keeps today as its label date and sorts first', () {
    final today = DateTime.utc(2026, 1, 1);
    final dueToday = plan(
      name: 'Zulu',
      frequency: RecurrenceFrequency.monthly,
      anchor: today,
    );
    final dueLater = plan(
      name: 'Alpha',
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 1, 15),
    );
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(buildLedger([dueLater, dueToday])),
        clockProvider.overrideWithValue(() => today),
      ],
    );
    addTearDown(container.dispose);

    final projection = container.read(planListProjectionProvider).requireValue;

    expect(projection.plans.first.id, dueToday.id);
    expect(projection.nextOccurrences[dueToday.id], today);
    expect(projection.nextOccurrences[dueLater.id], DateTime.utc(2026, 1, 15));
  });

  test('a ledger change refreshes the plans', () {
    final first = plan(
      name: 'First',
      frequency: RecurrenceFrequency.monthly,
      anchor: DateTime.utc(2026, 3, 1),
    );
    final ledger = buildLedger([first]);
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWithValue(ledger)],
    );
    addTearDown(container.dispose);
    container.listen(planListProjectionProvider, (previous, next) {});

    ledger.deletePlan(first.id);

    final projection = container.read(planListProjectionProvider).requireValue;
    expect(projection.plans, isEmpty);
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
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(buildLedger([early, late])),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    container.listen(planListProjectionProvider, (previous, next) {});
    final before = container.read(planListProjectionProvider).requireValue;

    now = DateTime.utc(2026, 1, 10);
    container.invalidate(todayProvider);

    final after = container.read(planListProjectionProvider).requireValue;
    expect(before.plans.map((p) => p.id), [early.id, late.id]);
    expect(after.plans.map((p) => p.id), [late.id, early.id]);
  });
}
