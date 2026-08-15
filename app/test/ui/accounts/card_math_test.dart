import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/accounts/card_math.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);
  const cardID = 'a0000000-0000-0000-0000-000000000001';
  const otherID = 'a0000000-0000-0000-0000-000000000002';

  group('statementCut clamp matrix', () {
    // now is the 1st of the month after the target, always short of any
    // tested statementDay, so the anchor lands on the target month and the
    // clamp behavior is what each case actually proves.
    final cases = <String, (DateTime now, int statementDay, DateTime want)>{
      'day 28 in February': (
        DateTime.utc(2026, 3, 1),
        28,
        DateTime.utc(2026, 2, 28),
      ),
      'day 29 in February clamps to 28': (
        DateTime.utc(2026, 3, 1),
        29,
        DateTime.utc(2026, 2, 28),
      ),
      'day 29 in leap February lands on 29': (
        DateTime.utc(2028, 3, 1),
        29,
        DateTime.utc(2028, 2, 29),
      ),
      'day 30 in leap February clamps to 29': (
        DateTime.utc(2028, 3, 1),
        30,
        DateTime.utc(2028, 2, 29),
      ),
      'day 30 in a 30-day month lands on 30': (
        DateTime.utc(2026, 5, 1),
        30,
        DateTime.utc(2026, 4, 30),
      ),
      'day 31 in a 30-day month clamps to 30': (
        DateTime.utc(2026, 5, 1),
        31,
        DateTime.utc(2026, 4, 30),
      ),
      'day 31 in a 31-day month lands on 31': (
        DateTime.utc(2026, 8, 1),
        31,
        DateTime.utc(2026, 7, 31),
      ),
    };

    cases.forEach((description, testCase) {
      test(description, () {
        final (now, statementDay, want) = testCase;
        expect(statementCut(statementDay, now), want);
      });
    });
  });

  group('statementCut anchor month', () {
    test('anchors to the current month when today is on the statement day', () {
      final cut = statementCut(15, DateTime.utc(2026, 7, 15));
      expect(cut, DateTime.utc(2026, 7, 15));
    });

    test(
      'anchors to the current month when today is after the statement day',
      () {
        final cut = statementCut(15, DateTime.utc(2026, 7, 20));
        expect(cut, DateTime.utc(2026, 7, 15));
      },
    );

    test(
      'anchors to the previous month when today is before the statement day',
      () {
        final cut = statementCut(15, DateTime.utc(2026, 7, 10));
        expect(cut, DateTime.utc(2026, 6, 15));
      },
    );

    test('crosses a year boundary when anchoring to the previous month', () {
      final cut = statementCut(15, DateTime.utc(2026, 1, 10));
      expect(cut, DateTime.utc(2025, 12, 15));
    });
  });

  group('payable', () {
    test('negates a negative total', () {
      expect(payable(dec('-120')), dec('120'));
    });

    test('clamps to zero for a card in credit', () {
      expect(payable(dec('50')), Decimal.zero);
    });

    test('stays zero for a zero total', () {
      expect(payable(Decimal.zero), Decimal.zero);
    });
  });

  group('outstanding filter matrix', () {
    final cut = DateTime.utc(2026, 7, 15);
    final now = DateTime.utc(2026, 7, 20);

    test('excludes a transfer even though it is negative and in window', () {
      final entries = [
        Entry(
          amount: dec('-40'),
          name: 'repayment',
          sourceID: cardID,
          destinationID: otherID,
          date: DateTime.utc(2026, 7, 16),
        ),
      ];
      expect(outstanding(entries, cardID, cut, now), Decimal.zero);
    });

    test('excludes a positive amount', () {
      final entries = [
        Entry(
          amount: dec('40'),
          name: 'refund',
          sourceID: cardID,
          date: DateTime.utc(2026, 7, 16),
        ),
      ];
      expect(outstanding(entries, cardID, cut, now), Decimal.zero);
    });

    test(
      'excludes an entry sourced from a pocket rather than the card itself',
      () {
        final entries = [
          Entry(
            amount: dec('-40'),
            name: 'pocket spend',
            sourceID: otherID,
            date: DateTime.utc(2026, 7, 16),
          ),
        ];
        expect(outstanding(entries, cardID, cut, now), Decimal.zero);
      },
    );

    test('excludes an entry dated before the cut', () {
      final entries = [
        Entry(
          amount: dec('-40'),
          name: 'old spend',
          sourceID: cardID,
          date: DateTime.utc(2026, 7, 14),
        ),
      ];
      expect(outstanding(entries, cardID, cut, now), Decimal.zero);
    });

    test('excludes an entry dated after now', () {
      final entries = [
        Entry(
          amount: dec('-40'),
          name: 'future spend',
          sourceID: cardID,
          date: DateTime.utc(2026, 7, 21),
        ),
      ];
      expect(outstanding(entries, cardID, cut, now), Decimal.zero);
    });

    test('sums qualifying spend and includes both window boundaries', () {
      final entries = [
        Entry(
          amount: dec('-10'),
          name: 'on the cut',
          sourceID: cardID,
          date: cut,
        ),
        Entry(amount: dec('-15'), name: 'on now', sourceID: cardID, date: now),
      ];
      expect(outstanding(entries, cardID, cut, now), dec('25'));
    });
  });
}
