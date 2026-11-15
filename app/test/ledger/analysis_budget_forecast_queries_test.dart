import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/budgets/budget_forecast.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

import 'analysis_pace_fixture.dart';
import 'analysis_test_support.dart';

Decimal _d(String value) => Decimal.parse(value);

Future<void> _loadFixtureWithBudgets(Ledger ledger, ManualRunner runner) async {
  addPaceHistory(ledger);
  ledger.addBudget(paceCategoryIDs[paceDining], paceDiningLimit);
  ledger.addBudget(paceCategoryIDs[paceGroceries], paceGroceriesLimit);
  ledger.addBudget(paceCategoryIDs[paceTransport], paceTransportLimit);
  await settle(runner, ledger);
}

BudgetForecast _forecastFor(BudgetForecasts forecasts, String categoryKey) {
  return forecasts.categoryBudgets.firstWhere(
    (f) => f.categoryID == paceCategoryIDs[categoryKey],
  );
}

void main() {
  group('readBudgetForecasts', () {
    test('the seed at its pinned day has no forecasts yet', () async {
      final state = LedgerState();
      buildSeed(state, today: paceToday);
      final ledger = Ledger(state: state);
      final cache = AnalysisCache(
        runner: (s) async => Accounting.analysisItems(s),
      )..start(ledger.bus, sourceRevision: () => ledger.revision);
      final queries = AnalysisQueries(
        ledger: ledger,
        cache: cache,
        today: paceToday,
      );
      addTearDown(() async {
        queries.dispose();
        await cache.dispose();
      });
      await pumpEventQueue();

      final result = queries.readBudgetForecasts();

      expect(result.state, AnalysisQueryState.ready);
      expect(result.value?.hasBaseline, isFalse);
      expect(result.value?.completeMonthCount, 2);
      expect(result.value?.allSpending, isNull);
      expect(result.value?.categoryBudgets, isEmpty);
      expect(result.value?.overCount, 0);
    });

    test('the fixture through the ledger gives the AC2 forecasts', () async {
      final setup = setupAnalysis(today: paceToday);
      await _loadFixtureWithBudgets(setup.ledger, setup.runner);

      final result = setup.queries.readBudgetForecasts();
      final forecasts = result.value!;
      final cap = forecasts.allSpending!;

      expect(result.state, AnalysisQueryState.ready);
      expect(_forecastFor(forecasts, paceDining).overBy, _d('98.15'));
      expect(_forecastFor(forecasts, paceGroceries).overBy, isNull);
      expect(_forecastFor(forecasts, paceTransport).overBy, _d('11.07'));
      expect(cap.isDerivedCap, isTrue);
      expect(cap.limit, _d('920'));
      expect(cap.projected, _d('927.30'));
      expect(cap.overBy, _d('7.30'));
      expect(forecasts.overCount, 3);
      expect(identical(setup.queries.readBudgetForecasts(), result), isTrue);
    });

    test('a limit change recomputes once the cache catches up', () async {
      final setup = setupAnalysis(today: paceToday);
      await _loadFixtureWithBudgets(setup.ledger, setup.runner);
      final before = setup.queries.readBudgetForecasts().value!;
      final diningBudget = _forecastFor(before, paceDining).budgetID!;

      setup.ledger.updateBudgetLimit(diningBudget, Decimal.fromInt(600));
      await settle(setup.runner, setup.ledger);
      final after = setup.queries.readBudgetForecasts().value!;

      expect(before.overCount, 3);
      expect(_forecastFor(after, paceDining).overBy, isNull);
      expect(after.allSpending!.limit, _d('1170'));
      expect(after.overCount, 1);
    });
  });
}
