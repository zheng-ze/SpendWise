import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/transactions/daily_list/day_sections.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);
  DateTime day(int d) => DateTime.utc(2026, 7, d);

  final account = Account(
    id: 'a0000000-0000-0000-0000-000000000001',
    name: 'Checking',
    type: AccountType.checking,
  );
  final other = Account(
    id: 'a0000000-0000-0000-0000-000000000002',
    name: 'Savings',
    type: AccountType.savings,
  );
  final thirdParty = Account(
    id: 'a0000000-0000-0000-0000-000000000003',
    name: 'External',
    type: AccountType.checking,
  );

  LedgerState baseState() => LedgerState(
    moneySources: {
      account.id: MoneySource.account(account),
      other.id: MoneySource.account(other),
      thirdParty.id: MoneySource.account(thirdParty),
    },
  );

  test('groups entries by day and orders days newest first', () {
    final state = baseState();
    final entries = [
      Entry(
        amount: dec('-1'),
        name: 'first same-day entry',
        sourceID: account.id,
        date: day(1),
      ),
      Entry(
        amount: dec('-2'),
        name: 'second same-day entry',
        sourceID: account.id,
        date: day(1),
      ),
      Entry(
        amount: dec('-3'),
        name: 'latest day',
        sourceID: account.id,
        date: DateTime.utc(2026, 7, 3),
      ),
    ];

    final sections = daySections(entries, state);

    expect(sections.map((section) => section.date), [day(3), day(1)]);
  });

  test(
    'scope includes entries touching any selected source or destination',
    () {
      final state = baseState();
      final entries = [
        Entry(
          amount: dec('-1'),
          name: 'source',
          sourceID: account.id,
          date: day(1),
        ),
        Entry(
          amount: dec('2'),
          name: 'destination',
          sourceID: thirdParty.id,
          destinationID: account.id,
          date: day(1),
        ),
        Entry(
          amount: dec('-3'),
          name: 'other source',
          sourceID: other.id,
          date: day(1),
        ),
        Entry(
          amount: dec('-4'),
          name: 'unrelated',
          sourceID: thirdParty.id,
          date: day(1),
        ),
      ];

      final sections = daySections(
        entries,
        state,
        sourceScope: {account.id, other.id},
      );

      expect(sections.single.rows.map((row) => row.note), [
        'other source',
        'destination',
        'source',
      ]);
    },
  );

  test(
    'section totals follow included income, expenses, and transfer rules',
    () {
      final flaggedOther = Account(
        id: other.id,
        name: other.name,
        type: AccountType.savings,
        incomingTransfersAsExpenses: true,
      );
      final state = LedgerState(
        moneySources: {
          account.id: MoneySource.account(account),
          other.id: MoneySource.account(flaggedOther),
        },
      );
      final entries = [
        Entry(
          amount: dec('100'),
          name: 'salary',
          sourceID: account.id,
          date: day(1),
          includeInAnalysis: true,
        ),
        Entry(
          amount: dec('-40'),
          name: 'rent',
          sourceID: account.id,
          date: day(1),
        ),
        Entry(
          amount: dec('500'),
          name: 'excluded gift',
          sourceID: account.id,
          date: day(1),
          includeInAnalysis: false,
        ),
        Entry(
          amount: dec('50'),
          name: 'transfer',
          sourceID: account.id,
          destinationID: other.id,
          date: day(1),
        ),
      ];

      final section = daySections(entries, state).single;

      expect(section.income, dec('100'));
      expect(section.expenses, dec('90'));
    },
  );

  test('interval includes its start and excludes its end', () {
    final state = baseState();
    final entries = [
      Entry(
        amount: dec('-1'),
        name: 'at start',
        sourceID: account.id,
        date: day(1),
      ),
      Entry(
        amount: dec('-2'),
        name: 'at end',
        sourceID: account.id,
        date: day(3),
      ),
    ];

    final sections = daySections(
      entries,
      state,
      interval: DateRange(day(1), day(3)),
    );

    expect(sections.single.rows.single.note, 'at start');
  });
}
