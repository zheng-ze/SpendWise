import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/transactions/month_summaries.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);
  DateTime day(int year, [int month = 1, int d = 1]) =>
      DateTime.utc(year, month, d);

  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );

  LedgerState baseState({List<Entry> entries = const []}) => LedgerState(
    moneySources: {account.id: MoneySource.account(account)},
    entries: {for (final entry in entries) entry.id: entry},
  );

  // now is pinned to a fixed date via the test-only seam so year-cutoff and
  // current-month/current-week flags do not depend on the wall clock.
  final now = day(2026, 7, 15);

  test('a future year yields zero months', () {
    final state = baseState();

    final months = monthSummaries(state, day(2027), now: now);

    expect(months, isEmpty);
  });

  test('a fully past year yields all twelve months', () {
    final state = baseState();

    final months = monthSummaries(state, day(2025), now: now);

    expect(months.length, 12);
  });

  test('current year stops at the current month, newest first', () {
    final state = baseState();

    final months = monthSummaries(state, day(2026), now: now);

    expect(months.length, 7);
    expect(months.first.month, day(2026, 7, 1));
    expect(months.last.month, day(2026, 1, 1));
  });

  test('only the current month carries the current-month flag', () {
    final state = baseState();

    final months = monthSummaries(state, day(2026), now: now);

    expect(months.first.isCurrentMonth, isTrue);
    expect(months.skip(1).every((m) => !m.isCurrentMonth), isTrue);
  });

  test('a month totals income and expenses by entry-level analysis flag', () {
    final state = baseState(
      entries: [
        Entry(
          amount: dec('100'),
          name: 'salary',
          sourceID: account.id,
          date: day(2026, 7, 3),
        ),
        Entry(
          amount: dec('-40'),
          name: 'rent',
          sourceID: account.id,
          date: day(2026, 7, 4),
        ),
        Entry(
          amount: dec('-9999'),
          name: 'off the books',
          sourceID: account.id,
          date: day(2026, 7, 5),
          includeInAnalysis: false,
        ),
      ],
    );

    final months = monthSummaries(state, day(2026), now: now);
    final july = months.firstWhere((m) => m.month == day(2026, 7, 1));

    expect(july.income, dec('100'));
    expect(july.expenses, dec('40'));
  });

  test('a spillover week appears under both months with identical totals', () {
    // 2026-08-01 is a Saturday, so the week containing it (Mon 2026-07-27 to
    // Sun 2026-08-02) spills from July into August. "now" is pinned to
    // August here so both months are within the year cutoff.
    final state = baseState(
      entries: [
        Entry(
          amount: dec('-20'),
          name: 'late july',
          sourceID: account.id,
          date: day(2026, 7, 30),
        ),
        Entry(
          amount: dec('-5'),
          name: 'early august',
          sourceID: account.id,
          date: day(2026, 8, 1),
        ),
      ],
    );

    final months = monthSummaries(state, day(2026), now: day(2026, 8, 15));
    final july = months.firstWhere((m) => m.month == day(2026, 7, 1));
    final august = months.firstWhere((m) => m.month == day(2026, 8, 1));

    final julySpillover = july.weeks.firstWhere(
      (w) => w.range.start == day(2026, 7, 27),
    );
    final augustSpillover = august.weeks.firstWhere(
      (w) => w.range.start == day(2026, 7, 27),
    );

    expect(julySpillover.range, augustSpillover.range);
    expect(julySpillover.income, augustSpillover.income);
    expect(julySpillover.expenses, augustSpillover.expenses);
    expect(julySpillover.expenses, dec('25'));
  });

  test('weeks are listed newest first', () {
    final state = baseState();

    final months = monthSummaries(state, day(2026), now: now);
    final july = months.firstWhere((m) => m.month == day(2026, 7, 1));

    final starts = july.weeks.map((w) => w.range.start).toList();
    final sorted = [...starts]..sort((a, b) => b.compareTo(a));
    expect(starts, sorted);
  });

  test('only the week containing now carries the current-week flag', () {
    final state = baseState();

    final months = monthSummaries(state, day(2026), now: now);
    final july = months.firstWhere((m) => m.month == day(2026, 7, 1));

    final currentWeeks = july.weeks.where((w) => w.isCurrentWeek);
    expect(currentWeeks.length, 1);
    expect(currentWeeks.single.range.contains(now), isTrue);
  });

  test('week range label subtracts a day off the exclusive end', () {
    final state = baseState();

    final months = monthSummaries(state, day(2026), now: now);
    final july = months.firstWhere((m) => m.month == day(2026, 7, 1));

    // Monday 2026-07-06 through Sunday 2026-07-12, stored end-exclusive as
    // the 13th.
    final week = july.weeks.firstWhere((w) => w.range.start == day(2026, 7, 6));
    expect(week.range.end, day(2026, 7, 13));
  });
}
