import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/summaries/month_pace.dart';

import 'analysis_pace_fixture.dart';

Decimal _d(String value) => Decimal.parse(value);

AnalysisItem _expense(String amount, DateTime date) {
  return AnalysisItem(
    bucketID: null,
    amount: _d(amount),
    date: date,
    kind: CategoryKind.expense,
  );
}

MonthPace _fixturePace({DateTime? today, DateTime? firstRecordMonth}) {
  return monthPace(
    items: paceItems(),
    firstRecordMonth: firstRecordMonth ?? paceFirstRecordMonth,
    today: today ?? paceToday,
  );
}

List<Decimal> _cumulativeValues(MonthPace pace) {
  return [for (final day in pace.cumulativeSpend) day.cumulative];
}

void main() {
  group('fixture on 3 Oct 2026', () {
    final pace = _fixturePace();

    test('reports the month and its calendar facts', () {
      expect(pace.month, DateTime.utc(2026, 10, 1));
      expect(pace.today, paceToday);
      expect(pace.daysInMonth, 31);
      expect(pace.daysAfterToday, 28);
      expect(pace.completeMonthCount, 10);
    });

    test('reports spent so far without the committed 15 Oct row', () {
      expect(pace.spentSoFar, _d('167.40'));
    });

    test('reports the usual month, usual by today and the gap', () {
      final usual = pace.usual!;

      expect(usual.usualMonth, _d('841.32'));
      expect(usual.usualByToday, _d('81.42'));
      expect(usual.usualByMonthEnd, _d('841.32'));
      expect(usual.gap, _d('85.98'));
    });

    test('accumulates spend per elapsed day from the month start', () {
      expect(pace.cumulativeSpend.map((day) => day.day), [
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 2),
        DateTime.utc(2026, 10, 3),
      ]);
      expect(_cumulativeValues(pace), [
        _d('45.00'),
        _d('118.50'),
        _d('167.40'),
      ]);
    });
  });

  group('threshold', () {
    test('three complete months make the usual available', () {
      final pace = _fixturePace(firstRecordMonth: DateTime.utc(2026, 7, 1));
      final usual = pace.usual!;

      expect(pace.completeMonthCount, 3);
      expect(usual.usualMonth, _d('869.73'));
      expect(usual.usualByToday, _d('84.17'));
      expect(usual.gap, _d('83.23'));
    });

    test('two complete months leave the usual unavailable', () {
      final pace = _fixturePace(firstRecordMonth: DateTime.utc(2026, 8, 1));

      expect(pace.completeMonthCount, 2);
      expect(pace.usual, isNull);
      expect(pace.spentSoFar, _d('167.40'));
    });

    test('no records gives no baseline, a zero series and zero spend', () {
      final pace = monthPace(
        items: [],
        firstRecordMonth: null,
        today: paceToday,
      );

      expect(pace.completeMonthCount, 0);
      expect(pace.usual, isNull);
      expect(pace.spentSoFar, Decimal.zero);
      expect(_cumulativeValues(pace), [
        Decimal.zero,
        Decimal.zero,
        Decimal.zero,
      ]);
    });

    test('spent so far is not gated on the first record month', () {
      final pace = monthPace(
        items: paceItems(),
        firstRecordMonth: null,
        today: paceToday,
      );

      expect(pace.usual, isNull);
      expect(pace.spentSoFar, _d('167.40'));
    });
  });

  group('baseline', () {
    test('counts a complete month without expense as zero', () {
      final pace = monthPace(
        items: [
          _expense('300.00', DateTime.utc(2026, 7, 10)),
          _expense('600.00', DateTime.utc(2026, 9, 10)),
        ],
        firstRecordMonth: DateTime.utc(2026, 7, 1),
        today: paceToday,
      );

      expect(pace.completeMonthCount, 3);
      expect(pace.usual!.usualMonth, _d('300.00'));
      expect(pace.usual!.usualByToday, _d('29.03'));
    });

    test('looks back 11 months and drops older spending', () {
      final pace = monthPace(
        items: [
          _expense('1000.00', DateTime.utc(2025, 10, 31)),
          _expense('110.00', DateTime.utc(2025, 11, 1)),
          _expense('220.00', DateTime.utc(2026, 9, 30)),
        ],
        firstRecordMonth: DateTime.utc(2025, 1, 1),
        today: paceToday,
      );

      expect(pace.completeMonthCount, 11);
      expect(pace.usual!.usualMonth, _d('30.00'));
    });

    test('crosses the year boundary from Feb to Dec of the prior year', () {
      final pace = monthPace(
        items: [
          _expense('500.00', DateTime.utc(2026, 1, 20)),
          _expense('120.00', DateTime.utc(2026, 2, 15)),
        ],
        firstRecordMonth: paceFirstRecordMonth,
        today: DateTime.utc(2027, 1, 3),
      );

      expect(pace.completeMonthCount, 11);
      expect(pace.usual!.usualMonth, _d('10.91'));
      expect(pace.usual!.usualByToday, _d('1.06'));
    });

    test('rounds an exact half cent away from zero', () {
      final pace = monthPace(
        items: [_expense('0.02', DateTime.utc(2026, 7, 10))],
        firstRecordMonth: DateTime.utc(2026, 7, 1),
        today: DateTime.utc(2026, 11, 15),
      );

      expect(pace.completeMonthCount, 4);
      expect(pace.usual!.usualMonth, _d('0.01'));
    });
  });

  group('elapsed days', () {
    test('day 1 gives a one element series', () {
      final pace = _fixturePace(today: DateTime.utc(2026, 10, 1));

      expect(_cumulativeValues(pace), [_d('45.00')]);
      expect(pace.spentSoFar, _d('45.00'));
      expect(pace.usual!.usualByToday, _d('27.14'));
      expect(pace.usual!.gap, _d('17.86'));
    });

    test('last day includes the whole month and meets the usual month', () {
      final pace = _fixturePace(today: DateTime.utc(2026, 10, 31));

      expect(pace.cumulativeSpend, hasLength(31));
      expect(pace.daysAfterToday, 0);
      expect(pace.spentSoFar, _d('227.40'));
      expect(pace.cumulativeSpend.last.cumulative, _d('227.40'));
      expect(pace.usual!.usualByToday, pace.usual!.usualMonth);
    });

    test('a 30 day month reports 30 days', () {
      final pace = _fixturePace(today: DateTime.utc(2026, 11, 15));

      expect(pace.month, DateTime.utc(2026, 11, 1));
      expect(pace.daysInMonth, 30);
      expect(pace.daysAfterToday, 15);
      expect(pace.cumulativeSpend, hasLength(15));
      expect(pace.completeMonthCount, 11);
    });
  });

  group('value semantics', () {
    test('equal inputs give equal results with equal hash codes', () {
      final first = _fixturePace();
      final second = _fixturePace();

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.usual, second.usual);
      expect(first.usual.hashCode, second.usual.hashCode);
      expect(first.cumulativeSpend.first, second.cumulativeSpend.first);
      expect(
        first.cumulativeSpend.first.hashCode,
        second.cumulativeSpend.first.hashCode,
      );
    });

    test('different inputs give different results', () {
      final first = _fixturePace();

      expect(first, isNot(_fixturePace(today: DateTime.utc(2026, 10, 2))));
      expect(
        first,
        isNot(_fixturePace(firstRecordMonth: DateTime.utc(2026, 8, 1))),
      );
    });

    test('the series cannot be modified', () {
      final pace = _fixturePace();

      expect(
        () => pace.cumulativeSpend.add(pace.cumulativeSpend.first),
        throwsUnsupportedError,
      );
    });
  });
}
