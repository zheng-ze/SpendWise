import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/transactions/day_sections.dart';

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

  test('entries group into sections by their start of day', () {
    final state = baseState();
    final entries = [
      Entry(amount: dec('-5'), name: 'a', sourceID: account.id, date: day(1)),
      Entry(amount: dec('-6'), name: 'b', sourceID: account.id, date: day(2)),
    ];

    final sections = daySections(entries, state);

    expect(sections.map((s) => s.date), [day(2), day(1)]);
  });

  test('rows within a day sort newest first, latest input first', () {
    final state = baseState();
    final entries = [
      Entry(
        amount: dec('-1'),
        name: 'entered first',
        sourceID: account.id,
        date: day(1),
      ),
      Entry(
        amount: dec('-2'),
        name: 'entered second',
        sourceID: account.id,
        date: day(1),
      ),
    ];

    final sections = daySections(entries, state);

    expect(sections.single.rows.map((r) => r.note), [
      'entered second',
      'entered first',
    ]);
  });

  test('days sort newest first', () {
    final state = baseState();
    final entries = [
      Entry(amount: dec('-1'), name: 'old', sourceID: account.id, date: day(1)),
      Entry(
        amount: dec('-2'),
        name: 'newer',
        sourceID: account.id,
        date: day(5),
      ),
      Entry(
        amount: dec('-3'),
        name: 'middle',
        sourceID: account.id,
        date: day(3),
      ),
    ];

    final sections = daySections(entries, state);

    expect(sections.map((s) => s.date), [day(5), day(3), day(1)]);
  });

  test('scope filter matches entries where the id is the source', () {
    final state = baseState();
    final entries = [
      Entry(
        amount: dec('-1'),
        name: 'scoped',
        sourceID: account.id,
        date: day(1),
      ),
      Entry(
        amount: dec('-2'),
        name: 'unrelated',
        sourceID: other.id,
        date: day(1),
      ),
    ];

    final sections = daySections(entries, state, sourceScope: {account.id});

    expect(sections.single.rows.map((r) => r.note), ['scoped']);
  });

  test('scope filter matches entries where the id is the destination', () {
    final state = baseState();
    final entries = [
      Entry(
        amount: dec('1'),
        name: 'incoming transfer',
        sourceID: other.id,
        destinationID: account.id,
        date: day(1),
      ),
      Entry(
        amount: dec('-2'),
        name: 'unrelated',
        sourceID: thirdParty.id,
        date: day(1),
      ),
    ];

    final sections = daySections(entries, state, sourceScope: {account.id});

    expect(sections.single.rows.map((r) => r.note), ['incoming transfer']);
  });

  test('scope filter with multiple ids matches any of them', () {
    final state = baseState();
    final entries = [
      Entry(
        amount: dec('-1'),
        name: 'from account',
        sourceID: account.id,
        date: day(1),
      ),
      Entry(
        amount: dec('-2'),
        name: 'from other',
        sourceID: other.id,
        date: day(1),
      ),
      Entry(
        amount: dec('-3'),
        name: 'from third party',
        sourceID: thirdParty.id,
        date: day(1),
      ),
    ];

    final sections = daySections(
      entries,
      state,
      sourceScope: {account.id, other.id},
    );

    expect(sections.single.rows.map((r) => r.note), [
      'from other',
      'from account',
    ]);
  });

  test('income row included in analysis contributes to the income total', () {
    final state = baseState();
    final entries = [
      Entry(
        amount: dec('100'),
        name: 'salary',
        sourceID: account.id,
        date: day(1),
        includeInAnalysis: true,
      ),
    ];

    final sections = daySections(entries, state);

    expect(sections.single.income, dec('100'));
    expect(sections.single.expenses, Decimal.zero);
  });

  test('entry excluded from analysis does not contribute to totals', () {
    final state = baseState();
    final entries = [
      Entry(
        amount: dec('100'),
        name: 'gift, off the books',
        sourceID: account.id,
        date: day(1),
        includeInAnalysis: false,
      ),
    ];

    final sections = daySections(entries, state);

    expect(sections.single.income, Decimal.zero);
    expect(sections.single.expenses, Decimal.zero);
  });

  test('expense total is the positive magnitude of expense rows', () {
    final state = baseState();
    final entries = [
      Entry(
        amount: dec('-40'),
        name: 'rent',
        sourceID: account.id,
        date: day(1),
      ),
    ];

    final sections = daySections(entries, state);

    expect(sections.single.expenses, dec('40'));
    expect(sections.single.income, Decimal.zero);
  });

  test('a transfer contributes to neither total when neither end treats '
      'incoming transfers as expense', () {
    final state = baseState();
    final entries = [
      Entry(
        amount: dec('50'),
        name: 'move funds',
        sourceID: account.id,
        destinationID: other.id,
        date: day(1),
      ),
    ];

    final sections = daySections(entries, state);

    expect(sections.single.income, Decimal.zero);
    expect(sections.single.expenses, Decimal.zero);
    expect(sections.single.rows.single.amountKind, AmountKind.transfer);
  });

  test('a transfer into a destination flagged treat-as-expense counts as an '
      'expense', () {
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
        amount: dec('50'),
        name: 'move to savings',
        sourceID: account.id,
        destinationID: other.id,
        date: day(1),
      ),
    ];

    final sections = daySections(entries, state);

    expect(sections.single.expenses, dec('50'));
    expect(sections.single.income, Decimal.zero);
  });

  test(
    'a transfer whose source is flagged treat-as-expense counts as income',
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
          other.id: MoneySource.account(other),
        },
      );
      final entries = [
        Entry(
          amount: dec('50'),
          name: 'move from savings',
          sourceID: account.id,
          destinationID: other.id,
          date: day(1),
        ),
      ];

      final sections = daySections(entries, state);

      expect(sections.single.income, dec('50'));
      expect(sections.single.expenses, Decimal.zero);
    },
  );

  test(
    'a transfer flagged treat-as-expense on both ends counts in both totals',
    () {
      final flaggedAccount = Account(
        id: account.id,
        name: account.name,
        type: AccountType.savings,
        incomingTransfersAsExpenses: true,
      );
      final flaggedOther = Account(
        id: other.id,
        name: other.name,
        type: AccountType.savings,
        incomingTransfersAsExpenses: true,
      );
      final state = LedgerState(
        moneySources: {
          account.id: MoneySource.account(flaggedAccount),
          other.id: MoneySource.account(flaggedOther),
        },
      );
      final entries = [
        Entry(
          amount: dec('50'),
          name: 'move between flagged accounts',
          sourceID: account.id,
          destinationID: other.id,
          date: day(1),
        ),
      ];

      final sections = daySections(entries, state);

      expect(sections.single.income, dec('50'));
      expect(sections.single.expenses, dec('50'));
    },
  );

  test('interval end is exclusive, an entry exactly at end is dropped', () {
    final state = baseState();
    final entries = [
      Entry(
        amount: dec('-1'),
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

    expect(sections, isEmpty);
  });

  test('interval start is inclusive, an entry exactly at start is kept', () {
    final state = baseState();
    final entries = [
      Entry(
        amount: dec('-1'),
        name: 'at start',
        sourceID: account.id,
        date: day(1),
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
