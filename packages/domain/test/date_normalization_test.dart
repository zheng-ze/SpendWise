import 'package:domain/domain.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

void main() {
  final a = uuid(1);
  final may1 = DateTime.utc(2026, 5, 1);

  group('Entry.date names a calendar day', () {
    test('a local value keeps the day its components read', () {
      expect(entry(sourceID: a, date: DateTime(2026, 5, 1)).date, may1);
    });

    test('a utc value keeps its day', () {
      expect(entry(sourceID: a, date: DateTime.utc(2026, 5, 1)).date, may1);
    });

    test('a time of day is dropped', () {
      expect(
        entry(sourceID: a, date: DateTime(2026, 5, 1, 23, 59, 59, 999)).date,
        may1,
      );
      expect(
        entry(sourceID: a, date: DateTime.utc(2026, 5, 1, 12, 30)).date,
        may1,
      );
    });

    test('a local and a utc value naming one day store the same date', () {
      final local = entry(sourceID: a, date: DateTime(2026, 5, 1)).date;
      final utc = entry(sourceID: a, date: DateTime.utc(2026, 5, 1)).date;

      expect(local, utc);
    });

    test('the stored date is utc whatever it was given', () {
      expect(entry(sourceID: a, date: DateTime(2026, 5, 1)).date.isUtc, isTrue);
    });
  });

  group('AnalysisItem.date names a calendar day', () {
    AnalysisItem itemOn(DateTime date) => AnalysisItem(
      bucketID: null,
      amount: Decimal.fromInt(10),
      date: date,
      kind: CategoryKind.expense,
    );

    test('a local value keeps the day its components read', () {
      expect(itemOn(DateTime(2026, 5, 1)).date, may1);
    });

    test('a time of day is dropped', () {
      expect(itemOn(DateTime.utc(2026, 5, 1, 23, 59, 59, 999)).date, may1);
    });
  });

  group('windows over a normalized day', () {
    final may = DateRange(DateTime.utc(2026, 5, 1), DateTime.utc(2026, 6, 1));
    final april = DateRange(DateTime.utc(2026, 4, 1), may.start);
    final june = DateRange(may.end, DateTime.utc(2026, 7, 1));

    test('a local month bound builds the same window as a utc one', () {
      final localBuilt = DateRange(DateTime(2026, 5, 1), DateTime(2026, 6, 1));

      expect(localBuilt.contains(may1), may.contains(may1));
    });

    test('the first and last of a month fall inside it', () {
      expect(may.contains(may1), isTrue);
      expect(may.contains(DateTime.utc(2026, 5, 31)), isTrue);
    });

    test('a day is excluded from the neighbouring windows', () {
      expect(april.contains(may1), isFalse);
      expect(june.contains(DateTime.utc(2026, 5, 31)), isFalse);
    });

    test('every day of a month tiles into exactly one adjacent window', () {
      for (var day = 1; day <= 31; day++) {
        final date = DateTime.utc(2026, 5, day);

        expect(may.contains(date), isTrue, reason: '$date left may');
        expect(june.contains(date), isFalse);
      }
    });

    test('an entry recorded locally stays in the month it was recorded in', () {
      final ledger = LedgerState();
      ledger.addAccount(account(a));
      ledger.addEntry(
        entry(
          amount: Decimal.fromInt(-100),
          sourceID: a,
          date: DateTime(2026, 5, 1),
        ),
      );
      final items = Accounting.analysisItems(ledger);

      expect(items.total(interval: may), Decimal.fromInt(100));
      expect(items.total(interval: april), Decimal.zero);
    });
  });
}
