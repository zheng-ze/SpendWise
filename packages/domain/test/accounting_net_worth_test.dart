import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

Decimal money(int value) => Decimal.fromInt(value);

void main() {
  final a = uuid(1);
  final b = uuid(2);
  final p = uuid(3);

  test('net worth splits by sign, not by type', () {
    final ledger = LedgerState();
    ledger.addAccount(account(a, type: AccountType.savings));
    ledger.addAccount(account(b, type: AccountType.card));
    ledger.addEntry(entry(amount: money(1000), sourceID: a));
    ledger.addEntry(entry(amount: money(-300), sourceID: b));

    final worth = Accounting.netWorth(ledger);

    expect(worth.asset, money(1000));
    expect(worth.liability, money(300));
  });

  test('a card in credit is an asset', () {
    final ledger = LedgerState();
    ledger.addAccount(account(a, type: AccountType.card));
    ledger.addEntry(entry(amount: money(250), sourceID: a));

    expect(Accounting.netWorth(ledger), NetWorth(money(250), Decimal.zero));
  });

  test('net worth excludes an account flagged out of it', () {
    final ledger = LedgerState();
    ledger.addAccount(account(a));
    ledger.addAccount(account(b, includeInNetWorth: false));
    ledger.addEntry(entry(amount: money(1000), sourceID: a));
    ledger.addEntry(entry(amount: money(5000), sourceID: b));

    expect(Accounting.netWorth(ledger).asset, money(1000));
  });

  test('net worth counts pocket balances through the parent', () {
    final ledger = LedgerState();
    ledger.addAccount(account(a));
    ledger.addPocket(pocket(p), a);
    ledger.addEntry(entry(amount: money(1000), sourceID: a));
    ledger.addEntry(entry(amount: money(400), sourceID: a, destinationID: p));

    final worth = Accounting.netWorth(ledger);

    expect(worth.asset, money(1000));
    expect(worth.liability, Decimal.zero);
  });

  test('net worth excludes an archived account', () {
    final ledger = LedgerState();
    ledger.addAccount(account(a));
    ledger.addAccount(account(b));
    ledger.addEntry(entry(amount: money(1000), sourceID: a));
    ledger.addEntry(entry(amount: money(5000), sourceID: b));
    ledger.deleteAccount(b);

    expect(Accounting.netWorth(ledger).asset, money(1000));
  });

  test('an archived account still counts as a transfer endpoint', () {
    final ledger = LedgerState();
    ledger.addAccount(account(a));
    ledger.addAccount(account(b));
    ledger.addEntry(entry(amount: money(1000), sourceID: a));
    ledger.addEntry(entry(amount: money(400), sourceID: a, destinationID: b));

    expect(Accounting.netWorth(ledger).asset, money(1000));

    ledger.deleteAccount(b);

    // Archiving drops the account as a subject but keeps it in the existence
    // set, so the transfer out of the survivor keeps applying.
    final worth = Accounting.netWorth(ledger);
    expect(worth.asset, money(600));
    expect(worth.liability, Decimal.zero);
    expect(
      Accounting.balance(
        of: a,
        entries: ledger.entries.values.toList(),
        sourceIDs: ledger.moneySources.keys.toSet(),
      ),
      money(600),
    );
  });

  test('an account-to-account transfer is zero sum for net worth', () {
    final ledger = LedgerState();
    ledger.addAccount(account(a));
    ledger.addAccount(account(b));
    ledger.addEntry(entry(amount: money(1000), sourceID: a));
    ledger.addEntry(entry(amount: money(400), sourceID: a, destinationID: b));

    expect(Accounting.netWorth(ledger).asset, money(1000));
  });

  test('an archived pocket leaves its parent total', () {
    final ledger = LedgerState();
    ledger.addAccount(account(a));
    ledger.addPocket(pocket(p), a);
    ledger.addEntry(entry(amount: money(1000), sourceID: a));
    ledger.addEntry(entry(amount: money(400), sourceID: a, destinationID: p));
    ledger.deletePocket(p);

    expect(Accounting.netWorth(ledger).asset, money(600));
  });

  test('an empty ledger has zero net worth', () {
    final worth = Accounting.netWorth(LedgerState());

    expect(worth.asset, Decimal.zero);
    expect(worth.liability, Decimal.zero);
  });

  test('a pocket is never counted at top level', () {
    final ledger = LedgerState();
    ledger.addAccount(account(a, includeInNetWorth: false));
    ledger.addPocket(pocket(p), a);
    ledger.addEntry(entry(amount: money(1000), sourceID: a));
    ledger.addEntry(entry(amount: money(400), sourceID: a, destinationID: p));

    expect(Accounting.netWorth(ledger).asset, Decimal.zero);
  });

  group('NetWorth value equality', () {
    test('holds by field', () {
      expect(NetWorth(money(10), money(2)), NetWorth(money(10), money(2)));
      expect(
        NetWorth(money(10), money(2)).hashCode,
        NetWorth(money(10), money(2)).hashCode,
      );
      expect(
        NetWorth(money(10), money(2)),
        isNot(NetWorth(money(2), money(10))),
      );
    });
  });
}
