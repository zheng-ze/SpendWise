import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

Decimal money(int value) => Decimal.fromInt(value);

Entry txn(int amount, String source) =>
    entry(amount: money(amount), sourceID: source);

Entry transfer(int amount, {required String from, required String to}) =>
    entry(amount: money(amount), sourceID: from, destinationID: to);

void main() {
  final a = uuid(1);
  final b = uuid(2);
  final p = uuid(3);
  final q = uuid(4);

  group('applies', () {
    test('a non-transfer qualifies on its source alone', () {
      expect(Accounting.applies(txn(-50, a), {a}), isTrue);
      expect(Accounting.applies(txn(-50, a), {b}), isFalse);
    });

    test('a transfer needs both endpoints', () {
      final t = transfer(100, from: a, to: b);

      expect(Accounting.applies(t, {a, b}), isTrue);
      expect(Accounting.applies(t, {a}), isFalse);
      expect(Accounting.applies(t, {b}), isFalse);
      expect(Accounting.applies(t, const <String>{}), isFalse);
    });
  });

  group('balance', () {
    test('nets signed transactions', () {
      final entries = [txn(1000, a), txn(-200, a)];

      expect(
        Accounting.balance(of: a, entries: entries, sourceIDs: {a}),
        money(800),
      );
    });

    test('a transaction only affects its own holder', () {
      final entries = [txn(-50, a)];

      expect(
        Accounting.balance(of: b, entries: entries, sourceIDs: {a, b}),
        Decimal.zero,
      );
      expect(
        Accounting.balance(of: a, entries: entries, sourceIDs: {a, b}),
        money(-50),
      );
    });

    test('a transfer moves between holders', () {
      final entries = [transfer(300, from: a, to: b)];

      expect(
        Accounting.balance(of: a, entries: entries, sourceIDs: {a, b}),
        money(-300),
      );
      expect(
        Accounting.balance(of: b, entries: entries, sourceIDs: {a, b}),
        money(300),
      );
    });

    test('a deleted holder unapplies its transfer to the survivor', () {
      final entries = [txn(1000, a), transfer(300, from: a, to: b)];

      expect(
        Accounting.balance(of: a, entries: entries, sourceIDs: {a, b}),
        money(700),
      );
      expect(
        Accounting.balance(of: a, entries: entries, sourceIDs: {a}),
        money(1000),
      );
    });

    test('a deleted source unapplies its transfer to the survivor', () {
      final entries = [txn(500, b), transfer(300, from: a, to: b)];

      expect(
        Accounting.balance(of: b, entries: entries, sourceIDs: {a, b}),
        money(800),
      );
      expect(
        Accounting.balance(of: b, entries: entries, sourceIDs: {b}),
        money(500),
      );
    });

    test('an empty entry list balances to zero', () {
      expect(
        Accounting.balance(of: a, entries: const [], sourceIDs: {a}),
        Decimal.zero,
      );
    });
  });

  group('accountTotal', () {
    test('funding a pocket moves its own cash but not the account total', () {
      final acc = account(a, subPocketIDs: {p});
      final entries = [txn(1000, a), transfer(400, from: a, to: p)];
      final ids = {a, p};

      expect(
        Accounting.balance(of: a, entries: entries, sourceIDs: ids),
        money(600),
      );
      expect(
        Accounting.balance(of: p, entries: entries, sourceIDs: ids),
        money(400),
      );
      expect(
        Accounting.accountTotal(
          acc,
          entries: entries,
          sourceIDs: ids,
          activePockets: ids,
        ),
        money(1000),
      );
    });

    test('spending from a pocket reduces the pocket and the total', () {
      final acc = account(a, subPocketIDs: {p});
      final entries = [
        txn(1000, a),
        transfer(400, from: a, to: p),
        txn(-100, p),
      ];
      final ids = {a, p};

      expect(
        Accounting.balance(of: p, entries: entries, sourceIDs: ids),
        money(300),
      );
      expect(
        Accounting.accountTotal(
          acc,
          entries: entries,
          sourceIDs: ids,
          activePockets: ids,
        ),
        money(900),
      );
    });

    test('a pocket-to-pocket transfer across accounts moves both totals', () {
      final acc1 = account(a, subPocketIDs: {p});
      final acc2 = account(b, subPocketIDs: {q});
      final ids = {a, p, b, q};
      final entries = [
        txn(1000, a),
        transfer(500, from: a, to: p),
        transfer(200, from: p, to: q),
      ];

      expect(
        Accounting.accountTotal(
          acc1,
          entries: entries,
          sourceIDs: ids,
          activePockets: ids,
        ),
        money(800),
      );
      expect(
        Accounting.accountTotal(
          acc2,
          entries: entries,
          sourceIDs: ids,
          activePockets: ids,
        ),
        money(200),
      );
    });

    test('multiple pockets sum into the account total', () {
      final acc = account(a, subPocketIDs: {p, q});
      final ids = {a, p, q};
      final entries = [
        txn(1000, a),
        transfer(200, from: a, to: p),
        transfer(300, from: a, to: q),
      ];

      expect(
        Accounting.balance(of: a, entries: entries, sourceIDs: ids),
        money(500),
      );
      expect(
        Accounting.accountTotal(
          acc,
          entries: entries,
          sourceIDs: ids,
          activePockets: ids,
        ),
        money(1000),
      );
    });

    test('an archived pocket drops out of the account total', () {
      final acc = account(a, subPocketIDs: {p, q});
      final ids = {a, p, q};
      final entries = [
        txn(1000, a),
        transfer(200, from: a, to: p),
        transfer(300, from: a, to: q),
      ];

      expect(
        Accounting.accountTotal(
          acc,
          entries: entries,
          sourceIDs: ids,
          activePockets: {a, p},
        ),
        money(700),
      );
      expect(acc.subPocketIDs, {p, q});
    });
  });
}
