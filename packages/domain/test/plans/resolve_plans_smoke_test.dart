import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const accountID = '00000000-0000-4000-8000-000000000001';

  LedgerState seeded() {
    final state = LedgerState();
    state.addAccount(
      Account(id: accountID, name: 'Checking', type: AccountType.cash),
    );
    return state;
  }

  RecurringPlan monthly({DateTime? endDate, DateTime? lastResolvedDate}) =>
      RecurringPlan(
        template: EntryTemplate(
          amount: Decimal.fromInt(-25),
          name: 'rent',
          sourceID: accountID,
        ),
        frequency: RecurrenceFrequency.monthly,
        anchor: DateTime.utc(2026, 1, 15),
        endDate: endDate,
        lastResolvedDate: lastResolvedDate ?? DateTime.utc(2026, 1, 15),
      );

  test('materializes due occurrences and advances the cursor', () {
    final state = seeded();
    state.addPlan(monthly());

    final result = state.resolvePlans(DateTime.utc(2026, 3, 20));

    expect(result.failures, isEmpty);
    expect(state.entries, hasLength(2));
    expect(result.changes.whereType<UpsertEntry>().map((c) => c.entry.date), [
      DateTime.utc(2026, 2, 15),
      DateTime.utc(2026, 3, 15),
    ]);
    expect(result.changes.last, isA<UpsertPlan>());
  });

  test('a second sweep at the same instant materializes nothing', () {
    final state = seeded();
    state.addPlan(monthly());
    state.resolvePlans(DateTime.utc(2026, 3, 20));

    final second = state.resolvePlans(DateTime.utc(2026, 3, 20));

    expect(second.changes, isEmpty);
    expect(state.entries, hasLength(2));
  });

  test('rewinding the cursor re-offers occurrences without duplicating', () {
    final state = seeded();
    final plan = monthly();
    state.addPlan(plan);
    state.resolvePlans(DateTime.utc(2026, 3, 20));
    final materialized = {...state.entries};

    state.updatePlan(plan.resolvedAt(DateTime.utc(2026, 1, 15)));
    final replay = state.resolvePlans(DateTime.utc(2026, 3, 20));

    expect(replay.changes.whereType<UpsertEntry>(), isEmpty);
    expect(replay.failures, isEmpty);
    expect(state.entries, materialized);
  });

  test('emits nothing when no occurrence is due', () {
    final state = seeded();
    state.addPlan(monthly());

    final result = state.resolvePlans(DateTime.utc(2026, 1, 20));

    expect(result.changes, isEmpty);
    expect(result.failures, isEmpty);
    expect(state.entries, isEmpty);
  });

  test('retires an exhausted plan after its final occurrence', () {
    final state = seeded();
    final plan = monthly(endDate: DateTime.utc(2026, 2, 20));
    state.addPlan(plan);

    final result = state.resolvePlans(DateTime.utc(2026, 4, 1));

    expect(state.plans, isEmpty);
    expect(result.changes.last, DeletePlan(plan.id));
    expect(state.entries, hasLength(1));
  });

  test(
    'retires a plan whose final occurrence lands on the resolve instant',
    () {
      final state = seeded();
      final plan = monthly(endDate: DateTime.utc(2026, 2, 15));
      state.addPlan(plan);

      final result = state.resolvePlans(DateTime.utc(2026, 2, 15));

      expect(state.plans, isEmpty);
      expect(result.changes.last, DeletePlan(plan.id));
      expect(state.entries, hasLength(1));
    },
  );
}
