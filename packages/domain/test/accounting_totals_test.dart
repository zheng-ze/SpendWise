import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

Decimal money(int value) => Decimal.fromInt(value);

void main() {
  final a = uuid(1);
  final b = uuid(2);

  group('Accounting.totals', () {
    test('a plain expense counts as expense', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      final e = entry(amount: money(-50), sourceID: a);

      final result = Accounting.totals(
        e,
        ledger,
        sourceIDs: ledger.moneySources.keys.toSet(),
      );

      expect(result.income, Decimal.zero);
      expect(result.expense, money(50));
    });

    test('a plain income counts as income', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      final e = entry(amount: money(1000), sourceID: a);

      final result = Accounting.totals(
        e,
        ledger,
        sourceIDs: ledger.moneySources.keys.toSet(),
      );

      expect(result.income, money(1000));
      expect(result.expense, Decimal.zero);
    });

    test('a transfer with neither holder flagged counts as neither', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addAccount(account(b));
      final e = entry(amount: money(200), sourceID: a, destinationID: b);

      final result = Accounting.totals(
        e,
        ledger,
        sourceIDs: ledger.moneySources.keys.toSet(),
      );

      expect(result.income, Decimal.zero);
      expect(result.expense, Decimal.zero);
    });

    test(
      'a transfer into a treat-as-expense destination counts as expense',
      () {
        final ledger = LedgerState();
        ledger.addAccount(account(a));
        ledger.addAccount(account(b, incomingTransfersAsExpenses: true));
        final e = entry(amount: money(300), sourceID: a, destinationID: b);

        final result = Accounting.totals(
          e,
          ledger,
          sourceIDs: ledger.moneySources.keys.toSet(),
        );

        expect(result.income, Decimal.zero);
        expect(result.expense, money(300));
      },
    );

    test('a transfer out of a treat-as-expense source counts as income', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a, incomingTransfersAsExpenses: true));
      ledger.addAccount(account(b));
      final e = entry(amount: money(300), sourceID: a, destinationID: b);

      final result = Accounting.totals(
        e,
        ledger,
        sourceIDs: ledger.moneySources.keys.toSet(),
      );

      expect(result.income, money(300));
      expect(result.expense, Decimal.zero);
    });

    test('a transfer between two treat-as-expense holders counts as both', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a, incomingTransfersAsExpenses: true));
      ledger.addAccount(account(b, incomingTransfersAsExpenses: true));
      final e = entry(amount: money(300), sourceID: a, destinationID: b);

      final result = Accounting.totals(
        e,
        ledger,
        sourceIDs: ledger.moneySources.keys.toSet(),
      );

      expect(result.income, money(300));
      expect(result.expense, money(300));
    });

    test('an entry excluded from analysis counts as neither', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      final e = entry(
        amount: money(-50),
        sourceID: a,
        includeInAnalysis: false,
      );

      final result = Accounting.totals(
        e,
        ledger,
        sourceIDs: ledger.moneySources.keys.toSet(),
      );

      expect(result.income, Decimal.zero);
      expect(result.expense, Decimal.zero);
    });

    test('an expense whose source holder was removed counts as neither', () {
      final ledger = LedgerState();
      // a is never added, standing in for a holder that was removed.
      final e = entry(amount: money(-50), sourceID: a);

      final result = Accounting.totals(
        e,
        ledger,
        sourceIDs: ledger.moneySources.keys.toSet(),
      );

      expect(result.income, Decimal.zero);
      expect(result.expense, Decimal.zero);
    });

    test(
      'a transfer whose destination holder was removed counts as neither',
      () {
        final ledger = LedgerState();
        ledger.addAccount(account(a, incomingTransfersAsExpenses: true));
        // b is never added, standing in for a holder that was removed.
        final e = entry(amount: money(300), sourceID: a, destinationID: b);

        final result = Accounting.totals(
          e,
          ledger,
          sourceIDs: ledger.moneySources.keys.toSet(),
        );

        expect(result.income, Decimal.zero);
        expect(result.expense, Decimal.zero);
      },
    );
  });
}
