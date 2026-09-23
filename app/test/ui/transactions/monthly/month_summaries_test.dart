import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/transactions/monthly/month_summaries.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);
  DateTime day(int year, [int month = 1, int d = 1]) =>
      DateTime.utc(year, month, d);

  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );
  final savings = Account(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Savings',
    type: AccountType.savings,
  );
  final flaggedSavings = Account(
    id: savings.id,
    name: savings.name,
    type: AccountType.savings,
    incomingTransfersAsExpenses: true,
  );

  LedgerState baseState({
    List<Entry> entries = const [],
    Account? secondAccount,
  }) => LedgerState(
    moneySources: {
      account.id: MoneySource.account(account),
      if (secondAccount != null)
        secondAccount.id: MoneySource.account(secondAccount),
    },
    entries: {for (final entry in entries) entry.id: entry},
  );

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

  test('a transfer into a treat-as-expense destination counts as an expense, '
      'in both its week and its month', () {
    final state = baseState(
      secondAccount: flaggedSavings,
      entries: [
        Entry(
          amount: dec('75'),
          name: 'move to savings',
          sourceID: account.id,
          destinationID: savings.id,
          date: day(2026, 7, 8),
        ),
      ],
    );

    final months = monthSummaries(state, day(2026), now: now);
    final july = months.firstWhere((m) => m.month == day(2026, 7, 1));
    final week = july.weeks.firstWhere(
      (w) => w.range.contains(day(2026, 7, 8)),
    );

    expect(july.expenses, dec('75'));
    expect(july.income, Decimal.zero);
    expect(week.expenses, dec('75'));
    expect(week.income, Decimal.zero);
  });

  test('a transfer between two accounts with neither flagged counts toward '
      'neither total', () {
    final state = baseState(
      secondAccount: savings,
      entries: [
        Entry(
          amount: dec('75'),
          name: 'move to savings',
          sourceID: account.id,
          destinationID: savings.id,
          date: day(2026, 7, 8),
        ),
      ],
    );

    final months = monthSummaries(state, day(2026), now: now);
    final july = months.firstWhere((m) => m.month == day(2026, 7, 1));

    expect(july.income, Decimal.zero);
    expect(july.expenses, Decimal.zero);
  });

  test(
    'a transfer flagged treat-as-expense on both ends counts in both totals',
    () {
      final flaggedAccount = Account(
        id: account.id,
        name: account.name,
        type: AccountType.savings,
        incomingTransfersAsExpenses: true,
      );
      final state = LedgerState(
        moneySources: {
          account.id: MoneySource.account(flaggedAccount),
          savings.id: MoneySource.account(flaggedSavings),
        },
        entries: {
          for (final entry in [
            Entry(
              amount: dec('75'),
              name: 'move between flagged accounts',
              sourceID: account.id,
              destinationID: savings.id,
              date: day(2026, 7, 8),
            ),
          ])
            entry.id: entry,
        },
      );

      final months = monthSummaries(state, day(2026), now: now);
      final july = months.firstWhere((m) => m.month == day(2026, 7, 1));

      expect(july.income, dec('75'));
      expect(july.expenses, dec('75'));
    },
  );

  test('a spillover week appears under both months with identical totals', () {
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

    final week = july.weeks.firstWhere((w) => w.range.start == day(2026, 7, 6));
    expect(week.range.end, day(2026, 7, 13));
  });
}
