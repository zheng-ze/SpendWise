import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/analysis_query_result.dart';
import 'package:spendwise/ledger/analysis/breakdowns/analysis_category_scope.dart';
import 'package:spendwise/ledger/analysis/breakdowns/scoped_trend.dart';
import 'package:spendwise/ledger/analysis/category_detail/category_detail.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

import 'analysis_category_detail_test.dart'
    show mainID, childID, accountID, category, today;
import 'analysis_test_support.dart';

void seed(Ledger ledger) {
  final account = Account(
    id: accountID,
    name: 'Bank',
    type: AccountType.checking,
  );
  ledger.addAccount(account);
  ledger.addCategory(category(mainID));
  ledger.addCategory(category(childID, parent: mainID));
}

void addExpense(Ledger ledger, int id, {String bucket = childID}) {
  final entry = Entry(
    id: testId(id),
    name: 'Merchant',
    amount: Decimal.fromInt(-id),
    sourceID: accountID,
    categoryID: bucket,
    date: today,
  );
  ledger.addEntry(entry);
}

AnalysisQueryResult<CategoryDetailPeriod> readPeriod(
  AnalysisQueries queries, {
  String main = mainID,
  AnalysisCategoryScope scope = const AllCategoryScope(),
  AnalysisPeriodMode mode = AnalysisPeriodMode.month,
  CategoryKind kind = CategoryKind.expense,
  DateTime? date,
}) {
  return queries.readCategoryDetailPeriod(
    mainID: main,
    kind: kind,
    scope: scope,
    period: date ?? today,
    mode: mode,
  );
}

AnalysisQueryResult<CategoryDetailSpread> readSpread(
  AnalysisQueries queries, {
  AnalysisCategoryScope scope = const AllCategoryScope(),
  AnalysisPeriodMode mode = AnalysisPeriodMode.month,
  DateTime? end,
  DateTime? selected,
}) {
  return queries.readCategoryDetailSpread(
    mainID: mainID,
    kind: CategoryKind.expense,
    scope: scope,
    endPeriod: end ?? today,
    mode: mode,
    selectedPeriod: selected,
  );
}

