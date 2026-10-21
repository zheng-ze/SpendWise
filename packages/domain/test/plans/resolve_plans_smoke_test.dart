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

  RecurringPlan monthly({DateTime? endDate}) => RecurringPlan(
    template: EntryTemplate(
      amount: Decimal.fromInt(-25),
      name: 'rent',
      sourceID: accountID,
    ),
    frequency: RecurrenceFrequency.monthly,
    anchor: DateTime.utc(2026, 1, 15),
    endDate: endDate,
    lastResolvedDate: DateTime.utc(2026, 1, 15),
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
