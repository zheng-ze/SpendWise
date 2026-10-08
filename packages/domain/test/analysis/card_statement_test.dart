import 'package:domain/domain.dart';
import 'package:test/test.dart';

import '../support/builders.dart';

LedgerState ledger({
  required List<MoneySource> sources,
  required List<Entry> entries,
  Map<String, TransactionCategory>? categories,
}) {
  return LedgerState(
    moneySources: {for (final source in sources) source.id: source},
    entries: {for (final entry in entries) entry.id: entry},
    categories: categories,
  );
}

MoneySource cardSource(
  String id, {
  int? statementDay = 10,
  Set<String> subPocketIDs = const {},
  LifecycleState lifecycle = LifecycleState.active,
}) {
  return MoneySource.account(
    account(
      id,
      name: 'card',
      type: AccountType.card,
      subPocketIDs: subPocketIDs,
      statementDay: statementDay,
      lifecycle: lifecycle,
    ),
  );
}

MoneySource checkingSource(String id) {
  return MoneySource.account(
    account(id, name: 'checking', type: AccountType.checking),
  );
}

MoneySource flaggedSavingsSource(String id) {
  return MoneySource.account(
    account(
      id,
      name: 'savings',
      type: AccountType.savings,
      incomingTransfersAsExpenses: true,
    ),
  );
}

Entry charge(
  int n, {
  required String source,
  required DateTime date,
  required String amount,
}) {
  return entry(
    id: uuid(n),
    date: date,
    amount: Decimal.parse(amount),
    name: 'charge',
    sourceID: source,
  );
}

LedgerState mainLedger(String card, String checking) {
  return ledger(
    sources: [cardSource(card), checkingSource(checking)],
    entries: [
      charge(11, source: card, date: DateTime.utc(2027, 2, 20), amount: '-81'),
      charge(12, source: card, date: DateTime.utc(2027, 3, 12), amount: '-24'),
      entry(
        id: uuid(13),
        date: DateTime.utc(2027, 4, 3),
        amount: Decimal.parse('15'),
        name: 'repayment',
        sourceID: checking,
        destinationID: card,
      ),
      entry(
        id: uuid(14),
        date: DateTime.utc(2027, 4, 4),
        amount: Decimal.parse('4'),
        name: 'refund',
        sourceID: card,
      ),
      charge(15, source: card, date: DateTime.utc(2027, 4, 7), amount: '-11'),
      charge(16, source: card, date: DateTime.utc(2027, 4, 9), amount: '-9'),
      charge(17, source: card, date: DateTime.utc(2027, 4, 10), amount: '-16'),
      charge(18, source: card, date: DateTime.utc(2027, 5, 1), amount: '-23'),
    ],
  );
}

