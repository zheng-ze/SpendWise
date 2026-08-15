import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/settings/plan_sort.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final now = DateTime.utc(2026, 1, 1);
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

  LedgerState stateWith(List<RecurringPlan> plans) {
    return LedgerState(
      moneySources: {source.id: MoneySource.account(source)},
      plans: {for (final p in plans) p.id: p},
    );
  }

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

    final result = sortedPlans([ended, live], stateWith([ended, live]), now);

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

    final result = sortedPlans([b, a], stateWith([b, a]), now);

    expect(result.map((p) => p.template.name), ['Alpha ended', 'Bravo ended']);
  });

  test('two plans sharing the same non-null next occurrence tiebreak by '
      'name (the strengthening over V1)', () {
    // Same frequency and anchor genuinely produce the same next occurrence.
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

    expect(a.nextOccurrence(onOrAfter: now), b.nextOccurrence(onOrAfter: now));

    final result = sortedPlans([b, a], stateWith([b, a]), now);

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
      stateWith([later, sooner]),
      now,
    );

    expect(result.map((p) => p.template.name), ['Sooner', 'Later']);
  });
}
