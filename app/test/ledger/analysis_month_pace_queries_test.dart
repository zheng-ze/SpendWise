import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/ledger.dart';

import 'analysis_pace_fixture.dart';
import 'analysis_test_support.dart';

Decimal _d(String value) => Decimal.parse(value);

Future<void> _loadFixture(Ledger ledger, ManualRunner runner) async {
  addPaceHistory(ledger);
  await settle(runner, ledger);
}

void main() {
  group('readMonthPace', () {
    test('the seed at its pinned day has spend and no usual yet', () async {
      final queries = await setupSeededAnalysis(today: paceToday);

      final result = queries.readMonthPace();

      expect(result.state, AnalysisQueryState.ready);
      expect(result.value?.spentSoFar, _d('167.40'));
      expect(result.value?.usual, isNull);
      expect(result.value?.completeMonthCount, 2);
    });

    test('the fixture through the ledger gives the AC1 figures', () async {
      final setup = setupAnalysis(today: paceToday);
      await _loadFixture(setup.ledger, setup.runner);

      final result = setup.queries.readMonthPace();
      final pace = result.value!;

      expect(result.state, AnalysisQueryState.ready);
      expect(pace.completeMonthCount, 10);
      expect(pace.spentSoFar, _d('167.40'));
      expect(pace.usual!.usualMonth, _d('841.32'));
      expect(pace.usual!.usualByToday, _d('81.42'));
      expect(pace.usual!.gap, _d('85.98'));
      expect(identical(setup.queries.readMonthPace(), result), isTrue);
    });

    test(
      'a pending revision keeps the prior value until items catch up',
      () async {
        final setup = setupAnalysis(today: paceToday);
        await _loadFixture(setup.ledger, setup.runner);
        final before = setup.queries.readMonthPace().value;

        setup.ledger.addEntry(
          Entry(
            id: testId(900),
            amount: _d('-10.00'),
            name: 'extra',
            sourceID: paceAccountID,
            categoryID: paceCategoryIDs[paceDining],
            date: paceToday,
          ),
        );
        final pending = setup.queries.readMonthPace();
        expect(pending.state, AnalysisQueryState.loading);
        expect(pending.value, before);

        await settle(setup.runner, setup.ledger);
        final after = setup.queries.readMonthPace();
        expect(after.state, AnalysisQueryState.ready);
        expect(after.value?.spentSoFar, _d('177.40'));
      },
    );

    test('moving today to the next day recomputes usual by today', () async {
      final setup = setupAnalysis(today: paceToday);
      await _loadFixture(setup.ledger, setup.runner);
      final before = setup.queries.readMonthPace().value!;

      setup.queries.setToday(DateTime.utc(2026, 10, 4));
      final after = setup.queries.readMonthPace().value!;

      expect(before.usual!.usualByToday, _d('81.42'));
      expect(after.usual!.usualByToday, _d('108.56'));
      expect(after.cumulativeSpend, hasLength(4));
    });

    test('rolling into November completes October', () async {
      final setup = setupAnalysis(today: DateTime.utc(2026, 10, 31));
      await _loadFixture(setup.ledger, setup.runner);
      expect(setup.queries.readMonthPace().value?.completeMonthCount, 10);

      setup.queries.setToday(DateTime.utc(2026, 11, 1));
      final pace = setup.queries.readMonthPace().value!;

      expect(pace.month, DateTime.utc(2026, 11, 1));
      expect(pace.completeMonthCount, 11);
      expect(pace.spentSoFar, Decimal.zero);
    });
  });
}