void main() {
  final card = uuid(1);
  final checking = uuid(2);

  group('cardStatement', () {
    test('normalizes the account id at construction', () {
      const raw = 'ABCDEFAB-0000-4000-8000-000000000001';

      final statement = CardStatement(
        accountID: raw,
        currentCycle: DateRange(
          DateTime.utc(2027, 3, 10),
          DateTime.utc(2027, 4, 10),
        ),
        nextCut: DateTime.utc(2027, 4, 10),
        cycleAmount: Decimal.zero,
        payable: Decimal.zero,
      );

      expect(statement.accountID, raw.toLowerCase());
    });

    test('reports the current cycle, next cut, cycle amount and payable', () {
      final state = mainLedger(card, checking);

      final statement = cardStatement(
        ledger: state,
        accountID: card,
        today: DateTime.utc(2027, 4, 7),
      );

      expect(statement, isNotNull);
      expect(statement!.accountID, card);
      expect(
        statement.currentCycle,
        DateRange(DateTime.utc(2027, 3, 10), DateTime.utc(2027, 4, 10)),
      );
      expect(statement.nextCut, DateTime.utc(2027, 4, 10));
      expect(statement.payable, Decimal.parse('106'));
      expect(statement.cycleAmount, Decimal.parse('35'));
      expect(state.entries, hasLength(8));
    });

    test('moves payable with earlier debt alone', () {
      final withDebt = ledger(
        sources: [cardSource(card)],
        entries: [
          charge(
            21,
            source: card,
            date: DateTime.utc(2027, 2, 20),
            amount: '-81',
          ),
        ],
      );
      final withoutDebt = ledger(sources: [cardSource(card)], entries: []);

      expect(
        cardStatement(
          ledger: withDebt,
          accountID: card,
          today: DateTime.utc(2027, 4, 7),
        )!.payable,
        Decimal.parse('81'),
      );
      expect(
        cardStatement(
          ledger: withoutDebt,
          accountID: card,
          today: DateTime.utc(2027, 4, 7),
        )!.payable,
        Decimal.zero,
      );
    });

    test('moves payable with the repayment alone', () {
      LedgerState withRepayment(String amount) {
        return ledger(
          sources: [cardSource(card), checkingSource(checking)],
          entries: [
            charge(
              22,
              source: card,
              date: DateTime.utc(2027, 3, 12),
              amount: '-24',
            ),
            entry(
              id: uuid(23),
              date: DateTime.utc(2027, 4, 3),
              amount: Decimal.parse(amount),
              name: 'repayment',
              sourceID: checking,
              destinationID: card,
            ),
          ],
        );
      }

      Decimal payable(String amount) {
        return cardStatement(
          ledger: withRepayment(amount),
          accountID: card,
          today: DateTime.utc(2027, 4, 7),
        )!.payable;
      }

      expect(payable('15'), Decimal.parse('9'));
      expect(payable('30'), Decimal.zero);
    });

    test(
      'counts a future same-cycle charge in payable but not cycleAmount',
      () {
        LedgerState withFuture(DateTime date) {
          return ledger(
            sources: [cardSource(card)],
            entries: [charge(24, source: card, date: date, amount: '-9')],
          );
        }

        final beforeCut = cardStatement(
          ledger: withFuture(DateTime.utc(2027, 4, 9)),
          accountID: card,
          today: DateTime.utc(2027, 4, 7),
        )!;
        final atCut = cardStatement(
          ledger: withFuture(DateTime.utc(2027, 4, 10)),
          accountID: card,
          today: DateTime.utc(2027, 4, 7),
        )!;

        expect(beforeCut.payable, Decimal.parse('9'));
        expect(beforeCut.cycleAmount, Decimal.zero);
        expect(atCut.payable, Decimal.zero);
        expect(atCut.cycleAmount, Decimal.zero);
      },
    );

    test('excludes later-cycle charges from payable', () {
      final state = ledger(
        sources: [cardSource(card)],
        entries: [
          charge(
            25,
            source: card,
            date: DateTime.utc(2027, 5, 1),
            amount: '-23',
          ),
        ],
      );

      final statement = cardStatement(
        ledger: state,
        accountID: card,
        today: DateTime.utc(2027, 4, 7),
      )!;

      expect(statement.payable, Decimal.zero);
      expect(statement.cycleAmount, Decimal.zero);
    });

    test('starts a new cycle on the cut day', () {
      final state = mainLedger(card, checking);

      final statement = cardStatement(
        ledger: state,
        accountID: card,
        today: DateTime.utc(2027, 4, 10),
      )!;

      expect(
        statement.currentCycle,
        DateRange(DateTime.utc(2027, 4, 10), DateTime.utc(2027, 5, 10)),
      );
      expect(statement.nextCut, DateTime.utc(2027, 5, 10));
      expect(statement.payable, Decimal.parse('145'));
      expect(statement.cycleAmount, Decimal.parse('16'));
    });

    test('closes the cycle on the day before the cut', () {
      final state = mainLedger(card, checking);

      final statement = cardStatement(
        ledger: state,
        accountID: card,
        today: DateTime.utc(2027, 4, 9),
      )!;

      expect(
        statement.currentCycle,
        DateRange(DateTime.utc(2027, 3, 10), DateTime.utc(2027, 4, 10)),
      );
      expect(statement.nextCut, DateTime.utc(2027, 4, 10));
      expect(statement.payable, Decimal.parse('106'));
      expect(statement.cycleAmount, Decimal.parse('44'));
    });

    test('counts an opening balance in payable outside the cycle', () {
      final state = ledger(
        sources: [cardSource(card)],
        entries: [
          Entry(
            id: uuid(26),
            date: DateTime.utc(2027, 1, 5),
            amount: Decimal.parse('-50'),
            name: 'Opening balance',
            sourceID: card,
            includeInAnalysis: false,
            systemKind: SystemEntryKind.openingBalance,
          ),
          charge(
            27,
            source: card,
            date: DateTime.utc(2027, 3, 12),
            amount: '-20',
          ),
        ],
      );

      final statement = cardStatement(
        ledger: state,
        accountID: card,
        today: DateTime.utc(2027, 4, 7),
      )!;

      expect(statement.payable, Decimal.parse('70'));
      expect(statement.cycleAmount, Decimal.parse('20'));
    });

    test('floors a positive balance at zero payable', () {
      final state = ledger(
        sources: [cardSource(card), checkingSource(checking)],
        entries: [
          charge(
            28,
            source: card,
            date: DateTime.utc(2027, 3, 12),
            amount: '-10',
          ),
          entry(
            id: uuid(29),
            date: DateTime.utc(2027, 4, 3),
            amount: Decimal.parse('30'),
            name: 'repayment',
            sourceID: checking,
            destinationID: card,
          ),
        ],
      );

      final statement = cardStatement(
        ledger: state,
        accountID: card,
        today: DateTime.utc(2027, 4, 7),
      )!;

      expect(statement.payable, Decimal.zero);
      expect(statement.cycleAmount, Decimal.parse('10'));
    });

    test('ignores analysis exclusions for both amounts', () {
      final leaf = uuid(30);
      final state = ledger(
        sources: [cardSource(card)],
        entries: [
          entry(
            id: uuid(31),
            date: DateTime.utc(2027, 3, 12),
            amount: Decimal.parse('-30'),
            name: 'hidden',
            sourceID: card,
            includeInAnalysis: false,
          ),
          entry(
            id: uuid(32),
            date: DateTime.utc(2027, 3, 13),
            amount: Decimal.parse('-40'),
            name: 'excluded',
            categoryID: leaf,
            sourceID: card,
          ),
        ],
        categories: {
          leaf: category(
            leaf,
            name: 'leaf',
            kind: CategoryKind.expense,
            includeInAnalysis: false,
          ),
        },
      );

      final statement = cardStatement(
        ledger: state,
        accountID: card,
        today: DateTime.utc(2027, 4, 7),
      )!;

      expect(statement.payable, Decimal.parse('70'));
      expect(statement.cycleAmount, Decimal.parse('70'));
    });

    test('counts flagged transfers in payable but not cycleAmount', () {
      final savings = uuid(33);
      LedgerState transfers(String amount, {required bool outOfCard}) {
        return ledger(
          sources: [cardSource(card), flaggedSavingsSource(savings)],
          entries: [
            entry(
              id: uuid(34),
              date: DateTime.utc(2027, 3, 12),
              amount: Decimal.parse(amount),
              name: 'transfer',
              sourceID: outOfCard ? card : savings,
              destinationID: outOfCard ? savings : card,
            ),
          ],
        );
      }

      final out = cardStatement(
        ledger: transfers('20', outOfCard: true),
        accountID: card,
        today: DateTime.utc(2027, 4, 7),
      )!;
      final into = cardStatement(
        ledger: transfers('20', outOfCard: false),
        accountID: card,
        today: DateTime.utc(2027, 4, 7),
      )!;

      expect(out.payable, Decimal.parse('20'));
      expect(out.cycleAmount, Decimal.zero);
      expect(into.payable, Decimal.zero);
      expect(into.cycleAmount, Decimal.zero);
    });

    test('counts active pocket activity in payable but not cycleAmount', () {
      final pocketID = uuid(35);
      final state = ledger(
        sources: [
          cardSource(card, subPocketIDs: {pocketID}),
          MoneySource.pocket(pocket(pocketID, name: 'reserve')),
        ],
        entries: [
          entry(
            id: uuid(36),
            date: DateTime.utc(2027, 3, 12),
            amount: Decimal.parse('-5'),
            name: 'pocket charge',
            sourceID: pocketID,
          ),
        ],
      );

      final statement = cardStatement(
        ledger: state,
        accountID: card,
        today: DateTime.utc(2027, 4, 7),
      )!;

      expect(statement.payable, Decimal.parse('5'));
      expect(statement.cycleAmount, Decimal.zero);
    });

    test('excludes archived pocket activity from payable', () {
      final pocketID = uuid(37);
      final state = ledger(
        sources: [
          cardSource(card, subPocketIDs: {pocketID}),
          MoneySource.pocket(
            pocket(
              pocketID,
              name: 'reserve',
              lifecycle: LifecycleState.archived,
            ),
          ),
        ],
        entries: [
          entry(
            id: uuid(38),
            date: DateTime.utc(2027, 3, 12),
            amount: Decimal.parse('-5'),
            name: 'pocket charge',
            sourceID: pocketID,
          ),
        ],
      );

      final statement = cardStatement(
        ledger: state,
        accountID: card,
        today: DateTime.utc(2027, 4, 7),
      )!;

      expect(statement.payable, Decimal.zero);
    });

    test('drops entries touching unknown holders from payable', () {
      final state = ledger(
        sources: [cardSource(card)],
        entries: [
          charge(
            39,
            source: card,
            date: DateTime.utc(2027, 3, 12),
            amount: '-100',
          ),
          entry(
            id: uuid(40),
            date: DateTime.utc(2027, 3, 13),
            amount: Decimal.parse('50'),
            name: 'orphan transfer',
            sourceID: uuid(43),
            destinationID: card,
          ),
        ],
      );

      final statement = cardStatement(
        ledger: state,
        accountID: card,
        today: DateTime.utc(2027, 4, 7),
      )!;

      expect(statement.payable, Decimal.parse('100'));
    });

    test('returns null for ineligible cards', () {
      final active = ledger(sources: [cardSource(card)], entries: []);
      final spending = ledger(
        sources: [
          MoneySource.account(
            account(uuid(41), name: 'cash', type: AccountType.cash),
          ),
        ],
        entries: [],
      );
      final day = DateTime.utc(2027, 4, 7);

      expect(
        cardStatement(ledger: active, accountID: uuid(42), today: day),
        isNull,
      );
      expect(
        cardStatement(ledger: spending, accountID: uuid(41), today: day),
        isNull,
      );
      expect(
        cardStatement(
          ledger: ledger(
            sources: [cardSource(card, lifecycle: LifecycleState.archived)],
            entries: [],
          ),
          accountID: card,
          today: day,
        ),
        isNull,
      );
      expect(
        cardStatement(
          ledger: ledger(
            sources: [cardSource(card, statementDay: null)],
            entries: [],
          ),
          accountID: card,
          today: day,
        ),
        isNull,
      );
    });

    test('clamps cuts in short months', () {
      final february = ledger(
        sources: [cardSource(card, statementDay: 31)],
        entries: [],
      );

      final short = cardStatement(
        ledger: february,
        accountID: card,
        today: DateTime.utc(2027, 2, 15),
      )!;
      expect(short.nextCut, DateTime.utc(2027, 2, 28));
      expect(
        short.currentCycle,
        DateRange(DateTime.utc(2027, 1, 31), DateTime.utc(2027, 2, 28)),
      );

      final leap = cardStatement(
        ledger: february,
        accountID: card,
        today: DateTime.utc(2028, 2, 15),
      )!;
      expect(leap.nextCut, DateTime.utc(2028, 2, 29));
    });

    test('rolls cuts over the year end', () {
      final state = ledger(sources: [cardSource(card)], entries: []);

      final statement = cardStatement(
        ledger: state,
        accountID: card,
        today: DateTime.utc(2026, 12, 20),
      )!;

      expect(
        statement.currentCycle,
        DateRange(DateTime.utc(2026, 12, 10), DateTime.utc(2027, 1, 10)),
      );
      expect(statement.nextCut, DateTime.utc(2027, 1, 10));
    });

    test('normalizes the account id and the day', () {
      const rawCard = 'ABCDEFAB-0000-4000-8000-000000000001';
      const rawChecking = 'ABCDEFAB-0000-4000-8000-000000000002';
      final cardID = rawCard.toLowerCase();
      final state = ledger(
        sources: [cardSource(cardID), checkingSource(rawChecking)],
        entries: [
          charge(
            51,
            source: cardID,
            date: DateTime.utc(2027, 3, 12),
            amount: '-24',
          ),
          charge(
            52,
            source: cardID,
            date: DateTime.utc(2027, 4, 7),
            amount: '-11',
          ),
          charge(
            53,
            source: cardID,
            date: DateTime.utc(2027, 4, 8),
            amount: '-6',
          ),
        ],
      );

      final statement = cardStatement(
        ledger: state,
        accountID: rawCard,
        today: DateTime.utc(2027, 4, 7, 15, 30),
      )!;

      expect(statement.accountID, cardID);
      expect(statement.nextCut, DateTime.utc(2027, 4, 10));
      expect(statement.payable, Decimal.parse('41'));
      expect(statement.cycleAmount, Decimal.parse('35'));
    });
  });
}
