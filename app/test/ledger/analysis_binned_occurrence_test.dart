import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/calendar.dart';
import 'package:spendwise/ledger/analysis/upcoming.dart';

void main() {
  late LedgerState state;
  late RecurringPlan weekly;
  final today = DateTime.utc(2026, 3, 1);
  final window = DateRange(today, DateTime.utc(2026, 3, 8));

  setUp(() {
    state = LedgerState();
    final account = Account(name: 'acc', type: AccountType.savings);
    state.addAccount(account);
    weekly = RecurringPlan(
      template: EntryTemplate(
        amount: Decimal.fromInt(-10),
        name: 'gym',
        sourceID: account.id,
      ),
      frequency: RecurrenceFrequency.weekly,
      anchor: DateTime.utc(2026, 3, 4),
      lastResolvedDate: DateTime.utc(2026, 3, 3),
    );
    state.addPlan(weekly);
    state.resolvePlans(DateTime.utc(2026, 3, 5));
    state.updatePlan(weekly);
  });

  test('a materialized occurrence is not projected', () {
    expect(state.entries, hasLength(1));

    expect(
      upcomingPlanOccurrences(ledger: state, today: today, window: window),
      isEmpty,
    );
  });

  test('a binned occurrence is not projected as upcoming', () {
    state.archiveEntry(state.entries.keys.single);

    expect(
      upcomingPlanOccurrences(ledger: state, today: today, window: window),
      isEmpty,
    );
  });

  test('a binned occurrence does not appear in the calendar', () {
    state.archiveEntry(state.entries.keys.single);

    expect(calendarDays(ledger: state, today: today, window: window), isEmpty);
  });
}