void main() {
  test('mixed reads load, publish coherent revisions and retain only same identities', () async {
    final setup = setupAnalysis(today: today);
    seed(setup.ledger);
    addExpense(setup.ledger, 10);
    expect(readPeriod(setup.queries).state, AnalysisQueryState.loading);
    expect(readSpread(setup.queries).value, isNull);
    await settle(setup.runner, setup.ledger);

    final before = readPeriod(setup.queries);
    final beforeSpread = readSpread(setup.queries, selected: today);
    expect(before.state, AnalysisQueryState.ready);
    expect(before.sourceRevision, setup.ledger.revision);
    expect(before.value?.totals.scopeTotal, Decimal.fromInt(10));
    expect(beforeSpread.state, AnalysisQueryState.ready);
    expect(beforeSpread.sourceRevision, setup.ledger.revision);
    expect(beforeSpread.value?.selection?.entryIDs, [testId(10)]);

    addExpense(setup.ledger, 20);
    final pending = readPeriod(setup.queries);
    expect(pending.state, AnalysisQueryState.loading);
    expect(pending.value, same(before.value));
    expect(pending.sourceRevision, before.sourceRevision);
    expect(
      readSpread(setup.queries, selected: today).state,
      AnalysisQueryState.loading,
    );
    expect(
      readPeriod(setup.queries, scope: const DirectCategoryScope()).value,
      isNull,
    );
    await settle(setup.runner, setup.ledger);

    final after = readPeriod(setup.queries);
    final afterSpread = readSpread(setup.queries, selected: today);
    expect(after.sourceRevision, setup.ledger.revision);
    expect(after.value?.totals.scopeTotal, Decimal.fromInt(30));
    expect(afterSpread.value?.selection?.entryIDs, [testId(20), testId(10)]);
    expect(afterSpread.value?.slots.last.total, Decimal.fromInt(30));
  });

  test(
    'normalized requests share memo identity and semantic inputs stay separate',
    () async {
      final setup = setupAnalysis(today: today);
      seed(setup.ledger);
      addExpense(setup.ledger, 10);
      await settle(setup.runner, setup.ledger);
      final first = readPeriod(setup.queries);
      final equivalent = readPeriod(
        setup.queries,
        main: mainID.toUpperCase(),
        date: DateTime(2026, 10, 31, 23),
      );
      expect(equivalent, same(first));
      final staleChild = readPeriod(
        setup.queries,
        scope: SubCategoryScope(accountID),
      );
      expect(staleChild, same(first));
      final child = readPeriod(setup.queries, scope: SubCategoryScope(childID));
      expect(child, isNot(same(first)));
      expect(
        readPeriod(setup.queries, scope: const DirectCategoryScope()),
        isNot(same(first)),
      );
      final income = readPeriod(setup.queries, kind: CategoryKind.income);
      expect(income.value?.totals.scopeTotal, Decimal.zero);
      expect(
        readPeriod(setup.queries, mode: AnalysisPeriodMode.year),
        isNot(same(first)),
      );
      expect(
        readPeriod(setup.queries, date: DateTime.utc(2026, 9)),
        isNot(same(first)),
      );
      final noSelection = readSpread(setup.queries);
      final selected = readSpread(setup.queries, selected: today);
      expect(selected, isNot(same(noSelection)));
      expect(
        readSpread(setup.queries, selected: DateTime(2026, 10, 31, 23)),
        same(selected),
      );
      expect(
        readSpread(setup.queries, selected: DateTime.utc(2026, 9)),
        isNot(same(selected)),
      );
      expect(
        readSpread(setup.queries, end: DateTime.utc(2026, 9)),
        isNot(same(noSelection)),
      );
      expect(
        readSpread(setup.queries, mode: AnalysisPeriodMode.year),
        isNot(same(noSelection)),
      );
      expect(
        readSpread(setup.queries, scope: const DirectCategoryScope()),
        isNot(same(noSelection)),
      );
    },
  );

  test(
    'refresh failure retains financial values as failed and retry recovers',
    () async {
      final setup = setupAnalysis(today: today);
      seed(setup.ledger);
      addExpense(setup.ledger, 10);
      await settle(setup.runner, setup.ledger);
      final before = readPeriod(setup.queries);
      final beforeSpread = readSpread(setup.queries);
      addExpense(setup.ledger, 20);
      setup.runner.pending.last.completeError(StateError('compute failed'));
      await pumpEventQueue();
      expect(readPeriod(setup.queries).state, AnalysisQueryState.failed);
      expect(readPeriod(setup.queries).value, same(before.value));
      expect(readSpread(setup.queries).state, AnalysisQueryState.failed);
      expect(readSpread(setup.queries).value, same(beforeSpread.value));
      final retry = setup.queries.retry();
      expect(readPeriod(setup.queries).state, AnalysisQueryState.loading);
      await settle(setup.runner, setup.ledger);
      await retry;
      expect(readPeriod(setup.queries).state, AnalysisQueryState.ready);
      expect(
        readPeriod(setup.queries).value?.totals.scopeTotal,
        Decimal.fromInt(30),
      );
      expect(readSpread(setup.queries).state, AnalysisQueryState.ready);
    },
  );

  test(
    'day change reevaluates spreads and future failure stays isolated',
    () async {
      final setup = setupAnalysis(today: today);
      seed(setup.ledger);
      await settle(setup.runner, setup.ledger);
      final before = readSpread(setup.queries);
      final invalid = readSpread(setup.queries, end: DateTime.utc(2026, 11));
      expect(invalid.state, AnalysisQueryState.failed);
      expect(invalid.value, isNull);
      expect(readPeriod(setup.queries).state, AnalysisQueryState.ready);
      expect(readSpread(setup.queries), same(before));
      final nextDay = DateTime.utc(2026, 10, 16);
      setup.queries.setToday(nextDay);
      final after = readSpread(setup.queries);
      expect(after, isNot(same(before)));
      expect(after.value?.today, nextDay);
      expect(after.sourceRevision, setup.ledger.revision);
    },
  );
}
