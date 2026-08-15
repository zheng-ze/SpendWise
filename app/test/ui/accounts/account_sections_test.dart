import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/accounts/account_sections.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);
  final now = DateTime.utc(2026, 7, 20);

  test(
    'groups active accounts by type in the fixed order, skipping empty types',
    () {
      final cash = Account(
        id: 'a0000000-0000-0000-0000-000000000001',
        name: 'Wallet',
        type: AccountType.cash,
      );
      final card = Account(
        id: 'a0000000-0000-0000-0000-000000000002',
        name: 'Visa',
        type: AccountType.card,
        statementDay: 15,
      );
      final checking = Account(
        id: 'a0000000-0000-0000-0000-000000000003',
        name: 'Checking',
        type: AccountType.checking,
      );

      final state = LedgerState(
        moneySources: {
          card.id: MoneySource.account(card),
          checking.id: MoneySource.account(checking),
          cash.id: MoneySource.account(cash),
        },
      );

      final sections = accountSections(state, now: now);

      expect(sections.map((s) => s.type), [
        AccountType.cash,
        AccountType.checking,
        AccountType.card,
      ]);
    },
  );

  test('excludes an archived account from its section', () {
    final active = Account(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Active',
      type: AccountType.cash,
    );
    final archived = Account(
      id: 'a0000000-0000-0000-0000-000000000002',
      name: 'Archived',
      type: AccountType.cash,
      lifecycle: LifecycleState.archived,
    );

    final state = LedgerState(
      moneySources: {
        active.id: MoneySource.account(active),
        archived.id: MoneySource.account(archived),
      },
    );

    final sections = accountSections(state, now: now);

    expect(sections.single.rows.map((r) => r.name), ['Active']);
  });

  test(
    'a row totals its own balance plus its active pockets, excluding an archived pocket',
    () {
      final account = Account(
        id: 'a0000000-0000-0000-0000-000000000001',
        name: 'Checking',
        type: AccountType.checking,
        subPocketIDs: {
          'a0000000-0000-0000-0000-000000000002',
          'a0000000-0000-0000-0000-000000000003',
        },
      );
      final activePocket = SubPocket(
        id: 'a0000000-0000-0000-0000-000000000002',
        name: 'Rent',
      );
      final archivedPocket = SubPocket(
        id: 'a0000000-0000-0000-0000-000000000003',
        name: 'Old',
        lifecycle: LifecycleState.archived,
      );

      final state = LedgerState(
        moneySources: {
          account.id: MoneySource.account(account),
          activePocket.id: MoneySource.pocket(activePocket),
          archivedPocket.id: MoneySource.pocket(archivedPocket),
        },
        entries: {
          for (final e in [
            Entry(amount: dec('100'), name: 'own', sourceID: account.id),
            Entry(amount: dec('30'), name: 'pocket', sourceID: activePocket.id),
            Entry(
              amount: dec('999'),
              name: 'archived pocket',
              sourceID: archivedPocket.id,
            ),
          ])
            e.id: e,
        },
      );

      final row = accountSections(state, now: now).single.rows.single;

      expect(row.ownBalance, dec('100'));
      expect((row.amount as SingleTotal).total, dec('130'));
      expect(row.pockets.map((p) => p.name), ['Rent']);
      expect(row.pockets.single.balance, dec('30'));
    },
  );

  test(
    'non-card section header sums row totals, negative when liabilities dominate',
    () {
      final a = Account(
        id: 'a0000000-0000-0000-0000-000000000001',
        name: 'A',
        type: AccountType.checking,
      );
      final b = Account(
        id: 'a0000000-0000-0000-0000-000000000002',
        name: 'B',
        type: AccountType.checking,
      );

      final state = LedgerState(
        moneySources: {
          a.id: MoneySource.account(a),
          b.id: MoneySource.account(b),
        },
        entries: {
          for (final e in [
            Entry(amount: dec('-50'), name: 'x', sourceID: a.id),
            Entry(amount: dec('-60'), name: 'y', sourceID: b.id),
          ])
            e.id: e,
        },
      );

      final header =
          accountSections(state, now: now).single.header as SubtotalHeader;

      expect(header.subtotal, dec('-110'));
    },
  );

  test(
    'card section header sums payable and outstanding separately over its rows',
    () {
      final cardA = Account(
        id: 'a0000000-0000-0000-0000-000000000001',
        name: 'Card A',
        type: AccountType.card,
        statementDay: 15,
      );
      final cardB = Account(
        id: 'a0000000-0000-0000-0000-000000000002',
        name: 'Card B',
        type: AccountType.card,
        statementDay: 15,
      );

      final state = LedgerState(
        moneySources: {
          cardA.id: MoneySource.account(cardA),
          cardB.id: MoneySource.account(cardB),
        },
        entries: {
          for (final e in [
            Entry(
              amount: dec('-40'),
              name: 'a spend',
              sourceID: cardA.id,
              date: DateTime.utc(2026, 7, 16),
            ),
            Entry(
              amount: dec('-25'),
              name: 'b spend',
              sourceID: cardB.id,
              date: DateTime.utc(2026, 7, 16),
            ),
          ])
            e.id: e,
        },
      );

      final header =
          accountSections(state, now: now).single.header as CardHeader;

      expect(header.payable, dec('65'));
      expect(header.outstanding, dec('65'));
    },
  );

  test(
    'a card row carries payable and outstanding instead of a single total',
    () {
      final card = Account(
        id: 'a0000000-0000-0000-0000-000000000001',
        name: 'Card',
        type: AccountType.card,
        statementDay: 15,
      );

      final state = LedgerState(
        moneySources: {card.id: MoneySource.account(card)},
        entries: {
          for (final e in [
            Entry(
              amount: dec('-40'),
              name: 'spend',
              sourceID: card.id,
              date: DateTime.utc(2026, 7, 16),
            ),
          ])
            e.id: e,
        },
      );

      final row = accountSections(state, now: now).single.rows.single;
      final amount = row.amount as CardAmounts;

      expect(amount.payable, dec('40'));
      expect(amount.outstanding, dec('40'));
    },
  );
}
